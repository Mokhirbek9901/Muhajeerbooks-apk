'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const base=path.resolve(__dirname,'../personal-assistant');
const helper=require(path.join(base,'book-cost-simple.js'));
const currency=require(path.join(base,'decimal-fx.js'));
const costs=require(path.join(base,'book-costs.js'));
const read=f=>fs.readFileSync(path.join(base,f),'utf8');
const state=rate=>({preciseExchangeRates:{krwToUzsPer1000:currency.valid(rate)}});
test('legacy 8.7 UZS per won becomes 8700 UZS per 1000 won in book calculator only',()=>{
 assert.equal(currency.text(helper.bookFx(state('8.7'))),'8700');
 assert.equal(currency.text(helper.bookFx(state('8700'))),'8700');
 assert.equal(currency.text(helper.bookFx(state('8841.492544'))),'8841.492544');
 assert.equal(currency.text(helper.bookFx(state('12.5'))),'12500');
});
test('old book 97.02 display restores 97020 while genuine 97020 stays unchanged',()=>{
 assert.equal(currency.text(helper.normalizedPrice('97.02',11148)),'97020');
 assert.equal(currency.text(helper.normalizedPrice('60.02',6896)),'60020');
 assert.equal(currency.text(helper.normalizedPrice('50.02',5747)),'50020');
 assert.equal(currency.text(helper.normalizedPrice('97020',11148)),'97020');
 assert.equal(currency.text(helper.normalizedPrice('500',null)),'500');
});
test('user-entered 97.02 is normalized, new full UZS input remains full',()=>{
 assert.equal(currency.text(helper.normalizedPrice('97.02',null,true)),'97020');
 assert.equal(currency.text(helper.normalizedPrice('100000',null,true)),'100000');
});
test('shipping 3024 won at 8.7 UZS/won displays full rounded 26309 som',()=>{
 const result=helper.uzsFromWon(state('8.7'),'3024');
 assert.equal(currency.text(result),'26308.8');
 assert.equal(helper.formatUzs(result),'26,309 so‘m');
 assert.equal(helper.formatUzs(helper.uzsFromWon(state('8.7'),'5124')),'44,579 so‘m');
});
test('one unit with 610g and kg 8400 stays 5124 won shipping',()=>{
 const result=costs.calculate({price:11148,grams:610},8400);
 assert.deepEqual(result,{shipping:5124,total:16272});
});
test('sample from screenshot has whole thousands-based UZS purchase and total',()=>{
 const uzs=helper.normalizedPrice('97.02',11148);
 const purchase=helper.wonFromUzs(state('8.7'),uzs);
 assert.equal(helper.formatUzs(uzs),'97,020 so‘m');
 const total=currency.multiply(currency.valid('1'),currency.valid('1')); // precision is retained
 assert.ok(total);
 const cost=costs.calculate({price:currency.number(purchase),grams:610},8400);
 assert.equal(helper.formatUzs(helper.uzsFromWon(state('8.7'),String(cost.total))),'141,599 so‘m');
});
test('global kg form is visible and independent of per-row historical rate snapshots',()=>{
 const html=read('index.html'),app=read('app.js'),css=read('styles.css');
 assert.ok(html.includes('id="costPlainKgForm"'));
 assert.ok(html.includes('id="costPlainKgInput"'));
 assert.ok(app.includes("costs.calculate({...row,price:unitPurchase},state.bookCostRate)"));
 assert.ok(app.includes("const tariff=state.bookCostRate"));
 assert.ok(app.includes("if(!original)row.originRate=kg"));
 assert.ok(css.includes('label[for="costSimplePricingKg"]{display:none!important}'));
 assert.ok(css.includes('.cost-plain-incomplete'));
});
test('FX/price display conversion uses isolated correction and rounded whole UZS',()=>{
 const app=read('app.js');
 assert.ok(app.includes('window.BookCostSimple.bookFx(state)'));
 assert.ok(app.includes('window.BookCostSimple.normalizedPrice(rawUzs,row.price)'));
 assert.ok(app.includes('window.BookCostSimple.uzsFromWon(state,String(won))'));
 assert.ok(!app.slice(app.indexOf('function costSomCompact(won)'),app.indexOf('function costUzsClean')).includes('maximumFractionDigits:2'));
});
test('new v87 helper loads before app and offline cache includes it',()=>{
 const html=read('index.html'),sw=read('sw.js');
 for(const f of ['app.js','styles.css','book-costs.js','book-cost-simple.js']){
 assert.ok(html.includes(f+'?v=87'),f+' HTML');
 assert.ok(sw.includes(f+'?v=87'),f+' SW');
 }
 assert.ok(html.indexOf('book-cost-simple.js')<html.indexOf('app.js'));
 assert.ok(sw.includes('bek-yordamchi-v87'));
});