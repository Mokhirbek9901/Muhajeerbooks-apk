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

test('shipping is proportional to product grams and shares the book per-kg rate',()=>{
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
