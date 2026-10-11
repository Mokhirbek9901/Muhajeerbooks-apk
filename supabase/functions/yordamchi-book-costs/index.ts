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
function validReadingLibrary(p:Record<string,unknown>){
  const obj=(v:unknown)=>v!==null && typeof v==='object' && !Array.isArray(v);
  const text=(v:unknown,max=500)=>typeof v==='string' && v.length<=max;
  const number=(v:unknown,max=1e7)=>typeof v==='number' && Number.isFinite(v) && v>=0 && v<=max;
  const date=(v:unknown)=>text(v,10) && (v==='' || /^\d{4}-\d{2}-\d{2}$/.test(v as string));
  const allowed=['id','title','author','category','publisher','isbn','description','publishedYear','statusOverride','cover','pages','currentPage','startedAt','finishedAt','rating','notes','readingLog','createdAt','updatedAt'];
  if(!obj(p) || Object.keys(p).sort().join(',')!=='books,profile' || !Array.isArray(p.books) || p.books.length>2000 || !obj(p.profile))return false;
  const profile=p.profile as Record<string,unknown>;
  if(Object.keys(profile).sort().join(',')!=='customCategories,dailyMinutesGoal,dailyPageGoal,dailyPlanBookId,yearlyGoal' || !number(profile.yearlyGoal,500) || !number(profile.dailyPageGoal,300) || !number(profile.dailyMinutesGoal,240) || !text(profile.dailyPlanBookId,100) || !Array.isArray(profile.customCategories) || profile.customCategories.length>200 || profile.customCategories.some(v=>!text(v,100)))return false;
  const ids=new Set();
  for(const b of p.books as Record<string,unknown>[]){
    if(!obj(b) || Object.keys(b).some(k=>!allowed.includes(k)) || !text(b.id,100) || !b.id || ids.has(b.id) || !text(b.title,500) || !b.title || !Array.isArray(b.readingLog) || b.readingLog.length>10000)return false;
    ids.add(b.id);
    for(const k of ['author','category','publisher','isbn'])if(b[k]!==undefined && !text(b[k],500))return false;
    for(const k of ['description','notes'])if(b[k]!==undefined && !text(b[k],50000))return false;
    if(b.cover!==undefined && (!text(b.cover,2000000) || b.cover!=='' && !/^(https:\/\/|data:image\/(jpeg|png|webp);base64,)/i.test(b.cover as string)))return false;
    for(const k of ['pages','currentPage','publishedYear','rating'])if(b[k]!==undefined && !number(b[k]))return false;
    if(b.statusOverride!==undefined && !['','reading','finished','wishlist'].includes(b.statusOverride as string))return false;
    for(const k of ['startedAt','finishedAt'])if(b[k]!==undefined && !date(b[k]))return false;
    for(const k of ['createdAt','updatedAt'])if(b[k]!==undefined && !text(b[k],40))return false;
    for(const log of b.readingLog as Record<string,unknown>[]){if(!obj(log) || Object.keys(log).some(k=>!['date','page','readPages','minutes'].includes(k)) || !date(log.date) || !log.date || !number(log.page) || log.readPages!==undefined && !number(log.readPages) || log.minutes!==undefined && !number(log.minutes))return false;}
  }
  return true;
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
    const raw=await req.text();if(raw.length>12000000)return reply(413,{ok:false,error:'So‘rov juda katta.'});
    const body=JSON.parse(raw);
    if(!body || typeof body!=='object' || Array.isArray(body) || Object.keys(body).some(k=>!['action','admin_code','changes'].includes(k)) || !['catalog','update-costs','load-list','save-list','load-library','save-library'].includes(body.action))return reply(400,{ok:false,error:'Amal ruxsat etilmagan.'});
    if(typeof body.admin_code!=='string' || !body.admin_code || body.admin_code.length>512)return reply(401,{ok:false,error:'Admin kodini kiriting.'});
    const verified=await database('rpc/admin_verify',{p_secret:body.admin_code});
    if(!verified.response.ok || verified.data!==true)return reply(401,{ok:false,error:'Admin kodi noto‘g‘ri.'});
    if(body.action==='load-library'){
      const result=await database('yordamchi_reading_library?select=version,payload&id=eq.true');
      if(!result.response.ok)return reply(502,{ok:false,error:'Shaxsiy kitoblarni olib bo‘lmadi.'});
      return reply(200,{ok:true,data:result.data[0]||{version:0,payload:null}});
    }
    if(body.action==='save-library'){
      const c=body.changes,p=c?.payload;
      if(!c || Object.keys(c).sort().join(',')!=='payload,version' || !Number.isSafeInteger(c.version) || c.version<0 || !validReadingLibrary(p))return reply(400,{ok:false,error:'Shaxsiy kitoblar ma’lumotlari yaroqsiz.'});
      const result=await database('rpc/yordamchi_save_reading_library',{p_version:c.version,p_payload:p});
      if(!result.response.ok)return reply(result.data?.code==='40001'?409:400,{ok:false,error:'Kitoblar boshqa qurilmada o‘zgargan. Kitoblarni yangilashni bosing.'});
      return reply(200,{ok:true,data:result.data});
    }
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
