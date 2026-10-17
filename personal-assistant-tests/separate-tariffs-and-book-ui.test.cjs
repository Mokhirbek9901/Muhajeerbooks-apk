'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const dir=path.join(__dirname,'../personal-assistant');
const html=fs.readFileSync(path.join(dir,'index.html'),'utf8');
const app=fs.readFileSync(path.join(dir,'app.js'),'utf8');
const product=fs.readFileSync(path.join(dir,'korea-products.js'),'utf8');
const css=fs.readFileSync(path.join(dir,'styles.css'),'utf8');
test('book rates only expose KRW and UZS, with a two-direction entry and converter',()=>{
  const book=html.slice(html.indexOf('id="screen-book-costs"'),html.indexOf('id="screen-finance"'));
  assert.ok(book.includes('id="bookRateDirection"'));
  assert.ok(book.includes('id="bookRateSwap"'));
  assert.ok(book.includes('id="bookRateSave"'));
  assert.ok(book.includes('data-currency-view="books"'));
  assert.ok(!book.includes('value="USD"'),'no dollar option visible in book cost screen');
  assert.ok(book.includes('id="bookSomTotal"'),'prior converted-cost output retained');
  assert.ok(app.includes("function formatBookRate("));
  assert.ok(app.includes('state.preciseExchangeRates='));
});
test('book main, list and report contents are isolated without removing cost statistics',()=>{
  assert.ok(app.includes("$('costListPanel').hidden=costView!=='list'"));
  assert.ok(html.includes('id="costReportPanel"'));
  assert.ok(html.includes('id="costMainActions"'));
  assert.ok(css.includes('data-cost-view="main"] .cost-dashboard article'));
  assert.ok(css.includes('data-cost-view="report"] #screen-book-costs .cost-dashboard'));
  assert.ok(css.includes('data-cost-view="settings"] .book-simple-fx'));
});
test('product editor exposes own kg rate and both won/som choices',()=>{
  assert.ok(html.includes('id="koreaItemKgRate"'));
  assert.ok(html.includes('id="koreaItemRateCurrency"'));
  assert.match(product,/rateInWon\(\$\('koreaItemKgRate'\)/);
  assert.match(product,/const item=\{id:id\|\|api\.id\(\),name,kind:.*kgRate\}/);
});
test('bulk rate changes require selection AND explicit confirmation',()=>{
  assert.ok(html.includes('id="koreaBulkTargets"'));
  assert.ok(html.includes('id="koreaBulkSelectAll"'));
  assert.ok(html.includes('id="koreaBulkApply" disabled'));
  assert.match(product,/if\(!targets\.length\)/);
  assert.match(product,/if\(!confirm\(/);
  assert.match(product,/applyRateToSelected\(old,selectedProductIds,rate\)/);
});
test('user data is normalized into per-product kg rates while preserving book information',()=>{
  assert.match(app,/koreaProducts: window\.KoreaProducts\.normalize\(input\?\.koreaProducts,makeId,/);
  assert.match(app,/window\.KoreaProducts\.shippingRate\(input\?\.koreaShippingRate,costs\.rate\(input\?\.bookCostRate\)\)/);
  assert.match(app,/bookCosts: costs\.normalize\(input\?\.bookCosts,makeId\)/);
});
