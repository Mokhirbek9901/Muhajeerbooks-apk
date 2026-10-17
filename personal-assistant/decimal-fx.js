(function(root,factory){'use strict';const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.YordamchiDecimalFX=api;})(typeof globalThis==='object'?globalThis:this,function(){
  'use strict';
  // JSON-safe rational numbers retain every entered decimal digit, including
  // reciprocal quotes, without passing through JavaScript Number storage.
  function gcd(a,b){a=a<0n?-a:a;while(b){const next=a%b;a=b;b=next;}return a||1n;}
  function fraction(n,d=1n){if(d===0n)return null;if(d<0n){n=-n;d=-d;}const g=gcd(n,d);return {n:String(n/g),d:String(d/g)};}
  function read(value){
    if(value&&typeof value==='object'){
      if(!/^-?\d+$/.test(value.n)||!/^\d+$/.test(value.d))return null;
      return fraction(BigInt(value.n),BigInt(value.d));
    }
    if(value===null||value===undefined)return null;
    let s=String(value).trim().replace(/[\s₩$]/g,'');
    if(/^[1-9]\d{0,2}(?:,\d{3})+(?:\.\d+)?$/.test(s))s=s.replace(/,/g,'');
    else if(/^-?\d+,\d+$/.test(s))s=s.replace(',','.');
    // Exponent notation is only produced by legacy numeric records, not input fields.
    if(typeof value==='number'&&Number.isFinite(value)){
      const [mantissa,e='0']=s.toLowerCase().split('e');
      const decimals=(mantissa.split('.')[1]||'').length-Number(e);
      const n=BigInt(mantissa.replace('.',''));
      return decimals<0?fraction(n*10n**BigInt(-decimals)):fraction(n,10n**BigInt(decimals));
    }
    if(!/^-?(?:\d+(?:\.\d*)?|\.\d+)$/.test(s))return null;
    const places=(s.split('.')[1]||'').length;
    return fraction(BigInt(s.replace('.','').replace(/^(-?)\./,'$10')),10n**BigInt(places));
  }
  function multiply(a,b){a=read(a);b=read(b);return a&&b?fraction(BigInt(a.n)*BigInt(b.n),BigInt(a.d)*BigInt(b.d)):null;}
  function divide(a,b){a=read(a);b=read(b);return a&&b&&b.n!=='0'?fraction(BigInt(a.n)*BigInt(b.d),BigInt(a.d)*BigInt(b.n)):null;}
  function valid(value,max='1000000000000000',positive=false){
    const x=read(value);if(!x)return null;const n=BigInt(x.n),d=BigInt(x.d);
    return (positive?n>0n:n>=0n)&&n<=BigInt(max)*d?x:null;
  }
  function text(value){
    const x=read(value);if(!x)return '';
    let n=BigInt(x.n),d=BigInt(x.d),sign=n<0n?'-':'';if(n<0n)n=-n;
    const whole=n/d;let remainder=n%d;if(!remainder)return sign+whole;
    // Finite decimals are printed in full, with no fixed decimal-place limit.
    // Only infinitely recurring expansions need a finite on-screen preview.
    let rest=d,twos=0,fives=0;
    while(rest%2n===0n){rest/=2n;twos++;}
    while(rest%5n===0n){rest/=5n;fives++;}
    const places=rest===1n?Math.max(twos,fives):Math.max(40,x.n.length,x.d.length);
    let digits='';for(let i=0;i<places&&remainder;i++){remainder*=10n;digits+=remainder/d;remainder%=d;}
    return sign+whole+'.'+digits.replace(/0+$/,'');
  }
  function number(value){const s=text(value);return s===''?null:Number(s);}
  function rates(state){
    const old=state?.preciseExchangeRates||{};
    return {krwToUzsPer1000:valid(old.krwToUzsPer1000,'10000000',true)||valid(state?.krwToUzsPer1000,'10000000',true),
      krwPerUsd:valid(old.krwPerUsd,'10000000',true)||valid(state?.krwPerUsd,'10000000',true)};
  }
  function convert(value,from,to,state){
    const n=valid(value);if(!n||!['KRW','UZS','USD'].includes(from)||!['KRW','UZS','USD'].includes(to))return null;
    if(from===to)return n;
    const r=rates(state),factors={KRW:read(1),UZS:divide(1000,r.krwToUzsPer1000),USD:r.krwPerUsd};
    return factors[from]&&factors[to]?divide(multiply(n,factors[from]),factors[to]):null;
  }
  function display(value,unit){
    let s=text(value);if(!s)return '—';const [whole,decimal]=s.split('.');
    s=whole.replace(/\B(?=(\d{3})+(?!\d))/g,',')+(decimal?'.'+decimal:'');
    return unit==='KRW'?'₩'+s:unit==='USD'?'$'+s:s+' so‘m';
  }
  function input(el){
    if(el.dataset.fxText===el.value){try{return read(JSON.parse(el.dataset.fxExact));}catch(_){}}
    return valid(el.value);
  }
  function equal(a,b){a=read(a);b=read(b);return Boolean(a&&b&&a.n===b.n&&a.d===b.d);}
  function fill(el,value,literal=null){const x=read(value);const shown=literal??el.value;el.value=x?(equal(shown,x)?shown:text(x)):'';el.dataset.fxText=el.value;el.dataset.fxExact=JSON.stringify(x);}
  return {read,valid,multiply,divide,text,number,rates,convert,display,input,fill,equal};
});
