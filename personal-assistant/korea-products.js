(function(root){
  'use strict';
  const KINDS=['Jenshen','Kosmetika','Vitamin','Boshqa'];
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
  function som(won,rate){
    const n=amount(won),r=fx(rate);
    return n===null||r===null?null:Math.round(n*r/1000);
  }
  function calculate(item,perKg,exchange){
    const price=amount(item.price),weight=amount(item.grams),kg=amount(perKg);
    const shipping=weight===null||kg===null?null:Math.round(weight*kg/1000);
    const total=price===null||shipping===null?null:Math.round(price)+shipping;
    return {price,shipping,total,priceSom:som(price,exchange),shippingSom:som(shipping,exchange),totalSom:som(total,exchange)};
  }
  function normalize(rows,id){
    return (Array.isArray(rows)?rows:[]).filter(x=>x&&typeof x==='object').map(row=>({
      id:String(row.id||id()),name:String(row.name||'').trim().slice(0,160),
      kind:KINDS.includes(row.kind)?row.kind:'Boshqa',
      price:amount(row.price),grams:amount(row.grams)
    })).filter(x=>x.name);
  }
  const fmt=(value,currency)=>value===null?'—':api.money(value,currency);
  function sumText(won){
    const value=som(won,api.get().krwToUzsPer1000);
    return value===null?'Kursni kiriting':fmt(value,'UZS');
  }
  function syncRateInputs(){
    const state=api.get();
    document.querySelectorAll('.krw-uzs-input').forEach(input=>{
      if(document.activeElement!==input)input.value=state.krwToUzsPer1000??'';
    });
    document.querySelectorAll('.krw-uzs-hint').forEach(el=>{
      el.textContent=fx(state.krwToUzsPer1000)===null?'Kurs kiritilmagan':('1 000 ₩ = '+fmt(state.krwToUzsPer1000,'UZS'));
    });
  }
  function renderPreview(){
    if(!$('koreaPrice'))return;
    const state=api.get();
    const result=calculate({price:$('koreaPrice').value,grams:$('koreaGrams').value},state.bookCostRate,state.krwToUzsPer1000);
    $('koreaPreviewPriceSom').textContent=result.price===null?'—':sumText(result.price);
    $('koreaPreviewShipWon').textContent=fmt(result.shipping,'KRW');
    $('koreaPreviewShipSom').textContent=result.shipping===null?'—':sumText(result.shipping);
    $('koreaPreviewTotalWon').textContent=fmt(result.total,'KRW');
    $('koreaPreviewTotalSom').textContent=result.total===null?'—':sumText(result.total);
  }
  function render(){
    if(!api||!$('koreaProductsList'))return;
    const state=api.get();
    syncRateInputs();
    $('koreaKgRate').textContent=fmt(state.bookCostRate,'KRW')+' / kg';
    const products=state.koreaProducts||[];
    let total=0,count=0;
    products.forEach(item=>{
      const sum=calculate(item,state.bookCostRate,state.krwToUzsPer1000).total;
      if(sum!==null){total+=sum;count++;}
    });
    $('koreaCount').textContent=products.length+' ta mahsulot';
    $('koreaTotalWon').textContent=count?fmt(total,'KRW'):'—';
    $('koreaTotalSom').textContent=count?sumText(total):'—';
    $('koreaComplete').textContent=count+' ta to‘liq kiritilgan mahsulot';
    $('koreaProductsList').innerHTML=products.length?products.map(item=>{
      const r=calculate(item,state.bookCostRate,state.krwToUzsPer1000);
      return '<article class="korea-card"><div class="korea-card-head"><div><small>'+api.escape(item.kind)+'</small><h3>'+api.escape(item.name)+'</h3><span>'+(item.grams===null?'Vazn kiritilmagan':item.grams+' g')+'</span></div><div class="korea-card-actions"><button class="soft-button" data-korea-edit="'+api.escape(item.id)+'">Tahrir</button><button class="soft-button" data-korea-delete="'+api.escape(item.id)+'" aria-label="O‘chirish">×</button></div></div><div class="korea-grid"><div><small>Xarid</small><b>'+fmt(r.price,'KRW')+'</b><em>'+(r.price===null?'—':sumText(r.price))+'</em></div><div><small>Yetkazish</small><b>'+fmt(r.shipping,'KRW')+'</b><em>'+(r.shipping===null?'—':sumText(r.shipping))+'</em></div></div><div class="korea-total-line"><span>Jami tan narxi</span><b>'+fmt(r.total,'KRW')+'</b><strong>'+(r.total===null?'—':sumText(r.total))+'</strong></div></article>';
    }).join(''):'<div class="empty-state"><strong>Mahsulot hali qo‘shilmadi</strong>Jenshen yoki kosmetikani kiritishdan boshlang.</div>';
    renderPreview();
  }
  function appendAmount(container,text){
    const el=document.createElement('p');el.className='converted-cost';el.textContent=text;container.appendChild(el);
  }
  function bookSomDescription(row,state){
    const value=root.BookCosts.calculate(row,state.bookCostRate);
    const price=row.price===null?'—':sumText(row.price);
    const shipping=value.shipping===null?'—':sumText(value.shipping);
    const total=value.total===null?'—':sumText(value.total);
    return 'Xarid: '+price+' · Yetkazish: '+shipping+' · Jami: '+total;
  }
  function renderBookList(rows){
    if(!api||!$('costReadyList'))return;
    const state=api.get();
    syncRateInputs();
    const saved=state.bookCosts.filter(row=>row.saved&&String(row.title||'').trim());
    let total=0,count=0;
    for(const row of saved){const n=root.BookCosts.calculate(row,state.bookCostRate).total;if(n!==null){total+=n;count++;}}
    $('bookSomTotal').textContent=count?sumText(total):'—';
    document.querySelectorAll('#costReadyList .cost-main-row,#costReadyList .cost-ready-row').forEach((card,index)=>{
      card.querySelector('.converted-cost')?.remove();
      const item=rows[index];
      if(!item)return;
      const n=root.BookCosts.calculate(item,state.bookCostRate).total;
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
      const n=root.BookCosts.calculate(row,state.bookCostRate).total;
      const result=card.querySelector('.cost-result');
      if(result)appendAmount(result,bookSomDescription(row,state));
    });
  }
  function resetEditor(){
    $('koreaId').value='';$('koreaName').value='';$('koreaKind').value='Jenshen';
    $('koreaPrice').value='';$('koreaGrams').value='';
    $('koreaSave').textContent='+ Mahsulotni saqlash';$('koreaCancel').hidden=true;renderPreview();
  }
  function init(deps){
    api=deps;
    document.querySelectorAll('.krw-uzs-save').forEach(btn=>btn.addEventListener('click',()=>{
      const input=btn.closest('.exchange-editor').querySelector('.krw-uzs-input');
      const rate=fx(input.value);
      if(rate===null){api.toast('1 000 ₩ uchun to‘g‘ri, musbat kursni kiriting.');input.focus();return;}
      const old=api.get().krwToUzsPer1000;
      api.get().krwToUzsPer1000=rate;
      try{api.save('Umumiy kurs yangilandi.');}
      catch(_){api.get().krwToUzsPer1000=old;api.toast('Kurs saqlanmadi.');}
    }));
    ['koreaPrice','koreaGrams'].forEach(id=>$(id).addEventListener('input',renderPreview));
    $('koreaCancel').addEventListener('click',resetEditor);
    $('koreaProductsList').addEventListener('click',event=>{
      const edit=event.target.closest('[data-korea-edit]'),remove=event.target.closest('[data-korea-delete]');
      if(edit){
        const item=api.get().koreaProducts.find(x=>x.id===edit.dataset.koreaEdit);
        if(!item)return;
        $('koreaId').value=item.id;$('koreaName').value=item.name;$('koreaKind').value=item.kind;
        $('koreaPrice').value=item.price??'';$('koreaGrams').value=item.grams??'';
        $('koreaSave').textContent='O‘zgarishlarni saqlash';$('koreaCancel').hidden=false;renderPreview();
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
      const name=$('koreaName').value.trim().slice(0,160),price=amount($('koreaPrice').value),grams=amount($('koreaGrams').value);
      if(!name){api.toast('Mahsulot nomini kiriting.');return;}
      if(($('koreaPrice').value.trim()&&price===null)||($('koreaGrams').value.trim()&&grams===null)){
        api.toast('Narx va vaznni musbat raqamlarda kiriting.');return;
      }
      const state=api.get(),id=$('koreaId').value;
      const item={id:id||api.id(),name,kind:$('koreaKind').value,price,grams};
      const old=state.koreaProducts.slice(),index=state.koreaProducts.findIndex(x=>x.id===id);
      if(index>=0)state.koreaProducts[index]=item;else state.koreaProducts.unshift(item);
      try{api.save('Mahsulot saqlandi.');resetEditor();}
      catch(_){state.koreaProducts=old;api.toast('Mahsulot saqlanmadi.');}
    });
    $('costBooksList').addEventListener('input',()=>queueMicrotask(renderBookEntry));
  }
  const exported={amount,fx,som,calculate,normalize,init,render,renderBookList,renderBookEntry};
  if(typeof module==='object' && module.exports)module.exports=exported;
  else root.KoreaProducts=exported;
})(typeof window==='object'?window:globalThis);
