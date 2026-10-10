const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const costs=require('../personal-assistant/book-costs.js');

test('10,000 won per kilogram, including decimal weights and missing fields',()=>{
  for(const [grams,shipping] of [[100,1000],[1000,10000],[300.5,3005]]){
    assert.deepEqual(costs.calculate({price:8000,grams}),{shipping,total:8000+shipping});
  }
  assert.deepEqual(costs.calculate({price:15000,grams:100}),{shipping:1000,total:16000});
  assert.deepEqual(costs.calculate({price:null,grams:100}),{shipping:1000,total:null});
  assert.deepEqual(costs.calculate({price:8000,grams:''}),{shipping:null,total:null});
  assert.deepEqual(costs.calculate({price:0,grams:0}),{shipping:0,total:0});
  for(const bad of ['-1','abc','Infinity','1e3','1.2.3',1e15])assert.equal(costs.amount(bad),null);
  assert.equal(costs.amount('₩8,000'),8000);
});
test('bulk pasted names preserve punctuation, strip list prefixes, skip repeats',()=>{
  assert.deepEqual(costs.parseTitles('1. Arosat\r\n• Ko‘rlik\n\n2) Men (Bas qil, ey nafs!)\nKo\'rlik; Oq nilufarlar'),['Arosat','Ko‘rlik','Men (Bas qil, ey nafs!)','Oq nilufarlar']);
});
test('saved cost records survive JSON reload and old backups default to empty',()=>{
  assert.deepEqual(costs.normalize(undefined,()=> 'new'),[]);
  const rows=[{id:'a',title:'Arosat',price:8000,grams:300,saved:true},{id:'b',title:'',price:null,grams:null,saved:false}];
  assert.deepEqual(costs.normalize(JSON.parse(JSON.stringify(rows)),()=> 'new'),rows);
});

function appHarness(){
  const nodes=new Map();
  const node=id=>{
    if(!nodes.has(id))nodes.set(id,{value:'',textContent:'',innerHTML:'',listeners:{},addEventListener(t,fn){this.listeners[t]=fn;},querySelectorAll:()=>[],scrollIntoView(){},classList:{add(){},remove(){}}});
    return nodes.get(id);
  };
  const data=new Map();
  const document={getElementById:node,addEventListener(){},querySelectorAll:()=>[]};
  const localStorage={getItem:k=>data.get(k)||null,setItem:(k,v)=>data.set(k,v)};
  const ctx={window:{BookCosts:costs,addEventListener(){}},document,localStorage,crypto:require('node:crypto').webcrypto,navigator:{},console,setTimeout:()=>0,clearTimeout(){},confirm:()=>true};
  const source=fs.readFileSync(require.resolve('../personal-assistant/app.js'),'utf8').replace('  bindBookCosts();\n  bindEvents();\n  renderAll();\n  navigate(\'home\',false);\n  maybeDailyReminder();\n  scheduleMissingMetadataAuto();',`window.testing={normalizeState,addCostTitles,bindBookCosts,renderBookCosts,costIsReady,renderCostReadyList,getState:()=>state};`);
  vm.runInNewContext(source,ctx);
  return {api:ctx.window.testing,node,data};
}
test('app import, duplicate handling, input calculation, persistence, backup migration',()=>{
  const {api,node,data}=appHarness();
  api.addCostTitles('Arosat\nKo‘rlik');api.addCostTitles('Arosat\nOq nilufarlar');
  assert.equal(api.getState().bookCosts.length,3);
  api.bindBookCosts();
  const row=api.getState().bookCosts[0];
  const fields=new Map();
  const card={querySelectorAll:()=>[],dataset:{costId:row.id},querySelector:s=>{if(!fields.has(s))fields.set(s,{});return fields.get(s);}};
  function input(field,value){node('costBooksList').listeners.input({target:{dataset:{costField:field},value,closest:()=>card,setAttribute(){}}});}
  input('price','8,000');input('grams','300');
  assert.equal(fields.get('[data-cost-total]').textContent,'₩11,000');
  assert.equal(fields.get('[data-cost-shipping]').textContent,'₩3,000');
  assert.equal(JSON.parse(data.get('bek_personal_assistant_v4')).bookCosts[0].grams,300);
  input('grams','-20');assert.equal(fields.get('[data-cost-total]').textContent,'—');
  input('grams','100');assert.equal(fields.get('[data-cost-total]').textContent,'₩9,000');
  const restored=api.normalizeState(JSON.parse(data.get('bek_personal_assistant_v4')));
  assert.equal(restored.bookCosts[0].grams,100);
  assert.equal(api.costIsReady(row),false);
  let savedTarget={closest(selector){return selector==='[data-cost-save]'?{}:card;}};
  node('costBooksList').listeners.click({target:savedTarget});
  assert.equal(api.costIsReady(row),true);
  assert.equal(node('costReadyCount').textContent,1);
  assert.match(node('costReadyList').innerHTML,/Arosat/);
  assert.match(node('costReadyList').innerHTML,/₩9,000/);
  node('costSearch').value='Ko‘rlik';api.renderCostReadyList();
  assert.doesNotMatch(node('costReadyList').innerHTML,/Arosat/);
  node('costSearch').value='';
  const migrated=api.normalizeState({bookCosts:[{id:'old',title:'Old',price:5000,grams:100}]});
  assert.equal(migrated.bookCosts[0].saved,true);
  assert.equal(api.normalizeState({bookCosts:[{id:'draft',title:'Draft',price:5000,grams:null}]}).bookCosts[0].saved,false);
  const old=api.normalizeState({profile:{name:'Bek'},books:[],transactions:[{id:'tx1',amount:500,date:'2026-10-10'}]});
  assert.equal(old.transactions[0].amount,500);assert.equal(old.profile.name,'Bek');assert.equal(old.bookCosts.length,0);
  let prevented=false;
  node('costBulkNames').listeners.paste({clipboardData:{getData:()=> 'Yashamoq\nArosat'},preventDefault(){prevented=true;}});
  assert.equal(prevented,true);assert.equal(api.getState().bookCosts.length,4);
});


