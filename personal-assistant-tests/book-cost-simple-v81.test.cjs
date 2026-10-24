'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const base=path.join(__dirname,'../personal-assistant');
const read=f=>fs.readFileSync(path.join(base,f),'utf8');
const costs=require(path.join(base,'book-costs.js'));
const currency=require(path.join(base,'currency-converter.js'));
test('per-book price is purchase plus gram shipping at its chosen rate',()=>{
 const row={title:'Arosat',price:11000,grams:250,originRate:10000};
 const result=costs.calculate(row,row.originRate);
 assert.deepEqual(result,{shipping:2500,total:13500});
 assert.equal(costs.calculate({...row,grams:300},10000).shipping,3000);
});
test('current exact FX converts Uzbek som to won without premature rounding',()=>{
 const state={preciseExchangeRates:{krwToUzsPer1000:currency.precise.valid('8841.492544')}};
 const won=currency.precise.convert('100000','UZS','KRW',state);
 assert.ok(won);
 const raw=currency.precise.text(won);
 assert.ok(raw.startsWith('11310.'));
 assert.equal(currency.precise.text(currency.precise.convert('1000','KRW','UZS',state)),'8841.492544');
 const totalSom=currency.precise.convert('13500','KRW','UZS',state);
 assert.equal(currency.precise.text(totalSom),'119360.149344');
});
test('UI uses one-book form and shows KRW plus UZS for every subtotal',()=>{
 const html=read('index.html'),app=read('app.js');
 for(const id of ['costSimpleTitle','costSimplePrice','costSimpleCurrency','costSimpleGrams','costSimplePricingKg','costSimplePurchaseWon','costSimplePurchaseSom','costSimpleShipping','costSimpleShippingSom','costSimpleUnit','costSimpleTotalSom'])
  assert.ok(html.includes('id="'+id+'"'),id);
 assert.ok(app.includes('renderCostPlainCatalog()'));
 assert.ok(app.includes('costSimpleShippingSom'));
 assert.ok(app.includes('costPlainCard(row)'));
 assert.ok(app.includes("costView='list'"));
});
test('no quantity or batch fields on the visible book calculator',()=>{
 const css=read('styles.css');
 for(const id of ['#costSimpleQuantityWrap','#costSimpleBatchWrap','#costSimpleBatchMoneyWrap','#costAdvancedEditor','#costReportPanel']){
  assert.ok(css.includes(id),id);
 }
 assert.ok(css.includes('display:none!important'));
 const app=read('app.js');
 const start=app.indexOf('  function saveSimpleCostForm(event){'),end=app.indexOf('  function setCostView(view){',start);
 const save=app.slice(start,end);
 assert.ok(save.includes('quantity:1'));
 assert.ok(!save.includes('existing.batches='));
 assert.ok(!save.includes('costSimpleBatchActualKg'));
 assert.ok(save.includes('row.originRate=kg'));
});
test('no conversion of currency display string back to number',()=>{
 const app=read('app.js');
 const slice=app.slice(app.indexOf('  function costSomCompact(won){'),app.indexOf('  function costUzsClean(value){'));
 assert.ok(slice.includes('window.BookCostSimple.uzsFromWon(state,String(won))'));
 assert.ok(slice.includes('window.BookCostSimple.formatUzs(quote)'));
 assert.ok(!slice.includes("exact.replace("));
});
test('legacy records remain untouched by new UI and the catalog is unique by normalized title',()=>{
 const app=read('app.js');
 const first=app.indexOf('  function renderCostPlainCatalog(){');
 const last=app.indexOf('  function renderCostReadyList(){',first);
 const render=app.slice(first,last);
 assert.ok(render.includes("window.BookCostListUI.filterBooks"));
 const ui=read('book-cost-list-ui.js');
 assert.ok(ui.includes("if(!unique.has(key))"));
 assert.ok(!render.includes('state.bookCosts='));
});
test('cache and navigation show the minimal v84 variant',()=>{
 const html=read('index.html'),sw=read('sw.js');
 for(const f of ['app.js','styles.css','book-costs.js'])assert.ok(html.includes(f+'?v=84') && sw.includes(f+'?v=84'));
 assert.ok(sw.includes('bek-yordamchi-v84'));
 assert.ok(html.includes('data-mode-tab="settings"'));
 assert.ok(html.includes('<small>Kurs</small>'));
});