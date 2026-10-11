const {test}=require('node:test');const assert=require('node:assert/strict');const vm=require('node:vm');const fs=require('node:fs');const timer=require('../personal-assistant/reading-timer.js');
test('clock uses actual elapsed time even without background ticks',()=>{
 const s={startedAt:100000};assert.equal(timer.clock(timer.elapsed(s,100000+185000)),'03:05');assert.equal(timer.clock(timer.elapsed(s,90000)),'00:00');
 assert.equal(timer.restore('{bad',[],''),null);assert.equal(timer.restore({bookId:'gone',sessionId:'s',startedAt:0},[],''),null);assert.equal(timer.restore({bookId:'a',sessionId:'saved',startedAt:0},[{id:'a'}],'saved'),null);
});
test('sessions crossing local midnight allocate minutes to the actual days, without double rounding',()=>{
 const start=new Date(2026,9,11,23,58,30).getTime(),end=new Date(2026,9,12,0,2,30).getTime();const rows=timer.dailyMinutes(start,end);
 assert.equal(rows.length,2);assert.equal(rows[0].date,'2026-10-11');assert.equal(rows[1].date,'2026-10-12');assert.equal(rows.reduce((n,x)=>n+x.minutes,0),4);
 assert.deepEqual(timer.dailyMinutes(start,start+500),[]);
});
function app(data=new Map(),time={now:new Date(2026,9,11,17,0).getTime()}){
 const nodes=new Map(),events=new Map(),intervals=new Map();let intervalId=0;
 const node=id=>{if(!nodes.has(id))nodes.set(id,{value:'',textContent:'',hidden:false,classList:{add(){},remove(){}},addEventListener(){}});return nodes.get(id);};
 class DateMock extends Date{constructor(...args){super(...(args.length?args:[time.now]));}static now(){return time.now;}}
 const doc={hidden:false,getElementById:node,querySelectorAll:()=>[],addEventListener:(n,f)=>events.set(n,f)};
 const ctx={window:{BookCosts:require('../personal-assistant/book-costs.js'),ReadingTimer:timer,addEventListener:(n,f)=>events.set(n,f)},document:doc,localStorage:{getItem:k=>data.get(k)||null,setItem:(k,v)=>data.set(k,v),removeItem:k=>data.delete(k)},navigator:{},crypto:require('node:crypto').webcrypto,Date:DateMock,setTimeout:()=>0,clearTimeout(){},setInterval:f=>{intervals.set(++intervalId,f);return intervalId;},clearInterval:id=>intervals.delete(id),console};
 let source=fs.readFileSync('personal-assistant/app.js','utf8').replace("  bindBookCosts();\n  bindEvents();\n  renderAll();\n  navigate('home',false);\n  maybeDailyReminder();\n  scheduleMissingMetadataAuto();",'window.test={toggleReadingTimer,stopReadingTimer,restoreReadingTimer,runReadingTimerDisplay,getState:()=>state,getTimer:()=>readingTimer};');
 source=source.replaceAll('renderAll();','window.rendered=true;').replaceAll('renderBookDetail();','window.detailRendered=true;');vm.runInNewContext(source,ctx);
 return {api:ctx.window.test,data,time,node,doc,events,intervals,ctx};
}
test('lock, pagehide, process restart and reload preserve elapsed time; stop saves once',()=>{
 const a=app();const id=a.api.getState().books[0].id;a.api.toggleReadingTimer(id);assert.ok(a.data.has('bek_reading_timer_v1'));
 a.doc.hidden=true;a.api.runReadingTimerDisplay();a.events.get('pagehide')();assert.equal(a.intervals.size,0);assert.equal(a.api.getTimer().bookId,id);
 a.time.now+=7*60000+5000;const b=app(a.data,a.time);assert.equal(b.node('readingTimerBannerClock').textContent,'07:05');assert.equal(b.api.getTimer().bookId,id);
 assert.equal(b.api.stopReadingTimer(),true);assert.equal(b.api.getState().books.find(x=>x.id===id).readingLog.find(x=>x.date==='2026-10-11').minutes,8);assert.equal(b.data.has('bek_reading_timer_v1'),false);
 a.api.stopReadingTimer();const c=app(b.data,b.time);assert.equal(c.api.getTimer().bookId,'');assert.equal(c.api.getState().books.find(x=>x.id===id).readingLog.find(x=>x.date==='2026-10-11').minutes,8);
});
test('switching books saves the old session; failed storage leaves active timer and logs intact',()=>{
 const a=app();const [one,two]=a.api.getState().books;a.api.toggleReadingTimer(one.id);a.time.now+=60000;a.api.toggleReadingTimer(two.id);assert.equal(a.api.getTimer().bookId,two.id);assert.equal(one.readingLog.find(x=>x.date==='2026-10-11').minutes,1);
 const before=JSON.stringify(two.readingLog);a.time.now+=120000;a.ctx.localStorage.setItem=()=>{throw Error('Quota');};assert.equal(a.api.stopReadingTimer(),false);assert.equal(a.api.getTimer().bookId,two.id);assert.equal(JSON.stringify(two.readingLog),before);assert.ok(a.data.has('bek_reading_timer_v1'));
});
