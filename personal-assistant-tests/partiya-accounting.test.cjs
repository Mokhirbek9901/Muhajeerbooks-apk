'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const costs=require('../personal-assistant/book-costs.js');
const sync=require('../personal-assistant/book-cost-device-sync.js');

const sample=[
 {id:'arosat',title:'Arosat',quantity:7,price:8000,grams:200,salePrice:16000,saved:true,originBatchId:'first',originBatchDate:'2026-10-01',
  batches:[{id:'arrival',groupId:'second',date:'2026-10-24',quantity:3,price:10000,grams:300,rate:10000}]},
 {id:'kitob-b',title:'Kitob B',quantity:2,price:12000,grams:100,salePrice:20000,saved:true,originBatchId:'first',originBatchDate:'2026-10-01'}
];

test('one catalog title can appear in two independent groups with different landed prices',()=>{
 const rows=costs.normalize(sample,()=>'_id');
 assert.equal(rows.length,2);
 assert.equal(rows[0].quantity,7);
 assert.equal(costs.inventory(rows[0],10000).knownTotal,79000);
 const groups=costs.groupByBatch(rows,10000);
 assert.equal(groups.length,2);
 const first=groups.find(g=>g.id==='partiya:first');
 const second=groups.find(g=>g.id==='partiya:second');
 assert.equal(first.bookCount,2);
 assert.equal(first.totals.quantityTotal,6);
 assert.equal(first.totals.total,66000);
 assert.equal(first.totals.profitTotal,38000);
 assert.equal(second.bookCount,1);
 assert.equal(second.totals.quantityTotal,3);
 assert.equal(second.totals.total,39000);
 assert.equal(second.totals.profitTotal,9000);
 assert.equal(groups.reduce((total,g)=>total+g.totals.total,0),costs.summary(rows,10000).total);
});

test('group identifiers survive both normalization and cross-device snapshot',()=>{
 const rows=costs.normalize(sample,()=>'_id');
 const snap=sync.snapshot({bookCosts:rows,bookCostRate:10000,bookCostComparisons:[]});
 assert.equal(snap.books[0].originBatchId,'first');
 assert.equal(snap.books[0].batches[0].groupId,'second');
 const restored=costs.normalize(snap.books,()=>'_id');
 assert.equal(restored[0].batches[0].groupId,'second');
});

test('legacy groups are marked uncertain instead of guessed from common dates',()=>{
 const raw=[{id:'a',title:'A',quantity:2,price:1000,grams:100,salePrice:2000,batches:[{id:'b',date:'2026-10-24',quantity:1,price:1500,grams:100}]}];
 const groups=costs.groupByBatch(costs.normalize(raw,()=>'_id'),10000);
 assert.equal(groups.length,1);
 assert.equal(groups[0].legacy,true);
 assert.equal(groups[0].totals.quantityTotal,2);
});

test('last import recoverable from exact imported IDs with no guessed grouping',()=>{
 const original=[{id:'a',title:'A',quantity:3,price:1000,grams:100,
   batches:[{id:'b',date:'2026-10-24',quantity:2,price:2000,grams:150}]}];
 const restored=costs.restoreLastImportGroups(original,{id:'known',date:'2026-10-24',items:[{type:'batch',id:'a',batchId:'b'}]},()=>'_id');
 assert.equal(restored[0].batches[0].groupId,'known');
 assert.equal(restored[0].quantity,3);
 const groups=costs.groupByBatch(restored,10000);
 assert.equal(groups.length,2);
 assert.equal(groups.find(g=>g.id==='partiya:known').totals.quantityTotal,2);
 assert.equal(groups.find(g=>g.id==='legacy').totals.quantityTotal,1);
});

test('arrivalParts counts only new arrivals, while the catalog keeps one title',()=>{
 const rows=costs.normalize(sample,()=>'_id');
 const parts=costs.arrivalParts(rows[0]);
 assert.deepEqual(parts.map(x=>x.quantity),[4,3]);
 assert.equal(rows[0].quantity,7);
 assert.equal(rows.filter(x=>x.title==='Arosat').length,1);
 assert.equal(costs.inventory(rows[0],10000).knownProfit,33000);
});

test('old and new batch historical costs survive newer global shipping rates',()=>{
 const rows=costs.normalize(sample,()=>'_id');
 rows[0].originRate=10000;
 const initial=costs.inventory(rows[0],10000);
 const changed=costs.inventory(rows[0],18000);
 assert.equal(initial.knownTotal,79000);
 assert.equal(changed.knownTotal,initial.knownTotal);
});

test('separate finance-only overview and single lifetime arrival display',()=>{
 const fs=require('node:fs');
 const path=require('node:path');
 const source=fs.readFileSync(path.join(__dirname,'../personal-assistant/app.js'),'utf8');
 const begin=source.indexOf('function renderCostHomeBooks(){');
 const end=source.indexOf('function renderCostBatchCards(groups){',begin);
 const overview=source.slice(begin,end);
 assert.ok(overview.includes('Jami xarid'));
 assert.ok(overview.includes('Jami yetkazish'));
 assert.ok(overview.includes('Jami tan narxi'));
 assert.ok(overview.includes('Kutiladigan jami foyda'));
 assert.ok(!overview.includes('cost-home-book-qty'));
 assert.ok(!overview.includes('1 dona tan narxi'));
 assert.ok(source.includes('Jami kelgan: '));
 assert.ok(source.includes('Narx va partiyalar tafsilotlari'));
 assert.ok(source.includes('costs.arrivalParts(row)'));
});
