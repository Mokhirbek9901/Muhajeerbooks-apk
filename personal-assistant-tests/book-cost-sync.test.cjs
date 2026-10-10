const {test}=require('node:test');
const assert=require('node:assert/strict');
const sync=require('../personal-assistant/book-cost-sync.js');
const costs=require('../personal-assistant/book-costs.js');
const id='00000000-0000-4000-8000-000000000001';
const book={id,title:'Arosat',price:15000,cost_price:8000,discount_percent:20,discount_ends_at:'2026-12-01T00:00:00Z'};
test('punctuation, emoji and apostrophe differences match; volume numbers and ambiguities stay separate',()=>{
 const rows=[{title:'Binafsha shulasi 1-qism'},{title:'Chumolilar saltanati'},{title:'Binafsha shulasi 2-qism'}];
 const catalog=[{...book,title:"Binafsha shu'lasi 1-qism",price:19000,discount_percent:0},{...book,id:'00000000-0000-4000-8000-000000000002',title:'🐜Chumolilar saltanati',discount_percent:0}];
 assert.equal(sync.match(rows,catalog),2);assert.equal(rows[0].salePrice,19000);assert.equal(rows[1].salePrice,15000);
 assert.equal(rows[2].muhajeerId,undefined);
 const ambiguous=[{title:'Binafsha shulasi 1-qism'}];
 sync.match(ambiguous,[catalog[0],{...catalog[0],id:'00000000-0000-4000-8000-000000000003',title:'Binafsha shu’lasi 1 qism'}]);
 assert.equal(ambiguous[0].muhajeerId,undefined);
});
test('only landed cost is sent; no sale price can enter payload',()=>{
 const row={id:'local',title:'Arosat',muhajeerId:id,price:3000,grams:200,salePrice:999,saved:true};
 const result=sync.plan([row],[book],10000);
 assert.deepEqual(result.changes,[{id,cost_price:5000,expected_cost_price:8000}]);
 assert.equal(result.changes[0].price,undefined);assert.equal(result.changes[0].salePrice,undefined);
 assert.equal(sync.plan([{...row,grams:null}],[book],10000).changes.length,0);
 assert.equal(sync.plan([{...row,saved:false}],[book],10000).changes.length,0);
 assert.equal(sync.plan([{...row,muhajeerId:''}],[book],10000).changes.length,0);
 assert.throws(()=>sync.plan([row,{...row,id:'another'}],[book],10000),/bir nechta/);
});
test('sale prices respect discount expiry; matching uses IDs and skips duplicate titles',()=>{
 assert.equal(sync.salePrice(book,Date.parse('2026-10-10')),12000);
 assert.equal(sync.salePrice(book,Date.parse('2027-01-01')),15000);
 const rows=[{title:'Arosat',salePrice:999}];sync.match(rows,[book]);assert.equal(rows[0].muhajeerId,id);
 rows[0].title='Locally changed title';sync.match(rows,[{...book,price:20000}]);assert.equal(rows[0].salePrice,16000);
 const ambiguous=[{title:'Arosat'}];sync.match(ambiguous,[book,{...book,id:'00000000-0000-4000-8000-000000000002'}]);assert.equal(ambiguous[0].muhajeerId,undefined);
 const restored=costs.normalize(JSON.parse(JSON.stringify(rows)),()=> 'id');assert.equal(restored[0].muhajeerId,id);
 assert.equal(restored[0].salePrice,16000);
});
