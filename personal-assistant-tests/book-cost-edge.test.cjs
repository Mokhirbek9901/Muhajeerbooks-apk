const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const {stripTypeScriptTypes}=require('node:module');
function harness(verified=true){
 let handler;const calls=[];
 const source=stripTypeScriptTypes(fs.readFileSync('supabase/functions/yordamchi-book-costs/index.ts','utf8'));
 vm.runInNewContext(source,{Deno:{env:{get:()=> 'server-only'},serve:fn=>{handler=fn;}},Request,Response,AbortSignal,fetch:async(url,opts)=>{calls.push({url,body:opts.body && JSON.parse(opts.body)});return new Response(JSON.stringify(url.endsWith('admin_verify')?verified:url.includes('yordamchi_update')?[{id:'00000000-0000-4000-8000-000000000001',cost_price:5000}]:[]),{status:200});}});
 return {calls,call:body=>handler(new Request('https://example.com',{method:'POST',headers:{origin:'https://bek-shaxsiy-yordamchi-pro.onrender.com'},body:JSON.stringify(body)}))};
}
test('edge validates admin, rejects sale price payload and only invokes cost-only operation',async()=>{
 const h=harness();const change={id:'00000000-0000-4000-8000-000000000001',cost_price:5000,expected_cost_price:3000};
 const result=await h.call({action:'update-costs',admin_code:'test-not-a-real-code',changes:[change]});assert.equal(result.status,200);
 assert.deepEqual(h.calls[1].body,{p_changes:[change]});
 const bad=await h.call({action:'update-costs',admin_code:'test-not-a-real-code',changes:[{...change,price:9999}]});assert.equal(bad.status,400);assert.equal(h.calls.length,3);
 const noAuth=harness(false);assert.equal((await noAuth.call({action:'update-costs',admin_code:'invalid',changes:[change]})).status,401);assert.equal(noAuth.calls.length,1);
 assert.equal((await h.call({action:'admin_save_book',admin_code:'test'})).status,400);
});
test('device list storage requires admin verification and cannot call catalog updates',async()=>{
 const p={books:[{id:'local',title:'Test',price:null,grams:null,saved:true,salePrice:null,muhajeerId:null}],rate:7000,tariffs:[]};
 const h=harness();assert.equal((await h.call({action:'save-list',admin_code:'test',changes:{version:0,payload:p}})).status,200);
 assert.equal(h.calls[1].url.endsWith('rpc/yordamchi_save_device_list'),true);
 assert.deepEqual(h.calls[1].body,{p_version:0,p_payload:p});
 assert.equal((await h.call({action:'save-list',admin_code:'test',changes:{version:0,payload:{...p,admin_code:'secret'}}})).status,400);
 const noAuth=harness(false);assert.equal((await noAuth.call({action:'load-list',admin_code:'invalid'})).status,401);assert.equal(noAuth.calls.length,1);
});
