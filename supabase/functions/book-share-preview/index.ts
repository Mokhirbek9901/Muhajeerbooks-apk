import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const STORE_ORIGIN = "https://muhajeer-books-live-production.up.railway.app";
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

function escapeHtml(value: unknown) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function money(value: number) {
  return new Intl.NumberFormat("en-US").format(Math.max(0, Math.round(value)));
}

function currentPrice(price: number, discount: number) {
  const safe = Math.min(99, Math.max(0, discount));
  return Math.round(Math.max(0, price) * (100 - safe) / 100);
}

function responseHtml(html: string, status = 200, method = "GET") {
  return new Response(method === "HEAD" ? null : html, {
    status,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": status === 200
        ? "public, max-age=300, s-maxage=300, stale-while-revalidate=300"
        : "no-store",
      "X-Content-Type-Options": "nosniff",
      "X-Frame-Options": "DENY",
      "Referrer-Policy": "no-referrer",
      "Content-Security-Policy": "default-src 'none'; img-src https: data:; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'",
    },
  });
}

function isPreviewCrawler(req: Request) {
  const ua = (req.headers.get("user-agent") ?? "").toLowerCase();
  if (req.method === "HEAD") return true;
  return [
    "telegrambot", "facebookexternalhit", "facebot", "twitterbot",
    "linkedinbot", "discordbot", "slackbot", "skypeuripreview",
    "pinterestbot", "googlebot", "bingbot", "yandexbot", "applebot",
    "naverbot", "kakaotalk-scrap",
  ].some((token) => ua.includes(token));
}

function xmlEscape(value: unknown) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

