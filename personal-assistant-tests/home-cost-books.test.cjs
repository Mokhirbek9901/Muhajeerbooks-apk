'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.join(__dirname,'../personal-assistant');
const html=fs.readFileSync(path.join(root,'index.html'),'utf8');
const app=fs.readFileSync(path.join(root,'app.js'),'utf8');
const css=fs.readFileSync(path.join(root,'styles.css'),'utf8');
const cost=require('../personal-assistant/book-costs.js');

test('cost overview contains a distinct compact book collection and search',()=>{
 const ids=['costHomeBooksPanel','costHomeBooksTitle','costHomeBooksCount','costHomeSearch','costHomeBooksList'];
 for(const id of ids)assert.ok(html.includes('id="'+id+'"'),id+' exists');
 assert.ok(html.includes('Barcha kitoblar'));
 assert.ok(html.includes('Bu yerda faqat ma’lumotlar ko‘rinadi.'));
});

test('homepage book summaries are read-only and include all named books',()=>{
 const start=app.indexOf('  function renderCostHomeBooks(){');
 const end=app.indexOf('  function renderCostReadyList(){',start);
 assert.ok(start>0&&end>start);
 const fn=app.slice(start,end);
 assert.ok(fn.includes("state.bookCosts.filter(row=>String(row.title||'').trim()).slice().reverse()"),
   'home derives list from all named saved or draft books, not 3 recent ones');
 assert.ok(fn.includes('costs.inventory(row,state.bookCostRate)'),'shows batch value');
 assert.ok(fn.includes("costSom(inv.total)"),'displays converted total');
 assert.ok(fn.includes('cost-home-book-qty'),'arrival count visible');
 assert.ok(fn.includes('cost-home-book-profit'),'expected profit visible');
 assert.ok(!fn.includes('data-cost-edit'),'no edit buttons on homepage cards');
 assert.ok(!fn.includes('data-cost-quick'),'no inline editable fields');
 assert.ok(app.includes("$('costHomeBooksPanel').hidden=costView!=='main'"));
 assert.ok(app.includes("$('costHomeSearch').addEventListener('input',renderCostHomeBooks)"));
});

test('editing remains separate and unchanged',()=>{
 assert.ok(html.includes('id="costListPanel"'));
 assert.ok(html.includes('id="costSimpleForm"'));
 assert.ok(app.includes("$('costListPanel').hidden=costView!=='list'"));
 assert.ok(app.includes('data-cost-edit'));
 assert.ok(css.includes('.cost-home-books[hidden]{display:none!important}'));
});

test('arrival quantity still calculates per-unit and total independently',()=>{
 const row={id:'m',title:'Arosat',quantity:10,price:15000,grams:200,salePrice:24000,saved:true};
 const value=cost.inventory(row,10000);
 assert.equal(value.unitCost,17000);
 assert.equal(value.total,170000);
 assert.equal(value.profit,70000);
});
