import http from 'node:http';

const PORT=Number(process.env.PORT||10000);
const ALLOWED_ORIGIN='https://bek-shaxsiy-yordamchi-pro.onrender.com';
const MAX_QUERY=110;
const AGENT='Mozilla/5.0 (compatible; YordamchiBooks/1.0; book metadata research)';
const cache=new Map();
const requests=new Map();
const STORE_DOMAINS=['asaxiy.uz','hilolnashr.uz','kitobxon.com','kitob.uz','mutolaa.com','ziyouz.com'];
const BOOK_TERMS=/kitob|китоб|books|book|nashr|нашр|roman|роман|asar|асар|o.qi|ўқи|o'qi|mutolaa/i;
const escapeXml=s=>String(s||'').replace(/&(?:amp|lt|gt|quot|apos);|&#x[0-9a-f]+;|&#[0-9]+;/gi,code=>{
  const basic={amp:'&',lt:'<',gt:'>',quot:'"',apos:"'"};
  const name=code.slice(1,-1).toLowerCase();
  if(basic[name])return basic[name];
  const number=name.startsWith('#x')?parseInt(name.slice(2),16):name.startsWith('#')?Number(name.slice(1)):null;
  return Number.isInteger(number)&&number>0&&number<0x10ffff?String.fromCodePoint(number):'';
});
const noTags=s=>escapeXml(String(s||'').replace(/<!\[CDATA\[([\s\S]*?)\]\]>/gi,'$1').replace(/<[^>]*>/g,' '))
  .replace(/\s+/g,' ').trim();
