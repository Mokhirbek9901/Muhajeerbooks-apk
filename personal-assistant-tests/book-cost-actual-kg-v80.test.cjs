'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const base=path.resolve(__dirname,'../personal-assistant');
const costs=require(path.join(base,'book-costs.js'));
const read=name=>fs.readFileSync(path.join(base,name),'utf8');
const original={id:'book-a',title:'Arosat',quantity:7,price:8000,grams:200,salePrice:16000,
  originRate:10000,originActualKgRate:7500,originBatchId:'old',originBatchDate:'2026-10-01',
  batches:[{id:'new-part',groupId:'new',date:'2026-10-24',quantity:3,price:10000,
    grams:300,rate:12500,actualKgRate:8500}]};
test('partiya real kg rate changes report but never book pricing calculation',()=>{
  const rows=costs.normalize([original],()=> 'safe');
  assert.deepEqual(costs.calculate(rows[0],10000),{shipping:2000,total:10000});
  const groups=costs.groupByBatch(rows,10000);
  const old=groups.find(g=>g.id==='partiya:old'),newest=groups.find(g=>g.id==='partiya:new');
  assert.equal(old.actualKgRate,7500);
  assert.equal(old.totals.shippingTotal,6000); // 4 * 200g * 7500 / 1000
  assert.equal(old.totals.total,38000);
  assert.equal(newest.actualKgRate,8500);
  assert.equal(newest.totals.shippingTotal,7650); // 3 * 300g * 8500 / 1000
  assert.equal(newest.totals.total,37650);
  assert.equal(costs.inventory(rows[0],10000).knownShipping,19250); // separate pricing 8000+11250
});
test('actual tariff remains partiya-wide, not multiplied per book',()=>{
  const second={id:'book-b',title:'Laylo',quantity:2,price:5000,grams:100,salePrice:9000,
    originRate:20000,originBatchId:'old',originActualKgRate:7500};
  const rows=costs.normalize([original,second],()=> 'safe');
  const old=costs.groupByBatch(rows,10000).find(g=>g.id==='partiya:old');
  assert.equal(old.bookCount,2);
  assert.equal(old.totals.quantityTotal,6);
  assert.equal(old.totals.shippingTotal,7500); // 4 * 200g + 2 * 100g at 7500
  assert.equal(old.totals.purchaseTotal,42000);
  assert.equal(old.totals.total,49500);
});
test('no supplied real kg tariff retains old historical pricing as estimated report',()=>{
  const row={...original,originActualKgRate:undefined,batches:[] ,quantity:4};
  const groups=costs.groupByBatch(costs.normalize([row],()=> 'safe'),10000);
  assert.equal(groups[0].actualKgRate,null);
  assert.equal(groups[0].totals.shippingTotal,8000);
});
test('historical actual tariffs are not changed when current global rate changes',()=>{
  const rows=costs.freezeHistoricalRates(costs.normalize([original],()=> 'safe'),10500);
  const a=costs.groupByBatch(rows,10000),b=costs.groupByBatch(rows,19500);
  for(const id of ['partiya:old','partiya:new']){
    assert.deepEqual(a.find(g=>g.id===id).totals,b.find(g=>g.id===id).totals);
  }
});
test('seven million Uzbek som historical purchase stays preserved with real kg shipping',()=>{
  const row={...original,quantity:4,batches:[],originFxPer1000:'8841.492544',originPurchaseUzsTotal:'7000000'};
  const group=costs.groupByBatch(costs.normalize([row],()=> 'safe'),10500)[0];
  assert.equal(group.purchaseUzsTotal,'7000000');
  assert.equal(group.som.purchase,7000000);
  assert.equal(group.totals.shippingTotal,6000);
  assert.ok(group.totals.purchaseTotal>0);
});
test('device sync and UI store independently named real rate and pricing rate',()=>{
  const sync=require(path.join(base,'book-cost-device-sync.js'));
  const rows=costs.normalize([original],()=> 'safe');
  const snapshot=sync.snapshot({bookCosts:rows,bookCostRate:9999,bookCostComparisons:[]});
  assert.equal(snapshot.books[0].originActualKgRate,7500);
  assert.equal(snapshot.books[0].originRate,10000);
  assert.equal(snapshot.books[0].batches[0].actualKgRate,8500);
  assert.equal(snapshot.books[0].batches[0].rate,12500);
  const app=read('app.js'),html=read('index.html');
  for(const id of ['costSimpleBatchActualKg','costSimplePricingKg','costBatchActualKg'])
    assert.ok(html.includes('id="'+id+'"')&&app.includes(id),id);
  assert.ok(app.includes('originRate:kg'));
  assert.ok(app.includes('row.originRate=kg'));
});
test('cache versions and static syntax are aligned',()=>{
  const html=read('index.html'),sw=read('sw.js');
  assert.ok(sw.includes('bek-yordamchi-v81'));
  for(const name of ['app.js','book-costs.js','styles.css','book-cost-device-sync.js']){
    assert.ok(html.includes(name+'?v=81'),name+' html');
    assert.ok(sw.includes(name+'?v=81'),name+' sw');
  }
});