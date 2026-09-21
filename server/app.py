import base64
import hashlib
import io
import os
import time
from collections import defaultdict, deque

import requests
from flask import Flask, jsonify, request, Response

app = Flask(__name__)
_hits = defaultdict(deque)
_cache = {}

def _limited(ip):
    now=time.time(); q=_hits[ip]
    while q and q[0] < now-3600: q.popleft()
    if len(q) >= 20: return True
    q.append(now); return False

@app.get("/health")
def health():
    return jsonify(ok=True, ai=bool(os.getenv("OPENAI_API_KEY")))

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


def _chat_json(instructions, payload, max_tokens=1200, web_search=False):
    key=os.getenv("OPENAI_API_KEY","").strip()
    if not key: return None
    # Keep AI available when one model hits a temporary quota/rate-limit.
    models=[]
    configured=os.getenv("OPENAI_TEXT_MODEL","").strip()
    if configured: models.append(configured)
    models += ["gpt-5.6-luna","gpt-5.6-sol"]
    seen=set()
    for model in models:
      if model in seen: continue
      seen.add(model)
      data={"model":model,"instructions":instructions,
            "input":payload,"max_output_tokens":max_tokens}
      if web_search:
          data["tools"]=[{"type":"web_search"}]
          data["tool_choice"]="auto"
      try:
        r=requests.post("https://api.openai.com/v1/responses",
          headers={"Authorization":f"Bearer {key}","Content-Type":"application/json"},
          json=data,timeout=120)
      except Exception as e:
        print(f"Responses API request failed model={model} error={type(e).__name__}",flush=True)
        continue
      if r.status_code>=400:
        print(f"Responses API failed model={model} status={r.status_code} detail={r.text[:400]}",flush=True)
        continue
      j=r.json(); out=""
      for item in j.get("output",[]):
        for part in item.get("content",[]):
          if part.get("type")=="output_text": out+=part.get("text","")
      if out.strip(): return out.strip()
    return None

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
    for b in rows[:500]:
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
    q=_free_norm(query)
    books=_free_catalog(body)

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


