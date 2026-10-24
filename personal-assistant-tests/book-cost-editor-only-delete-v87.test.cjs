'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path');
const dir=path.resolve(__dirname,'../personal-assistant');
const read=f=>fs.readFileSync(path.join(dir,f),'utf8');
test('only edit buttons remain on both complete and incomplete book cards',()=>{
 const app=read('app.js'),a=app.indexOf('  function costPlainCard(row){'),b=app.indexOf('  function deleteCostPlainBook(id){',a);
 const card=app.slice(a,b);
 assert.equal((card.match(/data-cost-edit/g)||[]).length,2);
 assert.equal((card.match(/data-cost-remove/g)||[]).length,0);
 assert.equal((card.match(/cost-plain-remove/g)||[]).length,0);
 assert.equal((card.match(/>O‘chirish</g)||[]).length,0);
});
test('no home/list hidden delete event handler remains',()=>{
 const app=read('app.js');
 const start=app.indexOf("    $('costPlainHomeList').addEventListener('click'");
 const end=app.indexOf("    $('costReadyList').addEventListener('change'",start);
 const eventPart=app.slice(start,end);
 assert.ok(eventPart.includes('openSimpleCostEditor(button.dataset.costEdit)'));
 assert.equal((eventPart.match(/deleteCostPlainBook\(/g)||[]).length,0);
 assert.ok(!app.includes('data-cost-remove'));
 assert.ok(!app.includes('data-cost-delete'));
});
test('editing existing book shows one button at the very bottom and new books do not',()=>{
 const html=read('index.html'),app=read('app.js');
 assert.equal((html.match(/id="costSimpleDelete"/g)||[]).length,1);
 assert.ok(html.includes('<button type="button" class="cost-simple-delete" id="costSimpleDelete" hidden>O‘chirish</button>'));
 assert.ok(html.indexOf('id="costSimpleDelete"')>html.indexOf('id="costSimpleSave"'));
 assert.ok(app.includes("$('costSimpleDelete').hidden=!row;"));
 assert.ok(app.includes("    $('costSimpleDelete').addEventListener('click',()=>{"));
});
test('editor deletion retains confirmation before mutation and rollback on save failure',()=>{
 const app=read('app.js'),start=app.indexOf('  function deleteCostPlainBook(id){'),end=app.indexOf('  function renderCostPlainCatalog(){',start);
 const fn=app.slice(start,end);
 assert.ok(fn.includes("window.confirm("));
 assert.ok(fn.includes('rostdan ham o‘chirmoqchimisiz?'));
 assert.ok(fn.indexOf('window.confirm(')<fn.indexOf('state.bookCosts=before.filter('));
 assert.ok(fn.includes('state.bookCosts=before;'));
 assert.ok(fn.includes("persistBookCosts('Kitob ro‘yxatdan o‘chirildi.',false)"));
});
test('delete style and v87 offline cache are kept for the only editor delete button',()=>{
 const css=read('styles.css'),html=read('index.html'),sw=read('sw.js');
 assert.ok(css.includes('#costSimpleDelete:not([hidden]){display:block'));
 assert.ok(!css.includes('.cost-plain-remove'));
 assert.ok(sw.includes('bek-yordamchi-v87'));
 for(const f of ['app.js','styles.css','book-costs.js','book-cost-list-ui.js']){
 assert.ok(html.includes(f+'?v=87'),f+' html');
 assert.ok(sw.includes(f+'?v=87'),f+' sw');
 }
});
