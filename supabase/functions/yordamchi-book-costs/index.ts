const origin = 'https://bek-shaxsiy-yordamchi-pro.onrender.com';
const url = Deno.env.get('SUPABASE_URL') ?? '';
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const headers = {'Content-Type':'application/json','Cache-Control':'no-store','Access-Control-Allow-Origin':origin,'Access-Control-Allow-Headers':'authorization, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS','Vary':'Origin'};
const hits = new Map<string,{count:number,until:number}>();
function reply(status:number, data:unknown){return new Response(JSON.stringify(data),{status,headers});}
async function database(path:string,body?:unknown){
  const response=await fetch(url+'/rest/v1/'+path,{method:body===undefined?'GET':'POST',headers:{apikey:serviceKey,Authorization:'Bearer '+serviceKey,'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(15000)});
  const data=await response.json();return {response,data};
}
Deno.serve(async req=>{
  const requestOrigin=req.headers.get('origin');
  if(requestOrigin && requestOrigin!==origin)return reply(403,{ok:false,error:'Origin not allowed'});
  if(req.method==='OPTIONS')return new Response(null,{status:204,headers});
  if(req.method!=='POST')return reply(405,{ok:false,error:'Method not allowed'});
  const ip=(req.headers.get('x-forwarded-for')??req.headers.get('cf-connecting-ip')??'unknown').split(',')[0].trim();
  const now=Date.now();if(hits.size>10000){for(const [key,value] of hits)if(value.until<now)hits.delete(key);}
  const hit=hits.get(ip);if(hit && hit.until>now){if(hit.count>=30)return reply(429,{ok:false,error:'Biroz kutib, qayta urinib ko‘ring.'});hit.count++;}else hits.set(ip,{count:1,until:now+60000});
  try{
    const raw=await req.text();if(raw.length>1000000)return reply(413,{ok:false,error:'So‘rov juda katta.'});
    const body=JSON.parse(raw);
    if(!body || typeof body!=='object' || Array.isArray(body) || Object.keys(body).some(k=>!['action','admin_code','changes'].includes(k)) || !['catalog','update-costs','load-list','save-list'].includes(body.action))return reply(400,{ok:false,error:'Amal ruxsat etilmagan.'});
    if(typeof body.admin_code!=='string' || !body.admin_code || body.admin_code.length>512)return reply(401,{ok:false,error:'Admin kodini kiriting.'});
    const verified=await database('rpc/admin_verify',{p_secret:body.admin_code});
    if(!verified.response.ok || verified.data!==true)return reply(401,{ok:false,error:'Admin kodi noto‘g‘ri.'});
    if(body.action==='load-list'){
      const result=await database('yordamchi_device_list?select=version,payload&id=eq.true');
      if(!result.response.ok)return reply(502,{ok:false,error:'Qurilmalar ro‘yxatini olib bo‘lmadi.'});
      return reply(200,{ok:true,data:result.data[0]||{version:0,payload:null}});
    }
    if(body.action==='save-list'){
      const c=body.changes,p=c?.payload;
      const number=(v:unknown)=>v===null || typeof v==='number' && Number.isFinite(v) && v>=0 && v<=1e9;
      if(!c || Object.keys(c).sort().join(',')!=='payload,version' || !Number.isSafeInteger(c.version) || c.version<0 || !p || Object.keys(p).sort().join(',')!=='books,rate,tariffs' || !Array.isArray(p.books) || !Array.isArray(p.tariffs) || !number(p.rate) || p.rate===null || p.books.some((r:Record<string,unknown>)=>!r || Object.keys(r).sort().join(',')!=='grams,id,muhajeerId,price,salePrice,saved,title' || typeof r.id!=='string' || r.id.length>100 || typeof r.title!=='string' || r.title.length>300 || typeof r.saved!=='boolean' || !number(r.price) || !number(r.grams) || !number(r.salePrice) || (r.muhajeerId!==null && (typeof r.muhajeerId!=='string' || !/^[0-9a-f-]{36}$/i.test(r.muhajeerId)))) || new Set(p.books.map((r:{id:string})=>r.id)).size!==p.books.length || p.tariffs.some((t:Record<string,unknown>)=>!t || Object.keys(t).sort().join(',')!=='id,label,rate' || typeof t.id!=='string' || t.id.length>100 || typeof t.label!=='string' || t.label.length>80 || !number(t.rate)))return reply(400,{ok:false,error:'Ro‘yxat ma’lumotlari yaroqsiz.'});
      const result=await database('rpc/yordamchi_save_device_list',{p_version:c.version,p_payload:p});
      if(!result.response.ok)return reply(result.data?.code==='40001'?409:400,{ok:false,error:'Ro‘yxat boshqa qurilmada o‘zgargan. Ro‘yxatni yangilashni bosing.'});
      return reply(200,{ok:true,data:result.data});
    }
    if(body.action==='catalog'){
      // Only catalog fields needed for matching, cost comparison and current sale price.
      const result=await database('books?select=id,title,author,publisher,cost_price,price,discount_percent,discount_ends_at,is_active&order=title.asc&limit=1000');
      if(!result.response.ok)return reply(502,{ok:false,error:'Kitoblarni olib bo‘lmadi.'});
      return reply(200,{ok:true,data:result.data});
    }
    if(!Array.isArray(body.changes) || body.changes.length<1 || body.changes.length>300 || body.changes.some((c:Record<string,unknown>)=>!c || typeof c!=='object' || Array.isArray(c) || Object.keys(c).sort().join(',')!=='cost_price,expected_cost_price,id' || typeof c.id!=='string' || !/^[0-9a-f-]{36}$/i.test(c.id) || !Number.isInteger(c.cost_price) || Number(c.cost_price)<0 || Number(c.cost_price)>1e9 || (c.expected_cost_price!==null && (!Number.isInteger(c.expected_cost_price) || Number(c.expected_cost_price)<0))))return reply(400,{ok:false,error:'Faqat kitob IDsi va tan narxi yuborilishi mumkin.'});
    const result=await database('rpc/yordamchi_update_book_costs',{p_changes:body.changes});
    if(!result.response.ok){const conflict=['40001','P0002'].includes(result.data?.code);return reply(conflict?409:400,{ok:false,error:conflict?'Muhajeer Books’da tan narxi o‘zgargan yoki kitob o‘chirilgan. Sotuv narxlarini yangilab, qayta urinib ko‘ring.':'Tan narxi yangilanmadi.'});}
    return reply(200,{ok:true,data:result.data});
  }catch{return reply(503,{ok:false,error:'Ulanishda xato. Qayta urinib ko‘ring.'});}
});
