'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../personal-assistant');
const filter=require(path.join(root,'book-cost-list-ui.js'));
const costs=require(path.join(root,'book-costs.js'));
const read=f=>fs.readFileSync(path.join(root,f),'utf8');
const rows=[
 {id:'a',title:'Arosat',price:10000,grams:250},
 {id:'b',title:'Laylo',price:null,grams:300},
 {id:'c',title:'Ko‘rlik',price:2500,grams:null},
 {id:'d',title:'Qadimiy kitob',price:null,grams:null},
 {id:'e',title:'Arosat',price:11000,grams:251}
];
test('filter narxi kiritilmagan excludes complete and missing-weight-only books',()=>{
 const result=filter.filterBooks(rows,'missing-price','',costs.key);
 assert.deepEqual(result.map(x=>x.id),['d','b']);
});
test('missing price and search can be combined',()=>{
 assert.deepEqual(filter.filterBooks(rows,'missing-price','Laylo',costs.key).map(x=>x.id),['b']);
 assert.deepEqual(filter.filterBooks(rows,'missing-price','Arosat',costs.key),[]);
});
test('complete and incomplete catalog cards show only edit/fill actions',()=>{
 const app=read('app.js');const a=app.indexOf('  function costPlainCard(row){'),b=app.indexOf('  function deleteCostPlainBook(id){',a);
 const view=app.slice(a,b);
 assert.equal(view.split('data-cost-remove').length-1,0);
 assert.ok(view.includes('data-cost-edit'));
 assert.ok(!view.includes('cost-plain-remove'));
 const html=read('index.html');
 assert.ok(html.includes('<option value="missing-price">Narxi kiritilmagan</option>'));
});
test('confirmation is required before ANY deletion including empty draft',()=>{
 const app=read('app.js'),a=app.indexOf('  function deleteCostPlainBook(id){'),b=app.indexOf('  function renderCostPlainCatalog(){',a);
 const src=app.slice(a,b);
 assert.ok(src.includes('window.confirm('));
 assert.ok(src.includes('rostdan ham o‘chirmoqchimisiz?'));
 assert.ok(src.indexOf('window.confirm(')<src.indexOf('state.bookCosts=before.filter('));
 assert.ok(src.includes('state.bookCosts=before'));
 assert.ok(src.includes("persistBookCosts('Kitob ro‘yxatdan o‘chirildi.',false)"));
});
test('confirmed deletion removes duplicate names together and leaves other books alone',()=>{
 let confirmText='',writes=0,renders=0;
 const context={state:{bookCosts:rows.map(r=>({...r}))},costs,window:{confirm:msg=>{confirmText=msg;return true;}},
 persistBookCosts:(msg,auto)=>{writes++;assert.equal(auto,false);return true;},
 renderBookCosts:()=>{renders++;},syncWorkspaceUI:()=>{},toast:()=>{},
 costSelectedIds:new Set(['a','e']),costEditingIds:new Set(['a']),costEditingId:'a'};
 const src=read('app.js'),start=src.indexOf('  function deleteCostPlainBook(id){'),end=src.indexOf('  function renderCostPlainCatalog(){',start);
 const fn=vm.runInNewContext('('+src.slice(start,end).trim()+')',context);
 fn('e');
 assert.match(confirmText,/2 ta eski va yangi qayd/);
 assert.deepEqual(context.state.bookCosts.map(x=>x.id),['b','c','d']);
 assert.equal(writes,1);assert.equal(renders,1);
 assert.equal(context.costSelectedIds.size,0);assert.equal(context.costEditingId,'');
});
test('cancel leaves original rows and storage unchanged',()=>{
 let saved=0,rendered=0;
 const original=rows.map(r=>({...r}));
 const context={state:{bookCosts:original},costs,window:{confirm:()=>false},
 persistBookCosts:()=>{saved++;return true;},renderBookCosts:()=>{rendered++;},
 syncWorkspaceUI:()=>{},toast:()=>{},costSelectedIds:new Set(),costEditingIds:new Set(),costEditingId:''};
 const src=read('app.js'),a=src.indexOf('  function deleteCostPlainBook(id){'),b=src.indexOf('  function renderCostPlainCatalog(){',a);
 const fn=vm.runInNewContext('('+src.slice(a,b).trim()+')',context);
 fn('d');
 assert.equal(saved,0);assert.equal(rendered,0);
 assert.strictEqual(context.state.bookCosts,original);
 assert.equal(context.state.bookCosts.length,5);
});
test('storage write failure rolls back deletion with no screen refresh',()=>{
 let refreshed=0;
 const original=rows.map(r=>({...r}));
 const context={state:{bookCosts:original},costs,window:{confirm:()=>true},
 persistBookCosts:()=>false,renderBookCosts:()=>{refreshed++;},
 syncWorkspaceUI:()=>{},toast:()=>{},costSelectedIds:new Set(['d']),costEditingIds:new Set(),costEditingId:''};
 const src=read('app.js'),a=src.indexOf('  function deleteCostPlainBook(id){'),b=src.indexOf('  function renderCostPlainCatalog(){',a);
 const fn=vm.runInNewContext('('+src.slice(a,b).trim()+')',context);
 fn('d');
 assert.strictEqual(context.state.bookCosts,original);
 assert.equal(refreshed,0);
 assert.ok(context.costSelectedIds.has('d'));
});
test('home and list have no deletion handlers; editor is the only delete entry',()=>{
 const app=read('app.js');const i=app.indexOf("    $('costPlainHomeList').addEventListener('click'");
 const j=app.indexOf("    $('costReadyList').addEventListener('click'",i);
 assert.ok(i>=0&&j>i);
 assert.ok(!app.slice(i,j+400).includes("deleteCostPlainBook("));
 assert.ok(app.includes("    $('costSimpleDelete').addEventListener('click',()=>{"));
});
test('v87 assets and styles are aligned',()=>{
 const html=read('index.html'),sw=read('sw.js'),css=read('styles.css');
 assert.ok(sw.includes('bek-yordamchi-v87'));
 for(const f of ['app.js','styles.css','book-cost-list-ui.js']){
 assert.ok(html.includes(f+'?v=87'),f+' html');
 assert.ok(sw.includes(f+'?v=87'),f+' sw');
 }
 assert.ok(css.includes('#costSimpleDelete:not([hidden]){display:block'));
});
