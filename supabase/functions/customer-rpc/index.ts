import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const url = Deno.env.get("SUPABASE_URL") ?? "";
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const db = createClient(url, serviceKey, { auth: { persistSession: false } });

const origins = new Set(["https://muhajeer-books-live-production.up.railway.app","https://muhajeer-books-render-preview.onrender.com"]);
const allowed = new Set([
  "customer_catalog_delta",
  "customer_store_notice",
  "customer_order_statuses",
  "customer_order_statuses_v2",
  "customer_order_submit",
  "customer_register_free",
  "customer_pin_register",
  "customer_pin_login",
  "customer_pin_profile",
  "customer_pin_logout",
  "customer_pin_preorders",
  "customer_web_preorder_checkout",
  "customer_web_preorder_delivery",
  "customer_restock_notifications",
  "customer_restock_subscribe",
  "customer_restock_unsubscribe",
  "customer_restore_orders",
  "register_app_install",
  "register_app_install_v2",
  "customer_preorder_submit",
  "customer_preorder_balance_list",
  "customer_preorder_discovery",
  "customer_preorder_activity_list",
  "customer_preorder_event_list",
  "customer_preorder_extra_change",
  "customer_preorder_balance_proof",
  "customer_book_request_submit",
  "customer_search_miss_log",
  "customer_book_view_log",
  "customer_search_event_log",
  "customer_bundle_list",
  "customer_push_subscribe",
  "customer_register_native_fcm",
  "customer_unregister_native_fcm",
  "customer_register_native_apns",
  "customer_unregister_native_apns",
  "customer_push_open",
  "customer_push_history",
  "customer_book_reviews",
  "customer_book_review_submit",
  "customer_professional_code_verify",
  "customer_story_owner_check",
]);

const rate = new Map<string, { n: number; until: number }>();
const professionalRate = new Map<string, { n: number; until: number }>();
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
function professionalRateOk(k: string) {
  const now = Date.now();
  const v = professionalRate.get(k);
  if (!v || v.until <= now) {
    professionalRate.set(k, { n: 1, until: now + 10 * 60_000 });
    return true;
  }
  if (v.n >= 5) return false;
  v.n++;
  return true;
}

