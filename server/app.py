import base64
import hashlib
import hmac
import io
import os
import time
from collections import defaultdict, deque

import requests
from concurrent.futures import ThreadPoolExecutor, as_completed
from pywebpush import webpush, WebPushException
from flask import Flask, jsonify, request, Response

from preorder_delivery import register_preorder_routes
from native_customer_push import send_customer_apns_order_event, send_customer_apns_broadcast

app = Flask(__name__)
register_preorder_routes(app, webpush)
_hits = defaultdict(deque)
_cache = {}

def _limited(ip):
    now=time.time(); q=_hits[ip]
    while q and q[0] < now-3600: q.popleft()
    if len(q) >= 20: return True
    q.append(now); return False

@app.get("/health")
def health():
    return jsonify(ok=True, ai=bool(os.getenv("OPENAI_API_KEY")), ai_research_revision="20261025b", push_revision="20261029a")

@app.post("/api/ai-story-background")
def ai_story_background():
    # Paid image generation is admin-only. Verify before touching OpenAI.
    supplied=(request.form.get("admin_code") or "").strip()
    if not _verify_admin_code(supplied):
        return jsonify(error="Unauthorized"),401
    key=os.getenv("OPENAI_API_KEY","").strip()
    if not key: return jsonify(error="AI unavailable"),503
    if _limited(request.headers.get("X-Forwarded-For",request.remote_addr or "").split(",")[0].strip()):
        return jsonify(error="Too many requests"),429

    cover=request.files.get("cover")
    if not cover: return jsonify(error="Cover required"),400
    raw=cover.read(8*1024*1024+1)
    if not raw or len(raw)>8*1024*1024: return jsonify(error="Invalid cover"),400

    title=(request.form.get("title") or "")[:160]
    category=(request.form.get("category") or "")[:100]
    desc=(request.form.get("description") or "")[:500]
    digest=hashlib.sha256(raw+title.encode()+category.encode()).hexdigest()
    cached=_cache.get(digest)
    if cached and cached[0] > time.time()-86400:
        return Response(cached[1],mimetype="image/png",headers={"Cache-Control":"private, max-age=86400"})

    mime=cover.mimetype if cover.mimetype in ("image/png","image/jpeg","image/webp") else "image/jpeg"
    data_url=f"data:{mime};base64,{base64.b64encode(raw).decode()}"
    prompt=f"""Using the supplied BOOK COVER as visual reference, create a premium vertical Instagram Story BACKGROUND for Muhajeer Books.
Analyze the cover visually yourself: its visible subjects (bird, flower, building, moon, landscape, person/object), mood, palette, era and motifs. Echo those subjects in an artistic environmental way so this exact book leads to a distinct design. If a bird is visibly present, use compatible bird/nature motifs; if architecture is present, use compatible architectural atmosphere; if floral, use botanical atmosphere.
Book metadata for context only: title={title}; category={category}; description={desc}
STRICT: background/decor only. NO words, letters, numbers, logos, prices, UI, fake book, watermark. Do not reproduce or redraw the book cover itself. Keep the central upper-middle region relatively uncluttered for the original cover and the lower 40% calm/readable for app text overlays. Sophisticated editorial retail illustration, cohesive palette, vertical."""
    files={"image":("cover.jpg",raw,mime)}
    form={"model":"gpt-image-1.5","prompt":prompt,"size":"1024x1536","quality":"medium","output_format":"png"}
    ir=requests.post("https://api.openai.com/v1/images/edits",
      headers={"Authorization":f"Bearer {key}"},data=form,files=files,timeout=240)
    if ir.status_code>=400:
        detail=""
        try: detail=(ir.json().get("error") or {}).get("message","")
        except Exception: detail=ir.text[:300]
        print(f"AI image API failed status={ir.status_code} detail={detail}",flush=True)
        return jsonify(error="AI image generation failed", detail=detail[:180]),502
    ij=ir.json(); data=(ij.get("data") or [{}])[0]
    if data.get("b64_json"): out=base64.b64decode(data["b64_json"])
    elif data.get("url"):
        rr=requests.get(data["url"],timeout=60); rr.raise_for_status(); out=rr.content
    else: return jsonify(error="AI image missing"),502
    _cache[digest]=(time.time(),out)
    return Response(out,mimetype="image/png",headers={"Cache-Control":"private, max-age=86400"})


def _chat_json(instructions, payload, max_tokens=1200, web_search=False,
               web_search_required=False, search_context_size="medium",
               diagnostics=None):
    """Responses API, including safe diagnostics for authenticated admin routes.

    Do not return fabricated book research when the provider cannot search.
    """
    def note(code):
        if diagnostics is not None:
            diagnostics["code"]=code

    key=os.getenv("OPENAI_API_KEY","").strip()
    if not key:
        note("missing_key")
        print("Admin AI: OPENAI_API_KEY is missing",flush=True)
        return None

    configured=os.getenv("OPENAI_TEXT_MODEL","").strip()
    # 4.1-mini is an API-compatible fallback when the newer models are
    # unavailable to the particular API project (not ChatGPT subscription).
    models=[]
    for model in (configured,"gpt-6-luna","gpt-4.1-mini","gpt-4.1"):
        if model and model not in models:
            models.append(model)
    token_budget=max(max_tokens,3200) if web_search else max_tokens
    deadline=time.monotonic()+185
    for model in models:
        budget=token_budget
        for attempt in range(2):
            remaining=deadline-time.monotonic()
            if remaining<7:
                note("timeout")
                return None
            data={
                "model":model,"instructions":instructions,
                "input":payload,"max_output_tokens":budget,
            }
            if model.startswith(("gpt-5","gpt-6","o")):
                data["reasoning"]={"effort":"low"}
            if web_search:
                data["tools"]=[{"type":"web_search","search_context_size":search_context_size}]
                data["tool_choice"]="required" if web_search_required else "auto"
            try:
                r=requests.post(
                    "https://api.openai.com/v1/responses",
                    headers={"Authorization":f"Bearer {key}",
                             "Content-Type":"application/json"},
                    json=data,timeout=(8,min(70,max(5,remaining-3))),
                )
            except requests.RequestException as exc:
                note("network")
                print(f"Admin AI network error model={model} type={type(exc).__name__}",flush=True)
                break
            if r.status_code>=400:
                code=""
                try:
                    upstream=r.json().get("error") or {}
                    code=str(upstream.get("code") or upstream.get("type") or "").lower()
                    message=str(upstream.get("message") or "").lower()
                except (ValueError,AttributeError):
                    message=""
                print(f"Admin AI provider rejected model={model} status={r.status_code} code={code[:60]}",flush=True)
                if r.status_code==401:
                    note("invalid_key")
                    return None
                if r.status_code==403:
                    note("permission")
                    return None
                if r.status_code==429:
                    if any(x in (code+" "+message) for x in ("quota","billing","budget","spend_limit","insufficient")):
                        note("quota")
                    else:
                        note("rate_limit")
                    return None
                if r.status_code in (400,404):
                    note("model_or_request")
                    break
                note("provider_error")
                break
            try:
                result=r.json()
            except ValueError:
                note("invalid_response")
                break
            chunks=[]
            for item in result.get("output",[]):
                if not isinstance(item,dict):
                    continue
                for part in item.get("content",[]):
                    if isinstance(part,dict) and part.get("type")=="output_text":
                        chunks.append(str(part.get("text") or ""))
            out="".join(chunks).strip() or str(result.get("output_text") or "").strip()
            if out:
                if diagnostics is not None:
                    diagnostics.clear()
                return out
            incomplete=result.get("incomplete_details") or {}
            reason=str(incomplete.get("reason") or "")
            note("empty_response")
            print(f"Admin AI empty output model={model} status={result.get('status')} reason={reason} budget={budget}",flush=True)
            if result.get("status")=="incomplete" and reason=="max_output_tokens" and attempt==0:
                budget=min(budget*2,14000)
                continue
            break
    return None


