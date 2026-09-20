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


def _chat_json(instructions, payload, max_tokens=1200):
    key=os.getenv("OPENAI_API_KEY","").strip()
    if not key: return None
    r=requests.post("https://api.openai.com/v1/responses",
      headers={"Authorization":f"Bearer {key}","Content-Type":"application/json"},
      json={"model":"gpt-5.6-luna","instructions":instructions,
            "input":payload,"max_output_tokens":max_tokens},timeout=90)
    if r.status_code>=400: return None
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
    books=body.get("books") if isinstance(body.get("books"),list) else []
    books=books[:250]
    safe=[]
    for b in books:
      if not isinstance(b,dict): continue
      safe.append({k:b.get(k) for k in ("id","title","author","category","description","price","stock")})
    instructions="""You are Muhajeer Books' Uzbek-language shopping assistant. Use ONLY the supplied live catalog as product facts. Never invent availability, price, stock, author, or title. Recommend only stock>0 books unless the user explicitly asks about unavailable items. Be concise. You are advisory only: never claim to place, cancel, edit, refund, or change an order or inventory. When returning book suggestions, include the exact book id in [book:ID] form after its title."""
    if mode=="marketing":
      instructions="""You are Muhajeer Books' Uzbek marketing copy assistant. Using only supplied book facts, write concise, natural promotional copy. Do not invent plot facts, awards, discounts or availability. Return usable copy, not analysis."""
    elif mode=="description":
      instructions="""You are Muhajeer Books' Uzbek catalog editor. Using only supplied metadata, draft: 1) short description, 2) category suggestion, 3) Instagram caption, 4) Telegram caption. Do not invent facts about the book."""
    elif mode=="analytics":
      instructions="""You are Muhajeer Books' read-only business analyst. Summarize the supplied aggregate/order facts, identify observable trends and low-stock/restock candidates. Clearly separate facts from suggestions. Never claim to change inventory, prices, orders or promotions."""
    text=_chat_json(instructions, [{"role":"user","content":[{"type":"input_text","text":f"Mode: {mode}\nRequest: {query}\nCatalog/data: {safe}"}]}])
    if not text: return jsonify(error="AI unavailable"),502
    return jsonify(text=text)

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
