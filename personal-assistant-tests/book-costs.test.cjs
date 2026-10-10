const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const costs=require('../personal-assistant/book-costs.js');

test('Sheets clipboard table separates columns, recalculates rate and leaves unknown values empty',()=>{
  const exporter=require('../personal-assistant/book-cost-export.js');
  const table=exporter.textTable([{title:'Arosat',price:8000,grams:300,salePrice:15000},{title:'=SUM(1,2)\nKitob',price:0,grams:null}],12000).split('\n').map(row=>row.split('\t'));
  assert.equal(table[0].length,8);
  assert.deepEqual(table[1],['Arosat','8000','300','3600','11600','15000','3400','12000']);
  assert.deepEqual(table[2],["'=SUM(1,2) Kitob",'0','','','','','','12000']);
});

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
  assert.deepEqual(costs.normalize(JSON.parse(JSON.stringify(rows)),()=> 'new'),rows.map(row=>({...row,salePrice:null})));
});

function appHarness(){
  const nodes=new Map();
  const node=id=>{
    if(!nodes.has(id))nodes.set(id,{value:'',textContent:'',innerHTML:'',listeners:{},setAttribute(){},addEventListener(t,fn){this.listeners[t]=fn;},querySelectorAll:()=>[],scrollIntoView(){},classList:{add(){},remove(){}}});
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


test('missing price, missing weight and both filters combine with search, sorting and edits',()=>{
  const {api,node}=appHarness();
  api.bindBookCosts();
  const rows=api.getState().bookCosts;
  rows.push(
    {id:'both',title:'Keladigan A',price:null,grams:null,saved:true},
    {id:'weight',title:'Keladigan B',price:8000,grams:null,saved:true},
    {id:'price',title:'Keladigan C',price:null,grams:100,saved:true},
    {id:'complete',title:'Tayyor',price:8000,grams:100,saved:true},
    {id:'zero',title:'Nol qiymatlar',price:0,grams:0,saved:true},
    {id:'draft',title:'Saqlanmagan',price:null,grams:null,saved:false}
  );
  const visible=()=>[...node('costReadyList').innerHTML.matchAll(/data-cost-edit="([^"]+)"/g)].map(m=>m[1]);
  function filter(value){node('costFilter').value=value;node('costFilter').listeners.change();return visible();}
  node('costSort').value='oldest';
  assert.deepEqual(filter('all'),['both','weight','price','complete','zero']);
  assert.deepEqual(filter('missing-price'),['both','price']);
  assert.deepEqual(filter('missing-weight'),['both','weight']);
  assert.deepEqual(filter('missing-both'),['both']);
  assert.equal(node('costFilteredCount').textContent,'1 / 5 ta kitob');
  node('costSearch').value='B';
  assert.deepEqual(filter('missing-weight'),['weight']);
  node('costSearch').value='Tayyor';node('costSearch').listeners.input();
  assert.deepEqual(visible(),[]);
  assert.match(node('costReadyList').innerHTML,/Mos kitob topilmadi/);
  assert.equal(node('costFilteredCount').textContent,'0 / 5 ta kitob');
  node('costSearch').value='';node('costSort').value='recent';node('costSort').listeners.change();
  assert.deepEqual(visible(),['weight','both']);
  const fields=new Map();
  const card={dataset:{costId:'weight'},querySelector:s=>{if(!fields.has(s))fields.set(s,{});return fields.get(s);}};
  node('costBooksList').listeners.input({target:{dataset:{costField:'grams'},value:'300',closest:()=>card,setAttribute(){}}});
  assert.deepEqual(visible(),['both']);
  assert.equal(node('costFilteredCount').textContent,'1 / 5 ta kitob');
  assert.deepEqual(filter('missing-price'),['price','both']);
  assert.equal(rows[1].grams,300);
  assert.equal(node('costReadyCount').textContent,5);
});


test('custom kg rate recalculates existing and draft books, persists and restores with backups',()=>{
  assert.deepEqual(costs.calculate({price:8000,grams:300},12000),{shipping:3600,total:11600});
  assert.deepEqual(costs.calculate({price:null,grams:300.5},15000),{shipping:4508,total:null});
  assert.deepEqual(costs.calculate({price:8000,grams:null},12000),{shipping:null,total:null});
  assert.deepEqual(costs.calculate({price:8000,grams:300},0),{shipping:0,total:8000});
  const {api,node,data}=appHarness();api.bindBookCosts();
  const rows=api.getState().bookCosts;
  rows.push({id:'saved',title:'Mavjud',price:8000,grams:300,saved:true},{id:'draft',title:'Yangi',price:8000,grams:100,saved:false});
  node('costKgRate').value='12,000';node('costRateSaveBtn').listeners.click();
  assert.equal(api.getState().bookCostRate,12000);
  assert.match(node('costReadyList').innerHTML,/₩11,600/);
  assert.match(node('costBooksList').innerHTML,/₩9,200/);
  assert.match(node('costRateSummary').textContent,/₩12,000/);
  assert.equal(api.normalizeState(JSON.parse(data.get('bek_personal_assistant_v4'))).bookCostRate,12000);
  assert.equal(api.normalizeState({bookCosts:rows}).bookCostRate,10000);
  assert.equal(api.normalizeState({bookCostRate:0}).bookCostRate,0);
  for(const invalid of ['', '-5', 'abc']){
    node('costKgRate').value=invalid;node('costRateSaveBtn').listeners.click();
    assert.equal(api.getState().bookCostRate,12000);
    assert.match(node('costRateError').textContent,/raqam/);
  }
  node('costKgRate').value='15000';node('costRateSaveBtn').listeners.click();
  assert.match(node('costReadyList').innerHTML,/₩12,500/);
  assert.equal(rows[0].price,8000);assert.equal(rows[0].grams,300);assert.equal(rows[0].saved,true);
});


test('profit and summary exclude incomplete rows and preserve losses and zero sale prices',()=>{
  const rows=[{title:'A',price:8000,grams:300,salePrice:15000},{title:'B',price:8000,grams:null,salePrice:16000},{title:'C',price:8000,grams:100,salePrice:0}];
  assert.equal(costs.profit(rows[0]),4000);assert.equal(costs.profit(rows[1]),null);assert.equal(costs.profit(rows[2]),-9000);
  assert.deepEqual(costs.summary(rows),{total:20000,ready:2,pending:1,profitTotal:-5000,profitCount:2});
  assert.equal(costs.profit(rows[0],12000),3400);
  assert.equal(costs.normalize(rows,()=> 'id')[0].salePrice,15000);
});

test('quick save validates fields and selection edits only selected saved records',()=>{
  const {api,node,data}=appHarness();api.bindBookCosts();
  const rows=api.getState().bookCosts;
  rows.push({id:'a',title:'Arosat',price:8000,grams:null,saved:true},{id:'b',title:'Ko‘rlik',price:9000,grams:null,saved:true},{id:'c',title:'Draft',price:null,grams:null,saved:false});
  api.renderBookCosts();
  const fields=[['price','8000'],['grams','300'],['salePrice','15000']].map(([field,value])=>({dataset:{costQuick:field},value,setAttribute(){}}));
  const error={textContent:''};const card={dataset:{costQuickId:'a'},querySelectorAll:()=>fields,querySelector:()=>error};
  const quick={closest:()=>card};const target={closest:s=>s==='[data-cost-quick-save]'?quick:null};
  fields[1].value='bad';node('costReadyList').listeners.click({target});assert.equal(rows[0].grams,null);assert.match(error.textContent,/Raqam/);
  fields[1].value='300';node('costReadyList').listeners.click({target});
  assert.equal(rows[0].grams,300);assert.equal(rows[0].salePrice,15000);assert.match(node('costReadyList').innerHTML,/₩4,000/);
  assert.equal(JSON.parse(data.get('bek_personal_assistant_v4')).bookCosts[0].salePrice,15000);
  node('costSelectBtn').listeners.click();
  node('costReadyList').listeners.change({target:{dataset:{costSelect:'b'},checked:true}});
  node('costEditSelectedBtn').listeners.click();
  assert.equal(node('costEditorTitle').textContent,'Tanlangan kitoblarni tahrirlash');
  assert.match(node('costBooksList').innerHTML,/Ko‘rlik/);assert.doesNotMatch(node('costBooksList').innerHTML,/Arosat|Draft/);
  node('costSaveAllBtn').listeners.click();
  assert.equal(rows[2].saved,false);assert.equal(rows[0].salePrice,15000);
  assert.match(node('costReportValues').innerHTML,/Kutiladigan foyda/);
});


test('Sheets file sharing uses XLSX, respects cancellation and falls back when unsupported',async()=>{
  const excel=require('../personal-assistant/book-cost-export.js');
  const bytes=excel.build([{title:'Arosat',price:8000,grams:300,salePrice:15000}],10000);
  class FakeFile{constructor(parts,name,options){this.parts=parts;this.name=name;this.type=options.type;}}
  let shared;
  const env={File:FakeFile,navigator:{canShare:()=>true,share:async data=>{shared=data;}}};
  assert.equal(await excel.share(bytes,'kitob.xlsx',env),'shared');
  assert.equal(shared.files[0].name,'kitob.xlsx');
  assert.equal(shared.files[0].type,'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  assert.equal(shared.files[0].parts[0],bytes);
  assert.equal(await excel.share(bytes,'kitob.xlsx',{navigator:{}}),'download');
  env.navigator.canShare=()=>false;assert.equal(await excel.share(bytes,'kitob.xlsx',env),'download');
  env.navigator.canShare=()=>true;env.navigator.share=async()=>{throw {name:'AbortError'};};
  assert.equal(await excel.share(bytes,'kitob.xlsx',env),'cancelled');
  env.navigator.share=async()=>{throw {name:'NotAllowedError'};};
  assert.equal(await excel.share(bytes,'kitob.xlsx',env),'download');
});