def _admin_ai_failure(diagnostics):
    """Give the authenticated administrator an actionable, non-secret error."""
    code=diagnostics.get("code","unknown")
    messages={
        "missing_key":"OpenAI API kaliti serverda yo‘q. Railway Variables ichidagi OPENAI_API_KEY ni tekshiring.",
        "invalid_key":"OpenAI API kaliti yaroqsiz (401). Railway OPENAI_API_KEY ni tekshiring.",
        "permission":"OpenAI API loyihasiga model yoki internet qidiruv uchun ruxsat berilmagan (403). Project va API key ruxsatlarini tekshiring.",
        "quota":"OpenAI API loyihasida kvota yoki xarajat limiti tugagan (429). Aynan API kaliti tegishli loyihaning Billing va Limits sozlamalarini tekshiring.",
        "rate_limit":"OpenAI API tezlik limitiga yetdi (429). Birozdan so‘ng qayta urinib ko‘ring.",
        "model_or_request":"AI modeli yoki API so‘rovi qabul qilinmadi. Railway OPENAI_TEXT_MODEL sozlamasini va API loyiha ruxsatlarini tekshiring.",
        "network":"Server OpenAI API bilan bog‘lana olmadi. Railway tarmoq va deploy loglarini tekshiring.",
        "timeout":"OpenAI qidiruvi vaqt chegarasidan oshdi. Kamroq kitob bilan qayta urinib ko‘ring.",
        "empty_response":"OpenAI javobidan matn olinmadi. So‘rovni qayta yuboring yoki API loglarini tekshiring.",
        "provider_error":"OpenAI xizmatida vaqtinchalik xatolik. Qayta urinib ko‘ring.",
        "invalid_response":"OpenAI kutilmagan formatda javob qaytardi.",
    }
    return jsonify(error=messages.get(code,"AI internet qidiruvi serverda ishlamadi. Railway loglarini tekshiring."),
                   code=code),503


def _free_norm(value):
    import re, unicodedata
    s=unicodedata.normalize("NFKD",str(value or "").lower())
    s="".join(ch for ch in s if not unicodedata.combining(ch))
    s=s.replace("’","'").replace("ʻ","'").replace("‘","'")
    s=s.replace("o'","o").replace("g'","g")
    s=re.sub(r"[^a-z0-9а-яёқғҳў\s]"," ",s)
    return re.sub(r"\s+"," ",s).strip()

def _free_tokens(value):
    import re
    stop={"kitob","kitobi","kitoblar","bormi","narxi","qancha","necha","sotuvda","mavjud",
          "haqida","kerak","menga","bor","yoq","yo'q","qil","qiling","qilsang","iltimos","qaysi",
          "nima","uchun","bilan","ham","shu","bir","eng","dan","ning","degan","top","topib","ber"}
    return [w for w in re.findall(r"[a-z0-9а-яёқғҳў]+",_free_norm(value)) if len(w)>=2 and w not in stop]

def _free_similarity(a,b):
    from difflib import SequenceMatcher
    a=_free_norm(a); b=_free_norm(b)
    if not a or not b: return 0.0
    if a in b or b in a: return 1.0
    return SequenceMatcher(None,a,b).ratio()

def _free_catalog(body):
    rows=body.get("books") if isinstance(body.get("books"),list) else []
    out=[]
    for b in rows[:5000]:
      if not isinstance(b,dict): continue
      try: price=max(0,int(float(b.get("price") or 0)))
      except Exception: price=0
      try: stock=max(0,int(b.get("stock") or 0))
      except Exception: stock=0
      out.append({
        "id":str(b.get("id") or ""),
        "title":str(b.get("title") or "").strip(),
        "author":str(b.get("author") or "").strip(),
        "category":str(b.get("category") or "").strip(),
        "description":str(b.get("description") or "").strip(),
        "price":price,"stock":stock,
      })
    return out

def _free_rank_books(query,books,available_only=False):
    q=_free_norm(query); qtokens=_free_tokens(query)
    ranked=[]
    for x in books:
      if available_only and x["stock"]<=0: continue
      title=_free_norm(x["title"]); author=_free_norm(x["author"])
      category=_free_norm(x["category"]); desc=_free_norm(x["description"])
      score=0.0
      if q and (q in title or title in q): score+=12
      if q and (q in author or author in q): score+=8
      for w in qtokens:
        if w in title: score+=5
        elif w in author: score+=4
        elif w in category: score+=3
        elif w in desc: score+=1.5
        else:
          best=0.0
          for token in (title+" "+author+" "+category).split():
            if abs(len(token)-len(w))<=3:
              best=max(best,_free_similarity(w,token))
          if best>=0.84: score+=3.5
          elif best>=0.74 and len(w)>=4: score+=1.5
      if q:
        sim=max(_free_similarity(q,title),_free_similarity(q,author))
        if sim>=0.82: score+=8*sim
        elif sim>=0.64: score+=3*sim
      if score>0: ranked.append((score,x["stock"]>0,x))
    ranked.sort(key=lambda z:(z[0],z[1],z[2]["stock"]),reverse=True)
    return [x[2] for x in ranked]

def _free_recommendations(query,books):
    import re
    q=_free_norm(query)
    available=[x for x in books if x["stock"]>0]
    if not available: return []
    themes=[
      (("diniy","islom","alloh","namoz","quron","hadis","iymon","duo","ruhiy"),
       ("diniy","islom","quron","hadis","marif")),
      (("pul","biznes","boy","moliya","tadbirkor","savdo"),
       ("biznes","moliya","pul","boy","tadbirkor")),
      (("psixolog","motivats","rivojlan","odat","tafakkur","fikrlash"),
       ("psixolog","rivojlan","motivats","tafakkur","odat")),
      (("oila","nikoh","er xotin","farzand","tarbiya"),
       ("oila","nikoh","farzand","tarbiya")),
      (("tarix","biograf","hayoti","siyrat"),
       ("tarix","biograf","siyrat")),
      (("bola","bolalar","farzandga"),
       ("bolalar","bola")),
      (("roman","badiiy","hikoya","qissa","detektiv","sarguzasht","qiziqarli"),
       ("badiiy","roman","hikoya","qissa","detektiv","sarguzasht")),
      (("ozbek","uzbek"),("ozbek","uzbek")),
      (("jahon","chet el","xorij"),("jahon","turk","rus","ingliz")),
    ]
    wanted=[]
    for triggers,terms in themes:
      if any(t in q for t in triggers): wanted.extend(terms)
    max_price=None
    m=re.search(r"(\d{1,3})\s*(?:ming|k)\b",q)
    if m: max_price=int(m.group(1))*1000
    else:
      nums=[int(n.replace(",","")) for n in re.findall(r"\b\d{4,6}\b",q)]
      if nums and any(t in q for t in ("gacha","dan oshmasin","ostida","kam")): max_price=max(nums)
    if max_price is not None:
      available=[x for x in available if x["price"]<=max_price]
    scored=[]
    for x in available:
      hay=_free_norm(" ".join((x["title"],x["author"],x["category"],x["description"])))
      score=sum(3 if t in _free_norm(x["category"]) else 1 for t in wanted if t in hay)
      score+=min(x["stock"],5)*0.08
      if x["description"]: score+=0.35
      scored.append((score,x))
    if "arzon" in q or max_price is not None:
      scored.sort(key=lambda z:(z[0],-z[1]["price"]),reverse=True)
    else:
      scored.sort(key=lambda z:(z[0],z[1]["stock"]),reverse=True)
    if wanted:
      positive=[x for s,x in scored if s>0.45]
      if positive: return positive[:6]
    chosen=[]; seen=set()
    for _,x in scored:
      key=_free_norm(x["category"])
      if key not in seen:
        chosen.append(x); seen.add(key)
      if len(chosen)>=6: break
    return chosen or [x for _,x in scored[:6]]

