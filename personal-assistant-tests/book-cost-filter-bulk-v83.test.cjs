'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const base=path.resolve(__dirname,'../personal-assistant');
const ui=require(path.join(base,'book-cost-list-ui.js'));
const costs=require(path.join(base,'book-costs.js'));
const read=p=>fs.readFileSync(path.join(base,p),'utf8');
const books=[
 {id:'a',title:'Arosat',price:5000,grams:250},
 {id:'b',title:'Ko‘rlik',price:7000,grams:null},
 {id:'c',title:'Laylo',price:null,grams:300},
 {id:'d',title:'Oq nilufarlar',price:4000,grams:150},
 {id:'e',title:'Arosat',price:6500,grams:240},
 {id:'f',title:'Nizomimulk siyosatnoma',price:null,grams:null}
];
test('oldest first follows insertion order, latest duplicate data is displayed',()=>{
 const rows=ui.filterBooks(books,'oldest','',costs.key);
 assert.deepEqual(rows.map(r=>r.title),['Arosat','Ko‘rlik','Laylo','Oq nilufarlar','Nizomimulk siyosatnoma']);
 assert.equal(rows[0].price,6500);
});
test('newest first follows latest saved title and retains unique rows',()=>{
 const rows=ui.filterBooks(books,'newest','',costs.key);
 assert.deepEqual(rows.map(r=>r.title),['Nizomimulk siyosatnoma','Arosat','Oq nilufarlar','Laylo','Ko‘rlik']);
 assert.equal(rows.length,5);
});
test('weight-only filter does not include missing-price books with known weight',()=>{
 const rows=ui.filterBooks(books,'missing-weight','',costs.key);
 assert.deepEqual(rows.map(r=>r.id),['f','b']);
});
test('incomplete filter includes missing price OR missing weight',()=>{
 const rows=ui.filterBooks(books,'incomplete','',costs.key);
 assert.deepEqual(rows.map(r=>r.id),['f','c','b']);
});
test('search and missing-weight can be combined without altering state',()=>{
 const rows=ui.filterBooks(books,'missing-weight','Nizom',costs.key);
 assert.deepEqual(rows.map(r=>r.id),['f']);
 assert.equal(books.length,6);
});
test('home catalog shows entire list and list uses the same filter engine',()=>{
 const app=read('app.js');
 const start=app.indexOf('  function renderCostPlainCatalog(){'),end=app.indexOf('  function renderCostReadyList(){',start);
 const fn=app.slice(start,end);
 assert.ok(fn.includes('window.BookCostListUI.filterBooks'));
 assert.ok(fn.includes("all.map(costPlainCard).join('')"));
 assert.ok(!fn.includes('all.slice(0,5)'));
 assert.ok(fn.includes("('costPlainListFilter').value"));
 assert.ok(fn.includes("('costSearch').value"));
});
test('filter is a visible control with the four expected choices',()=>{
 const html=read('index.html'),css=read('styles.css');
 for(const val of ['newest','oldest','missing-weight','incomplete'])assert.ok(html.includes('<option value="'+val+'">'),val);
 assert.ok(html.includes('id="costPlainListFilter"'));
 assert.ok(css.includes('body[data-workspace="costs"] #screen-book-costs #costPlainListFilter{display:block!important'));
});
test('add entry explicitly offers one or many full books',()=>{
 const html=read('index.html');
 for(const id of ['costAddChoice','costBulkSimplePanel','costBulkSimpleForm','costBulkSimpleRows','costBulkSimpleAddRow','costBulkSimpleSave']){
 assert.ok(html.includes('id="'+id+'"'),id);}
 for(const mode of ['single','bulk'])assert.ok(html.includes('data-cost-add-mode="'+mode+'"'));
 const app=read('app.js');
 assert.ok(app.includes("if(view==='entry')costAddMode='choose'"));
 assert.ok(app.includes("costAddMode='single';costView='entry'"));
 assert.ok(app.includes("    $('costSimpleForm').hidden="));
 assert.ok(app.includes("    $('costBulkSimplePanel').hidden="));
});
test('bulk row editor includes individual full price and grams and live result',()=>{
 const app=read('app.js');const a=app.indexOf('  function renderCostBulkSimpleRows(){'),b=app.indexOf('  function saveCostBulkSimple(event){',a);
 const text=app.slice(a,b);
 for(const f of ['title','priceUzs','grams'])assert.ok(text.includes('data-cost-bulk-field="'+f+'"'));
 assert.ok(text.includes("costs.calculate({price,grams},state.bookCostRate)"));
 assert.ok(text.includes('costSomCompact(calc.total)'));
});
test('bulk save validates all, prevents duplicates and commits atomically without shop sync',()=>{
 const app=read('app.js');const a=app.indexOf('  function saveCostBulkSimple(event){'),b=app.indexOf('  function openSimpleCostEditor(',a);
 const text=app.slice(a,b);
 assert.ok(text.includes('pending.has(key)'));
 assert.ok(text.includes('existing.has(key)'));
 assert.ok(text.includes('newRows.push({id:makeId()'));
 assert.ok(text.includes('state.bookCosts=[...previous,...newRows]'));
 assert.ok(text.includes("persistBookCosts(newRows.length+' ta kitob saqlandi.',false)"));
 assert.ok(text.includes('state.bookCosts=previous'));
 assert.ok(!text.includes('pushCostCloud('));
});
test('v83 code and assets are version matched and loaded before app',()=>{
 const html=read('index.html'),sw=read('sw.js');
 assert.ok(sw.includes('bek-yordamchi-v83'));
 for(const file of ['app.js','styles.css','book-cost-simple.js','book-cost-list-ui.js']){
 assert.ok(html.includes(file+'?v=83'),file+' html');
 assert.ok(sw.includes(file+'?v=83'),file+' sw');
 }
 assert.ok(html.indexOf('book-cost-list-ui.js')<html.indexOf('app.js'));
});
