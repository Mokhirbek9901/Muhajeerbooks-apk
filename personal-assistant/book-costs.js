(function(root){
  'use strict';
  const currency=typeof module==='object'&&module.exports?require('./currency-converter.js'):root.YordamchiCurrency;
  const DEFAULT_WON_PER_KG=10000;
  const WON_PER_GRAM=DEFAULT_WON_PER_KG/1000;
  function amount(value){
    const number=currency.amount(value);
    return number!==null&&number<=1e9?number:null;
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
    const shipping=grams===null?null:currency.ratio([grams,rate(wonPerKg)],[1000]);
    return {shipping,total:price===null || shipping===null?null:currency.add(price,shipping)};
  }
  function profit(row,wonPerKg=DEFAULT_WON_PER_KG){
    const sale=amount(row.salePrice),total=calculate(row,wonPerKg).total;
    return sale===null || total===null?null:currency.add(sale,-total);
  }
  // Batches contain new arrivals only. The legacy row keeps the old batch intact.
  function extraQuantity(row){
    return (Array.isArray(row.batches)?row.batches:[]).reduce((sum,b)=>sum+(quantity(b.quantity)??0),0);
  }
  function baseQuantity(row){const total=quantity(row.quantity);return total===null?null:total-extraQuantity(row);}
  function inventory(row,wonPerKg=DEFAULT_WON_PER_KG){
    const qty=quantity(row.quantity),original=baseQuantity(row),sale=amount(row.salePrice),unit=calculate(row,wonPerKg);
    const parts=[{...row,quantity:original,rate:wonPerKg},
      ...(Array.isArray(row.batches)?row.batches:[]).map(batch=>({...batch,salePrice:row.salePrice,rate:rate(batch.rate??wonPerKg)}))];
    let readyQuantity=0,pendingQuantity=0,knownPurchase=0,knownShipping=0,knownTotal=0,knownRevenue=0,knownProfit=0,profitUnits=0;
    let allPurchase=true,allShipping=true,allTotal=true,allProfit=true;
    for(const part of parts){
      const n=part.quantity===null?null:Number(part.quantity);
      if(n===null||!Number.isInteger(n)||n<0){allPurchase=false;allShipping=false;allTotal=false;allProfit=false;continue;}
      if(n===0)continue;
      const calculated=calculate(part,part.rate),buy=amount(part.price);
      if(buy===null)allPurchase=false;else if(calculated.total!==null)knownPurchase=currency.add(knownPurchase,currency.ratio([buy,n]));
      if(calculated.shipping===null)allShipping=false;else if(calculated.total!==null)knownShipping=currency.add(knownShipping,currency.ratio([calculated.shipping,n]));
      if(calculated.total===null){allTotal=false;allProfit=false;pendingQuantity+=n;continue;}
      readyQuantity+=n;
      knownTotal=currency.add(knownTotal,currency.ratio([calculated.total,n]));
      if(sale===null){allProfit=false;continue;}
      profitUnits+=n;
      knownRevenue=currency.add(knownRevenue,currency.ratio([sale,n]));
      knownProfit=currency.add(knownProfit,currency.ratio([currency.add(sale,-calculated.total),n]));
    }
    const valid=qty!==null&&original!==null&&original>=0&&readyQuantity+pendingQuantity===qty;
    return {
      quantity:qty,unitPurchase:amount(row.price),unitShipping:unit.shipping,unitCost:unit.total,unitSale:sale,
      readyQuantity,pendingQuantity,profitUnits,
      knownPurchase,knownShipping,knownTotal,knownRevenue,knownProfit,
      purchase:valid&&allPurchase?knownPurchase:null,
      shipping:valid&&allShipping?knownShipping:null,
      total:valid&&allTotal?knownTotal:null,
      revenue:valid&&allProfit?knownRevenue:null,
      profit:valid&&allProfit?knownProfit:null
    };
  }
  function summary(rows,wonPerKg=DEFAULT_WON_PER_KG){
    const result={total:0,ready:0,pending:0,profitTotal:0,profitCount:0,
      quantityTotal:0,quantityReady:0,profitUnits:0,purchaseTotal:0,shippingTotal:0,revenueTotal:0};
    for(const row of rows){
      const v=inventory(row,wonPerKg);
      if(v.quantity===null){result.pending++;continue;}
      result.quantityTotal+=v.quantity;
      if(v.readyQuantity>0){
        result.total=currency.add(result.total,v.knownTotal);result.ready++;result.quantityReady+=v.readyQuantity;
        result.purchaseTotal=currency.add(result.purchaseTotal,v.knownPurchase);
        result.shippingTotal=currency.add(result.shippingTotal,v.knownShipping);
      }
      if(v.pendingQuantity>0)result.pending++;
      if(v.profitUnits>0){
        result.profitTotal=currency.add(result.profitTotal,v.knownProfit);result.profitCount++;result.profitUnits+=v.profitUnits;
        result.revenueTotal=currency.add(result.revenueTotal,v.knownRevenue);
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
      return {...tariff,...summary(rows,tariff.rate),shipping:complete.reduce((sum,row)=>currency.add(sum,inventory(row,tariff.rate).shipping),0)};
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
  function parseTitleEntries(text){
    const entries=[],seen=new Map(),invalid=[];
    for(const line of String(text).split(/\r?\n|;/)){
      const cleaned=line.trim().replace(/^(?:[-*•▪]\s+|\d+[.)]\s+)/,'').trim();
      if(!cleaned)continue;
      // Only explicit "3 ta" / "3 dona" marks a quantity; book titles ending in numbers stay intact.
      const match=cleaned.match(/^(.*?)\s*(?:[-–—:]\s*)?\(?(\d+)\s*(?:ta|dona)\)?\s*$/i);
      const hasQuantity=Boolean(match&&match[1].trim());
      const title=hasQuantity?match[1].trim():cleaned;
      const count=hasQuantity?quantity(match[2]):1;
      if(count===null){invalid.push(cleaned);continue;}
      const normalized=key(title);
      if(seen.has(normalized)){
        const previous=entries[seen.get(normalized)];
        if(previous.quantity+count>100000){invalid.push(cleaned);continue;}
        previous.quantity+=count;
      }else{
        seen.set(normalized,entries.length);
        entries.push({title,quantity:count});
      }
    }
    return {entries,invalid};
  }
  function normalize(rows,makeId){
    return (Array.isArray(rows)?rows:[]).filter(row=>row && typeof row==='object').map(row=>{
      const total=quantity(row.quantity)??1;
      const batches=(Array.isArray(row.batches)?row.batches:[]).filter(b=>b&&typeof b==='object')
        .map(b=>({id:String(b.id||makeId()),date:/^\d{4}-\d{2}-\d{2}$/.test(b.date||'')?b.date:'',
          quantity:quantity(b.quantity),price:amount(b.price),grams:amount(b.grams),rate:amount(b.rate)}))
        .filter(b=>b.quantity!==null);
      let sum=0;const safeBatches=batches.filter(b=>{if(sum+b.quantity>=total)return false;sum+=b.quantity;return true;});
      return {
      id:String(row.id||makeId()),title:String(row.title||'').slice(0,300),
      price:amount(row.price),grams:amount(row.grams),salePrice:amount(row.salePrice),quantity:total,
      ...(safeBatches.length?{batches:safeBatches}:{}),
      ...(typeof row.muhajeerId==='string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(row.muhajeerId)?{muhajeerId:row.muhajeerId,muhajeerTitle:String(row.muhajeerTitle||'').slice(0,300),muhajeerCost:amount(row.muhajeerCost)}:{}),
      saved:typeof row.saved==='boolean'?row.saved:Boolean(String(row.title||'').trim() && calculate(row).total!==null)
    };
    });
  }
  const api={DEFAULT_WON_PER_KG,WON_PER_GRAM,rate,amount,quantity,calculate,profit,inventory,summary,key,parseTitles,parseTitleEntries,extraQuantity,baseQuantity,normalize,normalizeRates,tariffs,compare};
  if(typeof module==='object' && module.exports)module.exports=api;
  else root.BookCosts=api;
})(typeof globalThis==='object'?globalThis:this);
