(function(root,factory){'use strict';const v=factory();if(typeof module==='object'&&module.exports)module.exports=v;else root.YordamchiRateEditor=v;})(typeof globalThis==='object'?globalThis:this,function(){'use strict';
const C=['KRW','UZS','USD'];
const DEFAULT_PAIRS=[{from:'KRW',to:'UZS'},{from:'USD',to:'KRW'}];
const currency=typeof module==='object'&&module.exports?require('./currency-converter.js'):globalThis.YordamchiCurrency;
const ratio=currency.ratio,exact=currency.precise;
function num(x){const n=currency.amount(x);return n!==null&&n>0?n:null;}
function base(from){return from==='USD'?1:from==='KRW'?10000:1;}
function unit(v){return v==='KRW'?'₩':v==='USD'?'$':'so‘m';}
function normalized(raw){
 return DEFAULT_PAIRS.map((defaultPair,i)=>{
  const v=Array.isArray(raw)?raw[i]:null;
  const from=C.includes(v?.from)?v.from:defaultPair.from;
  const to=C.includes(v?.to)&&v.to!==from?v.to:(defaultPair.to!==from?defaultPair.to:C.find(x=>x!==from));
  const source=exact.valid(v?.sourceExact??v?.sourceAmount,'1000000000000000',true);
  const quote=v?.quoteText??v?.value;
  return {from,to,...(source?{
   sourceAmount:num(v?.sourceAmount)??exact.text(source),
   ...(exact.valid(v?.sourceExact,'1000000000000000',true)?{sourceExact:exact.read(v.sourceExact)}:{}),
   ...(exact.valid(quote)?{quoteText:String(quote)}:{})
  }:{})};
 });
}
function rawValue(from,to,state,sourceAmount=base(from)){
 const uzs=num(state?.krwToUzsPer1000),usd=num(state?.krwPerUsd);
 if(!C.includes(from)||!C.includes(to)||from===to)return null;
 if((from==='UZS'||to==='UZS')&&uzs===null)return null;
 if((from==='USD'||to==='USD')&&usd===null)return null;
 const result=currency.convertExact(sourceAmount,from,to,uzs,usd);
 return Number.isFinite(result)&&result>0&&result<=1e15?result:null;
}
function showNumber(value){return exact.text(value);}
function solveExact(rows,previous){
 const dim={};
 for(const row of rows){
  if(String(row.value??'').trim()==='')continue;
  if(!C.includes(row.from)||!C.includes(row.to)||row.from===row.to)throw new Error('Ikki xil valyutani tanlang.');
  const from=exact.valid(row.sourceExact??row.sourceAmount??base(row.from),'1000000000000000',true);
  const to=exact.valid(row.quoteExact??row.value,'1000000000000000',true);
  if(!from||!to)throw new Error('Kurs summasini to‘g‘ri kiriting.');
  const key=[row.from,row.to].includes('USD')?([row.from,row.to].includes('UZS')?'ab':'b'):'a';
  if(Object.hasOwn(dim,key))throw new Error('Ikki kurs bir xil valyuta juftligida. Ikkinchi kurs uchun boshqa juftlikni tanlang.');
  const forward=key==='a'?row.from==='KRW':row.from==='USD';
  dim[key]=forward?exact.divide(to,from):exact.divide(from,to);
 }
 if(Object.keys(dim).length===0)throw new Error('Kamida bitta kurs kiriting.');
 const old=exact.rates(previous);
 let a=dim.a??null,b=dim.b??null;
 if(dim.ab){
  if(a)b=exact.divide(dim.ab,a);
  else if(b)a=exact.divide(dim.ab,b);
  else if(old.krwPerUsd){b=old.krwPerUsd;a=exact.divide(dim.ab,b);}
  else if(old.krwToUzsPer1000){a=exact.divide(old.krwToUzsPer1000,1000);b=exact.divide(dim.ab,a);}
  else throw new Error('Dollar-so‘m kursini hisoblash uchun yana von bilan juftlik kursini kiriting.');
 }
 const uzs=a?exact.multiply(a,1000):old.krwToUzsPer1000;
 b=b??old.krwPerUsd;
 if(uzs&&!exact.valid(uzs,'10000000',true))throw new Error('So‘m kursi juda katta yoki noto‘g‘ri.');
 if(b&&!exact.valid(b,'10000000',true))throw new Error('Dollar kursi juda katta yoki noto‘g‘ri.');
 return {krwToUzsPer1000:exact.number(uzs),krwPerUsd:exact.number(b),preciseExchangeRates:{krwToUzsPer1000:uzs,krwPerUsd:b}};
}
function solve(rows,previous){const r=solveExact(rows,previous);return {krwToUzsPer1000:r.krwToUzsPer1000,krwPerUsd:r.krwPerUsd};}
function bookRateExact(direction,sourceAmount,quoteAmount){
 if(direction!=='KRW_UZS'&&direction!=='UZS_KRW')throw new Error('Kurs yo‘nalishini tanlang.');
 const from=exact.valid(sourceAmount,'1000000000000000',true),to=exact.valid(quoteAmount,'1000000000000000',true);
 if(!from||!to)throw new Error('Har ikkala valyuta summasini musbat son bilan kiriting.');
 const rate=direction==='KRW_UZS'?exact.divide(exact.multiply(1000,to),from):exact.divide(exact.multiply(1000,from),to);
 if(!exact.valid(rate,'10000000',true))throw new Error('Valyuta kursi noto‘g‘ri yoki ruxsat etilgan oraliqdan tashqarida.');
 return rate;
}
function quoteExact(from,to,state,sourceAmount=base(from)){return exact.convert(sourceAmount,from,to,state);}
function normalizeBookInput(v){return v&&['KRW_UZS','UZS_KRW'].includes(v.direction)&&exact.valid(v.sourceText,'1000000000000000',true)&&exact.valid(v.targetText,'1000000000000000',true)?{direction:v.direction,sourceText:String(v.sourceText),targetText:String(v.targetText)}:null;}

function bookRateFromAmounts(direction,sourceAmount,quoteAmount){return exact.number(bookRateExact(direction,sourceAmount,quoteAmount));}

function bookRateQuote(direction,sourceAmount,savedUzsPer1000Won){
  if(direction!=='KRW_UZS'&&direction!=='UZS_KRW')return null;
  const from=num(sourceAmount),saved=num(savedUzsPer1000Won);
  if(from===null||saved===null)return null;
  const value=direction==='KRW_UZS'?ratio([from,saved],[1000]):ratio([from,1000],[saved]);
  return Number.isFinite(value)&&value>0&&value<=1e15?value:null;
}
return {DEFAULT_PAIRS,base,unit,normalized,rawValue,showNumber,solve,solveExact,bookRateExact,quoteExact,normalizeBookInput,bookRateFromAmounts,bookRateQuote};
});