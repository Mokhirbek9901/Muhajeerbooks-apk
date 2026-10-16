'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const edit=require('../personal-assistant/currency-rate-editor.js');
const conversion=require('../personal-assistant/currency-converter.js');
const near=(actual,expected)=>assert.ok(Math.abs(actual-expected)<Math.max(0.00000001,Math.abs(expected)*1e-8),actual+' != '+expected);
test('saved rates support Dollar -> Von and Von -> Som',()=>{
  const s=edit.solve([{from:'USD',to:'KRW',value:2000},{from:'KRW',to:'UZS',value:80000}],{});
  near(s.krwPerUsd,2000);near(s.krwToUzsPer1000,8000);
  assert.equal(conversion.convert(10000,'KRW','UZS',s.krwToUzsPer1000,s.krwPerUsd),80000);
  assert.equal(conversion.convert(1,'USD','UZS',s.krwToUzsPer1000,s.krwPerUsd),16000);
});
test('Som -> Von accepts a decimal quote for exactly one Som',()=>{
  const s=edit.solve([{from:'UZS',to:'KRW',value:0.125},{from:'USD',to:'KRW',value:2000}],{});
  near(s.krwToUzsPer1000,8000);near(s.krwPerUsd,2000);
});
test('Dollar -> Som combined with Von -> Som calculates dollar-won',()=>{
  const s=edit.solve([{from:'USD',to:'UZS',value:16000},{from:'KRW',to:'UZS',value:80000}],{});
  near(s.krwPerUsd,2000);near(s.krwToUzsPer1000,8000);
});
test('Von -> Dollar works with reciprocal small values',()=>{
  const s=edit.solve([{from:'KRW',to:'USD',value:5},{from:'KRW',to:'UZS',value:80000}],{});
  near(s.krwPerUsd,2000);near(s.krwToUzsPer1000,8000);
});
test('Som -> Dollar and Dollar -> Von calculate won-som cross rate',()=>{
  const s=edit.solve([{from:'UZS',to:'USD',value:0.0000625},{from:'USD',to:'KRW',value:2000}],{});
  near(s.krwPerUsd,2000);near(s.krwToUzsPer1000,8000);
});
test('changing one rate preserves the previous independent rate',()=>{
  const previous={krwToUzsPer1000:8000,krwPerUsd:2000};
  const changed=edit.solve([{from:'USD',to:'KRW',value:2500},{from:'KRW',to:'UZS',value:''}],previous);
  near(changed.krwPerUsd,2500);near(changed.krwToUzsPer1000,8000);
});
test('computed values do not round before reverse rate editing',()=>{
  const state={krwToUzsPer1000:8500,krwPerUsd:1400};
  near(edit.rawValue('UZS','KRW',state),1000/8500);
  near(edit.rawValue('KRW','USD',state),10000/1400);
  near(edit.rawValue('USD','UZS',state),1400*8.5);
});
test('reject two ambiguous copies of the same currency relationship',()=>{
  assert.throws(()=>edit.solve([{from:'KRW',to:'UZS',value:80000},{from:'UZS',to:'KRW',value:0.125}],{}),/bir xil/);
});
test('reject wrong same-currency pairs and zero',()=>{
  assert.throws(()=>edit.solve([{from:'USD',to:'USD',value:1}],{}),/ikki xil/i);
  assert.throws(()=>edit.solve([{from:'USD',to:'KRW',value:0}],{}),/to‘g‘ri/i);
});
test('old app backups retain the default currency pair options',()=>{
  assert.deepEqual(edit.normalized(null),[{from:'KRW',to:'UZS'},{from:'USD',to:'KRW'}]);
  assert.deepEqual(edit.normalized([{from:'UZS',to:'USD'},{from:'KRW',to:'USD'}]),[{from:'UZS',to:'USD'},{from:'KRW',to:'USD'}]);
});
test('only Dollar -> Som without any anchor is rejected until another rate is entered',()=>{
  assert.throws(()=>edit.solve([{from:'USD',to:'UZS',value:16000}],{}),/yana/);
});

test('displaying a 10,000 won manual quote does not change the legacy saved 1,000-won rate',()=>{
  const old={krwToUzsPer1000:8000,krwPerUsd:2000};
  assert.equal(edit.base('KRW'),10000);
  assert.equal(edit.base('UZS'),1);
  assert.equal(edit.rawValue('KRW','UZS',old),80000);
  assert.equal(conversion.convert(1000,'KRW','UZS',old.krwToUzsPer1000,old.krwPerUsd),8000);
  assert.equal(conversion.convert(13000,'KRW','UZS',old.krwToUzsPer1000,old.krwPerUsd),104000);
  const saved=edit.solve([{from:'KRW',to:'UZS',value:80000}],old);
  assert.equal(saved.krwToUzsPer1000,8000);
  assert.equal(saved.krwPerUsd,2000);
});
test('10,000-won base yields consistent KRW reverse and USD rates',()=>{
  const old={krwToUzsPer1000:8000,krwPerUsd:2000};
  assert.equal(edit.rawValue('UZS','KRW',old),0.125);
  assert.equal(edit.rawValue('KRW','USD',old),5);
  assert.deepEqual(edit.solve([{from:'UZS',to:'KRW',value:0.125},{from:'USD',to:'KRW',value:2000}],old),old);
});

test('decimal 1 so‘m = 0.11 ₩ converts precisely without premature rounding',()=>{
  const old={krwToUzsPer1000:8000,krwPerUsd:2000};
  const saved=edit.solve([{from:'UZS',to:'KRW',value:'0.11'}],old);
  near(saved.krwToUzsPer1000,1000/0.11);
  assert.equal(saved.krwPerUsd,2000);
  near(edit.rawValue('UZS','KRW',saved),0.11);
  near(edit.rawValue('KRW','UZS',saved),10000/0.11);
  assert.equal(conversion.convert(1000,'KRW','UZS',saved.krwToUzsPer1000,saved.krwPerUsd),9091);
  assert.equal(conversion.convert(13000,'KRW','UZS',saved.krwToUzsPer1000,saved.krwPerUsd),118182);
  const reciprocal=edit.solve([{from:'KRW',to:'UZS',value:String(10000/0.11)}],old);
  near(reciprocal.krwToUzsPer1000,saved.krwToUzsPer1000);
});
test('more precise 1 som quote survives saving and loading',()=>{
  const saved=edit.solve([{from:'UZS',to:'KRW',value:'0.123456789'}],{krwToUzsPer1000:8000});
  near(edit.rawValue('UZS','KRW',saved),0.123456789);
  assert.equal(edit.base('UZS'),1);
});
