(function(root,factory){
  'use strict';
  const api=factory();
  if(typeof module==='object'&&module.exports)module.exports=api;else root.BookCostListUI=api;
})(typeof globalThis==='object'?globalThis:this,function(){
  'use strict';
  function missingPrice(row){return (row.price===null||row.price===undefined)&&(row.priceUzs===null||row.priceUzs===undefined||String(row.priceUzs).trim()==='');}
  function missingWeight(row){return row.grams===null||row.grams===undefined;}
  function filterBooks(rows,choice='newest',search='',normalize=value=>String(value||'').toLowerCase()){
    const unique=new Map();
    (Array.isArray(rows)?rows:[]).forEach((row,index)=>{
      if(!String(row?.title||'').trim())return;
      const key=normalize(row.title);
      if(!unique.has(key))unique.set(key,{row,index,latest:index});
      else{const found=unique.get(key);found.row=row;found.latest=index;}
    });
    let values=[...unique.values()];
    if(search){const q=normalize(search);values=values.filter(item=>normalize(item.row.title).includes(q));}
    if(choice==='missing-price')values=values.filter(item=>missingPrice(item.row));
    if(choice==='missing-weight')values=values.filter(item=>missingWeight(item.row));
    if(choice==='incomplete')values=values.filter(item=>missingPrice(item.row)||missingWeight(item.row));
    if(choice==='oldest')values.sort((a,b)=>a.index-b.index);
    else values.sort((a,b)=>b.latest-a.latest);
    return values.map(item=>item.row);
  }
  function parseNameList(value,normalize=text=>String(text||'').toLocaleLowerCase()){
    const lines=String(value||'').split(/\r?\n/);
    const seen=new Set(),names=[];
    for(const raw of lines){
      // Accept plain lines, "1. Title", "2) Title", "- Title" and "• Title".
      const name=raw.trim().replace(/^(?:\d{1,4}[.)]\s+|[-•*]\s+)/,'').trim();
      if(!name)continue;
      if(name.length>300)return {names:[],error:'Kitob nomi 300 belgidan oshmasin.'};
      const key=normalize(name);
      if(!key||seen.has(key))continue;
      seen.add(key);
      if(names.length>=1000)return {names:[],error:'Bir martada 1 000 tagacha kitob nomini kiriting.'};
      names.push(name);
    }
    return {names,error:''};
  }
  return {filterBooks,missingPrice,missingWeight,parseNameList};
});