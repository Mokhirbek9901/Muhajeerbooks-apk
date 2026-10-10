const VERIFY_URL='https://rytfhjvhjxnbhgitowho.supabase.co/functions/v1/admin-rpc';
const PUBLIC_KEY='sb_publishable_5lDr_sw4bu8g3x8LCVzp4g_sHSTMBiO';
const RESEARCH_URL='https://muhajeer-books-live-production.up.railway.app/api/admin-ai/book-research';
const text=(v,n)=>typeof v==='string'?v.trim().slice(0,n):'';
export async function paidBookRequest(body,authOnly=false,fetcher=fetch){
  if(!body || typeof body!=='object' || Array.isArray(body) || Object.keys(body).some(k=>!['admin_code','title','author','publisher'].includes(k)))return {status:400,data:{error:'So‘rov yaroqsiz.'}};
  const code=text(body.admin_code,512),title=text(body.title,120);
  if(!code)return {status:401,data:{error:'Muhajeer Books admin kodini kiriting.'}};
  if(!authOnly && title.length<3)return {status:400,data:{error:'Kitob nomini kamida 3 harf bilan kiriting.'}};
  try{
    const verified=await fetcher(VERIFY_URL,{method:'POST',headers:{'Content-Type':'application/json',apikey:PUBLIC_KEY,Authorization:'Bearer '+PUBLIC_KEY},body:JSON.stringify({name:'admin_verify',params:{p_secret:code}}),signal:AbortSignal.timeout(20000)});
    const auth=await verified.json();
    if(!verified.ok || auth.ok!==true || auth.data!==true)return {status:401,data:{error:'Admin kodi noto‘g‘ri yoki ulanish mavjud emas.'}};
    if(authOnly)return {status:200,data:{ok:true}};
    const response=await fetcher(RESEARCH_URL,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({admin_code:code,title,author:text(body.author,100),publisher:text(body.publisher,150)}),signal:AbortSignal.timeout(110000)});
    if(!response.ok)return {status:response.status===401?401:502,data:{error:'Pullik AI qidiruvi ishlamadi. Kredit yoki xizmat holatini tekshiring.'}};
    const result=await response.json();
    if(!text(result.title,160))return {status:502,data:{error:'AI aniq kitob topolmadi. Nomini yoki muallifini aniqlashtiring.'}};
    return {status:200,data:{ok:true,book:{title:text(result.title,160),author:text(result.author,160),publisher:text(result.publisher,150),category:text(result.category,100),description:text(result.description,1600),pages:Number.isInteger(result.page_count)&&result.page_count>0&&result.page_count<=10000?result.page_count:0,confidence:['high','medium','low'].includes(result.confidence)?result.confidence:'low',notes:text(result.notes,600),source:'Muhajeer AI · internet tadqiqoti',verifiedSource:result.confidence==='high',isWebResult:true}}};
  }catch{return {status:503,data:{error:'AI xizmatiga ulanib bo‘lmadi. Internetni tekshirib, qayta qidiring.'}};}
}