def _free_book_lines(rows,include_desc=False):
    lines=[]
    for x in rows[:6]:
      price=f"₩{x['price']:,}" if x["price"] else "narxi ko‘rsatilmagan"
      status=f"omborda {x['stock']} dona" if x["stock"]>0 else "hozircha mavjud emas"
      author=f" — {x['author']}" if x["author"] else ""
      line=f"• {x['title']}{author} — {price} — {status}"
      if include_desc and x["description"]:
        d=x["description"].strip()
        if len(d)>150: d=d[:147].rstrip()+"…"
        line+=f"\n  {d}"
      lines.append(line)
    return "\n".join(lines)

@app.post("/api/ai-assistant")
def ai_assistant():
    """Always-free customer assistant. No OpenAI/API-credit call is made here."""
    body=request.get_json(silent=True) or {}
    query=str(body.get("query","")).strip()[:1000]
    mode=str(body.get("mode","advisor")).strip().lower()
    history=body.get("history") if isinstance(body.get("history"),list) else []
    q=_free_norm(query)
    books=_free_catalog(body)

    # Natural follow-up such as "yana", "boshqasi-chi?" reuses the previous
    # customer request without any paid language model.
    followup_words=("yana","boshqasi","boshqa variant","yana tavsiya","yana bormi")
    if any(x in q for x in followup_words):
      previous=""
      for item in reversed(history[-10:]):
        if isinstance(item,dict) and str(item.get("role",""))=="user":
          candidate=str(item.get("text","")).strip()
          if candidate and _free_norm(candidate)!=q:
            previous=candidate
            break
      if previous:
        query=previous+" boshqa variant"
        q=_free_norm(query)

    private_words=("tannarx","ulgurji","wholesale","supplier","yetkazib beruvchi narx","marja","margin",
                   "foyda","profit","admin","parol","password","token","mijoz malumot","buyurtma malumot")
    if any(_free_norm(x) in q for x in private_words):
      return jsonify(text="Bu ichki ma’lumot mijoz yordamchisida ochilmaydi. Kitoblar, narx, mavjudlik, tavsiya va yetkazib berish bo‘yicha yordam bera olaman.")

    if not q:
      return jsonify(text="Savolingizni yozing 🙂 Masalan: “Psixologiyadan qanday kitob tavsiya qilasan?” yoki “Binafsha shulasi bormi?”")

    if any(x in q for x in ("rahmat","tashakkur","raxmat")):
      return jsonify(text="Arzimaydi 🙂 Yana kitob tanlashda yordam beraman.")
    if any(x in q for x in ("yaxshimisan","qalaysan","qalesan","nima gap")):
      return jsonify(text="Yaxshi, rahmat 🙂 Sizga kitob topish yoki tanlashda yordam beraymi?")
    greetings=("salom","assalomu alaykum","assalom","hello","hi")
    if q in greetings or any(q.startswith(x+" ") for x in greetings):
      return jsonify(text="Assalomu alaykum! 🙂 Muhajeer Books yordamchisiman. Istasangiz mavzu yoki kayfiyatingizni ayting — hozir omborda bor kitoblardan tavsiya qilaman.")
    if any(x in q for x in ("nima qila olasan","nimalarni bilasan","qanday yordam")):
      return jsonify(text="Bepul yordam bera olaman: xato yozilgan kitob nomini ham topishga harakat qilaman, muallif/kategoriya bo‘yicha qidiraman, ombordagi kitoblardan didingizga mos tavsiya beraman, narx va mavjudlikni aytaman, narx oralig‘ida kitob topaman va yetkazib berish shartlarini tushuntiraman.")

    if any(x in q for x in ("yetkazib","pochta","dostavka","delivery","택배","necha kunda","yetib kel")):
      if any(x in q for x in ("qachon","necha kun","necha kunda","qancha vaqt","yetib")):
        return jsonify(text="Buyurtma pochtaga topshirilgandan keyin odatda 1–3 ish kunida yetkaziladi.")
      return jsonify(text="Koreya bo‘ylab 택배 ₩4,000. 4 ta yoki undan ko‘p mahsulotda odatda yetkazib berish bepul. Set 1 ta mahsulot hisoblanadi; chegirma yoki pochta kiritilgan setlarda ilovada ko‘rsatilgan joriy shart amal qiladi.")

    if mode=="marketing":
      rows=_free_rank_books(query,books,available_only=True)
      if not rows: rows=_free_recommendations(query,books)
      if rows:
        x=rows[0]
        desc=x["description"].strip()
        if len(desc)>180: desc=desc[:177].rstrip()+"…"
        body_text=(desc+"\n\n") if desc else ""
        return jsonify(text=f"📚 {x['title']}\n{body_text}💰 ₩{x['price']:,}\n📦 Omborda {x['stock']} dona\n\nBuyurtma uchun Muhajeer Books ilovasidan foydalaning.")
      return jsonify(text="Reklama matni tayyorlash uchun katalogdagi kitob nomini yozing.")

    recommendation_words=("tavsiya","maslahat","nima oq","nima o'q","qanday kitob",
                          "qiziqarli","oqishga","o'qishga","arzon","tanlab ber","mos kitob")
    if any(x in q for x in recommendation_words):
      rows=_free_recommendations(query,books)
      if rows:
        return jsonify(text="Hozir omborda bor kitoblardan sizga shularni tavsiya qilaman:\n"+_free_book_lines(rows,True))
      return jsonify(text="Hozir shu so‘rovga mos, omborda bor kitob topilmadi. Boshqa mavzu yoki narx oralig‘ini ayting.")

    matches=_free_rank_books(query,books)
    if matches:
      return jsonify(text=_free_book_lines(matches[:6], any(x in q for x in ("haqida","mazmun","nima haqida","qanday"))))

    themed=_free_recommendations(query,books)
    theme_tokens=("dini","islom","psix","biznes","moliya","oila","nikoh","tarix","bola","roman","badiiy","quron")
    if any(_free_similarity(t,w)>=0.72 for t in theme_tokens for w in _free_tokens(query)) and themed:
      return jsonify(text="Shu mavzuga yaqin, hozir omborda bor kitoblar:\n"+_free_book_lines(themed,True))

    return jsonify(text="Bu gapdan aniq kitob yoki mavzuni topolmadim. Boshqacharoq yozib ko‘ring — imlo xatosi bo‘lsa ham kitob nomi, muallif, mavzu yoki masalan “20 minggacha kitob tavsiya qil” deb yozishingiz mumkin.")


