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
test('one-or-many picker uses a single large textarea for pasted titles',()=>{
 const html=read('index.html');
 for(const id of ['costAddChoice','costBulkSimplePanel','costBulkSimpleForm','costBulkPasteNames','costBulkPasteCount','costBulkSimpleSave'])assert.ok(html.includes('id="'+id+'"'),id);
 assert.ok(!html.includes('id="costBulkSimpleRows"'));
 assert.ok(html.includes('data-cost-add-mode="single"'));
 assert.ok(html.includes('data-cost-add-mode="bulk"'));
 assert.ok(html.includes('rows="10"'));
 const app=read('app.js');
 assert.ok(app.includes("costView='entry'"));
 assert.ok(app.includes("    $('costSimpleForm').hidden="));
 assert.ok(app.includes("    $('costBulkSimplePanel').hidden="));
});
test('bulk parser accepts a 100-book paste and removes numbered-list prefixes',()=>{
 const names=Array.from({length:100},(_,i)=>(i+1)+'. Kitob '+(i+1)).join('\n');
 const parsed=ui.parseNameList(names,costs.key);
 assert.equal(parsed.error,'');
 assert.equal(parsed.names.length,100);
 assert.equal(parsed.names[0],'Kitob 1');
 assert.equal(parsed.names[99],'Kitob 100');
 const bullet=ui.parseNameList('- Arosat\n• Ko‘rlik\n2) Oq nilufarlar\nArosat',costs.key);
 assert.deepEqual(bullet.names,['Arosat','Ko‘rlik','Oq nilufarlar']);
});
test('pasted books are saved title-only and duplicate names are skipped',()=>{
 const app=read('app.js');
 const a=app.indexOf('  function saveCostBulkSimple(event){'),b=app.indexOf('  function openSimpleCostEditor(',a);
 const text=app.slice(a,b);
 assert.ok(text.includes('parseNameList('));
 assert.ok(text.includes('existing.has(key)'));
 assert.ok(text.includes('price:null,grams:null,saved:true'));
 assert.ok(text.includes('state.bookCosts=[...before,...newRows]'));
 assert.ok(text.includes("persistBookCosts(newRows.length+' ta kitob nomi saqlandi.',false)"));
 assert.ok(text.includes('state.bookCosts=before'));
 assert.ok(!text.includes('pushCostCloud('));
});
test('v85 code and assets are version matched and loaded before app',()=>{
 const html=read('index.html'),sw=read('sw.js');
 assert.ok(sw.includes('bek-yordamchi-v85'));
 for(const file of ['app.js','styles.css','book-cost-simple.js','book-cost-list-ui.js']){
 assert.ok(html.includes(file+'?v=85'),file+' html');
 assert.ok(sw.includes(file+'?v=85'),file+' sw');
 }
 assert.ok(html.indexOf('book-cost-list-ui.js')<html.indexOf('app.js'));
});
