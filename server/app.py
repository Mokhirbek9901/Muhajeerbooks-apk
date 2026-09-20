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
    data={"model":"gpt-5.6-luna","instructions":instructions,
          "input":payload,"max_output_tokens":max_tokens}
    if web_search:
        data["tools"]=[{"type":"web_search"}]
        data["tool_choice"]="auto"
    r=requests.post("https://api.openai.com/v1/responses",
      headers={"Authorization":f"Bearer {key}","Content-Type":"application/json"},
      json=data,timeout=120)
    if r.status_code>=400:
      print(f"Responses API failed status={r.status_code} detail={r.text[:400]}",flush=True)
      return None
    j=r.json(); out=""
    for item in j.get("output",[]):
      for part in item.get("content",[]):
        if part.get("type")=="output_text": out+=part.get("text","")
    return out.strip()

@app.post("/api/ai-assistant")
def ai_assistant():
    if _limited(request.headers.get("X-Forwarded-For",request.remote_addr or "").split(",")[0].strip()):
        return jsonify(error="Too many requests"),429
    body=request.get_json(silent=True) or {}
    mode=str(body.get("mode","advisor"))[:40]
    query=str(body.get("query",""))[:1000]
    # Customer assistant can answer general questions too. The live catalog remains
    # authoritative for Muhajeer Books product/stock/price facts.
    general_hint = """For general questions not answered by the catalog (for example delivery timing, Korean postal/courier practices, book/general knowledge), answer helpfully from general knowledge when reliable. If the answer depends on current/live information, say that live verification is needed rather than inventing a fact. For Muhajeer Books-specific policy, price and stock, use only supplied catalog/business facts."""
    books=body.get("books") if isinstance(body.get("books"),list) else []
    books=books[:250]
    safe=[]
    for b in books:
      if not isinstance(b,dict): continue
      safe.append({k:b.get(k) for k in ("id","title","author","category","description","price","stock")})
    instructions="""You are Muhajeer Books' customer-facing Uzbek-language shopping assistant. Use ONLY the supplied PUBLIC storefront catalog as product facts. Never invent availability, price, stock, author, or title. Recommend only stock>0 books unless the customer explicitly asks about unavailable items. All monetary amounts are South Korean won (KRW) and MUST be displayed only with the ₩ symbol, for example ₩17,000. NEVER display Uzbek so'm/sum/UZS and never convert KRW to another currency. You do NOT have access to wholesale cost, purchase cost, margin, profit, supplier price, admin notes, private customer data, or admin-only data. If asked for any such private data, say it is not available to the customer assistant. Be concise. You are advisory only: never claim to place, cancel, edit, refund, or change an order or inventory. Never expose internal ids, database keys, tags, JSON, markdown link syntax, or codes to the customer. Write clean natural Uzbek text only."""
    if mode=="marketing":
      instructions="""You are Muhajeer Books' Uzbek marketing copy assistant. Using only supplied PUBLIC book facts, write concise, natural promotional copy. Do not invent plot facts, awards, discounts or availability. All prices must be South Korean won using ₩ only; never use so'm/sum/UZS or convert currency. Never reveal or infer wholesale cost, margin, profit, supplier price, admin notes, or private customer data. Return usable copy, not analysis."""
    elif mode=="description":
      instructions="""You are Muhajeer Books' Uzbek catalog editor. Using only supplied metadata, draft: 1) short description, 2) category suggestion, 3) Instagram caption, 4) Telegram caption. Do not invent facts about the book."""
    elif mode=="analytics":
      instructions="""You are Muhajeer Books' read-only business analyst. Summarize the supplied aggregate/order facts, identify observable trends and low-stock/restock candidates. Clearly separate facts from suggestions. Never claim to change inventory, prices, orders or promotions."""
    web_modes={"advisor","general"}
    text=_chat_json(instructions + "\n" + general_hint + """ When web search is available, use it for current facts such as courier/post-office schedules, holidays, current services, recent book information, and other time-sensitive questions. Prefer official or primary sources. Clearly distinguish Muhajeer Books catalog facts from web facts. Do not expose raw URLs, internal tool traces, citation JSON, source IDs, or hidden metadata in the customer-facing answer.""",
      [{"role":"user","content":[{"type":"input_text","text":f"Mode: {mode}\nRequest: {query}\nPublic catalog/data: {safe}\nBusiness facts: Korea-wide delivery fee is ₩4,000; orders of 4 or more books have free delivery. Delivery timing can vary by carrier, destination, holidays and pickup time."}]}],
      web_search=(mode in web_modes))
    if not text: return jsonify(error="AI unavailable"),502
    return jsonify(text=text)

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
    body=request.get_json(silent=True) or {}
    # Admin code is verified against the same server-side secret used by admin RPC.
    supplied=str(body.get("admin_code",""))
    if not _verify_admin_code(supplied):
        return jsonify(error="Unauthorized"),401
    query=str(body.get("query",""))[:1500]
    context=body.get("context") if isinstance(body.get("context"),dict) else {}
    instructions="""You are Muhajeer Books' private ADMIN assistant. Answer in concise natural Uzbek. You may analyze the supplied admin-only books, stock, cost prices, sales and order aggregates, including profit/margin/restock and operational anomalies. Use web search for current external facts when useful. Never invent business data. You are read-only: do not claim to change prices, stock, orders, discounts, books, customers or settings. For any proposed mutation, explain the proposed change and require explicit admin confirmation before a separate app action performs it. Never expose admin credentials, secrets, tokens or unnecessary customer PII. Money is KRW and displayed with ₩."""
    text=_chat_json(instructions,[{"role":"user","content":[{"type":"input_text","text":f"Admin request: {query}\nAdmin data: {context}"}]}],1800,web_search=True)
    if not text: return jsonify(error="AI unavailable"),502
    return jsonify(text=text)


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
    body=request.get_json(silent=True) or {}
    query=str(body.get("query",""))[:500]
    books=body.get("books") if isinstance(body.get("books"),list) else []
    compact=[{"id":b.get("id"),"title":b.get("title"),"author":b.get("author"),"category":b.get("category"),"description":str(b.get("description",""))[:300],"price":b.get("price"),"stock":b.get("stock")} for b in books[:300] if isinstance(b,dict)]
    instructions="""Match a shopper's natural-language Uzbek request to the supplied catalog. Return ONLY a JSON array of at most 12 exact book ids, best semantic matches first. Never invent ids. Prefer stock>0. Example: ["uuid1","uuid2"]."""
    out=_chat_json(instructions,[{"role":"user","content":[{"type":"input_text","text":f"Query: {query}\nCatalog: {compact}"}]}],500)
    if not out: return jsonify(ids=[]),200
    try:
      import json
      ids=json.loads(out[out.find("["):out.rfind("]")+1])
      valid={str(b.get("id")) for b in compact}
      return jsonify(ids=[str(x) for x in ids if str(x) in valid][:12])
    except Exception:
      return jsonify(ids=[]),200
