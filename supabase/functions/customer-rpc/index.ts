import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const url = Deno.env.get("SUPABASE_URL") ?? "";
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const db = createClient(url, serviceKey, { auth: { persistSession: false } });

const origins = new Set(["https://muhajeer-books-live-production.up.railway.app"]);
const allowed = new Set([
  "customer_catalog_delta",
  "customer_order_statuses",
  "customer_register_free",
  "customer_restock_notifications",
  "customer_restock_subscribe",
  "customer_restock_unsubscribe",
  "customer_restore_orders",
  "register_app_install",
]);

const rate = new Map<string, { n: number; until: number }>();
const uuidRe = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function headers(origin: string) {
  return {
    "Content-Type": "application/json",
    "Cache-Control": "no-store",
    "Access-Control-Allow-Origin": origins.has(origin) ? origin : "https://muhajeer-books-live-production.up.railway.app",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}
function out(origin: string, status: number, body: unknown) {
  return new Response(JSON.stringify(body), { status, headers: headers(origin) });
}
function key(req: Request) {
  return (req.headers.get("x-forwarded-for") ?? req.headers.get("cf-connecting-ip") ?? "unknown").split(",")[0].trim();
}
function rateOk(k: string) {
  const now = Date.now();
  const v = rate.get(k);
  if (!v || v.until <= now) {
    rate.set(k, { n: 1, until: now + 60_000 });
    return true;
  }
  if (v.n >= 120) return false;
  v.n++;
  return true;
}
function textParam(v: unknown, max: number) {
  return typeof v === "string" && v.trim().length > 0 && v.length <= max;
}
function validate(name: string, p: Record<string, unknown>): string | null {
  if (name === "customer_catalog_delta") {
    if (!textParam(p.p_since, 64) || Number.isNaN(Date.parse(String(p.p_since)))) return "Invalid catalog cursor";
  } else if (name === "customer_order_statuses") {
    if (!Array.isArray(p.p_ids) || p.p_ids.length > 50 || p.p_ids.some((x) => typeof x !== "string" || !uuidRe.test(x))) return "Invalid order ids";
  } else if (name === "customer_register_free") {
    if (!textParam(p.p_name, 80) || String(p.p_name).trim().length < 2 || !textParam(p.p_phone, 32)) return "Invalid registration";
  } else if (name === "customer_restock_notifications") {
    if (!textParam(p.p_install_id, 120) || String(p.p_install_id).trim().length < 12) return "Invalid install id";
  } else if (name === "customer_restock_subscribe" || name === "customer_restock_unsubscribe") {
    if (!textParam(p.p_install_id, 120) || String(p.p_install_id).trim().length < 12 || typeof p.p_book_id !== "string" || !uuidRe.test(p.p_book_id)) return "Invalid restock request";
  } else if (name === "customer_restore_orders") {
    if (!textParam(p.p_phone, 32) || !textParam(p.p_recovery_code, 80) || String(p.p_recovery_code).replace(/[^0-9a-f]/gi, "").length < 12) return "Invalid recovery request";
  } else if (name === "register_app_install") {
    if (!textParam(p.p_install_id, 120) || String(p.p_install_id).trim().length < 12 || !textParam(p.p_platform, 30)) return "Invalid install registration";
  }
  return null;
}

Deno.serve(async (req) => {
  const origin = req.headers.get("origin") ?? "";
  if (req.method === "OPTIONS") {
    if (origin && !origins.has(origin)) return new Response(null, { status: 403 });
    return new Response(null, { status: 204, headers: headers(origin) });
  }
  if (req.method !== "POST") return out(origin, 405, { ok: false, error: "Method not allowed" });
  if (origin && !origins.has(origin)) return out(origin, 403, { ok: false, error: "Origin not allowed" });
  if (!rateOk(key(req))) return out(origin, 429, { ok: false, error: "Too many requests" });

  try {
    const body = await req.json();
    const name = String(body?.name ?? "");
    const params = body?.params && typeof body.params === "object" && !Array.isArray(body.params)
      ? body.params as Record<string, unknown>
      : {};
    if (!allowed.has(name)) return out(origin, 403, { ok: false, error: "Operation not allowed" });
    const invalid = validate(name, params);
    if (invalid) return out(origin, 400, { ok: false, error: invalid });

    const { data, error } = await db.rpc(name, params);
    if (error) {
      console.error("customer-rpc", name, error.code);
      const message = String(error.message ?? "Request failed").slice(0, 180);
      return out(origin, 200, { ok: false, error: message });
    }
    return out(origin, 200, { ok: true, data });
  } catch (e) {
    console.error("customer-rpc", e);
    return out(origin, 400, { ok: false, error: "Bad request" });
  }
});
