'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const exchange=require('../personal-assistant/currency-converter.js');
const bookCosts=require('../personal-assistant/book-costs.js');

test('von ⇄ so‘m swaps both directions',()=>{
  assert.equal(exchange.convert(10000,'KRW','UZS',8500,1400),85000);
  assert.equal(exchange.convert(85000,'UZS','KRW',8500,1400),10000);
  assert.equal(exchange.convert(100000,'UZS','KRW',8500,1400),11765);
});
test('all six directed currency pairs work with the same saved rates',()=>{
  assert.equal(exchange.convert(10,'USD','KRW',8500,1400),14000);
  assert.equal(exchange.convert(14000,'KRW','USD',8500,1400),10);
  assert.equal(exchange.convert(10,'USD','UZS',8500,1400),119000);
  assert.equal(exchange.convert(119000,'UZS','USD',8500,1400),10);
  assert.equal(exchange.convert(1000,'KRW','UZS',8500,1400),8500);
  assert.equal(exchange.convert(8500,'UZS','KRW',8500,1400),1000);
});
test('missing exchange rates never silently use invented rates',()=>{
  assert.equal(exchange.convert(1000,'KRW','UZS',null,1400),null);
  assert.equal(exchange.convert(1000,'KRW','USD',8500,null),null);
  assert.equal(exchange.convert(1000,'UZS','USD',8500,null),null);
  assert.equal(exchange.convert(1000,'USD','UZS',null,1400),null);
  assert.equal(exchange.convert(1000,'KRW','KRW',null,null),1000);
  assert.equal(exchange.rate(0),null);
  assert.equal(exchange.rate(-100),null);
  assert.equal(exchange.convert('','KRW','UZS',8500,1400),null);
});
test('USD displays two decimals and won / so‘m whole amounts',()=>{
  assert.equal(exchange.convert(10000,'KRW','USD',8500,1400),7.14);
  assert.equal(exchange.display(7.14,'USD'),'$7.14');
  assert.equal(exchange.display(10000,'KRW'),'₩10,000');
  assert.equal(exchange.display(85000,'UZS'),'85,000 so‘m');
});
test('existing book and Korea shipping costs remain stored in won',()=>{
  const sample={price:6600,grams:290,salePrice:15000};
  const won=bookCosts.calculate(sample,7000);
  assert.equal(won.shipping,2030);
  assert.equal(won.total,8630);
  assert.equal(exchange.convert(won.total,'KRW','UZS',8500,1400),73355);
  assert.equal(exchange.convert(won.total,'KRW','USD',8500,1400),6.16);
});

test('8.841492544 fractional rates are not rounded inside calculator',()=>{
  const saved=8841.492544; // 1 KRW = 8.841492544 so‘m
  assert.equal(exchange.rate(saved),saved);
  assert.ok(Math.abs(exchange.convertExact(1,'KRW','UZS',saved,null)-8.841492544)<1e-11);
  assert.equal(exchange.displayExact(8.841492544,'UZS'),'8.841492544 so‘m');
  assert.equal(exchange.convert(1,'KRW','UZS',saved,null),9,'book totals remain whole');
  assert.equal(exchange.displayExact(exchange.convertExact(100000,'KRW','UZS',saved,null),'UZS'),'884,149.2544 so‘m');
  assert.equal(exchange.amount('8.841492544'),8.841492544);
  assert.equal(exchange.amount('0,11'),0.11);
  assert.equal(exchange.amount('8,000'),8000);
  assert.equal(exchange.amount('8,00,00'),null);
  assert.equal(exchange.convertExact('', 'KRW','UZS',saved,null),null);
});
test('accurate reciprocal values and 9-plus digits are shown when swapping currencies',()=>{
 const saved=8841.492544;
 const value=exchange.convertExact(1,'UZS','KRW',saved,null);
 assert.ok(Math.abs(value-(1/8.841492544))<1e-14);
 assert.ok(exchange.displayExact(value,'KRW').includes('.'));
 assert.equal(exchange.displayExact(exchange.convertExact(13000,'KRW','UZS',saved,null),'UZS'),'114,939.403072 so‘m');
});
