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
  // Original Uzbek purchase price, when supplied, is kept for historical display.
  // Converted KRW price stays fixed so later exchange-rate changes do not rewrite deliveries.
  function uzsText(value){const valueText=currency.precise.text(currency.precise.valid(value,'1000000000000000'));return valueText||null;}
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
  // Sum of all arrivals stays on a single catalog record.
  // Individual parts retain the quantity from each delivery.
  function arrivalParts(row){
    const first=baseQuantity(row);
    const parts=[];
    if(first!==null&&first>0)parts.push({id:row.originBatchId||'legacy-original',date:row.originBatchDate||'',quantity:first,price:row.price,grams:row.grams,rate:row.originRate??null,priceUzs:row.priceUzs??null});
    for(const batch of Array.isArray(row.batches)?row.batches:[]){
      const n=quantity(batch.quantity);
      if(n!==null&&n>0)parts.push({id:batch.groupId||batch.id,date:batch.date||'',quantity:n,price:batch.price,grams:batch.grams,rate:batch.rate??null,priceUzs:batch.priceUzs??null});
    }
    return parts;
  }
  function inventory(row,wonPerKg=DEFAULT_WON_PER_KG){
    const qty=quantity(row.quantity),original=baseQuantity(row),sale=amount(row.salePrice),unit=calculate(row,rate(row.originRate??row.rate??wonPerKg));
    const parts=[{...row,quantity:original,rate:rate(row.originRate??row.rate??wonPerKg)},
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
  // Each import has one groupId shared across every book in that delivery.
  // Older records have no group identifier: keep them in an explicitly unassigned archive,
  // rather than guessing a grouping from dates that may contain multiple imports.
  function groupByBatch(rows,wonPerKg=DEFAULT_WON_PER_KG){
    const groups=new Map();
    function push(id,date,legacy,row,quantityValue,price,grams,shippingRate,priceUzs){
      const n=quantity(quantityValue);
      if(n===null||n<1)return;
      let group=groups.get(id);
      if(!group){
        group={id,date:date||'',legacy,rows:[],titles:new Set()};
        groups.set(id,group);
      }
      group.titles.add(key(row.title));
      group.rows.push({
        id:row.id,title:row.title,quantity:n,price,grams,priceUzs:priceUzs??null,
        salePrice:row.salePrice,
        ...(shippingRate!==null&&shippingRate!==undefined?{rate:shippingRate}:{})
      });
    }
    for(const row of Array.isArray(rows)?rows:[]){
      if(!row||!String(row.title||'').trim())continue;
      const original=baseQuantity(row);
      if(original!==null&&original>0){
        const known=typeof row.originBatchId==='string'&&row.originBatchId.trim();
        push(known?'partiya:'+row.originBatchId:'legacy',row.originBatchDate||'',!known,
          row,original,row.price,row.grams,row.originRate??null,row.priceUzs);
      }
      for(const batch of Array.isArray(row.batches)?row.batches:[]){
        const known=typeof batch.groupId==='string'&&batch.groupId.trim();
        push(known?'partiya:'+batch.groupId:'legacy',batch.date||'',!known,
          row,batch.quantity,batch.price,batch.grams,batch.rate,batch.priceUzs);
      }
    }
    return [...groups.values()]
      .sort((a,b)=>a.legacy-b.legacy || b.date.localeCompare(a.date) || a.id.localeCompare(b.id))
      .map((g,index)=>{
        const totals=summary(g.rows,wonPerKg);
        return {id:g.id,date:g.date,legacy:g.legacy,
          label:g.legacy?'Eski qaydlar · partiyasi belgilanmagan':
            'Partiya · '+(g.date||'Sana yo‘q')+' · '+g.id.slice(-6),
          rows:g.rows,bookCount:g.titles.size,totals};
      });
  }
  // Lock the currently stored tariff onto historical arrivals that lack snapshots.
  // Never infer a batch ID from title/date: unassigned history remains unassigned.
  function freezeHistoricalRates(rows,storedRate=DEFAULT_WON_PER_KG){
    const snapshot=rate(storedRate);
    return (Array.isArray(rows)?rows:[]).map(row=>({
      ...row,
      ...(amount(row.originRate??row.rate)===null?{originRate:snapshot}:{}),
      ...(Array.isArray(row.batches)?{
        batches:row.batches.map(batch=>({
          ...batch,
          ...(amount(batch.rate)===null?{rate:snapshot}:{})
        }))
      }:{})
    }));
  }
  function normalizeRates(rows,makeId){
    return (Array.isArray(rows)?rows:[]).filter(row=>row && typeof row==='object').map((row,index)=>({id:String(row.id||makeId()),label:String(row.label||'Variant '+(index+2)).slice(0,80),rate:amount(row.rate)}));
  }
  function tariffs(main,extra=[]){
    return [{id:'primary',label:'Asosiy',rate:rate(main)},...extra.filter(row=>amount(row.rate)!==null).map(row=>({...row,rate:amount(row.rate)}))];
  }
  function compare(rows,main,extra=[]){
    return tariffs(main,extra).map(tariff=>{
      const complete=rows.filter(row=>inventory(row,tariff.rate).readyQuantity>0);
      return {...tariff,...summary(rows,tariff.rate),shipping:complete.reduce((sum,row)=>currency.add(sum,inventory(row,tariff.rate).knownShipping),0)};
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
          quantity:quantity(b.quantity),price:amount(b.price),grams:amount(b.grams),rate:amount(b.rate),
          ...(uzsText(b.priceUzs)!==null?{priceUzs:uzsText(b.priceUzs)}:{}),
           ...(typeof b.groupId==='string'&&b.groupId.trim()?{groupId:b.groupId.slice(0,120)}:{})}))
        .filter(b=>b.quantity!==null);
      let sum=0;const safeBatches=batches.filter(b=>{if(sum+b.quantity>=total)return false;sum+=b.quantity;return true;});
      return {
      id:String(row.id||makeId()),title:String(row.title||'').slice(0,300),
      price:amount(row.price),grams:amount(row.grams),salePrice:amount(row.salePrice),quantity:total,
       ...(uzsText(row.priceUzs)!==null?{priceUzs:uzsText(row.priceUzs)}:{}),
       ...(amount(row.originRate)!==null?{originRate:amount(row.originRate)}:{}),
       ...(typeof row.originBatchId==='string'&&row.originBatchId.trim()?{originBatchId:row.originBatchId.slice(0,120),originBatchDate:/^\d{4}-\d{2}-\d{2}$/.test(row.originBatchDate||'')?row.originBatchDate:''}:{}),
      ...(safeBatches.length?{batches:safeBatches}:{}),
      ...(typeof row.muhajeerId==='string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(row.muhajeerId)?{muhajeerId:row.muhajeerId,muhajeerTitle:String(row.muhajeerTitle||'').slice(0,300),muhajeerCost:amount(row.muhajeerCost)}:{}),
      saved:typeof row.saved==='boolean'?row.saved:Boolean(String(row.title||'').trim() && calculate(row).total!==null)
    };
    });
  }
  // The previous data format only recorded the most recent import's list of book IDs.
  // Recover exactly that known delivery without merging unrelated same-day imports.
  function restoreLastImportGroups(rows,lastImport,makeId){
    const items=normalize(rows,makeId);
    if(!lastImport||typeof lastImport.id!=='string'||!Array.isArray(lastImport.items))return items;
    const date=/^\d{4}-\d{2}-\d{2}$/.test(lastImport.date||'')?lastImport.date:'';
    const lookup=new Map(items.map(row=>[row.id,row]));
    for(const entry of lastImport.items){
      const row=lookup.get(entry.id);
      if(!row)continue;
      if(entry.type==='new'&&!row.originBatchId){
        row.originBatchId=lastImport.id;
        row.originBatchDate=date;
      }
      if(entry.type==='batch'){
        const batch=(row.batches||[]).find(b=>b.id===entry.batchId);
        if(batch&&!batch.groupId)batch.groupId=lastImport.id;
      }
    }
    return items;
  }
  const api={DEFAULT_WON_PER_KG,WON_PER_GRAM,rate,amount,uzsText,quantity,calculate,profit,inventory,summary,key,parseTitles,parseTitleEntries,extraQuantity,baseQuantity,arrivalParts,groupByBatch,normalize,restoreLastImportGroups,freezeHistoricalRates,normalizeRates,tariffs,compare};
  if(typeof module==='object' && module.exports)module.exports=api;
  else root.BookCosts=api;
})(typeof globalThis==='object'?globalThis:this);
