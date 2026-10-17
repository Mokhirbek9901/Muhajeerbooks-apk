'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fx=require('../personal-assistant/currency-converter.js');
const editor=require('../personal-assistant/currency-rate-editor.js');
const books=require('../personal-assistant/book-costs.js');
const products=require('../personal-assistant/korea-products.js');
const near=(a,b)=>assert.ok(Math.abs(a-b)<=Math.max(1e-12,Math.abs(b)*Number.EPSILON*4),`${a} != ${b}`);

test('all requested long decimal quotes survive JSON and return to the same input',()=>{
 for(const [direction,quote] of [['KRW_UZS','8.841492544'],['UZS_KRW','0.1131004219'],['UZS_KRW','0.125']]){
  const saved=JSON.parse(JSON.stringify({krwToUzsPer1000:editor.bookRateFromAmounts(direction,1,quote)}));
  assert.equal(editor.showNumber(editor.bookRateQuote(direction,1,saved.krwToUzsPer1000)),quote);
 }
});
test('arbitrary grouped source and target amounts work identically in both editors',()=>{
 const rate=editor.bookRateFromAmounts('KRW_UZS','100 000','884 149.2544');
 assert.equal(rate,8841.492544);
 const state=editor.solve([{from:'KRW',to:'UZS',sourceAmount:'100 000',value:'884 149.2544'}],{});
 assert.equal(state.krwToUzsPer1000,rate);
 assert.equal(editor.rawValue('KRW','UZS',state,100000),884149.2544);
 const inverse=editor.solve([{from:'UZS',to:'KRW',sourceAmount:'884 149.2544',value:'100 000'}],state);
 assert.equal(inverse.krwToUzsPer1000,rate);
 assert.equal(editor.normalized([{from:'KRW',to:'UZS',sourceAmount:'100 000'}])[0].sourceAmount,100000);
});
test('decimal comma from a phone and decimal point share the same parser',()=>{
 for(const module of [fx,books,products]){
  assert.equal(module.amount('0,125'),0.125);
  assert.equal(module.amount('0,1131004219'),0.1131004219);
  assert.equal(module.amount('13,000'),13000);
  assert.equal(module.amount('.125'),0.125);
  assert.equal(module.amount('1.2.3'),null);
 }
 assert.equal(editor.bookRateFromAmounts('UZS_KRW',1,'0,125'),8000);
});
test('fractional shipping, quantity totals, profit and statistics are never rounded between steps',()=>{
 const row={price:100.125,grams:0.125,salePrice:200.5,quantity:8};
 const unit=books.calculate(row,10000.125);
 assert.equal(unit.shipping,1.250015625);
 assert.equal(unit.total,101.375015625);
 const inventory=books.inventory(row,10000.125);
 assert.equal(inventory.total,811.000125);
 assert.equal(inventory.profit,792.999875);
 const summary=books.summary([row,row],10000.125);
 assert.equal(summary.total,1622.00025);
 assert.equal(summary.profitTotal,1585.99975);
});
test('new common FX recalculates each item tariff and totals without mutating any stored record',()=>{
 const items=[{id:'a',name:'A',price:100.125,grams:0.125,kgRate:10000.125},
 {id:'b',name:'B',price:5.25,grams:0.5,kgRate:5000.25}];
 const stored=JSON.stringify(items);
 const a=products.summarize(items,10000,8000);
 const b=products.summarize(items,10000,8841.492544);
 assert.equal(a.total,b.total);
 assert.equal(b.shipping,3.750140625);
 assert.equal(b.total,109.125140625);
 near(b.totalSom,964.829117198889);
 assert.notEqual(a.totalSom,b.totalSom);
 near(products.wonAsRate(items[0].kgRate,'UZS',8841.492544),88416.030626568);
 assert.equal(JSON.stringify(items),stored);
});
test('conversion swaps retain fractional economic value through repeated swaps',()=>{
 let amount=0.125,from='UZS',to='KRW';
 const rate=editor.bookRateFromAmounts('UZS_KRW',1,'0.1131004219');
 for(let i=0;i<20;i++){
  amount=fx.convertExact(amount,from,to,rate,null);[from,to]=[to,from];
 }
 near(amount,0.125);
 assert.equal(fx.add(0.1,0.2),0.3);
 assert.equal(fx.ratio([8.841492544,1000]),8841.492544);
});