def _admin_rpc_call(name, params):
    url=os.getenv("SUPABASE_URL","https://rytfhjvhjxnbhgitowho.supabase.co").rstrip("/")+"/functions/v1/admin-rpc"
    anon=os.getenv("SUPABASE_ANON_KEY","sb_publishable_5lDr_sw4bu8g3x8LCVzp4g_sHSTMBiO").strip()
    try:
      r=requests.post(url,headers={"apikey":anon,"Authorization":f"Bearer {anon}","Content-Type":"application/json"},
        json={"name":name,"params":params},timeout=20)
      if r.status_code>=400: return None
      data=r.json() if r.content else {}
      if isinstance(data,str):
        import json
        data=json.loads(data)
      if not isinstance(data,dict) or data.get("ok") is not True: return None
      return data.get("data")
    except Exception:
      return None


@app.post("/api/push/send")
def send_push_notification():
    body=request.get_json(silent=True) or {}
    supplied=str(body.get("admin_code","")).strip()
    if not _verify_admin_code(supplied):
        return jsonify(error="Unauthorized"),401

    title=str(body.get("title","")).strip()[:120]
    message=str(body.get("message","")).strip()[:1000]
    if not title or not message:
        return jsonify(error="Sarlavha va xabar matnini kiriting."),400

    private_key=os.getenv("VAPID_PRIVATE_KEY","").strip()
    if not private_key:
        return jsonify(error="Push server sozlanmagan."),503

    subscriptions=_admin_rpc_call("admin_push_subscriptions",{"p_secret":supplied})
    if subscriptions is None:
        return jsonify(error="Obunachilarni yuklab bo‘lmadi."),502
    if not isinstance(subscriptions,list):
        subscriptions=[]

    message_id=_admin_rpc_call("admin_push_message_create",{
      "p_secret":supplied,
      "p_title":title,
      "p_body":message,
      "p_total":len(subscriptions),
    })
    if not message_id:
        return jsonify(error="Xabarnoma statistikasi yaratilmadi."),502

    import json
    payload=json.dumps({
      "message_id":str(message_id),
      "title":title,
      "body":message,
      "url":"/?open=notifications",
      "open_inbox":True,
      "icon":"/icons/Icon-192.png",
      "badge":"/icons/Icon-192.png",
    },ensure_ascii=False)

    def deliver(row):
      try:
        info={
          "endpoint":str(row.get("endpoint","")),
          "keys":{
            "p256dh":str(row.get("p256dh","")),
            "auth":str(row.get("auth","")),
          },
        }
        webpush(
          subscription_info=info,
          data=payload,
          vapid_private_key=private_key,
          vapid_claims={"sub":"https://muhajeer-books-live-production.up.railway.app"},
          ttl=86400,
          timeout=12,
        )
        return True
      except WebPushException as exc:
        print(f"WebPush failed status={getattr(getattr(exc,'response',None),'status_code',None)}",flush=True)
        return False
      except Exception as exc:
        print(f"WebPush failed error={type(exc).__name__}",flush=True)
        return False

    success=0
    failure=0
    with ThreadPoolExecutor(max_workers=8) as pool:
      futures=[pool.submit(deliver,row) for row in subscriptions if isinstance(row,dict)]
      for future in as_completed(futures):
        if future.result(): success+=1
        else: failure+=1

    # iOS announcements are public marketing notices; never relay an
    # individual customer's order details through this broadcast route.
    ios = send_customer_apns_broadcast(supplied, title, message, _admin_rpc_call)
    _admin_rpc_call("admin_push_message_finish",{
      "p_secret":supplied,
      "p_id":str(message_id),
      "p_success":success+ios["sent"],
      "p_failure":failure+ios["failed"],
    })
    return jsonify(
      ok=True, id=str(message_id),
      total=len(subscriptions)+ios["devices"],
      success=success+ios["sent"], failure=failure+ios["failed"],
      web_total=len(subscriptions), web_success=success, web_failure=failure,
      ios_total=ios["devices"], ios_success=ios["sent"], ios_failure=ios["failed"],
      ios_configured=ios["configured"], ios_lookup_error=ios.get("lookup_error",False),
    )


def _send_admin_apns_order_event(event_secret, notification, body):
    """Only authenticated admin-enrolled iOS devices receive private orders.
    APNs requires the Apple Developer APNs auth key (not the ASC upload key).
    """
    key_id=os.getenv("APPLE_APNS_KEY_ID","").strip()
    team_id=os.getenv("APPLE_APNS_TEAM_ID","8HJA5K2BQJ").strip()
    private_key=os.getenv("APPLE_APNS_PRIVATE_KEY","").strip().replace("\\n","\n")
    if not (key_id and team_id and private_key):
        print("Admin native APNs disabled: Apple APNs key not configured",flush=True)
        return {"configured":False,"devices":0,"sent":0,"failed":0}
    device_rows=_admin_rpc_call("event_admin_apns_devices",{
        "p_event_secret":event_secret,
    })
    if not isinstance(device_rows,list):
        print("Admin native APNs: recipient lookup unavailable",flush=True)
        return {"configured":True,"devices":0,"sent":0,"failed":0}
    tokens=[str(x.get("token","")) for x in device_rows if isinstance(x,dict)]
    tokens=[x for x in tokens if len(x)>=64 and all(c in "0123456789abcdef" for c in x)]
    if not tokens:
        return {"configured":True,"devices":0,"sent":0,"failed":0}
    try:
        import httpx
        import jwt
        bearer=jwt.encode({"iss":team_id,"iat":int(time.time())},
            private_key,algorithm="ES256",headers={"kid":key_id})
        payload={"aps":{"alert":{
            "title":notification["title"],
            "body":notification["body"][:950],
        },"sound":"default"},"kind":"admin_new_order",
            "order_id":str(body.get("order_id") or "")[:64],
            "order_number":int(body.get("order_number") or 0)}
        headers={"authorization":f"bearer {bearer}",
                 "apns-topic":"com.muhajeerbooks.app",
                 "apns-push-type":"alert",
                 "apns-priority":"10"}
        sent=failed=0
        with httpx.Client(http2=True,timeout=8.0) as client:
            for token in tokens:
                try:
                    response=client.post(
                        f"https://api.push.apple.com/3/device/{token}",
                        json=payload,headers=headers)
                    if response.status_code==200:
                        sent+=1
                    else:
                        failed+=1
                        reason=""
                        try: reason=str(response.json().get("reason",""))[:80]
                        except Exception: pass
                        print(f"Admin APNs status={response.status_code} reason={reason}",flush=True)
                except Exception as exc:
                    failed+=1
                    print(f"Admin APNs delivery error: {type(exc).__name__}",flush=True)
        return {"configured":True,"devices":len(tokens),"sent":sent,"failed":failed}
    except Exception as exc:
        print(f"Admin APNs setup error: {type(exc).__name__}",flush=True)
        return {"configured":True,"devices":len(tokens),"sent":0,"failed":len(tokens)}


@app.post("/api/push/apns-status")
def admin_apns_status():
    body=request.get_json(silent=True) or {}
    if not _verify_admin_code(str(body.get("admin_code","")).strip()):
        return jsonify(error="Unauthorized"),401
    configured=all(os.getenv(name,"").strip() for name in
                   ("APPLE_APNS_KEY_ID","APPLE_APNS_PRIVATE_KEY"))
    return jsonify(ok=True,configured=bool(configured))


