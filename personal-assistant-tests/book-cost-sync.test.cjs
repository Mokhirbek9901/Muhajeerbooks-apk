const {test}=require('node:test');
const assert=require('node:assert/strict');
const sync=require('../personal-assistant/book-cost-sync.js');
const costs=require('../personal-assistant/book-costs.js');
const id='00000000-0000-4000-8000-000000000001';
const book={id,title:'Arosat',price:15000,cost_price:8000,discount_percent:20,discount_ends_at:'2026-12-01T00:00:00Z'};
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
