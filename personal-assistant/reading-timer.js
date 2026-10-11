(function(root,factory){const api=factory();if(typeof module==='object' && module.exports)module.exports=api;else root.ReadingTimer=api;})(typeof window==='object'?window:this,function(){
  function elapsed(session,now=Date.now()){return session?Math.max(0,now-session.startedAt):0;}
  function clock(ms){const seconds=Math.floor(Math.max(0,ms)/1000);return String(Math.floor(seconds/60)).padStart(2,'0')+':'+String(seconds%60).padStart(2,'0');}
  function restore(raw,books,lastSaved='',now=Date.now()){
    let s;try{s=typeof raw==='string'?JSON.parse(raw):raw;}catch(_){return null;}
    if(!s || typeof s.sessionId!=='string' || !s.sessionId || s.sessionId===lastSaved || typeof s.bookId!=='string' || !books.some(b=>b.id===s.bookId) || !Number.isSafeInteger(s.startedAt) || s.startedAt<0 || s.startedAt>now)return null;
    return {sessionId:s.sessionId,bookId:s.bookId,startedAt:s.startedAt};
  }
  function dailyMinutes(start,end){
    if(!Number.isFinite(start) || !Number.isFinite(end) || end-start<1000)return [];
    const parts=[];let cursor=start;
    while(cursor<end){const d=new Date(cursor),next=new Date(d.getFullYear(),d.getMonth(),d.getDate()+1).getTime();const until=Math.min(end,next);
      const date=d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0');const exact=(until-cursor)/60000;
      parts.push({date,minutes:Math.floor(exact),fraction:exact%1});cursor=until;
    }
    let remaining=Math.ceil((end-start)/60000)-parts.reduce((n,p)=>n+p.minutes,0);
    for(const p of [...parts].sort((a,b)=>b.fraction-a.fraction || b.date.localeCompare(a.date))){if(remaining--<=0)break;p.minutes++;}
    return parts.filter(p=>p.minutes>0).map(({date,minutes})=>({date,minutes}));
  }
  return {elapsed,clock,restore,dailyMinutes};
});