@app.post("/api/push/order-event")
def order_push_event():
    body=request.get_json(silent=True) or {}
    supplied=str(request.headers.get("X-Muhajeer-Push-Secret","")).strip()
    expected=os.getenv("ORDER_PUSH_SECRET","").strip()
    if not expected or not hmac.compare_digest(supplied, expected):
        return jsonify(error="Unauthorized"),401

    phone=str(body.get("phone","")).strip()[:40]
    event=str(body.get("event","")).strip().lower()
    if event not in ("submitted","accepted","shipping","review_reminder","admin_new_order","admin_test"):
        return jsonify(error="Invalid event"),400
    is_admin_event = event in ("admin_new_order", "admin_test")
    if not is_admin_event and len(phone)<8:
        return jsonify(error="Invalid event"),400

    if is_admin_event:
        # Private order details MUST go only to devices enrolled with a
        # verified admin secret, never to a customer matching an admin phone.
        subscriptions=_admin_rpc_call("event_admin_order_push_subscriptions",{
            "p_event_secret":supplied,
        })
        if subscriptions is None:
            return jsonify(error="Verified admin subscriptions unavailable"),502
        print(f"Verified admin WebPush recipients: {len(subscriptions) if isinstance(subscriptions,list) else 0}",flush=True)
    else:
        subscriptions=_admin_rpc_call("event_push_subscriptions",{
            "p_event_secret":supplied,
            "p_phone":phone,
        })
        if subscriptions is None:
            return jsonify(error="Subscriptions unavailable"),502
    if not isinstance(subscriptions,list):
        subscriptions=[]

    private_key=os.getenv("VAPID_PRIVATE_KEY","").strip()
    if not private_key:
        subscriptions=[]

    try:
      order_no=int(body.get("order_number") or 0)
    except Exception:
      order_no=0
    try:
      total=int(body.get("total") or 0)
    except Exception:
      total=0
    order_label=f"#{order_no}" if order_no>0 else "buyurtmangiz"
    items=body.get("items") if isinstance(body.get("items"),list) else []
    item_count=0
    receipt_parts=[]
    for item in items[:8]:
      if not isinstance(item,dict): continue
      try: qty=max(1,int(item.get("quantity") or 1))
      except Exception: qty=1
      item_count+=qty
      title=str(item.get("title") or "Kitob").strip()
      if title: receipt_parts.append(f"{title} ×{qty}")
    total_text=f"₩{total:,}" if total>0 else ""

    if event=="admin_test":
      # A diagnostic can reach only the existing verified administrator devices.
      # It never creates an order, writes customer inboxes or broadcasts.
      notifications=[{
        "title":"Muhajeer Books • Push sinovi",
        "body":"Bu texnik sinov xabari. Yangi buyurtma emas.",
        "tag":"muhajeer-admin-push-test",
      }]
    elif event=="admin_new_order":
      notifications=[{
        "title":"Yangi buyurtma tushdi 🛒",
        "body":(
          f"{order_label}"
          + (f" • {item_count} ta kitob" if item_count else "")
          + (f" • Jami {total_text}" if total_text else "")
          + (f" • {'; '.join(receipt_parts)}" if receipt_parts else "")
        )[:950],
        "tag":f"admin-order-{order_no or 'new'}",
      }]
    elif event=="submitted":
      notifications=[
        {
          "title":"Buyurtma yuborildi ✅",
          "body":f"Muhajeer Books • {order_label} buyurtmangiz yuborildi. Tez orada ko‘rib chiqamiz.",
          "tag":f"order-{order_no or 'new'}-submitted",
        },
        {
          "title":"Muhajeer Books cheki 🧾",
          "body":(
            f"{order_label} • {item_count} ta kitob"
            + (f" • Jami {total_text}" if total_text else "")
            + (f" • {'; '.join(receipt_parts)}" if receipt_parts else "")
          )[:950],
          "tag":f"order-{order_no or 'new'}-receipt",
        },
      ]
    elif event=="shipping":
      notifications=[{
        "title":"Buyurtmangiz jo‘natildi 🚚",
        "body":f"{order_label} pochtaga topshirildi. Yetkazib berish holati va kuzatuv raqamini “Mening buyurtmalarim” bo‘limida tekshiring.",
        "tag":f"order-{order_no or 'new'}-shipping",
      }]
    elif event=="review_reminder":
      notifications=[{
        "title":"📚 Kitobingiz haqida fikr bildiring",
        "body":f"{order_label} kitoblari haqida baho va sharh qoldiring. “Mening buyurtmalarim” bo‘limiga o‘ting.",
        "tag":f"order-{order_no or 'new'}-review",
      }]
    else:
      customer_note=str(body.get("customer_note") or "").strip()[:500]
      notifications=[{
        "title":"Buyurtma qabul qilindi ✅",
        "body":(
          f"Muhajeer Books • {order_label} buyurtmangiz qabul qilindi."
          + (f" Jami {total_text}." if total_text else "")
          + (f"\nIzoh: {customer_note}" if customer_note else "")
        )[:950],
        "tag":f"order-{order_no or 'new'}-accepted",
      }]

    # Transactional xabarni in-app Bildirishnomalar tarixiga ham yozamiz.
    # Web Push yo'qolsa ham mijoz ilovaga kirganda chek/status xabarini ko'radi.
    for note in notifications:
      if event in ("shipping", "review_reminder", "admin_new_order", "admin_test"):
        # Durable in-app message is already recorded by the order/cron
        # transaction, avoiding a duplicate notification row.
        continue
      _admin_rpc_call("event_push_message_log",{
        "p_event_secret":supplied,
        "p_phone":phone,
        "p_title":note["title"],
        "p_body":note["body"],
        "p_kind":"receipt" if "cheki" in note["title"].lower() else event,
        "p_order_number":order_no if order_no>0 else None,
      })

    # Admin APNs is independent of Web Push (browser subscription).
    native_result = _send_admin_apns_order_event(supplied,notifications[0],body) if is_admin_event else send_customer_apns_order_event(supplied, phone, notifications, body, _admin_rpc_call)

    import json
    success=0
    failure=0
    for note in notifications:
      exact_order_link = event in ("shipping", "review_reminder")
      order_id = str(body.get("order_id") or "").strip()
      order_target = "/?open=orders"
      if order_id:
        from urllib.parse import quote
        order_target += "&order_id=" + quote(order_id[:64], safe="")
      if order_no > 0:
        order_target += "&order_number=" + str(order_no)
      payload=json.dumps({
        "title":note["title"],
        "body":note["body"],
        "url":"/?open=admin_orders" if is_admin_event else (order_target if exact_order_link else "/?open=notifications"),
        "open_inbox":not is_admin_event and not exact_order_link,
        "tag":note["tag"],
        "icon":"/icons/Icon-192.png",
        "badge":"/icons/Icon-192.png",
      },ensure_ascii=False)
      for row in subscriptions:
        if not isinstance(row,dict): continue
        try:
          webpush(
            subscription_info={
              "endpoint":str(row.get("endpoint","")),
              "keys":{"p256dh":str(row.get("p256dh","")),"auth":str(row.get("auth",""))},
            },
            data=payload,
            vapid_private_key=private_key,
            vapid_claims={"sub":"https://muhajeer-books-live-production.up.railway.app"},
            ttl=86400,
            timeout=12,
          )
          success+=1
        except Exception as exc:
          print(f"Order WebPush failed error={type(exc).__name__}",flush=True)
          failure+=1
    return jsonify(ok=True,subscriptions=len(subscriptions),sent=success,failed=failure,apns=native_result)