test('names-only and price-only save individually; batch edit keeps missing weight and later totals',()=>{
  const {api,node,data}=appHarness();
  api.bindBookCosts();api.addCostTitles('Keladigan kitob\nIkkinchi kitob');
  const rows=api.getState().bookCosts;
  const card={dataset:{costId:rows[0].id},querySelectorAll:()=>[]};
  node('costBooksList').listeners.click({target:{closest:s=>s==='[data-cost-save]'?{}:card}});
  assert.equal(api.costIsReady(rows[0]),true);
  assert.equal(rows[0].grams,null);
  assert.match(node('costReadyList').innerHTML,/Narx va vazn kutilmoqda/);
  assert.doesNotMatch(node('costReadyList').innerHTML,/₩0/);
  rows[1].price=9000;
  node('costSaveAllBtn').listeners.click();
  assert.equal(api.costIsReady(rows[1]),true);
  assert.match(node('costReadyList').innerHTML,/Vazn kutilmoqda/);
  const reload=api.normalizeState(JSON.parse(data.get('bek_personal_assistant_v4')));
  assert.equal(api.costIsReady(reload.bookCosts[0]),true);
  assert.equal(reload.bookCosts[1].price,9000);
  assert.equal(reload.bookCosts[1].grams,null);
  const unnamed={id:'only-price',title:'',price:3000,grams:null,saved:false};rows.push(unnamed);
  node('costEditAllBtn').listeners.click();
  assert.equal(node('costEditorTitle').textContent,'Hamma kitoblarni tahrirlash');
  assert.match(node('costBooksList').innerHTML,/Keladigan kitob/);
  assert.match(node('costBooksList').innerHTML,/Ikkinchi kitob/);
  rows[1].grams=100;
  node('costSaveAllBtn').listeners.click();
  assert.equal(api.costIsReady(unnamed),true);
  assert.match(node('costReadyList').innerHTML,/Nomsiz kitob/);
  assert.match(node('costReadyList').innerHTML,/₩10,000/);
  node('costSort').value='high';api.renderCostReadyList();
  assert.ok(node('costReadyList').innerHTML.indexOf('Ikkinchi kitob')<node('costReadyList').innerHTML.indexOf('Keladigan kitob'));
  const all=api.normalizeState(JSON.parse(data.get('bek_personal_assistant_v4')));
  assert.equal(all.bookCosts[1].grams,100);
  assert.equal(costs.calculate(all.bookCosts[1]).total,10000);
});