function textParam(v: unknown, max: number) {
  return typeof v === "string" && v.trim().length > 0 && v.length <= max;
}
function validate(name: string, p: Record<string, unknown>): string | null {
  if (name === "customer_catalog_delta") {
    if (!textParam(p.p_since, 64) || Number.isNaN(Date.parse(String(p.p_since)))) return "Invalid catalog cursor";
  } else if (name === "customer_order_submit") {
    if (!p.p_order || typeof p.p_order !== "object" || Array.isArray(p.p_order)) return "Invalid order";
  } else if (name === "customer_order_statuses" || name === "customer_order_statuses_v2") {
    if (!Array.isArray(p.p_ids) || p.p_ids.length > 50 || p.p_ids.some((x) => typeof x !== "string" || !uuidRe.test(x))) return "Invalid order ids";
  } else if (name === "customer_pin_register" || name === "customer_pin_login") {
    if (!textParam(p.p_phone, 32) ||
        !textParam(p.p_install_id, 120) ||
        String(p.p_install_id).trim().length < 12 ||
        typeof p.p_pin !== "string" || !/^[0-9]{4}$/.test(p.p_pin) ||
        (name === "customer_pin_register" &&
          (!textParam(p.p_name, 80) || String(p.p_name).trim().length < 2)))
      return "Invalid four-digit PIN request";
  } else if (name === "customer_pin_profile" ||
        name === "customer_pin_logout" ||
        name === "customer_pin_preorders") {
    if (typeof p.p_session !== "string" || !/^[a-f0-9]{64}$/.test(p.p_session))
      return "Invalid PIN session";
  } else if (name === "customer_web_preorder_checkout") {
    if (typeof p.p_session !== "string" || !/^[a-f0-9]{64}$/.test(p.p_session) ||
        typeof p.p_preorder_id !== "string" || !uuidRe.test(p.p_preorder_id) ||
        !["detail", "add", "proof"].includes(String(p.p_action))) return "Invalid prepaid order";
    if (p.p_action === "add" &&
        (typeof p.p_book_id !== "string" || !uuidRe.test(p.p_book_id) ||
         !Number.isInteger(p.p_delta) || Math.abs(Number(p.p_delta)) > 5 ||
         p.p_delta === 0)) return "Invalid add-on";
    if (p.p_action === "proof" &&
        !textParam(p.p_path, 500)) return "Invalid remaining payment proof";
  } else if (name === "customer_web_preorder_delivery") {
    if (typeof p.p_session !== "string" || !/^[a-f0-9]{64}$/.test(p.p_session) ||
        typeof p.p_preorder_id !== "string" || !uuidRe.test(p.p_preorder_id) ||
        !textParam(p.p_recipient_name,80) ||
        !textParam(p.p_recipient_phone,32) ||
        typeof p.p_address !== "string" || p.p_address.length > 500 ||
        !["택배","경산 직접수령"].includes(p.p_delivery_type))
      return "Invalid prepaid delivery";
  } else if (name === "customer_register_free") {
    if (!textParam(p.p_name, 80) || String(p.p_name).trim().length < 2 || !textParam(p.p_phone, 32)) return "Invalid registration";
  } else if (name === "customer_restock_notifications") {
    if (!textParam(p.p_install_id, 120) || String(p.p_install_id).trim().length < 12) return "Invalid install id";
  } else if (name === "customer_restock_subscribe" || name === "customer_restock_unsubscribe") {
    if (!textParam(p.p_install_id, 120) || String(p.p_install_id).trim().length < 12 || typeof p.p_book_id !== "string" || !uuidRe.test(p.p_book_id)) return "Invalid restock request";
  } else if (name === "customer_restore_orders") {
    if (!textParam(p.p_phone, 32) || !textParam(p.p_recovery_code, 80) || String(p.p_recovery_code).replace(/[^0-9a-f]/gi, "").length < 12) return "Invalid recovery request";
  } else if (name === "customer_preorder_submit") {
    if (!textParam(p.p_install_id, 120) || String(p.p_install_id).trim().length < 12 || typeof p.p_book_id !== "string" || !uuidRe.test(p.p_book_id) || !Number.isInteger(p.p_quantity) || Number(p.p_quantity) < 1 || Number(p.p_quantity) > 20) return "Invalid preorder";
  } else if (name === "customer_preorder_discovery" ||
    name === "customer_preorder_activity_list") {
    if (!textParam(p.p_install_id, 120) ||
        String(p.p_install_id).trim().length < 12 ||
        typeof p.p_name !== "string" || String(p.p_name).length > 80 ||
        typeof p.p_phone !== "string" || String(p.p_phone).length > 32)
      return "Invalid preorder lookup";
    if (name === "customer_preorder_activity_list" &&
        (!Number.isInteger(p.p_limit) ||
         Number(p.p_limit) < 1 || Number(p.p_limit) > 100))
      return "Invalid inbox limit";
  } else if (name === "customer_preorder_event_list") {
    if (!textParam(p.p_install_id, 120) || String(p.p_install_id).trim().length < 12 ||
        !Number.isInteger(p.p_limit) || Number(p.p_limit) < 1 || Number(p.p_limit) > 100) return "Invalid preorder inbox request";
  } else if (name === "customer_preorder_balance_list" ||
    name === "customer_preorder_extra_change" ||
    name === "customer_preorder_balance_proof") {
    if (!textParam(p.p_install_id, 120) ||
        String(p.p_install_id).trim().length < 12) return "Invalid install ID";
    if (name !== "customer_preorder_balance_list" &&
        (!Number.isInteger(p.p_preorder_id) || Number(p.p_preorder_id) < 1)) return "Invalid preorder ID";
    if (name === "customer_preorder_extra_change" &&
        (typeof p.p_book_id !== "string" || !uuidRe.test(p.p_book_id) ||
         !Number.isInteger(p.p_delta) || Math.abs(Number(p.p_delta)) > 5 ||
         Number(p.p_delta) === 0)) return "Invalid add-on";
    if (name === "customer_preorder_balance_proof" &&
        !textParam(p.p_path, 500)) return "Invalid payment proof";
  } else if (name === "customer_book_request_submit") {
    if (!textParam(p.p_install_id, 120) || String(p.p_install_id).trim().length < 12 || !textParam(p.p_title, 160) || String(p.p_title).trim().length < 2) return "Invalid book request";
  } else if (name === "customer_book_view_log") {
    if (!textParam(p.p_install_id, 120) || String(p.p_install_id).trim().length < 12 ||
        typeof p.p_book_id !== "string" || !uuidRe.test(p.p_book_id))
      return "Invalid book view";
  } else if (name === "customer_search_event_log") {
    if (!textParam(p.p_install_id, 120) || String(p.p_install_id).trim().length < 12 ||
        !textParam(p.p_query, 160) || String(p.p_query).trim().length < 2 ||
        !Number.isInteger(p.p_result_count) ||
        Number(p.p_result_count) < 0 || Number(p.p_result_count) > 10000)
      return "Invalid search event";
  } else if (name === "customer_search_miss_log") {
    if (!textParam(p.p_install_id, 120) || String(p.p_install_id).trim().length < 12 || !textParam(p.p_query, 160) || String(p.p_query).trim().length < 2) return "Invalid search";
  } else if (name === "customer_story_owner_check") {
    if (!textParam(p.p_name, 80) || !textParam(p.p_phone, 32)) return "Invalid owner profile";
  } else if (name === "customer_professional_code_verify") {
    if (!textParam(p.p_code, 32) || !/^\d{4,12}$/.test(String(p.p_code).trim())) return "Invalid professional code";
  } else if (name === "customer_book_reviews") {
    if (typeof p.p_book_id !== "string" || !uuidRe.test(p.p_book_id)) return "Invalid book id";
  } else if (name === "customer_book_review_submit") {
    if (typeof p.p_order_id !== "string" || !uuidRe.test(p.p_order_id) ||
        typeof p.p_book_id !== "string" || !uuidRe.test(p.p_book_id) ||
        !textParam(p.p_phone, 32) ||
        !Number.isInteger(p.p_rating) || Number(p.p_rating) < 1 || Number(p.p_rating) > 5 ||
        !textParam(p.p_comment, 600) || String(p.p_comment).trim().length < 2) return "Invalid review";
  } else if (name === "customer_push_history") {
    if (p.p_limit !== undefined && (!Number.isInteger(p.p_limit) || Number(p.p_limit) < 1 || Number(p.p_limit) > 100)) return "Invalid push history limit";
  } else if (name === "customer_push_open") {
    if (!textParam(p.p_message_id, 64) || !textParam(p.p_endpoint, 2048)) return "Invalid push open";
  } else if (name === "customer_register_native_fcm") {
    if (!textParam(p.p_token, 4096) || String(p.p_token).length < 40 ||
        !textParam(p.p_phone, 40) ||
        !textParam(p.p_install_id, 120) || String(p.p_install_id).length < 12)
      return "Invalid native token registration";
  } else if (name === "customer_register_native_apns") {
    if (!textParam(p.p_token, 200) || String(p.p_token).length < 64 ||
        !textParam(p.p_phone, 40) ||
        !textParam(p.p_install_id, 120) || String(p.p_install_id).length < 12)
      return "Invalid APNs registration";
  } else if (name === "customer_unregister_native_fcm" || name === "customer_unregister_native_apns") {
    if (!textParam(p.p_install_id, 120) || String(p.p_install_id).length < 12)
      return "Invalid installation ID";
  } else if (name === "customer_push_subscribe") {
    if (!textParam(p.p_endpoint, 2048) || !textParam(p.p_p256dh, 512) || !textParam(p.p_auth, 256)) return "Invalid push subscription";
  } else if (name === "register_app_install" || name === "register_app_install_v2") {
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
    if (name === "customer_story_owner_check" && !professionalRateOk(`story-owner:${key(req)}`)) {
      return out(origin, 429, { ok: false, error: "Too many owner checks" });
    }
    if (name === "customer_professional_code_verify" &&
        !professionalRateOk(`professional:${key(req)}`)) {
      return out(origin, 429, { ok: false, error: "Too many attempts" });
    }
    if ((name === "customer_pin_login" || name === "customer_pin_register") &&
        !professionalRateOk("profile-pin:" + key(req))) {
      return out(origin, 429, { ok: false, error: "Too many PIN attempts. Try later." });
    }
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
