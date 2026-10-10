(function(root,factory){const api=factory();if(typeof module==='object' && module.exports)module.exports=api;else root.BookCostDeviceSync=api;})(typeof window==='object'?window:this,function(){
  const stable=value=>JSON.stringify(value,function(key,value){return value && typeof value==='object' && !Array.isArray(value)?Object.keys(value).sort().reduce((o,k)=>(o[k]=value[k],o),{}):value;});
  const equal=(a,b)=>stable(a)===stable(b);
  function snapshot(state){return {books:state.bookCosts.map(r=>({id:r.id,title:r.title,price:r.price,grams:r.grams,saved:r.saved,salePrice:r.muhajeerId?null:(r.salePrice??null),muhajeerId:r.muhajeerId||null})),rate:state.bookCostRate,tariffs:state.bookCostComparisons.map(t=>({...t}))};}
  function merge(base,local,remote){
    if(!remote)return {value:local,conflicts:[]};
    if(!base && !local.books.length && !local.tariffs.length)return {value:remote,conflicts:[]};
    const conflicts=[];
    function scalar(b,l,r,name){if(equal(l,r))return l;if(equal(l,b))return r;if(equal(r,b))return l;conflicts.push(name);return l;}
    function records(b,l,r,name){const bm=new Map((b||[]).map(x=>[x.id,x])),lm=new Map(l.map(x=>[x.id,x])),rm=new Map(r.map(x=>[x.id,x]));const out=[];
      for(const id of new Set([...rm.keys(),...lm.keys(),...bm.keys()])){const bv=bm.get(id),lv=lm.get(id),rv=rm.get(id);let v;
        if(lv && rv && bv){v={id};for(const k of new Set([...Object.keys(bv),...Object.keys(lv),...Object.keys(rv)]))v[k]=scalar(bv[k],lv[k],rv[k],(lv.title||lv.label||id)+' · '+k);}
        else v=scalar(bv,lv,rv,name+' · '+(lv?.title||rv?.title||id));
        if(v)out.push(v);
      }return out;
    }
    const empty={books:[],rate:10000,tariffs:[]};const b=base||empty;
    const value={books:records(b.books,local.books,remote.books,'Kitob'),rate:scalar(b.rate,local.rate,remote.rate,'Kg narxi'),tariffs:records(b.tariffs,local.tariffs,remote.tariffs,'Tarif')};
    return {value,conflicts};
  }
  return {snapshot,merge,equal};
});
