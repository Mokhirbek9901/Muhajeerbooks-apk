'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'../personal-assistant');
const ui=require(path.join(root,'book-cost-list-ui.js'));
const costs=require(path.join(root,'book-costs.js'));
const html=fs.readFileSync(path.join(root,'index.html'),'utf8');
test('price missing filter includes only books without UZS or KRW price',()=>{
  const rows=[
    {title:'Nomgina',price:null,priceUzs:null,grams:240},
    {title:'Vazn ham yo‘q',price:null,grams:null},
    {title:'Som narx',price:null,priceUzs:'58000',grams:null},
    {title:'Von narx',price:6600,grams:null},
    {title:'To‘liq',price:7000,grams:350}
  ];
  assert.deepEqual(ui.filterBooks(rows,'missing-price','',costs.key).map(row=>row.title),['Vazn ham yo‘q','Nomgina']);
  assert.deepEqual(ui.filterBooks(rows,'missing-price','nom',costs.key).map(row=>row.title),['Nomgina']);
  assert.equal(ui.filterBooks(rows,'newest','',costs.key).length,5);
});
test('old filter options preserved, new option visible in real select',()=>{
  const start=html.indexOf('<select id="costPlainListFilter"');
  const end=html.indexOf('</select>',start);
  const section=html.slice(start,end);
  for(const [value,label] of [['newest','Yangi qo‘shilganlar'],['oldest','Avval qo‘shilganlar'],['missing-price','Narxi kiritilmagan'],['missing-weight','Vazni kiritilmagan'],['incomplete','To‘ldirilmagan kitoblar']]){
    assert.ok(section.includes('value="'+value+'"'),value);
    assert.ok(section.includes(label),label);
  }
});
test('v87 cache bust and search still use visible selection',()=>{
  const sw=fs.readFileSync(path.join(root,'sw.js'),'utf8');
  const app=fs.readFileSync(path.join(root,'app.js'),'utf8');
  assert.ok(sw.includes('bek-yordamchi-v87'));
  assert.ok(html.includes('book-cost-list-ui.js?v=87'));
  assert.ok(sw.includes('book-cost-list-ui.js?v=87'));
  assert.ok(app.includes("const choice=$('costPlainListFilter').value||'newest'"));
  assert.ok(app.includes("choice==='missing-price'"));
});
