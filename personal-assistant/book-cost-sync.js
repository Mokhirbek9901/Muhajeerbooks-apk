(function(root){
  'use strict';
  const costs=typeof module==='object' && module.exports?require('./book-costs.js'):root.BookCosts;
  const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  function titleKey(title){
    return costs.key(title).normalize('NFKD').replace(/[\u0300-\u036f]/g,'').replace(/['’‘ʻʼ`ʹ"“”]/g,'').replace(/[^\p{L}\p{N}]+/gu,' ').trim();
  }
  // Verified spellings and bundle titles; never use fuzzy matching for cost writes.
  const aliases=new Map([
    ['Tobeyinlardan maktublar','Tobe’iynlardan maktublar'],
    ['Harvad metodi','Harvard metodi'],
    ['Barzah hayoti','Barzax hayoti'],
    ['Men bas qi ey nafs','Men (Bas qil, ey nafs!)'],
    ['Yoz qisqartir','Yoz, qisqartir: Kuchli matn yozish siri'],
    ['Yashil kitob Muhammar kazzofiy','Yashil kitob'],
    ['Saodat asri qissalari 4 talik','Saodat asri qissalari. 1–4 kitoblar'],
    ['Payg’ambarlar tarixi 4 talik',"Payg'ambarlar tarixi"]
  ].map(([a,b])=>[titleKey(a),titleKey(b)]));
  function candidates(title,catalog){
    const key=titleKey(title),canonical=aliases.get(key)||key;
    if(!key)return [];
    return catalog.filter(b=>titleKey(b.title)===canonical || (b.author && titleKey(b.title+' '+b.author)===key));
  }
  function salePrice(book,now=Date.now()){
    const active=Number(book.discount_percent)>0 && (!book.discount_ends_at || Date.parse(book.discount_ends_at)>now);
    return Math.round(Number(book.price||0)*(100-(active?Number(book.discount_percent):0))/100);
  }
  function match(rows,catalog){
    const byId=new Map(catalog.map(b=>[b.id,b]));let linked=0;
    for(const row of rows){
      let book=byId.get(row.muhajeerId);
      if(!book && !row.muhajeerId){const matches=candidates(row.title,catalog);if(matches.length===1){book=matches[0];row.muhajeerId=book.id;linked++;}}
      if(book){row.salePrice=salePrice(book);row.muhajeerTitle=book.title;row.muhajeerCost=book.cost_price??null;}
    }
    return linked;
  }
  function plan(rows,catalog,rate){
    const map=new Map(catalog.map(b=>[b.id,b])),used=new Set(),changes=[],skipped=[];
    for(const row of rows){
      const book=map.get(row.muhajeerId),total=costs.calculate(row,rate).total;
      if(!row.saved || !book || !uuid.test(row.muhajeerId) || total===null || !Number.isInteger(total) || total>1e9){skipped.push(row);continue;}
      if(used.has(book.id))throw Error('Bir Muhajeer kitobiga bir nechta qator bog‘langan. Bog‘lashni tuzating.');
      used.add(book.id);
      if(total!==(book.cost_price??null))changes.push({id:book.id,cost_price:total,expected_cost_price:book.cost_price??null});
    }
    return {changes,skipped};
  }
  const api={salePrice,match,plan,titleKey};if(typeof module==='object'&&module.exports)module.exports=api;else root.BookCostSync=api;
})(typeof globalThis==='object'?globalThis:this);