async function sitemap(method: string) {
  const { data, error } = await supabase
    .from("books")
    .select("id,updated_at")
    .eq("is_active", true)
    .order("updated_at", { ascending: false })
    .limit(1000);

  if (error) {
    return new Response(method === "HEAD" ? null : "Sitemap unavailable", {
      status: 503,
      headers: { "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" },
    });
  }

  const rows = (data ?? []).map((book) => {
    const loc = `${STORE_ORIGIN}/kitob/${encodeURIComponent(String(book.id))}`;
    const lastmod = new Date(String(book.updated_at ?? Date.now())).toISOString();
    return `  <url><loc>${xmlEscape(loc)}</loc><lastmod>${xmlEscape(lastmod)}</lastmod><changefreq>weekly</changefreq><priority>0.8</priority></url>`;
  }).join("\n");

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>${STORE_ORIGIN}/</loc><changefreq>daily</changefreq><priority>1.0</priority></url>
${rows}
</urlset>`;

  return new Response(method === "HEAD" ? null : xml, {
    status: 200,
    headers: {
      "Content-Type": "application/xml; charset=utf-8",
      "Cache-Control": "public, max-age=900, s-maxage=900",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method !== "GET" && req.method !== "HEAD") {
    return new Response("Method not allowed", { status: 405 });
  }

  const url = new URL(req.url);
  if (url.searchParams.get("sitemap") === "1") {
    return sitemap(req.method);
  }

  const id = (url.searchParams.get("id") ?? "").trim().toLowerCase();
  if (!UUID_RE.test(id)) {
    return responseHtml("<!doctype html><title>Kitob topilmadi</title><p>Noto‘g‘ri kitob havolasi.</p>", 404, req.method);
  }

  const target = `${STORE_ORIGIN}/?book=${encodeURIComponent(id)}`;
  if (!isPreviewCrawler(req)) {
    return new Response(null, {
      status: 302,
      headers: {
        "Location": target,
        "Cache-Control": "no-store",
        "X-Content-Type-Options": "nosniff",
        "Referrer-Policy": "no-referrer",
      },
    });
  }

  const { data: book, error } = await supabase
    .from("books")
    .select("id,title,author,publisher,category,description,price,old_price,discount_percent,stock,image_url,updated_at,is_active")
    .eq("id", id)
    .eq("is_active", true)
    .maybeSingle();

  if (error || !book) {
    return responseHtml("<!doctype html><title>Kitob topilmadi</title><p>Bu kitob sotuvda mavjud emas.</p>", 404, req.method);
  }

  const price = Number(book.price ?? 0);
  const discount = Number(book.discount_percent ?? 0);
  const salePrice = currentPrice(price, discount);
  const title = String(book.title ?? "Kitob").trim() || "Kitob";
  const author = String(book.author ?? "").trim();
  const publisher = String(book.publisher ?? "").trim();
  const category = String(book.category ?? "").trim();
  const stock = Math.max(0, Number(book.stock ?? 0));
  const rawDescription = String(book.description ?? "").replace(/\s+/g, " ").trim();
  const description = (rawDescription || `${author ? `${author} · ` : ""}₩${money(salePrice)} · Muhajeer Books`).slice(0, 220);
  const image = String(book.image_url ?? "").trim() || `${STORE_ORIGIN}/icons/Icon-512.png`;
  const canonicalUrl = `${STORE_ORIGIN}/kitob/${encodeURIComponent(id)}`;
  const availability = stock > 0 ? "https://schema.org/InStock" : "https://schema.org/OutOfStock";

  const structured = {
    "@context": "https://schema.org",
    "@type": "Book",
    name: title,
    url: canonicalUrl,
    image: [image],
    description,
    ...(author ? { author: { "@type": "Person", name: author } } : {}),
    ...(publisher ? { publisher: { "@type": "Organization", name: publisher } } : {}),
    ...(category ? { genre: category } : {}),
    offers: {
      "@type": "Offer",
      priceCurrency: "KRW",
      price: String(salePrice),
      availability,
      url: canonicalUrl,
      seller: { "@type": "Organization", name: "Muhajeer Books" },
    },
  };
  const structuredJson = JSON.stringify(structured).replaceAll("<", "\\u003c");

  const html = `<!doctype html>
<html lang="uz">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>${escapeHtml(title)} — Muhajeer Books</title>
  <meta name="description" content="${escapeHtml(description)}">
  <meta name="robots" content="index,follow,max-image-preview:large">
  <link rel="canonical" href="${escapeHtml(canonicalUrl)}">
  <meta property="og:type" content="product">
  <meta property="og:site_name" content="Muhajeer Books">
  <meta property="og:title" content="${escapeHtml(title)} — ₩${money(salePrice)}">
  <meta property="og:description" content="${escapeHtml(description)}">
  <meta property="og:url" content="${escapeHtml(canonicalUrl)}">
  <meta property="og:image" content="${escapeHtml(image)}">
  <meta property="product:price:amount" content="${salePrice}">
  <meta property="product:price:currency" content="KRW">
  <meta property="product:availability" content="${stock > 0 ? "in stock" : "out of stock"}">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${escapeHtml(title)} — ₩${money(salePrice)}">
  <meta name="twitter:description" content="${escapeHtml(description)}">
  <meta name="twitter:image" content="${escapeHtml(image)}">
  <script type="application/ld+json">${structuredJson}</script>
  <style>
    body{font-family:system-ui,-apple-system,sans-serif;background:#f7f3ea;color:#10213d;margin:0;padding:32px}
    main{max-width:760px;margin:auto;background:white;border:1px solid #e8dfcf;border-radius:22px;padding:24px}
    img{width:180px;max-width:42vw;border-radius:12px;float:left;margin:0 22px 18px 0}
    h1{margin-top:0} .price{font-size:24px;font-weight:800}.stock{font-weight:700;color:#138a4b}
    a{display:inline-block;margin-top:14px;padding:12px 18px;border-radius:12px;background:#113d43;color:white;text-decoration:none;font-weight:800}
  </style>
</head>
<body>
  <main>
    <img src="${escapeHtml(image)}" alt="${escapeHtml(title)}">
    <h1>${escapeHtml(title)}</h1>
    ${author ? `<p>${escapeHtml(author)}</p>` : ""}
    <p class="price">₩${money(salePrice)}</p>
    <p class="stock">${stock > 0 ? `${stock} dona mavjud` : "Hozir mavjud emas"}</p>
    <p>${escapeHtml(description)}</p>
    <a href="${escapeHtml(target)}">Muhajeer Books’da ochish</a>
    <div style="clear:both"></div>
  </main>
</body>
</html>`;

  return responseHtml(html, 200, req.method);
});
