'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const costs=require('../personal-assistant/korea-products.js');

test('manual 1000 KRW to UZS conversion uses the entered rate',()=>{
  assert.equal(costs.som(13000,8500),110500);
  assert.equal(costs.som(15030,8500),127755);
  assert.equal(costs.som(13000,null),null);
  assert.equal(costs.fx(0),null);
  assert.equal(costs.fx(-500),null);
});

test('product shipping is proportional to grams and uses its own independent kg tariff',()=>{
  assert.deepEqual(costs.calculate({price:13000,grams:290},7000,8500),{
    price:13000,shipping:2030,total:15030,
    priceSom:110500,shippingSom:17255,totalSom:127755
  });
  assert.equal(costs.calculate({price:13000,grams:500},10000,8500).total,18000);
});

test('incomplete products never produce a misleading total',()=>{
  const noWeight=costs.calculate({price:13000,grams:null},7000,8500);
  assert.equal(noWeight.priceSom,110500);
  assert.equal(noWeight.shipping,null);
  assert.equal(noWeight.totalSom,null);
  const noRate=costs.calculate({price:13000,grams:290},7000,null);
  assert.equal(noRate.total,15030);
  assert.equal(noRate.totalSom,null);
});

test('product normalization preserves records without altering books',()=>{
  let next=0;
  const normalized=costs.normalize([{name:' Koreys jensheni ',kind:'Jenshen',price:'13,000',grams:'290'},{name:'',price:3000},{name:'Krem',kind:'invalid',price:'oops',grams:null}],()=>String(++next));
  assert.equal(normalized.length,2);
  assert.equal(normalized[0].name,'Koreys jensheni');
  assert.equal(normalized[0].price,13000);
  assert.equal(normalized[1].kind,'Boshqa');
  assert.equal(normalized[1].price,null);
});

test('a single global rate instantly converts every product including the purchase, shipping and grand totals',()=>{
  const products=[
    {name:'Jenshen',price:13000,grams:290},
    {name:'Vitamin',price:9000,grams:200}
  ];
  const result=costs.summarize(products,10000,8000);
  assert.equal(result.count,2);
  assert.equal(result.ready,2);
  assert.equal(result.purchase,22000);
  assert.equal(result.shipping,4900);
  assert.equal(result.total,26900);
  assert.equal(result.purchaseSom,176000);
  assert.equal(result.shippingSom,39200);
  assert.equal(result.totalSom,215200);
  assert.equal(costs.calculate(products[0],10000,8000).priceSom,104000);
  assert.equal(costs.calculate(products[0],10000,8000).totalSom,127200);
});
test('incomplete products remain visible but never inflate grand totals',()=>{
  const result=costs.summarize([
    {price:13000,grams:290},
    {price:14000,grams:null},
    {price:null,grams:100}
  ],10000,8000);
  assert.equal(result.count,3);
  assert.equal(result.ready,1);
  assert.equal(result.incomplete,2);
  assert.equal(result.total,15900);
  assert.equal(result.totalSom,127200);
});
test('a new global rate recalculates displayed UZS without changing stored won values',()=>{
  const item={price:13000,grams:290};
  const a=costs.summarize([item],10000,8000),b=costs.summarize([item],10000,8500);
  assert.equal(a.total,b.total);
  assert.equal(a.total,15900);
  assert.equal(a.totalSom,127200);
  assert.equal(b.totalSom,135150);
  assert.deepEqual(item,{price:13000,grams:290});
});
test('missing rate does not fake UZS summary while KRW costs are correct',()=>{
  const summary=costs.summarize([{price:13000,grams:290}],10000,null);
  assert.equal(summary.total,15900);
  assert.equal(summary.totalSom,null);
});

test('product kg rate is separate from book kg rate and preserves old records',()=>{
  const item={id:'g1',name:'Jenshen',price:13000,grams:290};
  const bookRate=10000;
  const koreaRate=7000;
  const oldState={bookCostRate:bookRate,koreaProducts:[item]};
  const newState={...oldState,koreaShippingRate:koreaRate};
  assert.equal(costs.shippingRate(newState.koreaShippingRate,newState.bookCostRate),7000);
  assert.equal(costs.shippingRate(null,oldState.bookCostRate),10000);
  assert.equal(costs.shippingRate(0,oldState.bookCostRate),0);
  assert.equal(costs.shippingRate('not a number',10000),10000);
  const product=costs.calculate(item,newState.koreaShippingRate,8000);
  assert.equal(product.shipping,2030);
  assert.equal(product.total,15030);
  assert.equal(product.totalSom,120240);
  // Changing the book tariff must not alter any Korean-product calculation.
  const bookAfterChange=15000;
  assert.equal(costs.calculate(item,newState.koreaShippingRate,8000).shipping,2030);
  assert.equal(bookAfterChange,15000);
  assert.deepEqual(newState.koreaProducts,[item]);
});
test('independent products tariff affects only product summary and category costs',()=>{
  const products=[{name:'Vitamin',price:9000,grams:100},{name:'Kosmetika',price:8000,grams:300}];
  const low=costs.summarize(products,7000,8000),high=costs.summarize(products,10000,8000);
  assert.equal(low.total,19800);
  assert.equal(high.total,21000);
  assert.equal(low.totalSom,158400);
  assert.equal(high.totalSom,168000);
  assert.equal(low.purchase,17000);
  assert.equal(high.purchase,17000);
  assert.equal(low.ready,2);
  assert.deepEqual(products,[{name:'Vitamin',price:9000,grams:100},{name:'Kosmetika',price:8000,grams:300}]);
});
