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
    let cleaned=String(value).trim().replace(/[\s₩$]/g,'');
    // Allow 8.841492544, 0,11, and grouped 8,000 without confusing decimal places.
    if(/^\d{1,3}(?:,\d{3})+(?:\.\d+)?$/.test(cleaned))cleaned=cleaned.replace(/,/g,'');
    else if(/^\d+,\d+$/.test(cleaned))cleaned=cleaned.replace(',','.');
    if(!/^\d+(?:\.\d+)?$/.test(cleaned))return null;
    const number=Number(cleaned);
    return Number.isFinite(number)&&number>=0&&number<=1e15?number:null;
  }
  function rate(value){
    const number=amount(value);
    return number!==null&&number>0&&number<=1e7?number:null;
  }
  // Legacy storage remains UZS for 1,000 KRW and KRW for 1 USD.
  // Never round intermediate exchange calculations.
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
  function rounded(value,currency){return Math.round(value*(currency==='USD'?100:1))/(currency==='USD'?100:1);}
  function convert(value,from,to,uzsPer1000Won,wonPerDollar){
    const exact=convertExact(value,from,to,uzsPer1000Won,wonPerDollar);
    return exact===null?null:rounded(exact,to);
  }
  // The converter may show decimals; financial/inventory totals stay whole won/som.
  function displayExact(value,currency){
    if(value===null||!Number.isFinite(value)||!CURRENCIES.includes(currency))return '—';
    const formatted=Number(value).toLocaleString('en-US',{maximumFractionDigits:12});
    return currency==='KRW'?'₩'+formatted:currency==='USD'?'$'+formatted:formatted+' so‘m';
  }
  function display(value,currency){
    if(value===null||!CURRENCIES.includes(currency))return '—';
    const digits=currency==='USD'?2:0;
    const str=Number(value).toLocaleString('en-US',{minimumFractionDigits:digits,maximumFractionDigits:digits});
    return currency==='KRW'?'₩'+str:currency==='USD'?'$'+str:str+' so‘m';
  }
  return {CURRENCIES,amount,rate,convert,convertExact,display,displayExact};
});
