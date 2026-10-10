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

function appHarness(extra={}){
  const nodes=new Map();
  const node=id=>{
    if(!nodes.has(id))nodes.set(id,{value:'',textContent:'',innerHTML:'',listeners:{},setAttribute(){},addEventListener(t,fn){this.listeners[t]=fn;},querySelectorAll:()=>[],scrollIntoView(){},classList:{add(){},remove(){}}});
    return nodes.get(id);
  };
  const data=new Map();
  const documentEvents=new Map(),windowEvents=new Map();
  const document={visibilityState:'visible',getElementById:node,addEventListener:(name,fn)=>documentEvents.set(name,fn),querySelectorAll:()=>[]};
  const localStorage={getItem:k=>data.get(k)||null,setItem:(k,v)=>data.set(k,v)};
  const ctx={window:{BookCosts:costs,BookCostSync:require('../personal-assistant/book-cost-sync.js'),BookCostSyncConfig:{url:'https://test',key:'public-test'},addEventListener:(name,fn)=>windowEvents.set(name,fn)},document,localStorage,crypto:require('node:crypto').webcrypto,navigator:{},console,AbortController,setTimeout:()=>0,clearTimeout(){},confirm:()=>true,...extra};
  const source=fs.readFileSync(require.resolve('../personal-assistant/app.js'),'utf8').replace('  bindBookCosts();\n  bindEvents();\n  renderAll();\n  navigate(\'home\',false);\n  maybeDailyReminder();\n  scheduleMissingMetadataAuto();',`window.testing={setCurrentView:value=>currentView=value,syncCostDevice,normalizeState,addCostTitles,bindBookCosts,renderBookCosts,costIsReady,renderCostReadyList,refreshCostCloud,getState:()=>state};`);
  if(extra.deviceSync)ctx.window.BookCostDeviceSync=require('../personal-assistant/book-cost-device-sync.js');
  vm.runInNewContext(source,ctx);
  return {api:ctx.window.testing,node,data,document,documentEvents,windowEvents};
}

test('linked sale price is read-only in both editors and ignored by save handlers',()=>{
  const {api,node}=appHarness();api.bindBookCosts();
  const row={id:'local',title:'Arosat',price:3000,grams:200,salePrice:15000,saved:true,muhajeerId:'00000000-0000-4000-8000-000000000001'};
  api.getState().bookCosts.push(row);api.renderBookCosts();
  assert.match(node('costReadyList').innerHTML,/readonly aria-readonly="true"[^>]*data-cost-quick="salePrice"/);
  node('costEditAllBtn').listeners.click();
  assert.match(node('costBooksList').innerHTML,/data-cost-field="salePrice"[^>]*readonly/);
  const card={dataset:{costId:row.id}};
  node('costBooksList').listeners.input({target:{dataset:{costField:'salePrice'},value:'1',closest:()=>card}});
  assert.equal(row.salePrice,15000);
  const fields=[['price','3000'],['grams','200'],['salePrice','1']].map(([field,value])=>({dataset:{costQuick:field},value,setAttribute(){}}));
  const quickCard={dataset:{costQuickId:row.id},querySelectorAll:()=>fields,querySelector:()=>({})};
  const quick={closest:()=>quickCard};
  node('costReadyList').listeners.click({target:{closest:s=>s==='[data-cost-quick-save]'?quick:null}});
  assert.equal(row.salePrice,15000);
});
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

test('connecting renders imported sale prices and reports unmatched rows accurately',async()=>{
 const {api,node,data}=appHarness({AbortSignal,fetch:async()=>({ok:true,json:async()=>({ok:true,data:[{id:'00000000-0000-4000-8000-000000000001',title:"Binafsha shu'lasi 1-qism",price:19000,cost_price:8000,discount_percent:0}]})})});
 api.bindBookCosts();api.getState().bookCosts.push({id:'a',title:'Binafsha shulasi 1-qism',price:null,grams:null,salePrice:null,saved:true},{id:'b',title:'Not in Muhajeer',price:null,grams:null,salePrice:null,saved:true});
 node('costCloudAdminCode').value='test-admin-code';await api.refreshCostCloud(true);
 assert.equal(api.getState().bookCosts[0].salePrice,19000);
 assert.match(node('costReadyList').innerHTML,/Muhajeer sotuv narxi <b>₩19,000/);
 assert.match(node('costCloudStatus').textContent,/1 \/ 2 ta kitobning sotuv narxi olindi/);
 assert.match(node('costCloudStatus').textContent,/1 ta kitob bog‘lanmagan/);
 assert.match(node('costReadyList').innerHTML,/Sotuv narxi kelishi uchun/);
 assert.equal(JSON.parse(data.get('bek_personal_assistant_v4')).bookCosts[0].salePrice,19000);
 assert.doesNotMatch(data.get('bek_personal_assistant_v4'),/test-admin-code/);
});

