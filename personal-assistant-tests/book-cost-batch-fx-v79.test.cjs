'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const costs=require('../personal-assistant/book-costs.js');
const sync=require('../personal-assistant/book-cost-device-sync.js');
const read=file=>fs.readFileSync(path.join(__dirname,'..','personal-assistant',file),'utf8');
const raw=()=>[
 {id:'a',title:'Arosat',quantity:7,price:8000,priceUzs:'72000',grams:200,salePrice:16000,
  originRate:10000,originBatchId:'old',originBatchDate:'2026-10-01',originFxPer1000:'9000',
  batches:[{id:'b',groupId:'new',date:'2026-10-24',quantity:3,price:10000,priceUzs:'80000',grams:300,rate:10000,fxPer1000:'8500'}]},
 {id:'c',title:'Kitob B',quantity:2,price:12000,grams:100,salePrice:20000,
  originRate:10000,originBatchId:'old',originBatchDate:'2026-10-01',originFxPer1000:'9000'}
];
const normalize=()=>costs.normalize(raw(),()=> 'id');
test('each part retains its exact own fx and original Uzbek unit price',()=>{
 const parts=costs.arrivalParts(normalize()[0]);
 assert.deepEqual(parts.map(x=>x.fxPer1000),['9000','8500']);
 assert.deepEqual(parts.map(x=>x.priceUzs),['72000','80000']);
});
test('historic totals remain unchanged after current kg tariff changes',()=>{
 const rows=normalize();
 const a=costs.groupByBatch(rows,10000),b=costs.groupByBatch(rows,20000);
 assert.deepEqual(a,b);
 assert.equal(a.find(g=>g.id==='partiya:old').totals.total,66000);
 assert.equal(a.find(g=>g.id==='partiya:new').totals.total,39000);
});
test('historical batch UZS is converted at its own saved quote',()=>{
 const old=costs.groupByBatch(normalize(),20000).find(x=>x.id==='partiya:old');
 assert.equal(old.fxPer1000,'9000');
 assert.equal(old.som.purchase,old.totals.purchaseTotal*9);
 assert.equal(old.som.total,old.totals.total*9);
 const newer=costs.groupByBatch(normalize(),20000).find(x=>x.id==='partiya:new');
 assert.equal(newer.fxPer1000,'8500');
 assert.equal(newer.som.purchase,newer.totals.purchaseTotal*8.5);
});
test('editable historical 7 million so‘m controls that batch only',()=>{
 const rows=normalize();rows[0].originPurchaseUzsTotal='7000000';
 const groups=costs.groupByBatch(rows,10000);
 const first=groups.find(g=>g.id==='partiya:old');
 const second=groups.find(g=>g.id==='partiya:new');
 assert.equal(first.purchaseUzsTotal,'7000000');
 assert.equal(first.som.purchase,7000000);
 assert.ok(Math.abs(first.totals.purchaseTotal-(7000000/9))<.00001);
 assert.equal(first.totals.total,first.totals.purchaseTotal+first.totals.shippingTotal);
 assert.equal(second.totals.total,39000);
 assert.equal(second.purchaseUzsTotal,null);
 assert.equal(costs.sumGroupTotals(groups).total,first.totals.total+second.totals.total);
});
test('unknown historic FX is not guessed from current global quote',()=>{
 const old=costs.groupByBatch(costs.normalize([{id:'old',title:'Unassigned',quantity:2,price:700,grams:100,salePrice:1000}],()=> 'id'),13500)[0];
 assert.equal(old.legacy,true);
 assert.equal(old.fxPer1000,null);
 assert.equal(old.som,null);
});
test('device backup and sync carry historic FX and batch expenses without loss',()=>{
 const state={bookCosts:normalize(),bookCostRate:10000,bookCostComparisons:[]};
 state.bookCosts[0].originPurchaseUzsTotal='7000000';
 state.bookCosts[0].batches[0].purchaseUzsTotal='240000';
 const snap=sync.snapshot(state);
 const result=costs.normalize(snap.books,()=> 'id');
 assert.equal(result[0].originFxPer1000,'9000');
 assert.equal(result[0].originPurchaseUzsTotal,'7000000');
 assert.equal(result[0].batches[0].fxPer1000,'8500');
 assert.equal(result[0].batches[0].purchaseUzsTotal,'240000');
});
test('zero trailing decimal is not introduced by UZS display',()=>{
 const app=read('app.js');
 assert.match(app,/function costUzsClean\(value\)/);
 assert.match(app,/maximumFractionDigits:2/);
});
test('history editor and repeated-title consolidator are wired',()=>{
 const app=read('app.js'),html=read('index.html'),css=read('styles.css');
 for(const id of ['costBatchHistoryEditor','costBatchFxRate','costBatchPurchaseUzs','costBatchHistorySave','costSimpleBatchFx','costSimplePurchaseUzsTotal']){
  assert.ok(html.includes('id="'+id+'"'),id);
  assert.ok(app.includes("$('"+id+"')"),id);
 }
 assert.ok(app.includes('const together=new Map()'));
 assert.ok(css.includes('.cost-unified-book'));
});
test('PWA references are refreshed together to v79',()=>{
 const html=read('index.html'),sw=read('sw.js');
 for(const p of ['app.js','book-costs.js','styles.css','book-cost-device-sync.js']){
  assert.ok(html.includes(p+'?v=79'),p);
  assert.ok(sw.includes(p+'?v=79'),p);
 }
 assert.ok(sw.includes('bek-yordamchi-v79'));
});
