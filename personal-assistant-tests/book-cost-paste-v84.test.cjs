'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'../personal-assistant');
const ui=require(path.join(root,'book-cost-list-ui.js'));
const costs=require(path.join(root,'book-costs.js'));
const simple=require(path.join(root,'book-cost-simple.js'));
const decimal=require(path.join(root,'decimal-fx.js'));
const read=name=>fs.readFileSync(path.join(root,name),'utf8');
test('100 pasted names, including Uzbek apostrophes, stay individually named and ordered',()=>{
 const original=Array.from({length:100},(_,i)=>'Kitob #'+(i+1)+(i===27?' — o‘zbekcha':'')).join('\n');
 const result=ui.parseNameList(original,costs.key);
 assert.equal(result.error,'');
 assert.equal(result.names.length,100);
 assert.equal(result.names[27],'Kitob #28 — o‘zbekcha');
 assert.equal(result.names[99],'Kitob #100');
});
test('pasted list supports Telegram-style bullets, numbering, duplicate lines and blank lines',()=>{
 const data='1. Oq nilufarlar\n2) Arosat\n- Ko‘rlik\n• Laylo\n\nArosat\n3. Ko‘rlik';
 const result=ui.parseNameList(data,costs.key);
 assert.deepEqual(result.names,['Oq nilufarlar','Arosat','Ko‘rlik','Laylo']);
});
test('limit and validation protect existing catalog from accidental huge import',()=>{
 assert.equal(ui.parseNameList(Array.from({length:1001},(_,i)=>'Nomi '+i).join('\n'),costs.key).error.includes('1 000'),true);
 assert.match(ui.parseNameList('x'.repeat(301),costs.key).error,/300/);
 assert.equal(ui.parseNameList('  \n\n  ',costs.key).names.length,0);
});
test('old cost records and duplicates remain unchanged by bulk import workflow',()=>{
 const app=read('app.js'),start=app.indexOf('  function saveCostBulkSimple(event){');
 const end=app.indexOf('  function openSimpleCostEditor(',start),snippet=app.slice(start,end);
 assert.ok(snippet.includes('price:null,grams:null,saved:true'));
 assert.ok(snippet.includes('existing.has(key)'));
 assert.ok(snippet.includes('state.bookCosts=[...before,...newRows]'));
 assert.ok(snippet.includes('state.bookCosts=before'));
 assert.ok(snippet.includes('persistBookCosts('));
 assert.ok(snippet.includes(',false)'));
 assert.ok(!snippet.includes('pushCostCloud('));
});
test('single book save accepts name only, purchase only or grams only',()=>{
 const app=read('app.js');const start=app.indexOf('  function saveSimpleCostForm(event){');
 const end=app.indexOf('  function setCostView(view){',start),snippet=app.slice(start,end);
 assert.ok(snippet.includes("if(!title)error='Kitob nomini kiriting.'"));
 assert.ok(snippet.includes("if($('costSimplePrice').value.trim()&&fields.price===null)"));
 assert.ok(snippet.includes("if($('costSimpleGrams').value.trim()&&fields.grams===null)"));
 assert.ok(!snippet.includes("!$('costSimpleGrams').value.trim()||fields.grams===null"));
 assert.ok(!snippet.includes("!$('costSimplePrice').value.trim()||fields.price===null"));
 assert.ok(snippet.includes('row.grams=fields.grams'));
 assert.ok(snippet.includes('row.price=previousPriceMissingQuote?original.price:fields.price'));
});
test('editor defaults to Uzbek som even for old won-denominated books',()=>{
 const app=read('app.js');
 const a=app.indexOf('  function fillSimpleCostForm(){'),b=app.indexOf('  function updateCostBulkPasteCount(){',a),snippet=app.slice(a,b);
 assert.ok(snippet.includes("$('costSimpleCurrency').value='UZS'"));
 assert.ok(snippet.includes('window.BookCostSimple.uzsFromWon(state,String(row.price))'));
 assert.ok(snippet.includes('precise.text(convertedUzs)'));
 const html=read('index.html');
 assert.ok(html.includes('<option value="UZS" selected>'));
});
test('a new entered som value is not silently multiplied by 1000',()=>{
 const app=read('app.js'),a=app.indexOf('  function costSimpleValues(){'),b=app.indexOf('  function refreshSimpleCostPreview(){',a);
 const code=app.slice(a,b);
 assert.ok(code.includes("currency==='UZS'?window.YordamchiCurrency.precise.valid(rawPrice):null"));
 assert.ok(!code.includes('normalizedPrice(rawPrice,null,true)'));
 const state={preciseExchangeRates:{krwToUzsPer1000:decimal.valid('8700')}};
 const amount=decimal.valid('85000');
 const won=simple.wonFromUzs(state,amount);
 assert.equal(simple.formatUzs(amount),'85,000 so‘m');
 assert.ok(decimal.number(won)>9000);
});
test('price-only book still shows purchase price and KRW; weight-only shows shipping',()=>{
 const app=read('app.js'),a=app.indexOf('  function costPlainCard(row){'),b=app.indexOf('  function renderCostPlainCatalog(){',a);
 const snippet=app.slice(a,b);
 assert.ok(snippet.includes('if(unitPurchase===null||row.grams===null)'));
 assert.ok(snippet.includes("Xarid: <strong>"));
 assert.ok(snippet.includes('Yetkazish: <strong>'));
 assert.ok(!snippet.includes("if(row.price===null||row.grams===null)return"));
 const costsRow={price:10000,grams:null};
 assert.equal(costs.calculate(costsRow,8400).total,null);
 assert.equal(costs.calculate({price:10000,grams:250},8400).total,12100);
});
test('v84 html and SW load correct scripts and there is a multiline textarea',()=>{
 const html=read('index.html'),sw=read('sw.js');
 for(const f of ['app.js','styles.css','book-cost-simple.js','book-cost-list-ui.js']){
 assert.ok(html.includes(f+'?v=84'),f);
 assert.ok(sw.includes(f+'?v=84'),f);
 }
 assert.ok(sw.includes('bek-yordamchi-v84'));
 assert.ok(html.indexOf('book-cost-list-ui.js')<html.indexOf('app.js'));
 assert.ok(html.includes('id="costBulkPasteNames" rows="10"'));
 assert.ok(html.includes('id="costBulkPasteCount"'));
 assert.ok(!html.includes('id="costBulkSimpleAddRow"'));
});
