const {test}=require('node:test');const assert=require('node:assert/strict');const sync=require('../personal-assistant/book-cost-device-sync.js');
const row=(id,price=100)=>({id,title:id,price,grams:null,saved:true,salePrice:null,muhajeerId:null});
const snap=(books,rate=10000)=>({books,rate,tariffs:[]});
test('first device uploads; empty second device restores names-only books and tariffs',()=>{
 const local=snap([row('book')],7000);local.tariffs.push({id:'t',label:'Avia',rate:10000});
 assert.deepEqual(sync.merge(null,local,null).value,local);
 assert.deepEqual(sync.merge(null,snap([]),local).value,local);
});
test('three-way sync combines separate field edits, additions and deletion without resurrection',()=>{
 const base=snap([row('a'),row('b')]);const local=snap([{...row('a'),grams:300},row('b'),row('c')]);const remote=snap([row('a',200)]);
 const result=sync.merge(base,local,remote);assert.deepEqual(result.conflicts,[]);
 assert.equal(result.value.books.length,2);assert.equal(result.value.books[0].price,200);assert.equal(result.value.books[0].grams,300);assert.equal(result.value.books[1].id,'c');
});
test('same-field concurrent edits are rejected and inputs made during a request are preserved',()=>{
 const base=snap([row('a')]);assert.ok(sync.merge(base,snap([row('a',200)]),snap([row('a',300)])).conflicts.length);
 const current=snap([{...row('a'),grams:300}]),saved=snap([row('a',200),row('b')]);const late=sync.merge(base,current,saved);
 assert.equal(late.conflicts.length,0);assert.equal(late.value.books.length,2);assert.equal(late.value.books[0].grams,300);
});
test('linked sale prices and credentials never enter device snapshots',()=>{
 const value=sync.snapshot({bookCosts:[{...row('a'),muhajeerId:'linked',salePrice:9999}],bookCostRate:7000,bookCostComparisons:[],admin_code:'secret'});
 assert.equal(value.books[0].salePrice,null);assert.doesNotMatch(JSON.stringify(value),/secret|admin_code/);
});

test('ten received copies survive the cloud snapshot and a remote reload',()=>{
 const state={bookCosts:[{...row('multi',15000),grams:200,quantity:10,salePrice:24000}],bookCostRate:10000,bookCostComparisons:[]};
 const initial=sync.snapshot(state);
 assert.equal(initial.books[0].quantity,10);
 assert.equal(initial.books[0].price,15000);
 const restored=sync.merge(null,snap([]),initial).value;
 assert.equal(restored.books[0].quantity,10);
 assert.equal(restored.books[0].price,15000);
});
test('legacy device payload with no quantity can still merge with modern records',()=>{
 const base=snap([row('legacy')]);
 const local=snap([{...row('legacy'),quantity:1}]);
 const remote=snap([{...row('legacy'),price:200}]);
 const result=sync.merge(base,local,remote);
 assert.deepEqual(result.conflicts,[]);
 assert.equal(result.value.books[0].quantity,1);
 assert.equal(result.value.books[0].price,200);
});

test('independent devices can add different batches for the same book without overwriting totals',()=>{
 const original={...row('a',8000),grams:300,quantity:4,batches:[]};
 const base=snap([original]);
 const local=snap([{...original,quantity:7,batches:[{id:'local-partiya',date:'2026-10-22',quantity:3,price:null,grams:null,rate:10000}]}]);
 const remote=snap([{...original,quantity:6,batches:[{id:'remote-partiya',date:'2026-10-22',quantity:2,price:null,grams:null,rate:10000}]}]);
 const merged=sync.merge(base,local,remote);
 assert.deepEqual(merged.conflicts,[]);
 assert.equal(merged.value.books[0].quantity,9);
 assert.equal(merged.value.books[0].batches.length,2);
 const snapRoundTrip=sync.snapshot({bookCosts:merged.value.books,bookCostRate:10000,bookCostComparisons:[]});
 assert.equal(snapRoundTrip.books[0].quantity,9);
 assert.equal(snapRoundTrip.books[0].batches[0].id,'remote-partiya');
});
