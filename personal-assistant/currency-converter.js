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
    if(typeof value==='number')return Number.isFinite(value)&&value>=0&&value<=1e15?value:null;
    let cleaned=String(value).trim().replace(/[\s₩$]/g,'');
    // Allow 8.841492544, 0,11, and grouped 8,000 without confusing decimal places.
    if(/^[1-9]\d{0,2}(?:,\d{3})+(?:\.\d+)?$/.test(cleaned))cleaned=cleaned.replace(/,/g,'');
    else if(/^\d+,\d+$/.test(cleaned))cleaned=cleaned.replace(',','.');
    if(!/^(?:\d+(?:\.\d*)?|\.\d+)$/.test(cleaned))return null;
    const number=Number(cleaned);
    return Number.isFinite(number)&&number>=0&&number<=1e15?number:null;
  }
  function rate(value){
    const number=amount(value);
    return number!==null&&number>0&&number<=1e7?number:null;
  }
  // Decimal coefficients avoid binary floating-point rounding between operations.
  // Public/state values remain Numbers for compatibility with existing backups.
  function decimal(value){
    const [mantissa,exponent='0']=String(value).toLowerCase().split('e');
    const places=(mantissa.split('.')[1]||'').length-Number(exponent);
    return {n:BigInt(mantissa.replace('.','')),s:places};
  }
  function ratio(numerators,denominators=[]){
    let n=1n,d=1n,scale=0;
    for(const value of numerators){const x=decimal(value);n*=x.n;scale+=x.s;}
    for(const value of denominators){const x=decimal(value);d*=x.n;scale-=x.s;}
    if(d===0n)return null;
    if(n===0n)return 0;
    const negative=(n<0n)!==(d<0n);if(n<0n)n=-n;if(d<0n)d=-d;
    // Carry 34 significant decimal digits before the one conversion to Number.
    const shift=34+d.toString().length-n.toString().length;
    const digits=shift>=0?n*10n**BigInt(shift)/d:n/(d*10n**BigInt(-shift));
    return Number((negative?'-':'')+digits+'e'+(-shift-scale));
  }
  function add(...values){
    const parts=values.map(decimal),scale=Math.max(...parts.map(x=>x.s));
    const n=parts.reduce((sum,x)=>sum+x.n*10n**BigInt(scale-x.s),0n);
    return Number(n+'e'+(-scale));
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
    const factors={KRW:[1,1],UZS:[1000,uzs],USD:[usd,1]};
    const target=ratio([n,factors[from][0],factors[to][1]],[factors[from][1],factors[to][0]]);
    return Number.isFinite(target)&&target>=0&&target<=1e15?target:null;
  }
  function rounded(value,currency){return Math.round(value*(currency==='USD'?100:1))/(currency==='USD'?100:1);}
  function convert(value,from,to,uzsPer1000Won,wonPerDollar){
    const exact=convertExact(value,from,to,uzsPer1000Won,wonPerDollar);
    return exact===null?null:rounded(exact,to);
  }
  // Formatting is presentation only; calculations always use the unrounded value.
  function displayExact(value,currency){
    if(value===null||!Number.isFinite(value)||!CURRENCIES.includes(currency))return '—';
    const formatted=Number(value).toLocaleString('en-US',{maximumSignificantDigits:17});
    return currency==='KRW'?'₩'+formatted:currency==='USD'?'$'+formatted:formatted+' so‘m';
  }
  function display(value,currency){
    if(value===null||!CURRENCIES.includes(currency))return '—';
    const digits=currency==='USD'?2:0;
    const str=Number(value).toLocaleString('en-US',{minimumFractionDigits:digits,maximumFractionDigits:digits});
    return currency==='KRW'?'₩'+str:currency==='USD'?'$'+str:str+' so‘m';
  }
  return {CURRENCIES,amount,rate,ratio,add,convert,convertExact,display,displayExact};
});
