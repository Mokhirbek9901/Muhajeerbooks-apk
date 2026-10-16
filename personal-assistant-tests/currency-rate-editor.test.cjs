'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const edit=require('../personal-assistant/currency-rate-editor.js');
const conversion=require('../personal-assistant/currency-converter.js');
const near=(actual,expected)=>assert.ok(Math.abs(actual-expected)<Math.max(0.00000001,Math.abs(expected)*1e-8),actual+' != '+expected);
test('saved rates support Dollar -> Von and Von -> Som',()=>{
  const s=edit.solve([{from:'USD',to:'KRW',value:2000},{from:'KRW',to:'UZS',value:8000}],{});
  near(s.krwPerUsd,2000);near(s.krwToUzsPer1000,8000);
  assert.equal(conversion.convert(10000,'KRW','UZS',s.krwToUzsPer1000,s.krwPerUsd),80000);
  assert.equal(conversion.convert(1,'USD','UZS',s.krwToUzsPer1000,s.krwPerUsd),16000);
});
test('Som -> Von reverses the 1000 Som rate',()=>{
  const s=edit.solve([{from:'UZS',to:'KRW',value:125},{from:'USD',to:'KRW',value:2000}],{});
  near(s.krwToUzsPer1000,8000);near(s.krwPerUsd,2000);
});
test('Dollar -> Som combined with Von -> Som calculates dollar-won',()=>{
  const s=edit.solve([{from:'USD',to:'UZS',value:16000},{from:'KRW',to:'UZS',value:8000}],{});
  near(s.krwPerUsd,2000);near(s.krwToUzsPer1000,8000);
});
test('Von -> Dollar works with reciprocal small values',()=>{
  const s=edit.solve([{from:'KRW',to:'USD',value:0.5},{from:'KRW',to:'UZS',value:8000}],{});
  near(s.krwPerUsd,2000);near(s.krwToUzsPer1000,8000);
});
test('Som -> Dollar and Dollar -> Von calculate won-som cross rate',()=>{
  const s=edit.solve([{from:'UZS',to:'USD',value:0.0625},{from:'USD',to:'KRW',value:2000}],{});
  near(s.krwPerUsd,2000);near(s.krwToUzsPer1000,8000);
});
test('changing one rate preserves the previous independent rate',()=>{
  const previous={krwToUzsPer1000:8000,krwPerUsd:2000};
  const changed=edit.solve([{from:'USD',to:'KRW',value:2500},{from:'KRW',to:'UZS',value:''}],previous);
  near(changed.krwPerUsd,2500);near(changed.krwToUzsPer1000,8000);
});
test('computed values do not round before reverse rate editing',()=>{
  const state={krwToUzsPer1000:8500,krwPerUsd:1400};
  near(edit.rawValue('UZS','KRW',state),1000*1000/8500);
  near(edit.rawValue('KRW','USD',state),1000/1400);
  near(edit.rawValue('USD','UZS',state),1400*8.5);
});
test('reject two ambiguous copies of the same currency relationship',()=>{
  assert.throws(()=>edit.solve([{from:'KRW',to:'UZS',value:8000},{from:'UZS',to:'KRW',value:125}],{}),/bir xil/);
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