def _verify_admin_code(code):
    code=str(code or "").strip()
    if not code: return False
    url=os.getenv("SUPABASE_URL","https://rytfhjvhjxnbhgitowho.supabase.co").rstrip("/")+"/functions/v1/admin-rpc"
    anon=os.getenv("SUPABASE_ANON_KEY","sb_publishable_5lDr_sw4bu8g3x8LCVzp4g_sHSTMBiO").strip()
    try:
      r=requests.post(url,headers={"apikey":anon,"Authorization":f"Bearer {anon}","Content-Type":"application/json"},
        json={"name":"admin_verify","params":{"p_secret":code}},timeout=15)
      if r.status_code>=400: return False
      data=r.json() if r.content else {}
      if isinstance(data,str):
        import json
        data=json.loads(data)
      return isinstance(data,dict) and data.get("ok") is True and data.get("data") is True
    except Exception:
      return False


def _admin_free_intent(query,words):
    q=_free_norm(query)
    tokens=_free_tokens(query)
    for word in words:
      w=_free_norm(word)
      if w in q: return True
      if any(len(t)>=4 and _free_similarity(t,w)>=0.78 for t in tokens): return True
    return False

@app.post("/api/admin-ai")
def admin_ai():
    """Free deterministic admin assistant. Paid research/image AI routes stay separate."""
    body=request.get_json(silent=True) or {}
    supplied=str(body.get("admin_code",""))
    if not _verify_admin_code(supplied):
        return jsonify(error="Unauthorized"),401
    raw_query=str(body.get("query","")).strip()[:1500]
    query=_free_norm(raw_query)
    context=body.get("context") if isinstance(body.get("context"),dict) else {}
    books=context.get("books") if isinstance(context.get("books"),list) else []
    sales=context.get("sales") if isinstance(context.get("sales"),list) else []
    orders=context.get("orders") if isinstance(context.get("orders"),list) else []

    if not query:
      return jsonify(text="Savol yozing. Masalan: “eng ko‘p sotilgan kitoblar”, “omborda 2 tadan kam qolganlar”, “jami tushum va foyda”, “buyurtmalar holati”.")

    if _admin_free_intent(query,("salom","assalom","hello")):
      return jsonify(text="Assalomu alaykum. Admin yordamchi tayyor. Savdo, foyda, ombor, top kitoblar, buyurtmalar, kategoriya yoki nashriyotlar bo‘yicha so‘rashingiz mumkin.")

    if _admin_free_intent(query,("kam qolgan","restock","qayta olib","tugayotgan","2 dona","ombor kam")):
      low=[]
      for x in books:
        try: stock=int(x.get("stock") or 0)
        except Exception: stock=0
        if stock<=2: low.append((stock,str(x.get("title") or "")))
      low.sort()
      if not low: return jsonify(text="Omborda 2 dona yoki undan kam qolgan kitob topilmadi.")
      return jsonify(text="Kam qolgan / qayta olib kelish kerak:\n"+"\n".join(f"• {t}: {s} dona" for s,t in low[:40]))

    if _admin_free_intent(query,("tugagan","0 dona","qolmagan","out of stock")):
      zero=[]
      for x in books:
        try: stock=int(x.get("stock") or 0)
        except Exception: stock=0
        if stock<=0: zero.append(str(x.get("title") or ""))
      return jsonify(text=("Omborda tugagan kitoblar:\n"+"\n".join(f"• {t}" for t in zero[:50])) if zero else "Omborda tugagan kitob yo‘q.")

    if _admin_free_intent(query,("eng kop sotilgan","top sotuv","kop sotilgan","bestseller")):
      totals={}
      for x in sales:
        title=str(x.get("title") or "Noma’lum")
        try: qty=int(x.get("quantity") or x.get("qty") or 0)
        except Exception: qty=0
        totals[title]=totals.get(title,0)+qty
      top=sorted(totals.items(),key=lambda z:z[1],reverse=True)[:15]
      return jsonify(text=("Eng ko‘p sotilgan kitoblar:\n"+"\n".join(f"• {t}: {q} dona" for t,q in top)) if top else "Sotuv ma’lumoti yo‘q.")

    if _admin_free_intent(query,("kategoriya","kategoriyalar")):
      counts={}
      for x in books:
        k=str(x.get("category") or "Kategoriyasiz").strip() or "Kategoriyasiz"
        counts[k]=counts.get(k,0)+1
      rows=sorted(counts.items(),key=lambda z:(-z[1],z[0]))
      return jsonify(text="Kategoriyalar:\n"+"\n".join(f"• {k}: {n} xil kitob" for k,n in rows))

    if _admin_free_intent(query,("nashriyot","publisher")):
      counts={}
      for x in books:
        k=str(x.get("publisher") or "").strip()
        if k: counts[k]=counts.get(k,0)+1
      rows=sorted(counts.items(),key=lambda z:(-z[1],z[0]))[:40]
      return jsonify(text=("Nashriyotlar:\n"+"\n".join(f"• {k}: {n} xil kitob" for k,n in rows)) if rows else "Nashriyot ma’lumoti yo‘q.")

    if _admin_free_intent(query,("ombor qiymati","tannarx qiymati","ombordagi pul","inventory value")):
      retail=0.0; cost=0.0; units=0
      for x in books:
        try:
          stock=max(0,int(x.get("stock") or 0)); units+=stock
          retail+=float(x.get("price") or 0)*stock
          cost+=float(x.get("cost_price") or 0)*stock
        except Exception: pass
      return jsonify(text=f"Ombor: {units} dona. Sotuv narxida jami ₩{retail:,.0f}. Tannarx bo‘yicha jami ₩{cost:,.0f}. Potensial farq ₩{retail-cost:,.0f}.")

    if _admin_free_intent(query,("savdo","sotuv","sotilgan","tushum","foyda","daromad")):
      qty=0; revenue=0.0; cost=0.0
      for x in sales:
        try:
          q=int(x.get("quantity") or x.get("qty") or 0); qty+=q
          total=x.get("total")
          if total is None:
            total=float(x.get("unit_price") or x.get("price") or 0)*q
          revenue+=float(total or 0)
          cost+=float(x.get("cost_price") or 0)*q
        except Exception: pass
      return jsonify(text=f"Yuklangan savdo yozuvlari bo‘yicha {qty} dona kitob sotilgan. Tushum ₩{revenue:,.0f}. Tannarx ₩{cost:,.0f}. Yalpi foyda ₩{revenue-cost:,.0f}.")

    if _admin_free_intent(query,("buyurtma","zakaz","order","kutilmoqda","qabul qilingan","jonatilgan")):
      counts={}
      total=0.0; delivery=0.0
      for x in orders:
        s=str(x.get("status") or "Noma’lum")
        counts[s]=counts.get(s,0)+1
        try:
          total+=float(x.get("total") or 0); delivery+=float(x.get("delivery_fee") or 0)
        except Exception: pass
      summary=", ".join(f"{k}: {v}" for k,v in sorted(counts.items()))
      return jsonify(text=f"Buyurtmalar: {summary or 'ma’lumot yo‘q'}. Buyurtmalar jami ₩{total:,.0f}; delivery yig‘indisi ₩{delivery:,.0f}.")

    if _admin_free_intent(query,("ombor","stock","nechta kitob","jami kitob")):
      units=0; active=0
      for x in books:
        try: units+=max(0,int(x.get("stock") or 0))
        except Exception: pass
        if x.get("active") is True: active+=1
      return jsonify(text=f"Omborda jami {units} dona, {len(books)} xil kitob bor. Sotuvda ko‘rsatilganlari: {active} xil.")

    return jsonify(text=f"Bepul admin yordamchi ishlayapti. Hozir {len(books)} ta kitob, {len(sales)} ta savdo yozuvi va {len(orders)} ta buyurtma yuklangan. Savdo/foyda, eng ko‘p sotilganlar, ombor, kam qolganlar, buyurtmalar, kategoriya yoki nashriyot haqida so‘rang. Pulli internet tadqiqoti va AI Story alohida o‘z holicha qolgan.")

