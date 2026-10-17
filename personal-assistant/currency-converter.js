(function(root,factory){
  'use strict';
  const api=factory();
  if(typeof module==='object'&&module.exports)module.exports=api;
  else root.YordamchiCurrency=api;
})(typeof globalThis==='object'?globalThis:this,function(){
  'use strict';
  const CURRENCIES=['KRW','UZS','USD'];
  function amount(value){
    if(value===null||value===undefined||String(value).trim()==='')return null;
    const cleaned=String(value).trim().replace(/[\s,₩$]/g,'');
    if(!/^\d+(?:\.\d+)?$/.test(cleaned))return null;
    const number=Number(cleaned);
    return Number.isFinite(number)&&number>=0&&number<=1e15?number:null;
  }
  function rate(value){
    const valueNumber=amount(value);
    return valueNumber!==null&&valueNumber>0&&valueNumber<=1e7?valueNumber:null;
  }
  // Both rates are user-defined: 1,000 KRW in UZS and 1 USD in KRW.
  // UZS/USD is derived from those two rates; no live-rate API is implied.
  // Keep every decimal in the rate and intermediate amounts.
  function convertExact(value,from,to,uzsPer1000Won,wonPerDollar){
    const n=amount(value);
    if(n===null||!CURRENCIES.includes(from)||!CURRENCIES.includes(to))return null;
    if(from===to)return n;
    const uzs=rate(uzsPer1000Won),usd=rate(wonPerDollar);
    if((from==='UZS'||to==='UZS')&&uzs===null)return null;
    if((from==='USD'||to==='USD')&&usd===null)return null;
    const won=from==='KRW'?n:from==='UZS'?n*1000/uzs:n*usd;
    const target=to==='KRW'?won:to==='UZS'?won*uzs/1000:won/usd;
    return Number.isFinite(target)&&target>=0&&target<=1e15?target:null;
  }
  // Legacy financial reports show whole won/som, but use the full-precision rate.
  function convert(value,from,to,uzsPer1000Won,wonPerDollar){
    const exact=convertExact(value,from,to,uzsPer1000Won,wonPerDollar);
    return exact===null?null:rounded(exact,to);
  }
  function displayExact(value,currency){
    if(value===null||!Number.isFinite(value)||!CURRENCIES.includes(currency))return '—';
    const stable=Number(value.toPrecision(15));
    const str=stable.toLocaleString('en-US',{minimumFractionDigits:0,maximumFractionDigits:9});
    return currency==='KRW'?'₩'+str:currency==='USD'?'$'+str:str+' so‘m';
  }
  function rounded(value,currency){return Math.round(value*(currency==='USD'?100:1))/(currency==='USD'?100:1);}
  function display(value,currency){
    if(value===null||!CURRENCIES.includes(currency))return '—';
    const digits=currency==='USD'?2:0;
    const str=Number(value).toLocaleString('en-US',{minimumFractionDigits:digits,maximumFractionDigits:digits});
    return currency==='KRW'?'₩'+str:currency==='USD'?'$'+str:str+' so‘m';
  }
  return {CURRENCIES,amount,rate,convert,convertExact,display,displayExact};
});
