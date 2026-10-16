(function(root){
  'use strict';
  const KINDS=['Jenshen','Kosmetika','Vitamin','Boshqa'];
  const currency=(typeof module==='object'&&module.exports)?require('./currency-converter.js'):root.YordamchiCurrency;
  let lastBookRows=[];
  const selectedProductIds=new Set();
  const $=id=>document.getElementById(id);
  let api=null;
  function amount(value){
    if(value===null || value===undefined || String(value).trim()==='')return null;
    const text=String(value).trim().replace(/[\s,₩]/g,'');
    if(!/^\d+(?:\.\d+)?$/.test(text))return null;
    const n=Number(text);
    return Number.isFinite(n)&&n>=0&&n<=1e9?n:null;
  }
  function fx(value){
    const n=amount(value);
    return n!==null&&n>0&&n<=1e7?n:null;
  }
  function shippingRate(value,fallback=10000){
    return amount(value)??amount(fallback)??10000;
  }
  function som(won,rate){
    const n=amount(won),r=fx(rate);
    return n===null||r===null?null:Math.round(n*r/1000);
  }
  function itemKgRate(item,perKg){return amount(item?.kgRate)??amount(perKg);}
  function rateInWon(value,unit,exchange){
    const n=amount(value);
    if(n===null)return null;
    if(unit==='UZS'){
      const r=fx(exchange);
      return r===null?null:Math.round(n*1000/r);
    }
    return n;
  }
  function wonAsRate(value,unit,exchange){
    if(value===null)return null;
    if(unit==='UZS')return som(value,exchange);
    return value;
  }
  function calculate(item,perKg,exchange){
    const price=amount(item.price),weight=amount(item.grams),kg=itemKgRate(item,perKg);
    const shipping=weight===null||kg===null?null:Math.round(weight*kg/1000);
    const total=price===null||shipping===null?null:Math.round(price)+shipping;
    return {price,shipping,total,priceSom:som(price,exchange),shippingSom:som(shipping,exchange),totalSom:som(total,exchange)};
  }
  function applyRateToSelected(rows,selectedIds,rate){
    const chosen=new Set(selectedIds),kg=amount(rate);
    if(kg===null||kg>10000000)throw new Error('Kg tarifi noto‘g‘ri.');
    return rows.map(item=>chosen.has(item.id)?{...item,kgRate:kg}:item);
  }
  function normalize(rows,id,defaultKgRate=10000){
    return (Array.isArray(rows)?rows:[]).filter(x=>x&&typeof x==='object').map(row=>({
      id:String(row.id||id()),name:String(row.name||'').trim().slice(0,160),
      kind:KINDS.includes(row.kind)?row.kind:'Boshqa',
      price:amount(row.price),grams:amount(row.grams),
      kgRate:shippingRate(row.kgRate,defaultKgRate)
    })).filter(x=>x.name);
  }
  const fmt=(value,unit)=>value===null?'—':api.money(value,unit);
  // Main records are stored in won and always displayed in won + som.
  // The independent converter's chosen direction must never alter item totals.
  function chosenText(won){
    if(won===null)return '—';
    const state=api.get();
    const value=currency.convert(won,'KRW','UZS',state.krwToUzsPer1000,state.krwPerUsd);
    return value===null?'Kursni kiriting':currency.display(value,'UZS');
  }
  function summarize(rows,perKg,exchange){
    const items=Array.isArray(rows)?rows:[],result={count:items.length,ready:0,incomplete:0,purchase:0,shipping:0,total:0,purchaseSom:null,shippingSom:null,totalSom:null};
    for(const item of items){
      const entry=calculate(item,perKg,exchange);
      if(entry.total===null){result.incomplete++;continue;}
      result.ready++;
      result.purchase+=entry.price;result.shipping+=entry.shipping;result.total+=entry.total;
    }
    if(result.ready&&fx(exchange)!==null){
      result.purchaseSom=som(result.purchase,exchange);
      result.shippingSom=som(result.shipping,exchange);
      result.totalSom=som(result.total,exchange);
    }
    return result;
  }
  function renderConverters(){
    if(!api)return;
    const state=api.get();
    document.querySelectorAll('.currency-converter').forEach(widget=>{
      const source=widget.querySelector('.currency-from').value,
        destination=widget.querySelector('.currency-to').value,
        input=widget.querySelector('.currency-amount'),
        result=widget.querySelector('.currency-result');
      const converted=currency.convert(input.value,source,destination,state.krwToUzsPer1000,state.krwPerUsd);
      result.textContent=currency.amount(input.value)===null?'Hisoblash uchun summa kiriting.':
        converted===null?'Bu juftlik uchun valyuta kurslarini kiriting.':
        currency.display(converted,destination);
    });
  }
  function refreshConvertedViews(){
    renderConverters();renderBookList(lastBookRows);renderBookEntry();render();
  }

  const rateEditor=(typeof module==='object'&&module.exports)?require('./currency-rate-editor.js'):root.YordamchiRateEditor;
  function paintRateRow(row,state,keepDraft=false){
    const from=row.querySelector('.exchange-rate-from').value,to=row.querySelector('.exchange-rate-to').value;
    row.querySelector('.exchange-rate-base').textContent=(from==='USD'?'1':'1 000')+' '+rateEditor.unit(from);
    row.querySelector('.exchange-rate-unit').textContent=rateEditor.unit(to);
    const rate=rateEditor.rawValue(from,to,state),input=row.querySelector('.exchange-rate-value');
    if(!keepDraft)input.value=rateEditor.showNumber(rate);
    row.querySelector('.exchange-rate-hint').textContent=rate===null?'Bu juftlikning kursi hali kiritilmagan.':
      'Saqlangan: '+(from==='USD'?'1':'1 000')+' '+rateEditor.unit(from)+' = '+rateEditor.showNumber(rate)+' '+rateEditor.unit(to);
  }
  function syncRateInputs(force=false){
    if(!api)return;
    const state=api.get(),pairs=rateEditor.normalized(state.exchangeRatePairs);
    document.querySelectorAll('.exchange-editor').forEach(panel=>{
      if(!force&&panel.dataset.rateInitialized==='yes')return;
      panel.querySelectorAll('.exchange-pair-editor').forEach((row,i)=>{
        row.querySelector('.exchange-rate-from').value=pairs[i].from;
        row.querySelector('.exchange-rate-to').value=pairs[i].to;
        paintRateRow(row,state);
      });
      panel.dataset.rateInitialized='yes';
    });
    renderConverters();
  }
  function renderPreview(){
    if(!$('koreaPrice'))return;
    const state=api.get();
    const raw=$('koreaItemKgRate').value.trim(),unit=$('koreaItemRateCurrency').value;
    const itemRate=rateInWon(raw,unit,state.krwToUzsPer1000);
    const result=calculate({price:$('koreaPrice').value,grams:$('koreaGrams').value,kgRate:itemRate},null,state.krwToUzsPer1000);
    $('koreaItemRateHint').textContent=raw===''?'Har mahsulot uchun alohida kg tarifini kiriting.':
      itemRate===null?'So‘m tarifini hisoblash uchun umumiy von–so‘m kursini kiriting.':
      '1 kg = '+fmt(itemRate,'KRW')+' = '+chosenText(itemRate);
    $('koreaPreviewPriceWon').textContent=fmt(result.price,'KRW');
    $('koreaPreviewPriceSom').textContent=chosenText(result.price);
    $('koreaPreviewShipWon').textContent=fmt(result.shipping,'KRW');
    $('koreaPreviewShipSom').textContent=result.shipping===null?'—':chosenText(result.shipping);
    $('koreaPreviewTotalWon').textContent=fmt(result.total,'KRW');
    $('koreaPreviewTotalSom').textContent=result.total===null?'—':chosenText(result.total);
  }
  function render(){
    if(!api||!$('koreaProductsList'))return;
    const state=api.get();
    syncRateInputs();
    const rate=shippingRate(state.koreaShippingRate);
    $('koreaKgRate').textContent=fmt(rate,'KRW')+' / kg';
    $('koreaRate100g').textContent=fmt(rate/10,'KRW')+' / 100 g';
    if(document.activeElement!==$('koreaKgRateInput')){
      const unit=$('koreaBulkRateCurrency').value;
      $('koreaKgRateInput').value=wonAsRate(rate,unit,state.krwToUzsPer1000)??'';
    }
    $('koreaRateHelp').textContent='Standart: '+fmt(rate,'KRW')+'/kg. Saqlangan mahsulotlar o‘zgarmaydi; faqat tanlab tasdiqlasangiz tarif yangilanadi.';
    const products=state.koreaProducts||[];
    const sums=summarize(products,rate,state.krwToUzsPer1000);
    $('koreaCount').textContent=sums.count+' ta mahsulot';
    $('koreaTotalWon').textContent=sums.ready?fmt(sums.total,'KRW'):'—';
    $('koreaTotalSom').textContent=sums.ready?chosenText(sums.total):'—';
    $('koreaPurchaseWon').textContent=sums.ready?fmt(sums.purchase,'KRW'):'—';
    $('koreaPurchaseSom').textContent=sums.ready?chosenText(sums.purchase):'—';
    $('koreaShippingWon').textContent=sums.ready?fmt(sums.shipping,'KRW'):'—';
    $('koreaShippingSom').textContent=sums.ready?chosenText(sums.shipping):'—';
    const complete=products.filter(item=>calculate(item,rate,state.krwToUzsPer1000).total!==null);
    const totalGrams=complete.reduce((sum,item)=>sum+amount(item.grams),0);
    $('koreaWeightTotal').textContent=complete.length?totalGrams.toLocaleString('en-US')+' g':'—';
    $('koreaAvgCost').textContent=sums.ready?fmt(sums.total/sums.ready,'KRW'):'—';
    $('koreaComplete').textContent=sums.ready+' ta to‘liq hisoblangan mahsulot';
    $('koreaUnfinished').hidden=!sums.incomplete;
    $('koreaUnfinished').textContent=sums.incomplete?('Yana '+sums.incomplete+' ta mahsulotda xarid narxi yoki vazn yetishmaydi. Ular umumiy tan narxiga kiritilmadi.'):''; 
    renderCategoryStats(products,state);
    $('koreaProductsList').innerHTML=products.length?products.map(item=>{
      const r=calculate(item,rate,state.krwToUzsPer1000),individualRate=itemKgRate(item,rate);
      return '<article class="korea-card"><div class="korea-card-head"><div><small>'+api.escape(item.kind)+'</small><h3>'+api.escape(item.name)+'</h3><span>'+(item.grams===null?'Vazn kiritilmagan':item.grams+' g')+'</span></div><div class="korea-card-actions"><button class="soft-button" data-korea-edit="'+api.escape(item.id)+'">Tahrir</button><button class="soft-button" data-korea-delete="'+api.escape(item.id)+'" aria-label="O‘chirish">×</button></div></div>'+
        '<div class="korea-item-rate"><small>Shu mahsulotning 1 kg tarifi</small><b>'+fmt(individualRate,'KRW')+'</b><span>'+chosenText(individualRate)+'</span></div>'+
        '<div class="korea-grid"><div><small>Xarid</small><b>'+fmt(r.price,'KRW')+'</b><em>'+chosenText(r.price)+'</em></div><div><small>Yetkazish</small><b>'+fmt(r.shipping,'KRW')+'</b><em>'+chosenText(r.shipping)+'</em></div></div><div class="korea-total-line"><span>Jami tan narxi</span><b>'+fmt(r.total,'KRW')+'</b><strong>'+chosenText(r.total)+'</strong></div></article>';
    }).join(''):'<div class="empty-state"><strong>Mahsulot hali qo‘shilmadi</strong>Jenshen yoki kosmetikani kiritishdan boshlang.</div>';
    renderBulkTargets(products);
    renderPreview();
  }
  function renderBulkTargets(products){
    const holder=$('koreaBulkTargets');
    if(!holder)return;
    const current=new Set(products.map(item=>item.id));
    for(const id of selectedProductIds){if(!current.has(id))selectedProductIds.delete(id);}
    holder.innerHTML=products.map(item=>'<label class="korea-bulk-option"><input type="checkbox" data-korea-bulk-id="'+api.escape(item.id)+'" '+(selectedProductIds.has(item.id)?'checked':'')+'><span><b>'+api.escape(item.name)+'</b><small>1 kg: '+fmt(item.kgRate,'KRW')+'</small></span></label>').join('')||
      '<p class="empty-state">Avval mahsulot qo‘shing, so‘ng umumiy tarifni keraklilariga qo‘llaysiz.</p>';
    $('koreaBulkCount').textContent=selectedProductIds.size+' ta tanlangan';
    $('koreaBulkSelectAll').checked=products.length>0&&selectedProductIds.size===products.length;
    $('koreaBulkApply').disabled=selectedProductIds.size===0;
  }
  function renderCategoryStats(products,state){
    const holder=$('koreaCategoryStats');
    if(!holder)return;
    const groups=new Map();
    for(const item of products){
      const kind=KINDS.includes(item.kind)?item.kind:'Boshqa';
      if(!groups.has(kind))groups.set(kind,[]);
      groups.get(kind).push(item);
    }
    holder.innerHTML=groups.size?[...groups.entries()].map(([kind,items])=>{
      const result=summarize(items,state.koreaShippingRate,state.krwToUzsPer1000);
      return '<article class="korea-category-row"><div><b>'+api.escape(kind)+'</b><small>'+items.length+' ta mahsulot · '+result.ready+' ta to‘liq hisoblangan'+(result.incomplete?' · '+result.incomplete+' ta chala':'')+'</small></div><div><b>'+(result.ready?fmt(result.total,'KRW'):'—')+'</b><strong>'+(result.ready?chosenText(result.total):'—')+'</strong></div></article>';
    }).join(''):'<p class="empty-state">Hozircha mahsulot yo‘q. Mahsulot qo‘shilganda bu yerda turiga qarab jami xarid va yetkazish xarajatlari ko‘rinadi.</p>';
  }
  function appendAmount(container,text){
    const el=document.createElement('p');el.className='converted-cost';el.textContent=text;container.appendChild(el);
  }
  function bookSomDescription(row,state){
    const value=root.BookCosts.calculate(row,state.bookCostRate);
    const price=row.price===null?'—':chosenText(row.price);
    const shipping=value.shipping===null?'—':chosenText(value.shipping);
    const total=value.total===null?'—':chosenText(value.total);
    return 'Xarid: '+price+' · Yetkazish: '+shipping+' · Jami: '+total;
  }
  function renderBookList(rows){
    if(!api||!$('costReadyList'))return;
    lastBookRows=rows;
    const state=api.get();
    syncRateInputs();
    const saved=state.bookCosts.filter(row=>row.saved&&String(row.title||'').trim());
    let total=0,count=0;
    for(const row of saved){const n=root.BookCosts.inventory(row,state.bookCostRate).total;if(n!==null){total+=n;count++;}}
    $('bookSomTotal').textContent=count?chosenText(total):'—';
    document.querySelectorAll('#costReadyList .cost-main-row,#costReadyList .cost-ready-row').forEach((card,index)=>{
      card.querySelector('.converted-cost')?.remove();
      const item=rows[index];
      if(!item)return;
      appendAmount(card,bookSomDescription(item,state));
    });
  }
  function renderBookEntry(){
    if(!api)return;
    const state=api.get();
    document.querySelectorAll('#costBooksList [data-cost-id]').forEach(card=>{
      card.querySelector('.converted-cost')?.remove();
      const row=state.bookCosts.find(x=>x.id===card.dataset.costId);
      if(!row)return;
      const result=card.querySelector('.cost-result');
      if(result)appendAmount(result,bookSomDescription(row,state));
    });
  }
  function resetEditor(){
    $('koreaId').value='';$('koreaName').value='';$('koreaKind').value='Jenshen';
    $('koreaPrice').value='';$('koreaGrams').value='';
    $('koreaItemRateCurrency').value='KRW';
    $('koreaItemKgRate').value=api.get().koreaShippingRate;
    $('koreaItemRateCurrency').dataset.oldUnit='KRW';
    $('koreaSave').textContent='+ Mahsulotni saqlash';$('koreaCancel').hidden=true;renderPreview();
  }
  function init(deps){
    api=deps;
    document.querySelectorAll('.currency-converter').forEach(widget=>{
      const from=widget.querySelector('.currency-from'),to=widget.querySelector('.currency-to'),
        input=widget.querySelector('.currency-amount'),swap=widget.querySelector('.currency-swap');
      from.addEventListener('change',refreshConvertedViews);
      to.addEventListener('change',refreshConvertedViews);
      input.addEventListener('input',renderConverters);
      swap.addEventListener('click',()=>{
        const state=api.get(),value=currency.convert(input.value,from.value,to.value,state.krwToUzsPer1000,state.krwPerUsd);
        const oldFrom=from.value;from.value=to.value;to.value=oldFrom;
        // Swap directions and keep the same economic value in the input.
        if(value!==null)input.value=String(value);
        refreshConvertedViews();
      });
    });

    document.querySelectorAll('.exchange-pair-editor').forEach(row=>{
      const from=row.querySelector('.exchange-rate-from'),to=row.querySelector('.exchange-rate-to'),
        input=row.querySelector('.exchange-rate-value'),swap=row.querySelector('.exchange-rate-swap');
      const selected=event=>{
        if(from.value===to.value){
          if(event.target===from)to.value=currency.CURRENCIES.find(code=>code!==from.value);
          else from.value=currency.CURRENCIES.find(code=>code!==to.value);
        }
        paintRateRow(row,api.get());
      };
      from.addEventListener('change',selected);
      to.addEventListener('change',selected);
      input.addEventListener('input',()=>{
        row.querySelector('.exchange-rate-hint').textContent='Yangi kurs — saqlash tugmasini bosing.';
      });
      swap.addEventListener('click',()=>{
        const oldFrom=from.value,oldTo=to.value,oldRate=currency.amount(input.value);
        const previousBase=rateEditor.base(oldFrom);
        from.value=oldTo;to.value=oldFrom;
        if(oldRate!==null&&oldRate>0){
          const reverse=rateEditor.base(oldTo)*previousBase/oldRate;
          input.value=rateEditor.showNumber(reverse);
          paintRateRow(row,api.get(),true);
          row.querySelector('.exchange-rate-hint').textContent='Kurs yo‘nalishi almashtirildi. Saqlashni unutmang.';
        }else paintRateRow(row,api.get());
      });
    });
    document.querySelectorAll('.exchange-save-all').forEach(btn=>btn.addEventListener('click',()=>{
      const panel=btn.closest('.exchange-editor');
      const rows=[...panel.querySelectorAll('.exchange-pair-editor')].map(row=>({
        from:row.querySelector('.exchange-rate-from').value,
        to:row.querySelector('.exchange-rate-to').value,
        value:row.querySelector('.exchange-rate-value').value.trim()
      }));
      const state=api.get();
      let next;
      try{next=rateEditor.solve(rows,state);}
      catch(err){api.toast(err.message||'Valyuta kurslarini tekshiring.');return;}
      const original={krwToUzsPer1000:state.krwToUzsPer1000,
        krwPerUsd:state.krwPerUsd,exchangeRatePairs:state.exchangeRatePairs};
      state.krwToUzsPer1000=next.krwToUzsPer1000;
      state.krwPerUsd=next.krwPerUsd;
      state.exchangeRatePairs=rateEditor.normalized(rows);
      try{
        api.save('✓ Kurslar saqlandi. Barcha kitob va mahsulotlar qayta hisoblandi.');
        syncRateInputs(true);
        document.querySelectorAll('.exchange-shared-status').forEach(el=>
          el.textContent='✓ Kurs saqlandi. Tanlangan juftliklar ikkala bo‘limda ham bir xil ishlaydi.');
        refreshConvertedViews();
      }catch(_){
        Object.assign(state,original);
        api.toast('Kurs saqlanmadi. Eski kurs o‘zgarmadi.');
      }
    }));
    $('koreaKgRateSave').addEventListener('click',()=>{
      const input=$('koreaKgRateInput'),state=api.get(),
        value=rateInWon(input.value,$('koreaBulkRateCurrency').value,state.krwToUzsPer1000);
      if(value===null||value>10000000){
        api.toast('Standart 1 kg narxini to‘g‘ri kiriting. So‘m uchun valyuta kursi kerak.');input.focus();return;
      }
      const previous=state.koreaShippingRate;
      state.koreaShippingRate=value;
      try{api.save('Standart tarif saqlandi. Eski mahsulotlarning alohida tariflariga tegilmadi.');}
      catch(_){state.koreaShippingRate=previous;api.toast('Tarif saqlanmadi.');return;}
      render();
    });
    function bindRateUnit(selectId,inputId){
      const picker=$(selectId),input=$(inputId);
      picker.dataset.oldUnit=picker.value;
      picker.addEventListener('change',()=>{
        const state=api.get(),previous=picker.dataset.oldUnit||'KRW';
        const won=rateInWon(input.value,previous,state.krwToUzsPer1000);
        if(won!==null){
          const next=wonAsRate(won,picker.value,state.krwToUzsPer1000);
          input.value=next===null?'':String(next);
        }else if(input.value.trim())api.toast('So‘mga aylantirish uchun umumiy valyuta kursi kerak.');
        picker.dataset.oldUnit=picker.value;
        renderPreview();
      });
    }
    bindRateUnit('koreaItemRateCurrency','koreaItemKgRate');
    bindRateUnit('koreaBulkRateCurrency','koreaKgRateInput');
    ['koreaPrice','koreaGrams','koreaItemKgRate'].forEach(id=>$(id).addEventListener('input',renderPreview));
    $('koreaBulkTargets').addEventListener('change',event=>{
      const id=event.target.dataset.koreaBulkId;if(!id)return;
      if(event.target.checked)selectedProductIds.add(id);else selectedProductIds.delete(id);
      renderBulkTargets(api.get().koreaProducts);
    });
    $('koreaBulkSelectAll').addEventListener('change',event=>{
      selectedProductIds.clear();
      if(event.target.checked)api.get().koreaProducts.forEach(item=>selectedProductIds.add(item.id));
      renderBulkTargets(api.get().koreaProducts);
    });
    $('koreaBulkApply').addEventListener('click',()=>{
      const state=api.get(),targets=state.koreaProducts.filter(item=>selectedProductIds.has(item.id));
      if(!targets.length){api.toast('Tarif qo‘llanadigan mahsulotlarni tanlang.');return;}
      const rate=shippingRate(state.koreaShippingRate);
      const preview=targets.slice(0,4).map(item=>item.name).join(', ')+(targets.length>4?' …':'');
      if(!confirm(targets.length+' ta mahsulotning 1 kg tarifi '+fmt(rate,'KRW')+' ga o‘zgartirilsinmi?\n'+preview+'\n\nBu faqat tanlanganlarga ta’sir qiladi. Davom etasizmi?'))return;
      const old=state.koreaProducts;
      state.koreaProducts=applyRateToSelected(old,selectedProductIds,rate);
      try{
        api.save(targets.length+' ta tanlangan mahsulotning kg tarifi yangilandi.');
        selectedProductIds.clear();render();
      }catch(_){state.koreaProducts=old;api.toast('Ommaviy tarifni saqlab bo‘lmadi.');}
    });
    $('koreaCancel').addEventListener('click',resetEditor);
    $('koreaProductsList').addEventListener('click',event=>{
      const edit=event.target.closest('[data-korea-edit]'),remove=event.target.closest('[data-korea-delete]');
      if(edit){
        const item=api.get().koreaProducts.find(x=>x.id===edit.dataset.koreaEdit);
        if(!item)return;
        $('koreaId').value=item.id;$('koreaName').value=item.name;$('koreaKind').value=item.kind;
        $('koreaPrice').value=item.price??'';$('koreaGrams').value=item.grams??'';
        $('koreaItemRateCurrency').value='KRW';
        $('koreaItemRateCurrency').dataset.oldUnit='KRW';
        $('koreaItemKgRate').value=itemKgRate(item,api.get().koreaShippingRate)??'';
        $('koreaSave').textContent='O‘zgarishlarni saqlash';$('koreaCancel').hidden=false;renderPreview();
        root.YordamchiWorkspace?.openProductsEntry?.();
        $('koreaForm').scrollIntoView({behavior:'smooth',block:'start'});return;
      }
      if(remove){
        const state=api.get(),item=state.koreaProducts.find(x=>x.id===remove.dataset.koreaDelete);
        if(!item||!confirm('“'+item.name+'” mahsulotini o‘chirasizmi?'))return;
        const old=state.koreaProducts;
        state.koreaProducts=old.filter(x=>x.id!==item.id);
        try{api.save('Mahsulot o‘chirildi.');resetEditor();}
        catch(_){state.koreaProducts=old;api.toast('O‘chirib bo‘lmadi.');}
      }
    });
    $('koreaForm').addEventListener('submit',event=>{
      event.preventDefault();
      const name=$('koreaName').value.trim().slice(0,160),price=amount($('koreaPrice').value),grams=amount($('koreaGrams').value),
        kgRate=rateInWon($('koreaItemKgRate').value,$('koreaItemRateCurrency').value,api.get().krwToUzsPer1000);
      if(!name){api.toast('Mahsulot nomini kiriting.');return;}
      if(($('koreaPrice').value.trim()&&price===null)||($('koreaGrams').value.trim()&&grams===null)){
        api.toast('Narx va vaznni musbat raqamlarda kiriting.');return;
      }
      if(kgRate===null||kgRate>10000000){api.toast('Har mahsulot uchun 1 kg tarifini kiriting (so‘m uchun kursni ham kiriting).');$('koreaItemKgRate').focus();return;}
      const state=api.get(),id=$('koreaId').value;
      const item={id:id||api.id(),name,kind:$('koreaKind').value,price,grams,kgRate};
      const old=state.koreaProducts.slice(),index=state.koreaProducts.findIndex(x=>x.id===id);
      if(index>=0)state.koreaProducts[index]=item;else state.koreaProducts.unshift(item);
      try{api.save('Mahsulot saqlandi.');resetEditor();}
      catch(_){state.koreaProducts=old;api.toast('Mahsulot saqlanmadi.');}
    });
    $('costBooksList').addEventListener('input',()=>queueMicrotask(renderBookEntry));
    resetEditor();
  }
  const exported={amount,fx,shippingRate,som,calculate,summarize,normalize,init,render,renderBookList,renderBookEntry,
    itemKgRate,rateInWon,wonAsRate,applyRateToSelected,refreshRates:()=>{syncRateInputs(true);refreshConvertedViews();}};
  if(typeof module==='object' && module.exports)module.exports=exported;
  else root.KoreaProducts=exported;
})(typeof window==='object'?window:globalThis);
