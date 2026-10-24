(function(root,factory){
  'use strict';
  const api=factory();
  if(typeof module==='object'&&module.exports)module.exports=api;else root.BookCostListUI=api;
})(typeof globalThis==='object'?globalThis:this,function(){
  'use strict';
  function missingPrice(row){return row.price===null||row.price===undefined;}
  function missingWeight(row){return row.grams===null||row.grams===undefined;}
  function filterBooks(rows,choice='newest',search='',normalize=value=>String(value||'').toLowerCase()){
    const unique=new Map();
    (Array.isArray(rows)?rows:[]).forEach((row,index)=>{
      if(!String(row?.title||'').trim())return;
      const key=normalize(row.title);
      if(!unique.has(key))unique.set(key,{row,index});
    });
    let values=[...unique.values()];
    if(search){const q=normalize(search);values=values.filter(item=>normalize(item.row.title).includes(q));}
    if(choice==='missing-weight')values=values.filter(item=>missingWeight(item.row));
    if(choice==='incomplete')values=values.filter(item=>missingPrice(item.row)||missingWeight(item.row));
    if(choice==='oldest')values.sort((a,b)=>a.index-b.index);
    else values.sort((a,b)=>b.index-a.index);
    return values.map(item=>item.row);
  }
  return {filterBooks,missingPrice,missingWeight};
});