import { createClient } from "npm:@supabase/supabase-js@2.57.4";

import { contentStamp, isDuplicateStorageError, optimizedUploadError } from "./storage_policy.mjs";

const LIVE_ORIGIN = "https://muhajeer-books-live-production.up.railway.app";
const ALLOWED_ORIGINS = new Set([LIVE_ORIGIN]);

const corsHeaders = (origin: string) => ({
  "Access-Control-Allow-Origin": ALLOWED_ORIGINS.has(origin) ? origin : LIVE_ORIGIN,
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
  "Cache-Control": "no-store",
});

const json = (origin: string, body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
  });

const attempts = new Map<string, { count: number; resetAt: number }>();
function allowRequest(key: string, limit = 30, windowMs = 60_000) {
  const now = Date.now();
  const current = attempts.get(key);
  if (!current || current.resetAt <= now) {
    attempts.set(key, { count: 1, resetAt: now + windowMs });
    return true;
  }
  if (current.count >= limit) return false;
  current.count += 1;
  return true;
}

function decodeBase64(value: string): Uint8Array | null {
  try {
    const raw = atob(value);
    return Uint8Array.from(raw, (c) => c.charCodeAt(0));
  } catch (_) {
    return null;
  }
}

function safeBaseName(fileName: string) {
  return fileName
    .replace(/\.[^.]+$/, "")
    .replace(/[^a-zA-Z0-9_-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 50) || "cover";
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("origin") ?? "";
  if (req.method === "OPTIONS") {
    if (origin && !ALLOWED_ORIGINS.has(origin)) return new Response(null, { status: 403 });
    return new Response("ok", { headers: corsHeaders(origin) });
  }
  if (req.method !== "POST") return json(origin, { error: "Method not allowed" }, 405);
  if (origin && !ALLOWED_ORIGINS.has(origin)) return json(origin, { error: "Origin not allowed" }, 403);

  const ip = (req.headers.get("x-forwarded-for") ?? req.headers.get("cf-connecting-ip") ?? "unknown")
    .split(",")[0].trim();
  if (!allowRequest(`upload:${ip}`)) {
    return json(origin, { error: "Juda ko‘p urinish. Birozdan keyin qayta urinib ko‘ring." }, 429);
  }

  const contentLength = Number(req.headers.get("content-length") ?? "0");
  if (contentLength > 11_000_000) return json(origin, { error: "So‘rov juda katta" }, 413);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceRole) return json(origin, { error: "Server config missing" }, 500);

    const body = await req.json();
    const adminCode = String(body?.admin_code ?? "").trim();
    const action = String(body?.action ?? "cover").trim().toLowerCase();
    const fileName = String(body?.file_name ?? "cover.jpg");
    const contentType = String(body?.content_type ?? "image/jpeg").toLowerCase();
    const dataBase64 = String(body?.data_base64 ?? "");

    if (!adminCode || !dataBase64) return json(origin, { error: "Admin code va rasm kerak" }, 400);
    if (!["image/jpeg", "image/png", "image/webp"].includes(contentType)) {
      return json(origin, { error: "Faqat JPG, PNG yoki WEBP rasm yuklash mumkin" }, 400);
    }

    const supabase = createClient(supabaseUrl, serviceRole, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: verified, error: verifyError } = await supabase.rpc("admin_verify", {
      p_secret: adminCode,
    });
    if (verifyError || verified !== true) return json(origin, { error: "Admin kodi noto‘g‘ri" }, 403);

    const bytes = decodeBase64(dataBase64);
    if (!bytes) return json(origin, { error: "Rasm ma’lumoti buzilgan" }, 400);
    if (bytes.byteLength === 0 || bytes.byteLength > 7_000_000) {
      return json(origin, { error: "Rasm hajmi 7 MB dan kichik bo‘lishi kerak" }, 413);
    }

    const optimized = body?.optimized === true;
    const incomingThumb = decodeBase64(String(body?.thumb_base64 ?? ""));
    if (optimized) {
      const problem = optimizedUploadError(bytes, incomingThumb);
      if (problem) return json(origin, { error: problem }, 413);
    }
    // Content-addressed variants: selecting the same photo reuses its object.
    const stamp = await contentStamp(bytes, !!incomingThumb);

    if (action === "thumbnail") {
      if (bytes.byteLength > 400_000) {
        return json(origin, { error: "Kichik rasm juda katta" }, 413);
      }
      const thumbPath = `covers/thumbs/${stamp}.jpg`;
      const { error: thumbError } = await supabase.storage.from("book-covers").upload(thumbPath, bytes, {
        contentType: "image/jpeg",
        cacheControl: "31536000",
        upsert: false,
      });
      if (thumbError) return json(origin, { error: "Kichik rasm yuklanmadi" }, 500);
      const { data: thumbData } = supabase.storage.from("book-covers").getPublicUrl(thumbPath);
      return json(origin, { url: thumbData.publicUrl, thumbnail_url: thumbData.publicUrl, path: thumbPath });
    }

    const originalExt = fileName.includes(".") ? fileName.split(".").pop()!.toLowerCase() : "";
    const ext = contentType === "image/png" ? "png" : contentType === "image/webp" ? "webp" : "jpg";
    const fullPath = `covers/${stamp}.${originalExt === ext ? originalExt : ext}`;

    const { error: uploadError } = await supabase.storage.from("book-covers").upload(fullPath, bytes, {
      contentType,
      cacheControl: "31536000",
      upsert: false,
    });
    if (uploadError && !isDuplicateStorageError(uploadError)) return json(origin, { error: "Rasm yuklanmadi" }, 500);

    const { data: fullData } = supabase.storage.from("book-covers").getPublicUrl(fullPath);

    let thumbnailUrl = "";
    let thumbnailPath = "";
    const thumbBase64 = String(body?.thumb_base64 ?? "");
    if (thumbBase64) {
      const thumbBytes = decodeBase64(thumbBase64);
      if (thumbBytes && thumbBytes.byteLength > 0 && thumbBytes.byteLength <= 400_000) {
        thumbnailPath = `covers/thumbs/${stamp}.jpg`;
        const { error: thumbError } = await supabase.storage.from("book-covers").upload(thumbnailPath, thumbBytes, {
          contentType: "image/jpeg",
          cacheControl: "31536000",
          upsert: false,
        });
        if (!thumbError || isDuplicateStorageError(thumbError)) {
          const { data: thumbData } = supabase.storage.from("book-covers").getPublicUrl(thumbnailPath);
          thumbnailUrl = thumbData.publicUrl;
        }
      }
    }

    if (optimized && !thumbnailUrl) {
      return json(origin, { error: "Kichik rasm yuklanmadi. Qayta urinib ko‘ring." }, 500);
    }
    return json(origin, {
      url: fullData.publicUrl,
      path: fullPath,
      thumbnail_url: thumbnailUrl,
      thumbnail_path: thumbnailPath,
    });
  } catch (e) {
    console.error("admin-cover-upload", e);
    return json(origin, { error: "Rasm yuklashda server xatosi" }, 500);
  }
});
