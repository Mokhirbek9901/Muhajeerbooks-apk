(function(root){
  'use strict';
  const DEFAULT_WON_PER_KG=10000;
  const WON_PER_GRAM=DEFAULT_WON_PER_KG/1000;
  function amount(value){
    if(value===null || value===undefined || String(value).trim()==='')return null;
    const text=String(value).trim().replace(/[\s₩]/g,'').replace(/,/g,'');
    if(!/^\d+(?:\.\d+)?$/.test(text))return null;
    const number=Number(text);
    return Number.isFinite(number) && number>=0 && number<=1e9 ? number : null;
  }
  function rate(value){return amount(value)??DEFAULT_WON_PER_KG;}
  function calculate(row,wonPerKg=DEFAULT_WON_PER_KG){
    const price=amount(row.price),grams=amount(row.grams);
    const shipping=grams===null?null:Math.round(grams*rate(wonPerKg)/1000);
    return {shipping,total:price===null || shipping===null?null:Math.round(price)+shipping};
  }
  function key(title){return String(title).normalize('NFKC').toLowerCase().replace(/[‘’ʻʼ`]/g,"'").replace(/\s+/g,' ').trim();}
  function parseTitles(text){
    const seen=new Set();
    return String(text).split(/\r?\n|;/).map(line=>line.trim()
      .replace(/^(?:[-*•▪]\s+|\d+[.)]\s+)/,'').trim()).filter(title=>{
        if(!title || seen.has(key(title)))return false;
        seen.add(key(title));return true;
      });
  }
  function normalize(rows,makeId){
    return (Array.isArray(rows)?rows:[]).filter(row=>row && typeof row==='object').map(row=>({
      id:String(row.id||makeId()),title:String(row.title||'').slice(0,300),
      price:amount(row.price),grams:amount(row.grams),
      saved:typeof row.saved==='boolean'?row.saved:Boolean(String(row.title||'').trim() && calculate(row).total!==null)
    }));
  }
  const api={DEFAULT_WON_PER_KG,WON_PER_GRAM,rate,amount,calculate,key,parseTitles,normalize};
  if(typeof module==='object' && module.exports)module.exports=api;
  else root.BookCosts=api;
})(typeof globalThis==='object'?globalThis:this);
