(function(root,factory){const api=factory();if(typeof module==='object' && module.exports)module.exports=api;else root.ReadingDeviceSync=api;})(typeof window==='object'?window:this,function(){
  const stable=v=>JSON.stringify(v,function(k,v){return v && typeof v==='object' && !Array.isArray(v)?Object.keys(v).sort().reduce((o,k)=>(o[k]=v[k],o),{}):v;});
  const equal=(a,b)=>stable(a)===stable(b);
  const fields=['id','title','author','category','publisher','isbn','description','publishedYear','statusOverride','cover','pages','currentPage','startedAt','finishedAt','rating','notes','readingLog','createdAt','updatedAt'];
  const profileFields=['yearlyGoal','dailyPageGoal','dailyMinutesGoal','dailyPlanBookId','customCategories'];
  function snapshot(state){return JSON.parse(JSON.stringify({books:state.books.map(b=>Object.fromEntries(fields.filter(k=>b[k]!==undefined).map(k=>[k,b[k]]))),profile:Object.fromEntries(profileFields.map(k=>[k,state.profile[k]]))}));}
  function merge(base,local,remote,initial){
    if(!remote)return {value:local,conflicts:[]};
    const b=base||initial||{books:[],profile:{}},conflicts=[];
    function scalar(b,l,r,label){if(equal(l,r))return l;if(equal(l,b))return r;if(equal(r,b))return l;conflicts.push(label);return l;}
    function logs(b,l,r,label){
      const group=arr=>{const m=new Map();for(const x of arr||[])m.set(x.date,[...(m.get(x.date)||[]),x]);return m;};
      const bm=group(b),lm=group(l),rm=group(r),out=[];
      for(const date of [...new Set([...bm.keys(),...lm.keys(),...rm.keys()])].sort())out.push(...(scalar(bm.get(date),lm.get(date),rm.get(date),label+' · '+date)||[]));
      return out;
    }
    const bm=new Map(b.books.map(x=>[x.id,x])),lm=new Map(local.books.map(x=>[x.id,x])),rm=new Map(remote.books.map(x=>[x.id,x]));
    const books=[];
    for(const id of new Set([...rm.keys(),...lm.keys(),...bm.keys()])){
      const bv=bm.get(id),lv=lm.get(id),rv=rm.get(id);let v;
      if(bv && lv && rv){v={};for(const k of fields){
        if(k==='updatedAt'){v[k]=[lv[k],rv[k]].filter(Boolean).sort().at(-1);continue;}
        v[k]=k==='readingLog'?logs(bv[k],lv[k],rv[k],lv.title+' · Mutolaa tarixi'):scalar(bv[k],lv[k],rv[k],lv.title+' · '+k);
      }}else v=scalar(bv,lv,rv,lv?.title||rv?.title||id);
      if(v)books.push(v);
    }
    const profile={};for(const k of profileFields)profile[k]=scalar(b.profile?.[k],local.profile?.[k],remote.profile?.[k],'Mutolaa rejasi · '+k);
    return {value:{books,profile},conflicts};
  }
  return {snapshot,merge,equal};
});
