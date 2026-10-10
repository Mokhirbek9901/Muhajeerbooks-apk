(function(root){
  'use strict';
  const WON_PER_GRAM=10;
  function amount(value){
    if(value===null || value===undefined || String(value).trim()==='')return null;
    const text=String(value).trim().replace(/[\s₩]/g,'').replace(/,/g,'');
    if(!/^\d+(?:\.\d+)?$/.test(text))return null;
    const number=Number(text);
    return Number.isFinite(number) && number>=0 && number<=1e9 ? number : null;
  }
  function calculate(row){
    const price=amount(row.price),grams=amount(row.grams);
    const shipping=grams===null?null:Math.round(grams*WON_PER_GRAM);
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
  const api={WON_PER_GRAM,amount,calculate,key,parseTitles,normalize};
  if(typeof module==='object' && module.exports)module.exports=api;
  else root.BookCosts=api;
})(typeof globalThis==='object'?globalThis:this);