@app.post("/api/admin-ai/book-research")
def admin_ai_book_research():
    body=request.get_json(silent=True) or {}
    supplied=str(body.get("admin_code",""))
    if not _verify_admin_code(supplied):
        return jsonify(error="Unauthorized"),401
    title=str(body.get("title",""))[:300].strip()
    author=str(body.get("author",""))[:200].strip()
    publisher=str(body.get("publisher",""))[:200].strip()
    if not title: return jsonify(error="Kitob nomi kerak"),400
    instructions="""Research the exact book on the web. Verify bibliographic facts using reliable sources. Return ONLY valid compact JSON with keys: title, author, publisher, category, description, page_count, cover, confidence, notes. PAGE COUNT IS A REQUIRED RESEARCH TARGET: explicitly search the web for the exact edition page count using the title plus author and publisher, including publisher/catalog/library/bookseller/Google Books records. Check multiple likely sources when necessary. page_count must be a plain integer greater than 0 when any reliable source gives the exact edition page count; use 0 only after an explicit page-count search fails. Never omit page_count. First use web search to find several existing public descriptions, publisher/bookstore summaries, reviews, or Google Books information for the exact book. Compare those sources to understand the book's real content and recurring themes; do not copy their wording. Then write ONE Uzbek bookstore description, about 45-70 words, in 3-4 compact sentences. It must accurately reflect the book's content while making a potential buyer curious to read it. Mention the central subject, idea, or conflict that makes the book interesting, without spoilers or invented details. Use natural sales-friendly Uzbek, not exaggerated advertising. Do not include prices, URLs, citations, copied jacket text, generic filler, or invented claims. A later request may intentionally produce a differently worded description, so do not return multiple variants. Do not guess uncertain fields; use empty strings. category must be exactly one of: Badiiy adabiyot; Biznes va moliya; Bolalar adabiyoti; Diniy-ma’rifiy; Islom tarixi; Jahon adabiyoti; Jamiyat va kommunikatsiya; O‘zbek adabiyoti; Oila va nikoh; Psixologiya va shaxsiy rivojlanish; Qur’on va islom ilmlari; Ta’lim va tillar; Tarix va biografiya; Texnologiya; Tibbiyot va jamiyat. cover must be Yumshoq muqova, Qattiq muqova, or empty. confidence is high/medium/low. notes briefly states uncertainty."""
    payload=f"Find this exact book. Title: {title}\nCurrent author: {author}\nCurrent publisher: {publisher}"
    diagnostics={}
    out=_chat_json(instructions,[{"role":"user","content":[{"type":"input_text","text":payload}]}],3200,web_search=True,web_search_required=True,search_context_size="high",diagnostics=diagnostics)
    if not out: return _admin_ai_failure(diagnostics)
    try:
      import json, re
      cleaned=out.strip()
      cleaned=re.sub(r"^```(?:json)?\\s*","",cleaned,flags=re.I)
      cleaned=re.sub(r"\\s*```$","",cleaned)
      start=cleaned.find("{"); end=cleaned.rfind("}")
      if start < 0 or end <= start: raise ValueError("missing JSON")
      data=json.loads(cleaned[start:end+1])
      variants=data.get("description_variants")
      if not isinstance(variants,dict): variants={}
      sales=str(variants.get("sales") or data.get("description") or "").strip()
      data["description_variants"]={
        "sales":sales,
        "detailed":str(variants.get("detailed") or sales).strip(),
        "short":str(variants.get("short") or sales).strip(),
      }
      if not str(data.get("description") or "").strip(): data["description"]=sales
      allowed=("title","author","publisher","category","description","description_variants","page_count","cover","confidence","notes")
      return jsonify({k:data.get(k,"") for k in allowed})
    except Exception as e:
      print(f"Book research parse failed {type(e).__name__}: {out[:800]!r}",flush=True)
      return jsonify(error="Research result parse failed"),502


@app.post("/api/admin-ai/book-price-research")
def admin_ai_book_price_research():
    """Paid admin-only web research for Uzbekistan retail price + Korea landed estimate."""
    body=request.get_json(silent=True) or {}
    supplied=str(body.get("admin_code",""))
    if not _verify_admin_code(supplied):
        return jsonify(error="Unauthorized"),401
    title=str(body.get("title",""))[:300].strip()
    author=str(body.get("author",""))[:200].strip()
    publisher=str(body.get("publisher",""))[:200].strip()
    if not title:
        return jsonify(error="Kitob nomi kerak"),400

    instructions="""Research the exact CURRENT Uzbek-language book/edition on the live web for a bookstore admin in South Korea.
You MUST actually web-search. Match title first, then author/publisher/ISBN/edition when available so you do not mix different books, bundles, scripts, or editions.
Find current CASH retail prices in Uzbekistan from reliable active bookstores/publishers. Prefer official publisher stores and established retailers such as Asaxiy when relevant. Ignore installment monthly payments, used books, bundles unless the requested item is itself a bundle, and obviously stale/out-of-stock prices when a current offer exists.
Search broadly across Uzbekistan bookshops and publisher stores, including Uzbek Latin/Cyrillic spelling variants and title-only searches when author/publisher hints are absent. Collect 2-6 verified current offers when possible. Return the seller name and integer UZS CASH price for each. If only one reliable current offer exists, return that one rather than returning no prices; never treat installment monthly payments as the cash price.
Also determine the physical weight of this exact edition in kilograms. Prefer explicit product/shipping weight. If exact weight is unavailable, estimate it conservatively from page count, format/dimensions and binding. If those details are also incomplete, still return a conservative typical single-book estimate instead of 0 and set weight_basis="estimated"; explain the uncertainty in notes.
Find a current UZS->KRW exchange rate and return KRW per 1 UZS as krw_per_uzs. This field must be non-zero when a current exchange-rate source is available. Do not use installment conversion.
Return ONLY valid JSON:
{"matched_title":"","matched_author":"","matched_publisher":"","offers":[{"seller":"","price_uzs":0}],"weight_kg":0.0,"weight_basis":"verified|estimated","krw_per_uzs":0.0,"confidence":"high|medium|low","notes":""}
Do not calculate shipping or final Korean price yourself; the server will calculate those deterministically. Never invent a seller or a price. If evidence is insufficient, leave offers empty or weight/rate as 0 and explain briefly in notes."""

    payload=f"""Book title: {title}
Author hint: {author}
Publisher hint: {publisher}
Shipping rule after research: Korea delivery/import transport costs 10,000 KRW per kilogram."""
    diagnostics={}
    out=_chat_json(
        instructions,
        [{"role":"user","content":[{"type":"input_text","text":payload}]}],
        3500,
        web_search=True,
        web_search_required=True,
        search_context_size="high",
        diagnostics=diagnostics,
    )
    if not out:
        return _admin_ai_failure(diagnostics)

    try:
        import json, math
        start=out.find("{"); end=out.rfind("}")
        data=json.loads(out[start:end+1])

        offers=[]
        seen=set()
        for item in data.get("offers",[]) if isinstance(data,dict) else []:
            if not isinstance(item,dict): continue
            seller=str(item.get("seller","")).strip()[:120]
            try: price=int(round(float(item.get("price_uzs") or 0)))
            except Exception: price=0
            key=(seller.lower(),price)
            if seller and price>0 and key not in seen:
                seen.add(key); offers.append({"seller":seller,"price_uzs":price})
        offers=sorted(offers,key=lambda x:x["price_uzs"])[:6]

        try: weight=max(0.0,float(data.get("weight_kg") or 0))
        except Exception: weight=0.0
        try: rate=max(0.0,float(data.get("krw_per_uzs") or 0))
        except Exception: rate=0.0

        prices=[x["price_uzs"] for x in offers]
        low_uzs=min(prices) if prices else 0
        high_uzs=max(prices) if prices else 0
        avg_uzs=round((low_uzs+high_uzs)/2) if prices else 0

        shipping_krw=int(math.ceil((weight*10000)/100.0)*100) if weight>0 else 0
        low_book_krw=low_uzs*rate if low_uzs and rate else 0
        high_book_krw=high_uzs*rate if high_uzs and rate else 0
        avg_book_krw=avg_uzs*rate if avg_uzs and rate else 0

        def ceil_1000(value):
            return int(math.ceil(value/1000.0)*1000) if value>0 else 0

        estimated_min=ceil_1000(low_book_krw+shipping_krw) if low_book_krw and shipping_krw else 0
        estimated_max=ceil_1000(high_book_krw+shipping_krw) if high_book_krw and shipping_krw else 0
        estimated_avg=ceil_1000(avg_book_krw+shipping_krw) if avg_book_krw and shipping_krw else 0

        return jsonify(
            matched_title=str(data.get("matched_title",""))[:300],
            matched_author=str(data.get("matched_author",""))[:200],
            matched_publisher=str(data.get("matched_publisher",""))[:200],
            offers=offers,
            low_uzs=low_uzs,
            high_uzs=high_uzs,
            average_uzs=avg_uzs,
            krw_per_uzs=rate,
            average_book_krw=int(round(avg_book_krw)) if avg_book_krw else 0,
            weight_kg=round(weight,3),
            weight_basis=str(data.get("weight_basis",""))[:20],
            shipping_per_kg_krw=10000,
            shipping_krw=shipping_krw,
            estimated_min_krw=estimated_min,
            estimated_average_krw=estimated_avg,
            estimated_max_krw=estimated_max,
            confidence=str(data.get("confidence",""))[:20],
            notes=str(data.get("notes",""))[:600],
        )
    except Exception as e:
        print(f"Book price research parse failed error={type(e).__name__}",flush=True)
        return jsonify(error="Narx tadqiqoti natijasini o‘qib bo‘lmadi"),502


