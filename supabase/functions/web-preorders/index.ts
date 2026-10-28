import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } });
const origin = "https://muhajeer-books-live-production.up.railway.app";
const bucket = "web-preorder-assets";
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const hits = new Map<string, { n: number; until: number }>();
function rate(key: string) {
  const now = Date.now(), v = hits.get(key);
  if (!v || v.until < now) { hits.set(key, { n: 1, until: now + 60000 }); return true; }
  if (v.n >= 60) return false;
  v.n++; return true;
}
function reply(status: number, body: unknown) {
  return new Response(JSON.stringify(body), { status, headers: {
    "Content-Type": "application/json", "Cache-Control": "no-store",
    "Access-Control-Allow-Origin": origin, "Vary": "Origin",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS", "X-Content-Type-Options": "nosniff",
  } });
}
async function rpc(name: string, params: Record<string, unknown> = {}) {
  const session = String((params.p_request as Record<string, unknown> | undefined)?.session ?? "");
  const device = /^device:[a-f0-9]{64}$/.test(session) &&
    ["web_preorder_submit", "web_preorder_submit_multi"].includes(name);
  const { data, error } = await db.rpc(device ? "customer_device_dispatch" : name,
    device ? {p_device_session: session, p_action: name, p_params: params} : params);
  if (error) throw new Error(error.message);
  return data;
}
Deno.serve(async (req) => {
  if (req.headers.get("origin") && req.headers.get("origin") !== origin) return reply(403, { ok: false });
  if (req.method === "OPTIONS") return reply(200, {});
  if (req.method !== "POST") return reply(405, { ok: false });
  const ip = (req.headers.get("x-forwarded-for") ?? "unknown").split(",")[0];
  if (!rate(ip)) return reply(429, { ok: false, error: "Biroz kutib, qayta urining." });
  if (Number(req.headers.get("content-length") ?? 0) > 3000000) return reply(413, { ok: false, error: "Rasm juda katta." });
  try {
    const body = await req.json(), p = body?.params ?? {};
    if (body.action === "config") return reply(200, { ok: true, data: await rpc("web_preorder_config") });
    if (body.action === "book_config") {
      if (!uuid.test(p.book_id)) throw new Error("Kitob identifikatori noto‘g‘ri.");
      return reply(200, { ok: true, data: await rpc("web_preorder_book_config", { p_book_id: p.book_id }) });
    }
    if (body.action === "delivery") {
      // Internal worker authentication is checked in SQL before any event/recipient is returned.
      return reply(200, { ok: true, data: await rpc("web_preorder_delivery", p) });
    }
    if (body.action === "admin") {
      if (typeof p.p_secret !== "string" || p.p_secret.length < 1 || p.p_secret.length > 512 ||
          !["settings", "save", "list", "status", "checkout_detail", "checkout_confirm"].includes(p.p_action)) return reply(403, { ok: false, error: "Ruxsat yo‘q" });
      if (p.p_action === "checkout_detail" || p.p_action === "checkout_confirm") {
        if (!uuid.test(p.p_payload?.id)) throw new Error("Zakaz identifikatori noto‘g‘ri.");
        const action = p.p_action === "checkout_detail"
          ? "admin_web_preorder_checkout_detail"
          : "admin_web_preorder_checkout_confirm";
        const data = await rpc(action, {p_secret: p.p_secret, p_preorder_id: p.p_payload.id});
        if (p.p_action === "checkout_detail" && data?.balance_proof_path) {
          const result = await db.storage.from("payment-receipts").createSignedUrl(data.balance_proof_path, 900);
          data.balance_proof_url = result.data?.signedUrl ?? "";
        }
        return reply(200, { ok: true, data });
      }
      const data = await rpc("admin_web_preorder_manage", p);
      if (p.p_action === "list" && Array.isArray(data)) {
        const contacts = await rpc("admin_customer_preorder_contacts", {p_secret: p.p_secret});
        for (const row of data) row.instagram_handle = contacts?.["web:" + row.id] ?? "";
      }
      if (p.p_action === "list" && Array.isArray(data)) {
        const paths: string[] = [...new Set<string>(data.flatMap(row => [row.book_image_path, row.payment_proof_path,
          ...(Array.isArray(row.request_items) ? row.request_items.map((item: any) => item.book_image_path) : [])]).filter(Boolean))];
        const urls = new Map<string, string>();
        for (let i = 0; i < paths.length; i += 100) {
          const signed = await db.storage.from(bucket).createSignedUrls(paths.slice(i, i + 100), 900);
          for (const row of signed.data ?? []) if (row.path && row.signedUrl) urls.set(row.path, row.signedUrl);
        }
        for (const row of data) {
          if (Array.isArray(row.request_items)) {
            row.request_items = row.request_items.map((item: any) => ({...item, book_image_url: urls.get(item.book_image_path) ?? ""}));
          }
          for (const field of ["book_image_path", "payment_proof_path"]) {
            row[field.replace("_path", "_url")] = urls.get(row[field]) ?? (field === "book_image_path" ? row.book_image_url ?? "" : "");
          }
        }
      }
      return reply(200, { ok: true, data });
    }
    if (body.action === "upload") {
      if (!uuid.test(p.id) || !["book", "proof"].includes(p.kind) ||
          typeof p.data_base64 !== "string" || p.data_base64.length > 2800000) throw new Error("Rasm ma’lumotlari noto‘g‘ri.");
      if (p.book_id && !uuid.test(p.book_id)) throw new Error("Kitob identifikatori noto‘g‘ri.");
      const config = p.book_id
        ? await rpc("web_preorder_book_config", { p_book_id: p.book_id })
        : await rpc("web_preorder_config");
      if (!config?.enabled || !config.arrival_note?.trim()) throw new Error("Oldindan buyurtma qabuli yopiq.");
      if (p.book_id ? p.terms_token !== config.terms_token : Number(p.revision) !== Number(config.revision)) throw new Error("Sana yoki avans o‘zgargan. Shartlarni yangilang.");
      const bytes = Uint8Array.from(atob(p.data_base64), c => c.charCodeAt(0));
      if (bytes.length < 12 || bytes.length > 2097152) throw new Error("Rasm hajmi 2 MB dan oshmasin.");
      const jpeg = bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
      const png = [137,80,78,71,13,10,26,10].every((n,i) => bytes[i] === n);
      const webp = String.fromCharCode(...bytes.slice(0,4)) === "RIFF" && String.fromCharCode(...bytes.slice(8,12)) === "WEBP";
      if (!jpeg && !png && !webp) throw new Error("JPG, PNG yoki WebP rasm tanlang.");
      const hash = [...new Uint8Array(await crypto.subtle.digest("SHA-256", bytes))].map(n => n.toString(16).padStart(2,"0")).join("");
      const ext = jpeg ? "jpg" : png ? "png" : "webp", contentType = jpeg ? "image/jpeg" : png ? "image/png" : "image/webp";
      const path = `${p.id}/${p.kind}-${hash}.${ext}`;
      const uploaded = await db.storage.from(bucket).upload(path, bytes, { contentType, upsert: false });
      if (uploaded.error && !uploaded.error.message.toLowerCase().includes("already exists")) throw new Error("Rasm yuklanmadi. Qayta urining.");
      return reply(200, { ok: true, data: { path } });
    }
    if (body.action === "submit_multi") {
      if (!p.p_request || !uuid.test(p.p_request.id)) throw new Error("Buyurtma identifikatori noto‘g‘ri.");
      return reply(200, { ok: true, data: await rpc("web_preorder_submit_multi", p) });
    }
    if (body.action === "submit") {
      if (!p.p_request || !uuid.test(p.p_request.id)) throw new Error("Buyurtma identifikatori noto‘g‘ri.");
      return reply(200, { ok: true, data: await rpc("web_preorder_submit", p) });
    }
    return reply(400, { ok: false, error: "Noto‘g‘ri amal" });
  } catch (error) {
    const message = error instanceof Error ? error.message : "So‘rov bajarilmadi.";
    return reply(200, { ok: false, error: message.slice(0,200) });
  }
});
