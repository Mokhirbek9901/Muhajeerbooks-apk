'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const migration=require('../personal-assistant/backup-migration.js');
function payload(){
  return {app:'Bek Shaxsiy Yordamchi',data:{
    books:[{id:'b1',title:'A',readingLog:[{date:'2026-10-16',page:9}]}],
    bookCosts:[{id:'c1',title:'A',price:10000,grams:250,saved:true}],
    transactions:[{id:'t1',amount:12000,currency:'KRW'}],
    koreaProducts:[{id:'k1',name:'Jenshen',price:15000,grams:30}],
    profile:{name:'Test'}
  }};
}
test('full backup inventory includes books, reading days, costs, finance and products',()=>{
  const report=migration.inspect(payload());
  assert.deepEqual(report.counts,{books:1,readingRecords:1,bookCosts:1,transactions:1,products:1});
  assert.match(migration.describe(report.counts),/1 ta mutolaa qaydi/);
});
test('reject unrelated product backup and incomplete file',()=>{
  assert.throws(()=>migration.inspect({app:'Some App',data:payload().data}),/Yordamchi/);
  assert.throws(()=>migration.inspect({data:{books:[],transactions:[]}}),/To‘liq/);
  assert.throws(()=>migration.inspect({data:{books:[null],bookCosts:[],transactions:[]}}),/buzilgan/);
});
test('refuse an import if the normalization drops any records',()=>{
  const counts=migration.inspect(payload()).counts;
  assert.throws(()=>migration.assertNotLost(counts,{books:[],bookCosts:[],transactions:[],koreaProducts:[]}),/kamaymoqda/);
  assert.deepEqual(migration.assertNotLost(counts,payload().data),counts);
});
test('empty, valid Yordamchi backup can be loaded with explicit confirmation',()=>{
  const result=migration.inspect({app:'Bek Shaxsiy Yordamchi',data:{books:[],bookCosts:[],transactions:[]}});
  assert.equal(result.counts.books,0);
});