test('background and pagehide disconnect; reopening never reconnects automatically',async()=>{
 let calls=0;
 const {api,node,document,documentEvents,windowEvents}=appHarness({fetch:async()=>{calls++;return {ok:true,json:async()=>({ok:true,data:[]})};}});
 api.bindBookCosts();node('costCloudAdminCode').value='test-code';await api.refreshCostCloud(true);
 assert.equal(node('costCloudConnected').hidden,false);assert.equal(calls,1);
 document.visibilityState='hidden';documentEvents.get('visibilitychange')();
 assert.equal(node('costCloudConnected').hidden,true);assert.equal(node('costCloudLogin').hidden,false);
 await api.refreshCostCloud();assert.equal(calls,1);
 document.visibilityState='visible';documentEvents.get('visibilitychange')();windowEvents.get('focus')();
 await api.refreshCostCloud();assert.equal(calls,1);
 node('costCloudAdminCode').value='test-code';await api.refreshCostCloud(true);assert.equal(calls,2);
 windowEvents.get('pagehide')();assert.equal(node('costCloudConnected').hidden,true);
 await api.refreshCostCloud();assert.equal(calls,2);
});

test('leaving during connection aborts request and ignores late response',async()=>{
 let resolve,signal;
 const {api,node,document,documentEvents}=appHarness({fetch:async(url,options)=>{signal=options.signal;return new Promise(r=>{resolve=r;});}});
 api.bindBookCosts();node('costCloudAdminCode').value='test-code';
 api.getState().bookCosts.push({id:'a',title:'Arosat',price:null,grams:null,salePrice:null,saved:true});
 const pending=api.refreshCostCloud(true);
 document.visibilityState='hidden';documentEvents.get('visibilitychange')();
 assert.equal(signal.aborted,true);assert.equal(node('costCloudAdminCode').value,'');
 document.visibilityState='visible';
 resolve({ok:true,json:async()=>({ok:true,data:[{id:'00000000-0000-4000-8000-000000000001',title:'Arosat',price:15000}]})});
 await pending;
 assert.equal(api.getState().bookCosts[0].salePrice,null);assert.equal(api.getState().bookCosts[0].muhajeerId,undefined);
 assert.equal(node('costCloudConnected').hidden,true);
 assert.match(node('costCloudStatus').textContent,/ulanish uzildi/);
});

test('multiple kg tariffs calculate independently, skip blanks and preserve primary sync cost',()=>{
 const extra=[{id:'seven',label:'Arzon',rate:7000},{id:'blank',label:'Bo‘sh',rate:null},{id:'zero',label:'Bepul',rate:0}];
 const rows=[{title:'A',price:3000,grams:200,salePrice:6000},{title:'B',price:1000,grams:100,salePrice:3000},{title:'Pending',price:null,grams:50,salePrice:5000}];
 const values=costs.compare(rows,10000,extra);
 assert.equal(values.length,3);
 assert.equal(values[0].total,7000);assert.equal(values[0].shipping,3000);assert.equal(values[0].profitTotal,2000);
 assert.equal(values[1].total,6100);assert.equal(values[1].shipping,2100);assert.equal(values[1].profitTotal,2900);
 assert.equal(values[2].total,4000);assert.equal(values[2].shipping,0);
 assert.equal(values[1].ready,2);assert.equal(values[1].pending,1);
 assert.equal(costs.compare(rows,7000,[]).length,1);
 assert.equal(costs.calculate(rows[0],10000).total,5000);assert.equal(costs.calculate(rows[0],7000).total,4400);
});

test('tariffs save and restore, live calculations update and primary changes only by explicit selection',()=>{
 const {api,node,data}=appHarness();api.bindBookCosts();
 api.getState().bookCosts.push({id:'a',title:'Arosat',price:3000,grams:200,salePrice:6000,saved:true});
 node('costRateAddBtn').listeners.click();
 const tariff=api.getState().bookCostComparisons[0];const fields={};
 const card={dataset:{costTariffId:tariff.id},querySelector:s=>fields[s]||=({})};
 node('costRatesList').listeners.input({target:{dataset:{costTariffField:'rate'},value:'7000',closest:()=>card,setAttribute(){}}});
 assert.equal(api.getState().bookCostRate,10000);
 assert.match(node('costReadyList').innerHTML,/₩4,400/);assert.match(node('costReportComparisons').innerHTML,/₩4,400/);
 const restored=api.normalizeState(JSON.parse(data.get('bek_personal_assistant_v4')));
 assert.equal(restored.bookCostComparisons[0].rate,7000);assert.equal(restored.bookCostRate,10000);
 assert.equal(api.normalizeState({}).bookCostComparisons.length,0);
 node('costRatesList').listeners.click({target:{closest:s=>s==='[data-cost-tariff-id]'?card:s==='[data-cost-tariff-primary]'?{}:null}});
 assert.equal(api.getState().bookCostRate,7000);assert.equal(tariff.rate,10000);
 node('costRatesList').listeners.click({target:{closest:s=>s==='[data-cost-tariff-id]'?card:s==='[data-cost-tariff-remove]'?{}:null}});
 assert.equal(api.getState().bookCostComparisons.length,0);assert.equal(api.getState().bookCostRate,7000);
});

