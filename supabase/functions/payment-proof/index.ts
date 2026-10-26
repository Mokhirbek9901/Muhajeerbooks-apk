import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2.57.4";

const LIVE_ORIGIN = "https://muhajeer-books-live-production.up.railway.app";
const ALLOWED_ORIGINS = new Set([LIVE_ORIGIN]);

const corsHeaders = (origin: string) => ({
  "Access-Control-Allow-Origin": ALLOWED_ORIGINS.has(origin) ? origin : LIVE_ORIGIN,
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
  "Cache-Control": "no-store",
});

function json(origin: string, data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
  });
}

function decodeBase64(value: string): Uint8Array {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

const limits = new Map<string, { count: number; resetAt: number }>();
function allowRequest(key: string, limit: number, windowMs: number) {
  const now = Date.now();
  const current = limits.get(key);
  if (!current || current.resetAt <= now) {
    limits.set(key, { count: 1, resetAt: now + windowMs });
    return true;
  }
  if (current.count >= limit) return false;
  current.count += 1;
  return true;
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("origin") ?? "";
  if (req.method === "OPTIONS") {
    if (origin && !ALLOWED_ORIGINS.has(origin)) return new Response(null, { status: 403 });
    return new Response("ok", { headers: corsHeaders(origin) });
  }
  if (req.method !== "POST") return json(origin, { error: "Method not allowed" }, 405);
  if (origin && !ALLOWED_ORIGINS.has(origin)) return json(origin, { error: "Origin not allowed" }, 403);

  const contentLength = Number(req.headers.get("content-length") ?? "0");
  if (contentLength > 11_000_000) return json(origin, { error: "So‘rov juda katta" }, 413);

  try {
    const url = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!url || !serviceRole) return json(origin, { error: "Server configuration missing" }, 500);

    const supabase = createClient(url, serviceRole, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const body = await req.json();
    const action = String(body?.action ?? "upload");
    const ip = (req.headers.get("x-forwarded-for") ?? req.headers.get("cf-connecting-ip") ?? "unknown")
      .split(",")[0].trim();

    if (action === "upload") {
      if (!allowRequest(`receipt-upload:${ip}`, 120, 10 * 60_000)) {
        return json(origin, { error: "Juda ko‘p yuklash urinishi. Birozdan keyin qayta urinib ko‘ring." }, 429);
      }

      const fileName = String(body?.file_name ?? "receipt.jpg");
      const contentType = String(body?.content_type ?? "image/jpeg").toLowerCase();
      const dataBase64 = String(body?.data_base64 ?? "");
      const allowed = new Set(["image/jpeg", "image/png", "image/webp"]);
      if (!allowed.has(contentType)) return json(origin, { error: "Faqat JPG, PNG yoki WEBP rasm qabul qilinadi" }, 400);
      if (!dataBase64) return json(origin, { error: "Chek rasmi yuborilmadi" }, 400);
      if (dataBase64.length > 10_000_000) return json(origin, { error: "Chek rasmi juda katta" }, 413);

      let bytes: Uint8Array;
      try {
        bytes = decodeBase64(dataBase64);
      } catch (_) {
        return json(origin, { error: "Chek rasmi ma’lumoti buzilgan" }, 400);
      }
      if (bytes.length === 0) return json(origin, { error: "Chek rasmi bo‘sh" }, 400);
      if (bytes.length > 7 * 1024 * 1024) return json(origin, { error: "Chek rasmi 7 MB dan kichik bo‘lishi kerak" }, 413);

      const ext = contentType === "image/png" ? "png" : contentType === "image/webp" ? "webp" : "jpg";
      const safeStem = fileName.replace(/\.[^.]+$/, "").replace(/[^A-Za-z0-9_-]/g, "_").slice(0, 40) || "receipt";
      const path = `receipts/${new Date().toISOString().slice(0, 10)}/${crypto.randomUUID()}_${safeStem}.${ext}`;

      const { error } = await supabase.storage.from("payment-receipts").upload(path, bytes, {
        contentType,
        upsert: false,
        cacheControl: "3600",
      });
      if (error) return json(origin, { error: "Chek yuklanmadi" }, 400);
      if (typeof body.session === "string" && /^[a-f0-9]{64}$/.test(body.session)) {
        const claim=await supabase.rpc("customer_release_receipt",{p_session:body.session,p_path:path});
        if(claim.error) return json(origin,{error:"PIN sessiyasi yoki chek bog‘lanishi tasdiqlanmadi"},403);
      }
      return json(origin, { path });
    }

    if (action === "view") {
      if (!allowRequest(`receipt-view:${ip}`, 180, 10 * 60_000)) {
        return json(origin, { error: "Juda ko‘p so‘rov. Birozdan keyin qayta urinib ko‘ring." }, 429);
      }

      const adminCode = String(body?.admin_code ?? "");
      const path = String(body?.path ?? "");
      if (!adminCode || !path) return json(origin, { error: "Ma’lumot yetarli emas" }, 400);
      if (!path.startsWith("receipts/") || path.includes("..")) return json(origin, { error: "Chek manzili noto‘g‘ri" }, 400);

      const { data: verified, error: verifyError } = await supabase.rpc("admin_verify", { p_secret: adminCode });
      if (verifyError || verified !== true) return json(origin, { error: "Ruxsat yo‘q" }, 403);

      const { data, error } = await supabase.storage.from("payment-receipts").createSignedUrl(path, 60 * 60);
      if (error || !data?.signedUrl) return json(origin, { error: "Chek topilmadi" }, 404);
      return json(origin, { url: data.signedUrl, expires_in: 3600 });
    }

    return json(origin, { error: "Noto‘g‘ri amal" }, 400);
  } catch (error) {
    console.error("payment-proof", error);
    return json(origin, { error: "Server xatosi" }, 500);
  }
});

