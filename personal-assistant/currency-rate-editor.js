(function(root,factory){'use strict';const v=factory();if(typeof module==='object'&&module.exports)module.exports=v;else root.YordamchiRateEditor=v;})(typeof globalThis==='object'?globalThis:this,function(){'use strict';
const C=['KRW','UZS','USD'];
const DEFAULT_PAIRS=[{from:'KRW',to:'UZS'},{from:'USD',to:'KRW'}];
function num(x){if(x===null||x===undefined||String(x).trim()==='')return null;const n=Number(String(x).replace(/[\s,₩$,]/g,''));return Number.isFinite(n)&&n>0&&n<=1e15?n:null;}
function base(from){return from==='USD'?1:from==='KRW'?10000:1;}
function unit(v){return v==='KRW'?'₩':v==='USD'?'$':'so‘m';}
function normalized(raw){return DEFAULT_PAIRS.map((defaultPair,i)=>{const v=Array.isArray(raw)?raw[i]:null;const from=C.includes(v?.from)?v.from:defaultPair.from;const to=C.includes(v?.to)&&v.to!==from?v.to:(defaultPair.to!==from?defaultPair.to:C.find(x=>x!==from));return {from,to};});}
function rawValue(from,to,state){
 const uzs=num(state?.krwToUzsPer1000),usd=num(state?.krwPerUsd);
 if(!C.includes(from)||!C.includes(to)||from===to)return null;
 if((from==='UZS'||to==='UZS')&&uzs===null)return null;
 if((from==='USD'||to==='USD')&&usd===null)return null;
 const won=from==='KRW'?base(from):from==='UZS'?base(from)*1000/uzs:base(from)*usd;
 const result=to==='KRW'?won:to==='UZS'?won*uzs/1000:won/usd;
 return Number.isFinite(result)&&result>0&&result<=1e15?result:null;
}
function showNumber(value){return value===null?'':String(Number(Number(value).toPrecision(11)));}
function convertRule(from,to,value){
 if(!C.includes(from)||!C.includes(to)||from===to)throw new Error('Ikki xil valyutani tanlang.');
 const n=num(value);if(n===null)throw new Error('Kurs summasini to‘g‘ri kiriting.');
 const v=n/base(from);
 if(from==='KRW'&&to==='UZS')return {key:'a',value:v};
 if(from==='UZS'&&to==='KRW')return {key:'a',value:1/v};
 if(from==='USD'&&to==='KRW')return {key:'b',value:v};
 if(from==='KRW'&&to==='USD')return {key:'b',value:1/v};
 if(from==='USD'&&to==='UZS')return {key:'ab',value:v};
 return {key:'ab',value:1/v};
}
function solve(rows,previous){
 const dim={};
 for(const row of rows){
  if(String(row.value??'').trim()==='')continue;
  const x=convertRule(row.from,row.to,row.value);
  if(Object.hasOwn(dim,x.key))throw new Error('Ikki kurs bir xil valyuta juftligida. Ikkinchi kurs uchun boshqa juftlikni tanlang.');
  dim[x.key]=x.value;
 }
 if(Object.keys(dim).length===0)throw new Error('Kamida bitta kurs kiriting.');
 const oldA=num(previous?.krwToUzsPer1000)===null?null:previous.krwToUzsPer1000/1000;
 const oldB=num(previous?.krwPerUsd);
 let a=dim.a??null,b=dim.b??null;
 if(dim.ab!==undefined){
  if(a!==null)b=dim.ab/a;
  else if(b!==null)a=dim.ab/b;
  else if(oldB!==null){b=oldB;a=dim.ab/b;}
  else if(oldA!==null){a=oldA;b=dim.ab/a;}
  else throw new Error('Dollar-so‘m kursini hisoblash uchun yana von bilan juftlik kursini kiriting.');
 }
 if(a===null)a=oldA;if(b===null)b=oldB;
 if(a!==null&&(!Number.isFinite(a*1000)||a*1000<=0||a*1000>1e7))throw new Error('So‘m kursi juda katta yoki noto‘g‘ri.');
 if(b!==null&&(!Number.isFinite(b)||b<=0||b>1e7))throw new Error('Dollar kursi juda katta yoki noto‘g‘ri.');
 return {krwToUzsPer1000:a===null?null:a*1000,krwPerUsd:b};
}
function bookRateFromAmounts(direction,sourceAmount,quoteAmount){
  if(direction!=='KRW_UZS'&&direction!=='UZS_KRW')throw new Error('Kurs yo‘nalishini tanlang.');
  const from=num(sourceAmount),to=num(quoteAmount);
  if(from===null||to===null)throw new Error('Har ikkala valyuta summasini musbat son bilan kiriting.');
  const value=direction==='KRW_UZS'?(1000*to/from):(1000*from/to);
  if(!Number.isFinite(value)||value<=0||value>1e7)throw new Error('Valyuta kursi noto‘g‘ri yoki ruxsat etilgan oraliqdan tashqarida.');
  return value;
}
function bookRateQuote(direction,sourceAmount,savedUzsPer1000Won){
  if(direction!=='KRW_UZS'&&direction!=='UZS_KRW')return null;
  const from=num(sourceAmount),saved=num(savedUzsPer1000Won);
  if(from===null||saved===null)return null;
  const value=direction==='KRW_UZS'?(from*saved/1000):(from*1000/saved);
  return Number.isFinite(value)&&value>0&&value<=1e15?value:null;
}
return {DEFAULT_PAIRS,base,unit,normalized,rawValue,showNumber,solve,bookRateFromAmounts,bookRateQuote};
});