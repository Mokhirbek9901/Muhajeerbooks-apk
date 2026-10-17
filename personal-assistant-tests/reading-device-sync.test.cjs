const {test}=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs');const vm=require('node:vm');
const sync=require('../personal-assistant/reading-device-sync.js');
const profile={yearlyGoal:24,dailyPageGoal:32,dailyMinutesGoal:20,dailyPlanBookId:'a',customCategories:[]};
const book=(id='a')=>({id,title:'Arosat',author:'Kadir Akel',category:'Roman',publisher:'Huzur',isbn:'',description:'Tavsif',publishedYear:2025,statusOverride:'reading',cover:'https://example.com/cover.jpg',pages:200,currentPage:50,startedAt:'2026-10-01',finishedAt:'',rating:4,notes:'Shaxsiy izoh',readingLog:[{date:'2026-10-10',page:50,readPages:20,minutes:10}],createdAt:'2026-10-01T00:00:00Z',updatedAt:'2026-10-10T00:00:00Z'});
const snap=books=>({books,profile:{...profile}});
test('reading snapshots preserve all book details and activity, without costs, finance or credentials',()=>{
 const actual=sync.snapshot({books:[book()],profile,bookCosts:[{price:1000}],transactions:[{amount:500}],admin_code:'secret'});
 assert.deepEqual(actual,snap([book()]));assert.doesNotMatch(JSON.stringify(actual),/secret|bookCosts|transactions/);
});
test('fresh seeded phone restores remote progress, notes, and deletes without resetting to finished',()=>{
 const seed={...book(),statusOverride:'finished',currentPage:200,notes:'',readingLog:[]};
 const initial=snap([seed,book('removed')]);const remote=snap([book(),book('new')]);
 const merged=sync.merge(null,initial,remote,initial);
 assert.deepEqual(merged.conflicts,[]);assert.deepEqual(merged.value,remote);
});
test('independent book field and daily activity changes combine; conflicting progress stays local',()=>{
 const base=snap([book()]);const local=snap([{...book(),notes:'New note',readingLog:[...book().readingLog,{date:'2026-10-11',page:50,minutes:15}]}]);
 const remote=snap([{...book(),author:'Updated author',readingLog:[...book().readingLog,{date:'2026-10-12',page:50,minutes:20}]}]);
 const r=sync.merge(base,local,remote);assert.deepEqual(r.conflicts,[]);assert.equal(r.value.books[0].notes,'New note');assert.equal(r.value.books[0].author,'Updated author');assert.equal(r.value.books[0].readingLog.length,3);
 const conflict=sync.merge(base,snap([{...book(),currentPage:70}]),snap([{...book(),currentPage:90}]));assert.ok(conflict.conflicts.length);assert.equal(conflict.value.books[0].currentPage,70);
 assert.deepEqual(sync.merge(base,snap([]),base).value.books,[]);
});
function app(fetch){
 const data=new Map(),nodes=new Map();const node=id=>{if(!nodes.has(id))nodes.set(id,{value:'',textContent:'',disabled:false});return nodes.get(id);};
 const document={hidden:false,visibilityState:'visible',getElementById:node,addEventListener(){},querySelectorAll:()=>[]};
 const ctx={window:{BookCosts:require('../personal-assistant/book-costs.js'),ReadingDeviceSync:sync,BookCostSyncConfig:{url:'https://test',key:'public'},addEventListener(){}},document,localStorage:{getItem:k=>data.get(k)||null,setItem:(k,v)=>data.set(k,v)},navigator:{},crypto:require('node:crypto').webcrypto,AbortController,setTimeout:()=>0,clearTimeout(){},fetch,console};
 Object.assign(ctx.window,{YordamchiCurrency:require('../personal-assistant/currency-converter.js'),YordamchiRateEditor:require('../personal-assistant/currency-rate-editor.js'),YordamchiWorkspaces:require('../personal-assistant/workspaces.js'),KoreaProducts:{...require('../personal-assistant/korea-products.js'),renderBookEntry(){},renderBookList(){},render(){},refreshRates(){}}});
 let source=fs.readFileSync('personal-assistant/app.js','utf8');
 source=source.replace("  bindBookCosts();\n  bindEvents();\n  renderAll();\n  navigate('home',false);\n  selectWorkspace(currentWorkspace);\n  maybeDailyReminder();\n  scheduleMissingMetadataAuto();",'window.test={syncReadingLibrary,disconnectReadingSync,disconnectCostCloud,saveState,getState:()=>state};');
 source=source.replaceAll('    renderAll();','    window.rendered=true;').replaceAll('      renderAll();','      window.rendered=true;');
 source=source.replace(/^  window\.KoreaProducts\.init\(.*$/m,'');
 vm.runInNewContext(source,ctx);return {api:ctx.window.test,data,node,document};
}
test('two real app instances transfer full library and later progress while keeping finance and cost state separate',async()=>{
 let stored={version:0,payload:null};const actions=[];
 const fetch=async(url,opts)=>{const body=JSON.parse(opts.body);actions.push(body.action);if(body.action==='save-library'){assert.equal(body.changes.version,stored.version);stored={version:stored.version+1,payload:body.changes.payload};}return {ok:true,json:async()=>({ok:true,data:JSON.parse(JSON.stringify(stored))})};};
 const a=app(fetch),b=app(fetch);a.api.getState().books.push(book());a.api.getState().profile.dailyPlanBookId='a';a.api.getState().bookCosts=[{id:'cost'}];b.api.getState().transactions=[{id:'finance'}];
 a.node('readingSyncAdminCode').value='test-code';await a.api.syncReadingLibrary(true);assert.match(a.node('readingSyncStatus').textContent,/bulutda saqlandi/);
 b.node('readingSyncAdminCode').value='test-code';await b.api.syncReadingLibrary(true);
 const restored=b.api.getState().books.find(x=>x.id==='a');assert.equal(restored.currentPage,50);assert.equal(restored.statusOverride,'reading');assert.equal(restored.notes,'Shaxsiy izoh');assert.equal(restored.readingLog[0].minutes,10);assert.equal(b.api.getState().transactions[0].id,'finance');assert.equal(b.api.getState().bookCosts.length,0);
 restored.currentPage=75;restored.readingLog.push({date:'2026-10-11',page:75,readPages:25,minutes:15});await b.api.syncReadingLibrary();await a.api.syncReadingLibrary();assert.equal(a.api.getState().books.find(x=>x.id==='a').currentPage,75);assert.equal(a.api.getState().bookCosts[0].id,'cost');
 assert.doesNotMatch(JSON.stringify([...a.data.values()]),/test-code/);assert.ok(actions.every(x=>['load-library','save-library'].includes(x)));
});
test('disconnect and hidden app reject late library responses and stop future requests',async()=>{
 let resolve,count=0;const a=app(async()=>{count++;return {ok:true,json:()=>new Promise(r=>resolve=r)};});a.node('readingSyncAdminCode').value='test-code';
 const task=a.api.syncReadingLibrary(true);await new Promise(r=>setImmediate(r));a.api.disconnectReadingSync();resolve({ok:true,data:{version:3,payload:snap([book()])}});await task;
 assert.equal(a.api.getState().books.some(x=>x.id==='a'),false);await a.api.syncReadingLibrary();assert.equal(count,1);
 a.document.hidden=true;await a.api.syncReadingLibrary(true);assert.equal(count,1);
});