const exact=fx.precise;
test('finite FX quotes preserve nine, twenty, one hundred and five hundred decimal places',()=>{
 for(const digits of [9,20,100,500]){
  const quote='8.'+'1234567890'.repeat(Math.ceil(digits/10)).slice(0,digits-1)+'7';
  const saved=editor.bookRateExact('KRW_UZS','1',quote);
  const state=JSON.parse(JSON.stringify({preciseExchangeRates:{krwToUzsPer1000:saved}}));
  assert.equal(exact.text(exact.convert(1,'KRW','UZS',state)),quote);
  assert.equal(exact.display(exact.convert(1,'KRW','UZS',state),'UZS'),quote+' so‘m');
  assert.equal(exact.text(editor.quoteExact('KRW','UZS',state,1)),quote);
 }
});
test('long reciprocal quotes survive save/reload, both editors and exact currency swaps',()=>{
 const quote='0.113100421912345678901234567890123456789';
 const rate=editor.bookRateExact('UZS_KRW','1',quote);
 const state=JSON.parse(JSON.stringify({preciseExchangeRates:{krwToUzsPer1000:rate}}));
 assert.equal(exact.text(exact.convert('1','UZS','KRW',state)),quote);
 let value=exact.read('1'),from='UZS',to='KRW';
 for(let i=0;i<100;i++){value=exact.convert(value,from,to,state);[from,to]=[to,from];}
 assert.equal(exact.text(value),'1');
 const solved=editor.solveExact([{from:'UZS',to:'KRW',sourceAmount:'1',value:quote}],{});
 assert.deepEqual(solved.preciseExchangeRates.krwToUzsPer1000,rate);
 assert.equal(exact.text(editor.quoteExact('UZS','KRW',solved,1)),quote);
});
test('arbitrary source and target fractions never round through Number',()=>{
 const source='100000.12345678901234567890123456789';
 const target='884149.25441234567890123456789';
 const state=editor.solveExact([{from:'KRW',to:'UZS',sourceAmount:source,value:target}],{});
 assert.equal(exact.text(exact.convert(source,'KRW','UZS',state)),target);
 const swapped=editor.solveExact([{from:'UZS',to:'KRW',sourceAmount:target,value:source}],{});
 assert.deepEqual(swapped.preciseExchangeRates,state.preciseExchangeRates);
});
test('recurring on-screen decimals retain the exact fraction when left unedited',()=>{
 const el={value:'',dataset:{}};
 exact.fill(el,exact.divide(1,3));
 assert.equal(el.value,'0.'+'3'.repeat(40));
 assert.equal(exact.text(exact.multiply(exact.input(el),3)),'1');
 el.value='0.333333333';
 assert.equal(exact.text(exact.multiply(exact.input(el),3)),'0.999999999');
});
test('old numeric rates remain available and malformed exact metadata never drops legacy values',()=>{
 assert.equal(exact.text(exact.convert(1,'KRW','UZS',{krwToUzsPer1000:8841.492544})),'8.841492544');
 assert.equal(exact.text(exact.rates({krwToUzsPer1000:8000,preciseExchangeRates:{krwToUzsPer1000:{n:'oops',d:'0'}}}).krwToUzsPer1000),'8000');
 assert.equal(exact.valid({n:'1',d:'0'}),null);
 assert.equal(exact.read('8.1234567890123456789').n,'81234567890123456789');
});
test('the ninth decimal digit is kept even when it is a trailing zero',()=>{
 const quote='8.123456780',input={value:'',dataset:{}};
 exact.fill(input,exact.read(quote),quote);
 assert.equal(input.value,quote);
 assert.deepEqual(editor.normalizeBookInput({direction:'KRW_UZS',sourceText:'1',targetText:quote}),{direction:'KRW_UZS',sourceText:'1',targetText:quote});
 const pair=editor.normalized([{from:'KRW',to:'UZS',sourceAmount:'1',value:quote}])[0];
 assert.equal(pair.quoteText,quote);
});
