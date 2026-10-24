'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const base=path.resolve(__dirname,'../personal-assistant');
const read=f=>fs.readFileSync(path.join(base,f),'utf8');
test('editor has a real delete button hidden until editing existing book',()=>{
 const html=read('index.html'),app=read('app.js'),css=read('styles.css');
 assert.ok(html.includes('id="costSimpleDelete" hidden'));
 assert.ok(html.includes('>O‘chirish</button>'));
 assert.ok(app.includes("$('costSimpleDelete').hidden=!row;"));
 assert.ok(css.includes('#costSimpleDelete:not([hidden]){display:block'));
 assert.ok(css.includes('#costSimpleDelete[hidden]{display:none!important}'));
});
test('editor delete triggers the existing double-confirmed removal, not an immediate destructive mutation',()=>{
 const app=read('app.js');
 const start=app.indexOf("    $('costSimpleDelete').addEventListener('click',()=>{");
 const end=app.indexOf("    qsa('[data-cost-add-mode]')",start);
 assert.ok(start>=0&&end>start);
 const block=app.slice(start,end);
 assert.ok(block.includes('deleteCostPlainBook(id)'));
 assert.ok(block.includes('if(!state.bookCosts.some(row=>row.id===id))'));
 assert.ok(block.includes("setCostView('list')"));
 const deleter=app.slice(app.indexOf('  function deleteCostPlainBook(id){'),app.indexOf('  function renderCostPlainCatalog(){'));
 assert.ok(deleter.includes('window.confirm('));
 assert.ok(deleter.indexOf('window.confirm(')<deleter.indexOf('state.bookCosts=before.filter('));
});
test('home and list show edit only, while editor keeps one confirmed delete',()=>{
 const app=read('app.js');
 const card=app.slice(app.indexOf('  function costPlainCard(row){'),app.indexOf('  function deleteCostPlainBook(id){'));
 assert.equal(card.split('data-cost-remove').length-1,0);
 assert.ok(card.includes('data-cost-edit'));
 assert.ok(!app.includes('data-cost-delete'));
 assert.ok(app.includes("deleteCostPlainBook(id)"));
});
test('versioned HTML and offline assets are consistent',()=>{
 const html=read('index.html'),sw=read('sw.js');
 assert.ok(sw.includes('bek-yordamchi-v87'));
 for(const file of ['app.js','styles.css','book-cost-list-ui.js']){
 assert.ok(html.includes(file+'?v=87'));
 assert.ok(sw.includes(file+'?v=87'));
 }
});