function cleanQuery(value){
  return String(value||'').trim().replace(/\s+/g,' ').replace(/[\u0000-\u001F]/g,' ').slice(0,MAX_QUERY);
}
function hostAllowed(uri){
  try{
    const url=new URL(uri);
    if(url.protocol!=='https:'||url.username||url.password)return false;
    return STORE_DOMAINS.some(domain=>url.hostname===domain||url.hostname.endsWith('.'+domain));
  }catch{return false}
}
async function fetchText(url,timeout=7000){
  const controller=new AbortController();
  const timer=setTimeout(()=>controller.abort(),timeout);
  try{
    const response=await fetch(url,{
      signal:controller.signal,
      redirect:'manual',
      headers:{'user-agent':AGENT,'accept':'text/html,application/rss+xml,application/xml;q=0.9,*/*;q=0.5'}
    });
    if(!response.ok||[301,302,303,307,308].includes(response.status))return '';
    const size=Number(response.headers.get('content-length')||0);
    if(size>1400000)return '';
    const reader=response.body?.getReader();
    if(!reader)return '';
    const chunks=[];let total=0;
    while(total<650000){
      const {value,done}=await reader.read();if(done)break;
      chunks.push(value);total+=value.length;
    }
    await reader.cancel().catch(()=>{});
    return new TextDecoder().decode(Buffer.concat(chunks.map(x=>Buffer.from(x))).subarray(0,650000));
  }catch{return ''}finally{clearTimeout(timer)}
}
function rssItems(xml){
  const out=[];
  for(const match of String(xml||'').matchAll(/<item\b[^>]*>([\s\S]*?)<\/item>/gi)){
    const item=match[1];
    const pick=tag=>noTags(item.match(new RegExp('<'+tag+'(?:\\s[^>]*)?>([\\s\\S]*?)<\\/'+tag+'>','i'))?.[1]||'');
    const title=pick('title'),description=pick('description');
    const link=pick('link');
    try{
      const url=new URL(link);
      if(url.protocol!=='https:'&&url.protocol!=='http:')continue;
      if(!title)continue;
      out.push({title,description,url:url.href,domain:url.hostname.replace(/^www\./,'')});
    }catch{}
  }
  return out;
}
function normalize(s){
  const map={а:'a',б:'b',в:'v',г:'g',ғ:'g',д:'d',е:'e',ё:'yo',ж:'j',з:'z',и:'i',й:'y',к:'k',қ:'q',л:'l',м:'m',н:'n',о:'o',п:'p',р:'r',с:'s',т:'t',у:'u',ў:'o',ф:'f',х:'x',ҳ:'h',ц:'ts',ч:'ch',ш:'sh',ъ:'',ь:'',ы:'i',э:'e',ю:'yu',я:'ya'};
  return String(s||'').toLowerCase().replace(/[\u0400-\u052f]/g,c=>map[c]??c)
    .normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/[‘’ʻʼ']/g,'')
    .replace(/[^\p{L}\p{N}]+/gu,' ').trim();
}
function isMatch(query,text){
  const q=normalize(query),t=normalize(text);
  if(!q||!t)return false;
  if(t.includes(q))return true;
  const terms=q.split(' ').filter(x=>x.length>=3);
  if(!terms.length)return false;
  const found=terms.filter(term=>t.split(' ').some(word=>word===term||word.startsWith(term)&&term.length>4)).length;
  return found>=Math.min(2,terms.length)&&found/terms.length>=.65;
}
function stripBookTitle(title,query){
  let candidate=noTags(title).replace(/\s+[-|–—]\s+(?:ASAXIY|Hilol Nashr|Kitobxon|Instagram|Kitoblar|Mutolaa).*$/i,'')
    .replace(/\s*[|–—]\s*.*(?:kitob do.koni|kitoblar).*$/i,'').trim().slice(0,160);
  if(!candidate||!isMatch(query,candidate))return '';
  return candidate;
}
function htmlMeta(html,name){
  for(const found of String(html||'').matchAll(/<meta\b[^>]*>/gi)){
    const tag=found[0];
    const readAttr=key=>{
      const regex=new RegExp('(?:^|\\s)'+key+'\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\'|([^\\s>]+))','i');
      const m=tag.match(regex);return m?.[1]??m?.[2]??m?.[3]??'';
    };
    if([readAttr('property'),readAttr('name'),readAttr('itemprop')].some(v=>v.toLowerCase()===name.toLowerCase()))
      return escapeXml(readAttr('content')).trim();
  }
  return '';
}
function imageUrl(text){
  try{
    const url=new URL(text);
    return url.protocol==='https:'&& !/logo|favicon|placeholder|default-profile/i.test(url.pathname)
      ?url.href:'';
  }catch{return ''}
}
function extractSchema(html){
  for(const match of String(html||'').matchAll(/<script\b[^>]*type=['"]application\/ld\+json['"][^>]*>([\s\S]*?)<\/script>/gi)){
    try{
      const json=JSON.parse(match[1]);
      const flat=Array.isArray(json)?json:json['@graph']?json['@graph']:[json];
      for(const o of flat){
        if(!o||typeof o!=='object')continue;
        const types=[].concat(o['@type']||[]);
        if(types.some(type=>/^(Book|Product)$/i.test(type)))return o;
      }
    }catch{}
  }
  return null;
}
function textProp(o){
  return typeof o==='string'?o:typeof o==='object'&&o?o.name||'':'';
}
async function enrich(result,query){
  if(!hostAllowed(result.url))return result;
  const html=await fetchText(result.url,4800);
  if(!html)return result;
  const schema=extractSchema(html)||{};
  const title=stripBookTitle(textProp(schema.name)||htmlMeta(html,'og:title')||
    html.match(/<title\b[^>]*>([\s\S]*?)<\/title>/i)?.[1]||result.title,query)
    ||stripBookTitle(result.title,query);
  if(!title)return result;
  const cover=imageUrl(textProp(schema.image)||htmlMeta(html,'og:image'));
  const author=Array.isArray(schema.author)
    ?schema.author.map(textProp).filter(Boolean).join(', ')
    :textProp(schema.author);
  const publisher=textProp(schema.publisher);
  const description=noTags(schema.description||htmlMeta(html,'description')||result.description).slice(0,900);
  const pages=Number(schema.numberOfPages||schema.numberOfItems||0);
  const isbn=String(schema.isbn||'').replace(/[^0-9X]/gi,'');
  return {...result,title,cover,author,publisher,description,
    pages:pages>0&&pages<10000?pages:0,
    isbn:/^(?:\d{13}|\d{9}[\dX])$/.test(isbn)?isbn:'',
    source:'Veb · '+result.domain,verifiedSource:true};
}
function sourceCandidate(row,query){
  if(!isMatch(query,row.title)&&!isMatch(query,row.description))return null;
  const title=stripBookTitle(row.title,query);
  if(!title)return null;
  return {title,author:'',publisher:'',description:'',cover:'',pages:0,isbn:'',
    source:'Qidiruv · '+row.domain,sourceUrl:row.url,domain:row.domain,verifiedSource:false,
    snippet:noTags(row.description).slice(0,350)};
}
async function search(query){
  const variants=[
    query+' kitob muallif nashriyot',
    '"'+query+'" site:asaxiy.uz OR site:hilolnashr.uz OR site:kitobxon.com',
    '"'+query+'" kitob site:instagram.com'
  ];
  const bodies=await Promise.all(variants.map(q=>
    fetchText('https://www.bing.com/search?format=rss&q='+encodeURIComponent(q),7800)));
  const raw=bodies.flatMap(rssItems);
  const dedup=new Map();
  for(const row of raw){
    if(!dedup.has(row.url))dedup.set(row.url,row);
  }
  const rows=[...dedup.values()].filter(row=>isMatch(query,row.title)||isMatch(query,row.description));
  const enriched=await Promise.all(rows.filter(row=>hostAllowed(row.url)).slice(0,5).map(row=>enrich(row,query)));
  const byUrl=new Map(enriched.map(row=>[row.url,row]));
  const results=[];
  for(const row of rows){
    const item=sourceCandidate(byUrl.get(row.url)||row,query);
    if(!item)continue;
    const detail=byUrl.get(row.url);
    results.push(detail?{...item,...detail,sourceUrl:row.url}:item);
  }
  results.sort((a,b)=>Number(Boolean(b.cover))*7+
    Number(Boolean(b.author))*4+Number(Boolean(b.verifiedSource))*2-
    (Number(Boolean(a.cover))*7+Number(Boolean(a.author))*4+Number(Boolean(a.verifiedSource))*2));
  return {results:results.slice(0,14),searchAvailable:bodies.some(Boolean),sources:['Bing RSS','Ochiq nashriyot/do‘kon sahifalari']};
}
function send(res,status,data){
  res.writeHead(status,{'content-type':'application/json; charset=utf-8',
    'access-control-allow-origin':ALLOWED_ORIGIN,
    'access-control-allow-methods':'GET,OPTIONS',
    'access-control-allow-headers':'Content-Type',
    'cache-control':'public, max-age=120',
    'x-content-type-options':'nosniff'});
  res.end(JSON.stringify(data));
}
http.createServer(async(req,res)=>{
  if(req.method==='OPTIONS'){res.writeHead(204,{'access-control-allow-origin':ALLOWED_ORIGIN,
    'access-control-allow-methods':'GET,OPTIONS','access-control-allow-headers':'Content-Type'});res.end();return;}
  if(req.method!=='GET'){send(res,405,{error:'Method not allowed'});return;}
  const url=new URL(req.url||'/', 'https://localhost');
  if(url.pathname==='/health'){send(res,200,{ok:true,service:'Yordamchi book web-search',version:1});return;}
  if(url.pathname!=='/api/search'){send(res,404,{error:'Not found'});return;}
  const query=cleanQuery(url.searchParams.get('q'));
  if(query.length<3){send(res,400,{error:'Kitob nomini kamida 3 ta harf bilan yozing'});return;}
  const ip=String(req.headers['x-forwarded-for']||req.socket.remoteAddress||'anonymous').split(',')[0].trim();
  const now=Date.now(),entry=requests.get(ip)||{time:now,count:0};
  if(now-entry.time>60000){entry.time=now;entry.count=0}
  entry.count++;requests.set(ip,entry);
  if(entry.count>24){send(res,429,{error:'Birozdan keyin yana urinib ko‘ring'});return;}
  const key=normalize(query),cached=cache.get(key);
  if(cached && now-cached.time<15*60000){send(res,200,{...cached.data,cached:true});return;}
  try{
    const data=await search(query);
    const response={query,...data};
    if(cache.size>250){for(const [k,v] of cache)if(now-v.time>15*60000)cache.delete(k)}
    cache.set(key,{time:now,data:response});
    send(res,200,response);
  }catch{
    send(res,503,{query,results:[],searchAvailable:false,error:'Qidiruv xizmati vaqtincha mavjud emas'});
  }
}).listen(PORT,'0.0.0.0',()=>console.log('Yordamchi book discovery API running on port '+PORT));

// Search-provider smoke test once per deploy. Does not change user data or serve false results.
setTimeout(async()=>{
  try{
    const probe=await search('O‘gay ona');
    console.log('[web-search-probe]',JSON.stringify({
      active:probe.searchAvailable,
      total:probe.results.length,
      sources:probe.results.slice(0,4).map(x=>x.domain)
    }));
  }catch(error){
    console.log('[web-search-probe]',JSON.stringify({active:false,reason:String(error?.message||'probe failed').slice(0,80)}));
  }
},3500);