@app.post("/api/admin-ai/books-bulk-research")
def admin_ai_books_bulk_research():
    """Research a small batch in one paid AI call. Nothing is saved here."""
    body=request.get_json(silent=True) or {}
    supplied=str(body.get("admin_code",""))
    if not _verify_admin_code(supplied):
        return jsonify(error="Unauthorized"),401
    rows=body.get("books") if isinstance(body.get("books"),list) else []
    rows=rows[:12]
    clean=[]
    for row in rows:
      if not isinstance(row,dict): continue
      title=str(row.get("title",""))[:300].strip()
      if not title: continue
      clean.append({
        "id":str(row.get("id",""))[:120],
        "title":title,
        "author":str(row.get("author",""))[:200].strip(),
        "publisher":str(row.get("publisher",""))[:200].strip(),
      })
    if not clean: return jsonify(error="Kitoblar kerak"),400
    instructions="""Research each exact book in the supplied list on the web. Independently verify every requested bibliographic field. Existing author, publisher, title, category, or description values are hints only and may be wrong; NEVER preserve them merely because they were manually entered. When reliable web sources show a different value, return the verified value so the app can REPLACE the old one. Prefer publisher, author, library/catalog and reliable bookseller bibliographic sources. Return ONLY a valid JSON object with key "books", whose value is an array. Preserve each input id exactly. Every item must contain: id, title, author, publisher, category, description, page_count, confidence, notes. PAGE COUNT IS A REQUIRED RESEARCH TARGET for every book: explicitly search title + author + publisher with page count/bet/sahifa/pages and check publisher, catalog/library, Google Books, and reliable bookseller records as available. page_count must be a plain integer greater than 0 whenever a reliable source gives the exact edition page count; use 0 only after an explicit page-count search fails. Never omit page_count. Do not guess uncertain fields: use empty strings. description must be a detailed, sales-ready Uzbek bookstore description grounded in verified web sources and faithful to the actual book. Aim for about 90-160 words when sources provide enough information. Explain the core subject or story, central themes/problems, what the reader will encounter or learn, and who may especially enjoy or benefit from it. Write naturally and persuasively without hype, invented claims, spoilers, prices, or unsupported facts. Synthesize facts in original wording; never copy jacket/store text verbatim. category must be exactly one of these store categories: Badiiy adabiyot; Biznes va moliya; Bolalar adabiyoti; Diniy-ma’rifiy; Islom tarixi; Jahon adabiyoti; Jamiyat va kommunikatsiya; O‘zbek adabiyoti; Oila va nikoh; Psixologiya va shaxsiy rivojlanish; Qur’on va islom ilmlari; Ta’lim va tillar; Tarix va biografiya; Texnologiya; Tibbiyot va jamiyat. Do not include price, stock, cost, URLs, markdown, citations, internal data, or books not requested."""
    import json
    payload=json.dumps(clean,ensure_ascii=False)
    diagnostics={}
    out=_chat_json(instructions,[{"role":"user","content":[{"type":"input_text","text":payload}]}],9000,web_search=True,web_search_required=True,search_context_size="high",diagnostics=diagnostics)
    if not out: return _admin_ai_failure(diagnostics)
    try:
      start=out.find("{"); end=out.rfind("}")
      data=json.loads(out[start:end+1])
      found=data.get("books") if isinstance(data,dict) else []
      allowed=("id","title","author","publisher","category","description","page_count","confidence","notes")
      result=[]
      valid_ids={x["id"] for x in clean}
      for item in found if isinstance(found,list) else []:
        if not isinstance(item,dict): continue
        if str(item.get("id","")) not in valid_ids: continue
        result.append({k:item.get(k,"") for k in allowed})
      return jsonify(books=result)
    except Exception:
      return jsonify(error="Bulk research result parse failed"),502


@app.post("/api/ai-search")
def ai_search():
    """Always-free typo-tolerant local catalog search; no model/API credits."""
    body=request.get_json(silent=True) or {}
    query=str(body.get("query","")).strip()[:500]
    mode=str(body.get("mode","search")).strip().lower()
    books=_free_catalog(body)
    ranked=_free_rank_books(query,books)
    if mode=="similar" and ranked:
      target=ranked[0]
      cat=_free_norm(target.get("category",""))
      alternatives=[]
      for x in books:
        if x.get("id")==target.get("id") or x.get("stock",0)<=0: continue
        score=0
        if cat and _free_norm(x.get("category",""))==cat: score+=5
        score+=_free_similarity(target.get("description",""),x.get("description",""))*2
        score+=_free_similarity(target.get("title",""),x.get("title",""))
        alternatives.append((score,x.get("stock",0),x))
      alternatives.sort(key=lambda z:(z[0],z[1]),reverse=True)
      ranked=[x[2] for x in alternatives if x[0]>0][:16]
    if not ranked:
      ranked=_free_recommendations(query,books)
    return jsonify(ids=[x["id"] for x in ranked[:16] if x.get("id")]),200

