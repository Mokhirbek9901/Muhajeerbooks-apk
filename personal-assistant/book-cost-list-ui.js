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
      if(!unique.has(key))unique.set(key,{row,index,latest:index});
      else{const found=unique.get(key);found.row=row;found.latest=index;}
    });
    let values=[...unique.values()];
    if(search){const q=normalize(search);values=values.filter(item=>normalize(item.row.title).includes(q));}
    if(choice==='missing-weight')values=values.filter(item=>missingWeight(item.row));
    if(choice==='incomplete')values=values.filter(item=>missingPrice(item.row)||missingWeight(item.row));
    if(choice==='oldest')values.sort((a,b)=>a.index-b.index);
    else values.sort((a,b)=>b.latest-a.latest);
    return values.map(item=>item.row);
  }
  function parsePastedTitles(raw,existingTitles=[],normalize=value=>String(value||'').toLowerCase()){
    const old=new Set(existingTitles.map(item=>normalize(typeof item==='string'?item:item?.title)).filter(Boolean));
    const used=new Set(),titles=[],invalid=[];
    let duplicates=0,sourceCount=0;
    const lines=String(raw||'').replace(/\r\n?/g,'\n').split('\n');
    for(const original of lines){
      // Remove list prefixes, never treat prices, quantities or commas as separators.
      const title=original.trim()
        .replace(/^(?:(?:\d{1,4}[.)]\s+)|(?:[-•●◦*]\s+)|(?:☐\s+))/, '')
        .trim();
      if(!title)continue;
      sourceCount++;
      if(title.length>300){invalid.push('Kitob nomi 300 belgidan uzun: '+title.slice(0,50));continue;}
      const key=normalize(title);
      if(!key){invalid.push('Kitob nomi noto‘g‘ri: '+title);continue;}
      if(old.has(key)||used.has(key)){duplicates++;continue;}
      used.add(key);titles.push(title);
    }
    return {titles,duplicates,invalid,sourceCount};
  }
  return {filterBooks,missingPrice,missingWeight,parsePastedTitles};
});