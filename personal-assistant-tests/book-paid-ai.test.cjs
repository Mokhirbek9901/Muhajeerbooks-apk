const {test}=require('node:test');const assert=require('node:assert/strict');
test('paid relay authenticates before research, restricts payload and returns no secrets or pricing guesses',async()=>{
 const {paidBookRequest}=await import('../personal-assistant-search/paid-book-ai.js');let calls=[];
 const rejected=await paidBookRequest({title:'Arosat',admin_code:'invalid'},false,async(url,options)=>{calls.push(url);return {ok:true,json:async()=>({ok:true,data:false})};});assert.equal(rejected.status,401);assert.equal(calls.length,1);
 calls=[];const fetch=async(url,options)=>{calls.push({url,body:JSON.parse(options.body)});return {ok:true,json:async()=>url.includes('admin-rpc')?{ok:true,data:true}:{title:'Arosat',author:'Kadir Akel',page_count:200,confidence:'high',price:999,grams:999,admin_code:'secret',description:'Description'}};};
 const out=await paidBookRequest({title:'Arosat',admin_code:'test-code'},false,fetch);assert.equal(out.status,200);assert.equal(out.data.book.pages,200);assert.equal(calls.length,2);assert.equal(calls[1].url,'https://muhajeer-books-live-production.up.railway.app/api/admin-ai/book-research');assert.equal(out.data.book.price,undefined);assert.equal(out.data.book.grams,undefined);assert.equal(out.data.book.admin_code,undefined);
 assert.equal((await paidBookRequest({title:'A',admin_code:'test-code',url:'https://arbitrary'},false,fetch)).status,400);
 const n=calls.length;assert.equal((await paidBookRequest({admin_code:'test-code'},true,fetch)).status,200);assert.equal(calls.length,n+1);
});
