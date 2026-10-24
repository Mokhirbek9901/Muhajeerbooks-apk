(function(root,factory){
'use strict';
const api=factory(typeof module==='object'&&module.exports?require('./decimal-fx.js'):root.YordamchiDecimalFX);
if(typeof module==='object'&&module.exports)module.exports=api;else root.BookCostSimple=api;
})(typeof globalThis==='object'?globalThis:this,function(precise){
'use strict';
function bookFx(state){
 const rate=precise.rates(state).krwToUzsPer1000;
 if(!rate)return null;
 const number=precise.number(rate);
 return Number.isFinite(number)&&number>0&&number<100?precise.multiply(rate,'1000'):rate;
}
function normalizedPrice(value,storedWon=null,fromInput=false){
 const price=precise.valid(value);
 if(!price)return null;
 const number=precise.number(price);
 if(number>0&&number<1000&&(fromInput||Number(storedWon)>1000))return precise.multiply(price,'1000');
 return price;
}
function wonFromUzs(state,value){
 const rate=bookFx(state),price=precise.valid(value);
 return rate&&price?precise.divide(precise.multiply(price,'1000'),rate):null;
}
function uzsFromWon(state,value){
 const rate=bookFx(state),amount=precise.valid(value);
 return rate&&amount?precise.divide(precise.multiply(amount,rate),'1000'):null;
}
function formatUzs(value){
 if(value===null||value===undefined)return '—';
 const n=typeof value==='object'?precise.number(value):Number(value);
 return Number.isFinite(n)?Math.round(n).toLocaleString('en-US')+' so‘m':'—';
}
return {bookFx,normalizedPrice,wonFromUzs,uzsFromWon,formatUzs};
});