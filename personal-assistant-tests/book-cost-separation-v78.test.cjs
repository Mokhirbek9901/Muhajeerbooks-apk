'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const costs = require('../personal-assistant/book-costs.js');

const costPath = path.join(__dirname,'..','personal-assistant');
const read = file => fs.readFileSync(path.join(costPath,file),'utf8');
const samples = () => [
  {id:'a',title:'Arosat',quantity:7,price:8000,grams:200,salePrice:16000,
   originBatchId:'p1',originBatchDate:'2026-10-01',originRate:10000,
   batches:[{id:'a2',groupId:'p2',quantity:3,date:'2026-10-24',price:10000,grams:300,rate:10000}]},
  {id:'b',title:'Kitob B',quantity:2,price:12000,grams:100,salePrice:20000,
   originBatchId:'p1',originBatchDate:'2026-10-01',originRate:10000}
];
const normal = () => costs.normalize(samples(),()=> 'safe-id');

test('catalog has one Arosat with separate 4+3 batch arrivals',()=>{
  const rows=normal(),parts=costs.arrivalParts(rows[0]);
  assert.equal(rows.filter(row=>costs.key(row.title)==='arosat').length,1);
  assert.deepEqual(parts.map(part=>part.quantity),[4,3]);
  assert.equal(rows[0].quantity,7);
});
test('unit calculation is independent from batch arrival count',()=>{
  assert.deepEqual(costs.calculate({price:8000,grams:200},10000),{shipping:2000,total:10000});
  assert.deepEqual(costs.calculate({price:8000,grams:300},12000),{shipping:3600,total:11600});
});
test('first and second batch costs are not overwritten by latest unit data',()=>{
  const groups=costs.groupByBatch(normal(),10000);
  assert.equal(groups.find(x=>x.id==='partiya:p1').totals.total,66000);
  assert.equal(groups.find(x=>x.id==='partiya:p2').totals.total,39000);
});
test('profit is forecast revenue minus purchase and shipping for every received unit',()=>{
  const result=costs.summary(normal(),10000);
  assert.equal(result.quantityTotal,9);
  assert.equal(result.purchaseTotal,86000);
  assert.equal(result.shippingTotal,19000);
  assert.equal(result.total,105000);
  assert.equal(result.revenueTotal,152000);
  assert.equal(result.profitTotal,47000);
});
test('lifetime totals equal the exact sum of all independent batch totals',()=>{
  const rows=normal(),groups=costs.groupByBatch(rows,10000);
  for(const key of ['total','purchaseTotal','shippingTotal','profitTotal','quantityTotal']){
    assert.equal(groups.reduce((sum,g)=>sum+g.totals[key],0),costs.summary(rows,10000)[key],key);
  }
});
test('changing kg tariff does not change locked historical deliveries',()=>{
  const raw=[{title:'Old',quantity:3,price:8000,grams:250,batches:[{
    id:'b',groupId:'part-2',quantity:2,price:12000,grams:300}]}];
  const fixed=costs.freezeHistoricalRates(costs.normalize(raw,()=> 'id'),7500);
  const old=costs.summary(fixed,7500),changed=costs.summary(fixed,20000);
  assert.equal(fixed[0].originRate,7500);
  assert.equal(fixed[0].batches[0].rate,7500);
  assert.deepEqual(changed,old);
});
test('legacy data with unknown partiya is never assigned a guessed identifier',()=>{
  const rows=costs.normalize([{title:'Unknown',price:1000,grams:100,quantity:2}],()=> 'id');
  const groups=costs.groupByBatch(rows,10000);
  assert.equal(groups.length,1);
  assert.equal(groups[0].id,'legacy');
  assert.equal(groups[0].legacy,true);
});
test('single-unit catalog and bidirectional currency display use separate fields',()=>{
  const app=read('app.js'),html=read('index.html');
  assert.ok(app.includes('const seenCatalogNames=new Set()'));
  assert.ok(app.includes('const conflictingTitle=Boolean(original'));
  assert.match(app,/row\.price===null\?'—':costSomCompact\(row\.price\)/);
  assert.ok(app.includes("costSimplePurchaseSom"));
  assert.ok(html.includes('id="costSimplePurchaseSom"'));
  assert.ok(html.includes('id="costSimpleCurrency"'));
  assert.ok(html.includes('id="costSimpleQuantityWrap"'));
  assert.ok(html.includes('id="costSimpleBatch"'));
});
test('report has both modes, selected-only detailed figures and forecast disclaimer',()=>{
  const html=read('index.html'),app=read('app.js');
  assert.ok(html.indexOf('id="costReportModeBatch"')<html.indexOf('id="costBatchSelect"'));
  assert.match(html,/belgilangan narxda sotilsa olinadigan kutilayotgan foyda/);
  const from=app.indexOf("    $('costReportValues').innerHTML=");
  const to=app.indexOf("    $('costReportComparisons').innerHTML=",from);
  const details=app.slice(from,to);
  assert.ok(details.includes('reportTotals.purchaseTotal'));
  assert.ok(details.includes('reportTotals.shippingTotal'));
  assert.ok(details.includes('reportTotals.total'));
  assert.ok(details.includes('reportTotals.profitTotal'));
  assert.ok(!details.includes('totals.purchaseTotal'));
});
test('compact style remains limited to cost workspace and cache references agree',()=>{
  const css=read('styles.css'),html=read('index.html'),sw=read('sw.js');
  assert.ok(css.includes('body[data-workspace="costs"] #costArrivalOverview'));
  assert.ok(css.includes('body[data-workspace="costs"] .cost-unit-book'));
  assert.ok(css.includes('#costBatchPicker[hidden]'));
  for(const name of ['app.js','styles.css','book-costs.js']){
    assert.ok(html.includes(name+'?v=81'));
    assert.ok(sw.includes(name+'?v=81'));
  }
  assert.ok(sw.includes('bek-yordamchi-v81'));
});
