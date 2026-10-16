(function(root){
  'use strict';
  const DEFAULT_WON_PER_KG=10000;
  const WON_PER_GRAM=DEFAULT_WON_PER_KG/1000;
  function amount(value){
    if(value===null || value===undefined || String(value).trim()==='')return null;
    const text=String(value).trim().replace(/[\s₩]/g,'').replace(/,/g,'');
    if(!/^\d+(?:\.\d+)?$/.test(text))return null;
    const number=Number(text);
    return Number.isFinite(number) && number>=0 && number<=1e9 ? number : null;
  }
  function quantity(value){
    // Existing Yordamchi records did not track quantity: one book is their safe default.
    if(value===null||value===undefined||String(value).trim()==='')return 1;
    const text=String(value).trim();
    if(!/^[1-9]\d*$/.test(text))return null;
    const n=Number(text);
    return Number.isSafeInteger(n)&&n<=100000?n:null;
  }
  function rate(value){return amount(value)??DEFAULT_WON_PER_KG;}
  function calculate(row,wonPerKg=DEFAULT_WON_PER_KG){
    const price=amount(row.price),grams=amount(row.grams);
    const shipping=grams===null?null:Math.round(grams*rate(wonPerKg)/1000);
    return {shipping,total:price===null || shipping===null?null:Math.round(price)+shipping};
  }
  function profit(row,wonPerKg=DEFAULT_WON_PER_KG){
    const sale=amount(row.salePrice),total=calculate(row,wonPerKg).total;
    return sale===null || total===null?null:Math.round(sale)-total;
  }
  function inventory(row,wonPerKg=DEFAULT_WON_PER_KG){
    const qty=quantity(row.quantity),unit=calculate(row,wonPerKg);
    const buy=amount(row.price),sale=amount(row.salePrice);
    const multiply=value=>value===null||qty===null?null:Math.round(value*qty);
    return {
      quantity:qty,unitPurchase:buy,unitShipping:unit.shipping,unitCost:unit.total,unitSale:sale,
      purchase:multiply(buy),shipping:multiply(unit.shipping),total:multiply(unit.total),
      revenue:multiply(sale),profit:multiply(profit(row,wonPerKg))
    };
  }
  function summary(rows,wonPerKg=DEFAULT_WON_PER_KG){
    const result={total:0,ready:0,pending:0,profitTotal:0,profitCount:0,
      quantityTotal:0,quantityReady:0,profitUnits:0,purchaseTotal:0,shippingTotal:0,revenueTotal:0};
    for(const row of rows){
      const v=inventory(row,wonPerKg);
      if(v.quantity===null){result.pending++;continue;}
      result.quantityTotal+=v.quantity;
      if(v.total!==null){
        result.total+=v.total;result.ready++;result.quantityReady+=v.quantity;
        result.purchaseTotal+=v.purchase;result.shippingTotal+=v.shipping;
      }else result.pending++;
      if(v.profit!==null){
        result.profitTotal+=v.profit;result.profitCount++;result.profitUnits+=v.quantity;
        result.revenueTotal+=v.revenue;
      }
    }
    return result;
  }
  function normalizeRates(rows,makeId){
    return (Array.isArray(rows)?rows:[]).filter(row=>row && typeof row==='object').map((row,index)=>({id:String(row.id||makeId()),label:String(row.label||'Variant '+(index+2)).slice(0,80),rate:amount(row.rate)}));
  }
  function tariffs(main,extra=[]){
    return [{id:'primary',label:'Asosiy',rate:rate(main)},...extra.filter(row=>amount(row.rate)!==null).map(row=>({...row,rate:amount(row.rate)}))];
  }
  function compare(rows,main,extra=[]){
    return tariffs(main,extra).map(tariff=>{
      const complete=rows.filter(row=>calculate(row,tariff.rate).total!==null);
      return {...tariff,...summary(rows,tariff.rate),shipping:complete.reduce((sum,row)=>sum+inventory(row,tariff.rate).shipping,0)};
    });
  }
  function key(title){return String(title).normalize('NFKC').toLowerCase().replace(/[‘’ʻʼ`]/g,"'").replace(/\s+/g,' ').trim();}
  function parseTitles(text){
    const seen=new Set();
    return String(text).split(/\r?\n|;/).map(line=>line.trim()
      .replace(/^(?:[-*•▪]\s+|\d+[.)]\s+)/,'').trim()).filter(title=>{
        if(!title || seen.has(key(title)))return false;
        seen.add(key(title));return true;
      });
  }
  function normalize(rows,makeId){
    return (Array.isArray(rows)?rows:[]).filter(row=>row && typeof row==='object').map(row=>({
      id:String(row.id||makeId()),title:String(row.title||'').slice(0,300),
      price:amount(row.price),grams:amount(row.grams),salePrice:amount(row.salePrice),quantity:quantity(row.quantity)??1,
      ...(typeof row.muhajeerId==='string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(row.muhajeerId)?{muhajeerId:row.muhajeerId,muhajeerTitle:String(row.muhajeerTitle||'').slice(0,300),muhajeerCost:amount(row.muhajeerCost)}:{}),
      saved:typeof row.saved==='boolean'?row.saved:Boolean(String(row.title||'').trim() && calculate(row).total!==null)
    }));
  }
  const api={DEFAULT_WON_PER_KG,WON_PER_GRAM,rate,amount,quantity,calculate,profit,inventory,summary,key,parseTitles,normalize,normalizeRates,tariffs,compare};
  if(typeof module==='object' && module.exports)module.exports=api;
  else root.BookCosts=api;
})(typeof globalThis==='object'?globalThis:this);
