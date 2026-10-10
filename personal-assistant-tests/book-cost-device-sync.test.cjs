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
