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

@app.post("/api/ai-assistant")
def ai_assistant():
    """Free customer helper: no OpenAI call. Uses only public storefront data."""
    body=request.get_json(silent=True) or {}
    query=str(body.get("query","")).strip()[:1000]
    q=query.lower()
    books=body.get("books") if isinstance(body.get("books"),list) else []
    safe=[]
    for b in books[:500]:
      if not isinstance(b,dict): continue
      safe.append({k:b.get(k) for k in ("title","author","category","description","price","stock")})

    # Never expose/admin-infer private business data.
    private_words=("tannarx","ulgurji","wholesale","supplier","yetkazib beruvchi narx","marja","margin","foyda","profit","admin","parol","password","token","mijoz ma'lumot","mijoz malumot","buyurtma ma'lumot")
    if any(x in q for x in private_words):
      return jsonify(text="Bu ma’lumot mijoz yordamchisida mavjud emas.")

    greetings=("salom","assalomu alaykum","assalom","hello","hi")
    if q in greetings or any(q.startswith(x+" ") for x in greetings):
      return jsonify(text="Assalomu alaykum! Muhajeer Books’ga xush kelibsiz. Kitob, narx, mavjudligi yoki yetkazib berish haqida so‘rashingiz mumkin.")

    if any(x in q for x in ("yetkazib","pochta","dostavka","delivery","택배")):
      return jsonify(text="Koreya bo‘ylab yetkazib berish ₩4,000. 4 ta yoki undan ko‘p kitob buyurtma qilsangiz, yetkazib berish bepul.")

    # Find books by title/author/category/description words. Public catalog only.
    import re
    words=[w for w in re.findall(r"[\wʻ’'-]+",q,flags=re.UNICODE) if len(w)>=3]
    stop={"kitob","kitobi","kitoblar","bormi","narxi","qancha","necha","sotuvda","mavjud","haqida","kerak","menga","bor","yoq","yo'q"}
    words=[w for w in words if w not in stop]
    matches=[]
    for x in safe:
      hay=" ".join(str(x.get(k) or "").lower() for k in ("title","author","category","description"))
      score=sum(1 for w in words if w in hay)
      title=str(x.get("title") or "").lower()
      if q and (q in title or title in q): score+=4
      if score: matches.append((score,x))
    matches.sort(key=lambda z:z[0],reverse=True)
    if matches:
      lines=[]
      for _,x in matches[:6]:
        try: price=f"₩{int(float(x.get('price') or 0)):,}"
        except Exception: price="Narxi ko‘rsatilmagan"
        stock=int(x.get("stock") or 0)
        status=f"Omborda {stock} dona" if stock>0 else "Hozircha mavjud emas"
        author=str(x.get("author") or "").strip()
        lines.append(f"{x.get('title')}"+(f" — {author}" if author else "")+f" — {price} — {status}")
      return jsonify(text="\n".join(lines))

    if any(x in q for x in ("arzon","tavsiya","tavsiya qil","nima o'q","nima oq")):
      avail=[x for x in safe if int(x.get("stock") or 0)>0]
      avail.sort(key=lambda x:float(x.get("price") or 0))
      if avail:
        lines=[]
        for x in avail[:5]:
          lines.append(f"{x.get('title')} — ₩{int(float(x.get('price') or 0)):,}")
        return jsonify(text="Hozir sotuvda bor kitoblardan:\n" + "\n".join(lines))

    return jsonify(text="Men Muhajeer Books do‘kon yordamchisiman. Kitob nomi, muallif, kategoriya, narx, mavjudligi yoki yetkazib berish haqida so‘rang.")

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
    instructions="""Research the exact book on the web. Prefer publisher, author, library/catalog, bookseller bibliographic pages, and other reliable sources. Return ONLY valid JSON with keys: title, author, publisher, category, description, cover, confidence, notes. Do not guess uncertain fields; use empty strings. description must be a short factual Uzbek catalog description, not copyrighted jacket copy. category should be a concise Uzbek bookstore category. cover should be Yumshoq muqova, Qattiq muqova, or empty only when verified. confidence is high/medium/low. notes briefly states ambiguity or verification caveats. Do not include prices, stock, cost, URLs, markdown, citations or internal codes."""
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
