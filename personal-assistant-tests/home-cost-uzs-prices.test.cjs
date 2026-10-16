'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const dir=path.join(__dirname,'../personal-assistant');
const app=fs.readFileSync(path.join(dir,'app.js'),'utf8');
const css=fs.readFileSync(path.join(dir,'styles.css'),'utf8');
const costs=require('../personal-assistant/book-costs.js');
function homeCode(){
 const start=app.indexOf('  function renderCostHomeBooks(){');
 const end=app.indexOf('  function renderCostReadyList(){',start);
 assert.ok(start>0&&end>start);
 return app.slice(start,end);
}
test('home cost cards show UZS per single book FIRST and total for all copies SECOND',()=>{
 const code=homeCode();
 const unit=code.indexOf("'<div class=\"cost-home-book-som-unit\">");
 const total=code.indexOf("'<div class=\"cost-home-book-som-total\">");
 assert.ok(unit!==-1&&total>unit,'unit price always precedes total');
 assert.ok(code.includes("costSom(inv.unitCost)"),'convert landed cost of a single book');
 assert.ok(code.includes("costSom(inv.total)"),'convert landed cost of all copies');
 assert.ok(code.includes("Jami · '+qty+' ta"),'disclose number of books in total');
 assert.ok(!code.includes('data-cost-edit'),'home stays read-only');
 assert.ok(!code.includes('data-cost-quick'),'home stays read-only');
});
test('both sums are independent of profit and change with received quantity',()=>{
 const book={title:'Hayotdan mazmun izlab',price:8000,grams:63,salePrice:15000};
 const single=costs.inventory({...book,quantity:1},10000);
 const four=costs.inventory({...book,quantity:4},10000);
 assert.equal(single.unitCost,four.unitCost);
 assert.equal(four.total,4*single.unitCost);
 assert.equal(four.quantity,4);
 const uzsPer1000Won=8000;
 const convertedUnit=Math.round(single.unitCost*uzsPer1000Won/1000);
 const convertedTotal=Math.round(four.total*uzsPer1000Won/1000);
 assert.equal(convertedTotal,convertedUnit*4);
});
test('iPhone layout reserves two compact price tiles with visible labels',()=>{
 assert.ok(css.includes('.cost-home-book .cost-home-book-som-total strong'));
 assert.ok(css.includes('grid-template-columns:repeat(2,minmax(0,1fr))'));
 assert.ok(css.includes('.cost-home-book .cost-home-book-som-unit')||css.includes('.cost-home-book .cost-home-book-som>div'));
});
