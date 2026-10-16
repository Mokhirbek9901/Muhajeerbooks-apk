'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const costs=require('../personal-assistant/book-costs.js');
const root=path.join(__dirname,'../personal-assistant');
const html=fs.readFileSync(path.join(root,'index.html'),'utf8');
const app=fs.readFileSync(path.join(root,'app.js'),'utf8');
const css=fs.readFileSync(path.join(root,'styles.css'),'utf8');
test('the new main flow shows book name, highlighted quantity, purchase, weight and selling price without opening advanced controls',()=>{
  const i=html.indexOf('<form id="costSimpleForm"');
  const j=html.indexOf('</form>',i);
  assert.ok(i>0&&j>i,'simple form exists');
  const form=html.slice(i,j);
  for(const id of ['costSimpleTitle','costSimpleQuantity','costSimplePrice','costSimpleGrams','costSimpleSale','costSimpleUnit','costSimpleTotal','costSimpleProfit','costSimpleSave']){
    assert.ok(form.includes('id="'+id+'"'),id+' must be visible in simple form');
  }
  assert.ok(form.includes('Nechta kitob keldi?'));
  assert.ok(form.includes('cost-simple-highlight'),'quantity field visually prominent');
  assert.ok(html.indexOf('id="costAdvancedEditor"')>j,'advanced tools separate');
  assert.ok(!/<details[^>]*costSimpleForm/.test(form),'simple form is not collapsed');
});
test('independent home/reading, product and cost stats and routes remain visible',()=>{
  for(const mode of ['reading','costs','products','finance'])assert.ok(html.includes('data-workspace-select="'+mode+'"'));
  assert.ok(html.includes('id="costMainActions"'));
  assert.ok(html.includes('id="costRecentHeading"'));
  assert.ok(html.includes('id="costReportPanel"'));
  assert.ok(html.includes('id="productsFxDetails"'));
  assert.ok(css.includes('data-cost-view="list"'));
  assert.ok(css.includes('data-cost-view="report"'));
  assert.ok(app.includes("costView==='main'?rows.slice(0,3):rows"));
});
test('ten received books yield expected acquisition, shipping, expense, projected margin; old records safe',()=>{
  const row={title:'Example',quantity:10,price:15000,grams:200,salePrice:24000,saved:true};
  assert.equal(costs.inventory(row,10000).purchase,150000);
  assert.equal(costs.inventory(row,10000).shipping,20000);
  assert.equal(costs.inventory(row,10000).total,170000);
  assert.equal(costs.inventory(row,10000).profit,70000);
  assert.equal(costs.normalize([{title:'Old book',price:8000,grams:100}],()=> 'id')[0].quantity,1);
});
test('the product and book tariff settings are still separate',()=>{
  assert.match(app,/state\.bookCostRate/);
  assert.match(html,/id="koreaKgRateInput"/);
  assert.match(html,/id="costKgRateQuick"/);
  assert.match(html,/id="costSimpleQuantity"/);
});