@app.post("/api/admin-ai")
def admin_ai():
    """Free deterministic admin analytics. OpenAI is reserved for book research."""
    body=request.get_json(silent=True) or {}
    supplied=str(body.get("admin_code",""))
    if not _verify_admin_code(supplied):
        return jsonify(error="Unauthorized"),401
    query=str(body.get("query","")).lower()[:1500]
    context=body.get("context") if isinstance(body.get("context"),dict) else {}
    books=context.get("books") if isinstance(context.get("books"),list) else []
    sales=context.get("sales") if isinstance(context.get("sales"),list) else []
    orders=context.get("orders") if isinstance(context.get("orders"),list) else []

    if any(x in query for x in ("ombor","kam qol","restock","qayta olib","qolgan")):
      low=[]
      for x in books:
        try: stock=int(x.get("stock") or 0)
        except Exception: stock=0
        if stock<=2: low.append((stock,str(x.get("title") or "")))
      low.sort()
      if not low: return jsonify(text="Omborda 2 dona yoki undan kam qolgan kitob topilmadi.")
      return jsonify(text="Qayta olib kelish/kam qolganlar:\n" + "\n".join(f"• {t}: {s} dona" for s,t in low[:30]))

    if any(x in query for x in ("savdo","sotuv","sotilgan")):
      qty=0; revenue=0.0; cost=0.0
      for x in sales:
        try:
          q=int(x.get("quantity") or x.get("qty") or 0); qty+=q
          revenue+=float(x.get("total") or 0)
          cp=float(x.get("cost_price") or 0); cost+=cp*q
        except Exception: pass
      profit=revenue-cost
      return jsonify(text=f"Yuklangan savdo ma’lumotlari bo‘yicha: {qty} ta kitob sotilgan. Tushum ₩{revenue:,.0f}. Hisoblangan tannarx ₩{cost:,.0f}. Farq/yalpi foyda ₩{profit:,.0f}.")

    if any(x in query for x in ("buyurtma","zakaz","order")):
      counts={}
      for x in orders:
        s=str(x.get("status") or "Noma’lum"); counts[s]=counts.get(s,0)+1
      return jsonify(text="Buyurtmalar: " + (", ".join(f"{k}: {v}" for k,v in counts.items()) if counts else "ma’lumot yo‘q."))

    return jsonify(text=f"Admin ma’lumotlari yuklandi: {len(books)} ta kitob, {len(sales)} ta savdo yozuvi, {len(orders)} ta buyurtma. Savdo, ombor/kam qolgan kitoblar yoki buyurtmalar haqida so‘rang.")


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
    instructions="""Research the exact book on the web. Independently verify the bibliographic facts: existing/current author and publisher values are hints only and may be wrong. When reliable sources show a different author, publisher, title, category, or description, return the verified value so it REPLACES the old manually entered value. Prefer publisher, author, library/catalog, bookseller bibliographic pages, and other reliable sources. Return ONLY valid JSON with keys: title, author, publisher, category, description, cover, confidence, notes. Do not guess uncertain fields; use empty strings. description must be a short factual Uzbek catalog description, not copyrighted jacket copy. category must be exactly one of these store categories: Badiiy adabiyot; Biznes va moliya; Bolalar adabiyoti; Diniy-ma’rifiy; Islom tarixi; Jahon adabiyoti; Jamiyat va kommunikatsiya; O‘zbek adabiyoti; Oila va nikoh; Psixologiya va shaxsiy rivojlanish; Qur’on va islom ilmlari; Ta’lim va tillar; Tarix va biografiya; Texnologiya; Tibbiyot va jamiyat. cover should be Yumshoq muqova, Qattiq muqova, or empty only when verified. confidence is high/medium/low. notes briefly states ambiguity or verification caveats. Do not include prices, stock, cost, URLs, markdown, citations or internal codes."""
    payload=f"Find this exact book. Title: {title}\nCurrent author: {author}\nCurrent publisher: {publisher}"
    out=_chat_json(instructions,[{"role":"user","content":[{"type":"input_text","text":payload}]}],1000,web_search=True)
    if not out: return jsonify(error="AI research unavailable"),502
    try:
      import json
      start=out.find("{"); end=out.rfind("}")
      data=json.loads(out[start:end+1])
      allowed=("title","author","publisher","category","description","cover","confidence","notes")
      return jsonify({k:data.get(k,"") for k in allowed})
    except Exception:
      return jsonify(error="Research result parse failed"),502


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
    instructions="""Research each exact book in the supplied list on the web. Independently verify every requested bibliographic field. Existing author, publisher, title, category, or description values are hints only and may be wrong; NEVER preserve them merely because they were manually entered. When reliable web sources show a different value, return the verified value so the app can REPLACE the old one. Prefer publisher, author, library/catalog and reliable bookseller bibliographic sources. Return ONLY a valid JSON object with key "books", whose value is an array. Preserve each input id exactly. Every item must contain: id, title, author, publisher, category, description, confidence, notes. Do not guess uncertain fields: use empty strings. description must be a short factual Uzbek catalog description, not copied jacket text. category must be exactly one of these store categories: Badiiy adabiyot; Biznes va moliya; Bolalar adabiyoti; Diniy-ma’rifiy; Islom tarixi; Jahon adabiyoti; Jamiyat va kommunikatsiya; O‘zbek adabiyoti; Oila va nikoh; Psixologiya va shaxsiy rivojlanish; Qur’on va islom ilmlari; Ta’lim va tillar; Tarix va biografiya; Texnologiya; Tibbiyot va jamiyat. Do not include price, stock, cost, URLs, markdown, citations, internal data, or books not requested."""
    import json
    payload=json.dumps(clean,ensure_ascii=False)
    out=_chat_json(instructions,[{"role":"user","content":[{"type":"input_text","text":payload}]}],6000,web_search=True)
    if not out: return jsonify(error="AI research unavailable"),502
    try:
      start=out.find("{"); end=out.rfind("}")
      data=json.loads(out[start:end+1])
      found=data.get("books") if isinstance(data,dict) else []
      allowed=("id","title","author","publisher","category","description","confidence","notes")
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
    """Free local catalog search; no model/API credits."""
    body=request.get_json(silent=True) or {}
    import re
    query=str(body.get("query","")).lower()[:500]
    words=[w for w in re.findall(r"[\\wʻ’'-]+",query,flags=re.UNICODE) if len(w)>=3]
    books=body.get("books") if isinstance(body.get("books"),list) else []
    ranked=[]
    for b in books[:500]:
      if not isinstance(b,dict): continue
      hay=" ".join(str(b.get(k) or "").lower() for k in ("title","author","category","description"))
      score=sum(1 for w in words if w in hay)
      if query and query in hay: score+=4
      if score: ranked.append((score, int(b.get("stock") or 0)>0, str(b.get("id") or "")))
    ranked.sort(key=lambda x:(x[0],x[1]),reverse=True)
    return jsonify(ids=[x[2] for x in ranked[:12] if x[2]]),200
