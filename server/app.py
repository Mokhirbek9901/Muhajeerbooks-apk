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
    vision_prompt="""Analyze this book cover visually. Return a compact art-direction description for an Instagram Story BACKGROUND only. Identify prominent visible subjects (for example bird, flower, building, moon, landscape, object), atmosphere, dominant palette, era/style and decorative motifs. Do not invent a subject that is not visible or strongly implied. No text, no logos, no book mockup. Leave a calm central area for the real book cover and a calm lower area for app text."""
    vr=requests.post("https://api.openai.com/v1/responses",headers={"Authorization":f"Bearer {key}","Content-Type":"application/json"},json={
      "model":"gpt-5.6-luna",
      "input":[{"role":"user","content":[{"type":"input_text","text":vision_prompt+f"\nBook metadata: {title}; {category}; {desc}"},{"type":"input_image","image_url":data_url}]}],
      "max_output_tokens":350
    },timeout=90)
    if vr.status_code>=400: return jsonify(error="AI analysis failed"),502
    vj=vr.json()
    direction=""
    for item in vj.get("output",[]):
      for part in item.get("content",[]):
        if part.get("type")=="output_text": direction += part.get("text","")
    if not direction: direction=f"Elegant book-inspired composition based on {title}."

    prompt=f"""Create a premium vertical Instagram Story background for Muhajeer Books, inspired by the supplied art direction: {direction}
The background must feel custom to this exact book. Echo visible subjects from the cover in an artistic, non-copying environmental way: if a bird is visible, use bird/nature motifs; if architecture is visible, use compatible architectural atmosphere; if floral, use botanical atmosphere. Make each cover lead to a meaningfully different composition.
STRICT: background/decor only. NO words, letters, numbers, logos, price tags, UI, book cover, fake book, frames containing text, or watermark. Keep the central upper-middle region relatively uncluttered for the original cover. Keep the lower 40% calm and readable for title/price/CTA overlays. Sophisticated editorial retail photography/illustration, cohesive palette, 9:16."""
    ir=requests.post("https://api.openai.com/v1/images/generations",headers={"Authorization":f"Bearer {key}","Content-Type":"application/json"},json={
      "model":"gpt-image-2","prompt":prompt,"size":"1024x1536","quality":"medium","output_format":"png"
    },timeout=180)
    if ir.status_code>=400: return jsonify(error="AI image generation failed"),502
    ij=ir.json(); data=(ij.get("data") or [{}])[0]
    if data.get("b64_json"): out=base64.b64decode(data["b64_json"])
    elif data.get("url"):
        rr=requests.get(data["url"],timeout=60); rr.raise_for_status(); out=rr.content
    else: return jsonify(error="AI image missing"),502
    _cache[digest]=(time.time(),out)
    return Response(out,mimetype="image/png",headers={"Cache-Control":"private, max-age=86400"})