test('Sheets and Excel include every populated tariff, including columns beyond Z',()=>{
 const exporter=require('../personal-assistant/book-cost-export.js');
 const extras=Array.from({length:12},(_,i)=>({id:String(i),label:'Tarif '+i,rate:7000+i*1000}));
 const row={title:'A',price:3000,grams:200,salePrice:6000};
 const table=exporter.textTable([row],10000,[...extras,{id:'blank',rate:null}]).split('\n').map(r=>r.split('\t'));
 assert.equal(table[0].length,44);assert.equal(table[1].length,44);assert.deepEqual(table[1].slice(8,11),['1400','4400','1600']);
 const xml=new TextDecoder().decode(exporter.build([row],10000,extras));
 assert.match(xml,/ref="A1:AR2"/);assert.match(xml,/r="AA2"/);assert.match(xml,/max="44"/);
});

test('bulk editor search and missing-field filters preserve and save hidden books',()=>{
  const {api,node}=appHarness();api.bindBookCosts();
  api.getState().bookCosts.push({id:'a',title:'Ko‘rlik',price:9000,grams:0,saved:true},{id:'b',title:'Arosat',price:0,grams:null,saved:true},{id:'c',title:'Yashamoq',price:null,grams:null,saved:true});
  node('costEditAllBtn').listeners.click();
  assert.equal(node('costBulkPanel').hidden,true);
  assert.match(node('costBooksList').innerHTML,/name="cost-editor-book"/);
  assert.doesNotMatch(node('costBooksList').innerHTML,/name="cost-editor-book" open/);
  const cards=['a','b','c'].map(id=>({dataset:{costId:id},hidden:false}));
  node('costBooksList').querySelectorAll=()=>cards;
  node('costEditorSearch').value='arosat';node('costEditorSearch').listeners.input();
  assert.deepEqual(cards.map(c=>c.hidden),[true,false,true]);
  node('costEditorSearch').value='';node('costEditorFilter').value='missing-both';node('costEditorFilter').listeners.change();
  assert.deepEqual(cards.map(c=>c.hidden),[true,true,false]);
  node('costSaveAllBtn').listeners.click();
  assert.equal(api.getState().bookCosts.length,3);
  assert.equal(api.getState().bookCosts[1].price,0);
  assert.equal(api.getState().bookCosts[0].grams,0);
});
test('two devices restore a shared list and edits, while leaving stops device requests',async()=>{
 let remote={version:0,payload:null};let calls=0;
 const fetch=async(url,options)=>{calls++;const body=JSON.parse(options.body);let result=[];
 if(body.action==='load-list')result=JSON.parse(JSON.stringify(remote));
 if(body.action==='save-list'){assert.equal(body.changes.version,remote.version);remote={version:remote.version+1,payload:body.changes.payload};result=remote;}
 return {ok:true,json:async()=>({ok:true,data:result})};};
 const first=appHarness({deviceSync:true,fetch});first.api.bindBookCosts();first.api.addCostTitles('Hayotdan mazmun izlab');first.node('costSaveAllBtn').listeners.click();
 first.api.getState().bookCostRate=7000;first.node('costCloudAdminCode').value='test-code';await first.api.refreshCostCloud(true);
 assert.equal(remote.payload.books.length,1);assert.equal(remote.payload.rate,7000);
 const second=appHarness({deviceSync:true,fetch});second.api.bindBookCosts();second.node('costCloudAdminCode').value='test-code';await second.api.refreshCostCloud(true);
 assert.equal(second.api.getState().bookCosts[0].title,'Hayotdan mazmun izlab');assert.equal(second.api.getState().bookCostRate,7000);
 second.api.getState().bookCosts[0].price=6600;await second.api.syncCostDevice();await first.api.syncCostDevice();assert.equal(first.api.getState().bookCosts[0].price,6600);
 const before=calls;first.document.visibilityState='hidden';first.documentEvents.get('visibilitychange')();await first.api.syncCostDevice();assert.equal(calls,before);
 first.document.visibilityState='visible';await first.api.syncCostDevice();assert.equal(calls,before);
});
test('editor back button and left-edge swipe preserve edits; vertical gestures stay in editor',()=>{
 const {api,node,windowEvents}=appHarness();api.bindBookCosts();api.setCurrentView('book-costs');api.getState().bookCosts.push({id:'a',title:'Book',price:6600,grams:null,saved:true});
 node('costEditAllBtn').listeners.click();assert.equal(node('costEntryPanel').hidden,false);
 const screen={listeners:Object.fromEntries(windowEvents)};screen.listeners.touchstart({touches:[{clientX:10,clientY:300}]});screen.listeners.touchend({changedTouches:[{clientX:110,clientY:500}]});assert.equal(node('costEntryPanel').hidden,false);
 screen.listeners.touchstart({touches:[{clientX:10,clientY:300}]});screen.listeners.touchend({changedTouches:[{clientX:130,clientY:320}]});assert.equal(node('costListPanel').hidden,false);assert.equal(api.getState().bookCosts[0].price,6600);
 node('costEditAllBtn').listeners.click();node('costEditorBackBtn').listeners.click();assert.equal(node('costEntryPanel').hidden,true);
});
