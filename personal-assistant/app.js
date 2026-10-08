(() => {
  'use strict';

  const STORAGE_KEY = 'bek_personal_assistant_v4';
  const LEGACY_KEYS = ['bek_personal_assistant_v3','bek_personal_assistant_v2','shaxsiy_yordamchi','personalAssistantData'];
  const $ = (id) => document.getElementById(id);
  const qsa = (selector, root=document) => [...root.querySelectorAll(selector)];
  const nowYear = new Date().getFullYear();

  const DEFAULT_CATEGORIES = ['Roman','Diniy','Tarixiy','Psixologiya','Motivatsiya','Shaxsiy rivojlanish','Detektiv','Badiiy adabiyot'];

  const defaultState = () => ({
    version: 4,
    profile: {
      name: 'Mohirbek Ismoilov',
      yearlyGoal: 24,
      theme: 'light',
      reminderTime: '08:00',
      customCategories: []
    },
    books: [],
    transactions: []
  });

  let state = loadState();
  let currentView = 'home';
  const viewStack = [];
  let selectedBookId = null;
  let bookFilter = 'all';
  let financePeriod = 'month';
  let financeCurrency = 'KRW';
  let statTab = 'general';
  let calendarDate = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
  let selectedCalendarDay = today();
  let pendingCover = '';

  function loadState(){
    for(const key of [STORAGE_KEY, ...LEGACY_KEYS]){
      const raw = localStorage.getItem(key);
      if(!raw) continue;
      try{
        const normalized = normalizeState(JSON.parse(raw));
        localStorage.setItem(STORAGE_KEY, JSON.stringify(normalized));
        return normalized;
      }catch(_){}
    }
    return defaultState();
  }

  function normalizeState(input){
    const base = defaultState();
    const profile = input?.profile || {};
    const books = Array.isArray(input?.books) ? input.books : [];
    const transactions = Array.isArray(input?.transactions) ? input.transactions :
      Array.isArray(input?.finance) ? input.finance : [];

    return {
      version: 4,
      profile: {
        name: String(profile.name || input?.name || base.profile.name),
        yearlyGoal: clampInt(profile.yearlyGoal ?? input?.yearlyGoal ?? 24, 1, 500),
        theme: profile.theme === 'dark' ? 'dark' : 'light',
        reminderTime: /^\d{2}:\d{2}$/.test(profile.reminderTime || '') ? profile.reminderTime : '08:00',
        customCategories: Array.isArray(profile.customCategories) ? profile.customCategories.map(String).filter(Boolean) : []
      },
      books: books.map(b => ({
        id: String(b.id || makeId()),
        title: String(b.title || b.name || '').trim(),
        author: String(b.author || '').trim(),
        category: String(b.category || '').trim(),
        publisher: String(b.publisher || b.nashriyot || '').trim(),
        cover: String(b.cover || b.coverUrl || '').trim(),
        pages: numOrZero(b.pages || b.totalPages),
        currentPage: numOrZero(b.currentPage || b.page),
        startedAt: normalizeDate(b.startedAt || b.startDate || ''),
        finishedAt: normalizeDate(b.finishedAt || b.finishDate || ''),
        rating: clampInt(b.rating || 0, 0, 5),
        notes: String(b.notes || b.note || ''),
        readingLog: Array.isArray(b.readingLog) ? b.readingLog
          .map(x => ({date: normalizeDate(x.date), page: numOrZero(x.page)}))
          .filter(x => x.date) : [],
        createdAt: b.createdAt || new Date().toISOString(),
        updatedAt: b.updatedAt || new Date().toISOString()
      })).filter(b => b.title),
      transactions: transactions.map(t => ({
        id: String(t.id || makeId()),
        type: t.type === 'income' ? 'income' : 'expense',
        currency: t.currency === 'UZS' ? 'UZS' : 'KRW',
        amount: Math.max(0, Number(t.amount) || 0),
        date: normalizeDate(t.date) || today(),
        category: String(t.category || 'Boshqa').trim() || 'Boshqa',
        note: String(t.note || ''),
        createdAt: t.createdAt || new Date().toISOString(),
        updatedAt: t.updatedAt || new Date().toISOString()
      }))
    };
  }

  function saveState(message){
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    renderAll();
    if(message) toast(message);
  }

  function makeId(){ return crypto?.randomUUID?.() || (Date.now().toString(36)+Math.random().toString(36).slice(2)); }
  function clampInt(v,min,max){ const n=Math.round(Number(v)||0); return Math.min(max,Math.max(min,n)); }
  function numOrZero(v){ const n=Number(v); return Number.isFinite(n) && n>0 ? Math.round(n) : 0; }
  function normalizeDate(v){ if(!v) return ''; const s=String(v).slice(0,10); return /^\d{4}-\d{2}-\d{2}$/.test(s)?s:''; }
  function today(){ const d=new Date(); const local=new Date(d.getTime()-d.getTimezoneOffset()*60000); return local.toISOString().slice(0,10); }
  function parseDay(v){ if(!v) return null; const [y,m,d]=v.split('-').map(Number); return new Date(y,m-1,d); }
  function escapeHtml(v){ return String(v??'').replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;').replaceAll("'",'&#039;'); }
  function formatDate(v){ const d=parseDay(v); return d ? new Intl.DateTimeFormat('uz-UZ',{day:'2-digit',month:'short',year:'numeric'}).format(d) : '—'; }
  function monthName(date){ return new Intl.DateTimeFormat('uz-UZ',{month:'long',year:'numeric'}).format(date); }
  function statusOf(book){ if(book.finishedAt) return 'finished'; if(book.startedAt) return 'reading'; return 'wishlist'; }
  function statusLabel(s){ return s==='reading'?'O‘qiyapman':s==='finished'?'Tugatilgan':'Reja qilingan'; }
  function progressOf(book){ if(statusOf(book)==='finished') return 100; if(!book.pages) return 0; return Math.max(0,Math.min(100,Math.round((book.currentPage/book.pages)*100))); }
  function durationDays(book){
    const start=parseDay(book.startedAt); if(!start) return 0;
    const end=parseDay(book.finishedAt)||parseDay(today());
    return Math.max(1,Math.floor((end-start)/86400000)+1);
  }
  function allCategories(){
    return [...new Set([...DEFAULT_CATEGORIES,...state.profile.customCategories,...state.books.map(b=>b.category).filter(Boolean)])];
  }
  function categoryIcon(name){
    const n=name.toLowerCase();
    if(n.includes('dini')) return '♟';
    if(n.includes('tarix')) return '▥';
    if(n.includes('psix')) return '◉';
    if(n.includes('motiv')) return '☀';
    if(n.includes('rivoj')) return '⚑';
    if(n.includes('detek')) return '⌕';
    if(n.includes('roman')) return '▤';
    return '▣';
  }
  function coverHtml(book, cls=''){
    if(book.cover) return '<div class="cover '+cls+'"><img src="'+escapeHtml(book.cover)+'" alt=""></div>';
    return '<div class="cover '+cls+'"><span>'+escapeHtml((book.title||'K').slice(0,1).toUpperCase())+'</span></div>';
  }
  function toast(message){
    const el=$('toast'); el.textContent=message; el.classList.add('show');
    clearTimeout(toast.timer); toast.timer=setTimeout(()=>el.classList.remove('show'),2200);
  }

  function navigate(view, push=true){
    if(view===currentView) return;
    if(push && currentView) viewStack.push(currentView);
    currentView=view;
    qsa('.screen').forEach(el=>el.classList.toggle('active',el.id==='screen-'+view));
    qsa('.bottom-nav button[data-nav]').forEach(btn=>btn.classList.toggle('active',btn.dataset.nav===view));
    const mainViews=['home','library','stats','profile'];
    if(!mainViews.includes(view)) qsa('.bottom-nav button[data-nav]').forEach(btn=>btn.classList.remove('active'));
    window.scrollTo({top:0,behavior:'smooth'});
    if(view==='library') setTimeout(()=>$('bookSearch')?.blur(),0);
    if(view==='detail') renderBookDetail();
    if(view==='calendar') renderCalendar();
    if(view==='categories') renderCategories();
    if(view==='stats') renderStats();
    if(view==='finance') renderFinance();
  }

  function goBack(){
    const back=viewStack.pop() || 'home';
    navigate(back,false);
  }

  function renderAll(){
    applyTheme();
    renderHome();
    renderBooks();
    renderStats();
    renderProfile();
    renderFinance();
    renderCategories();
    if(currentView==='detail') renderBookDetail();
    if(currentView==='calendar') renderCalendar();
    renderCategoryOptions();
  }

  function applyTheme(){
    document.documentElement.dataset.theme=state.profile.theme;
    $('themeLabel').textContent=state.profile.theme==='dark'?'Qorong‘i':'Yorug‘';
  }

  function renderHome(){
    const reading=state.books.filter(b=>statusOf(b)==='reading');
    const finished=state.books.filter(b=>statusOf(b)==='finished');
    const finishedYear=finished.filter(b=>parseDay(b.finishedAt)?.getFullYear()===nowYear);
    const goal=state.profile.yearlyGoal||24;
    $('homeTotalBooks').textContent=state.books.length;
    $('homeReadingBooks').textContent=reading.length;
    $('homeFinishedBooks').textContent=finished.length;
    $('homeGoalRemaining').textContent=Math.max(0,goal-finishedYear.length);

    const holder=$('homeCurrentReading');
    if(!reading.length){
      holder.innerHTML='<div class="empty-state"><strong>Hozir o‘qilayotgan kitob yo‘q</strong>Kitob qo‘shib, mutolaa boshlangan sanani kiriting.</div>';
    } else {
      const book=[...reading].sort((a,b)=>String(b.updatedAt).localeCompare(String(a.updatedAt)))[0];
      const p=progressOf(book);
      holder.innerHTML='<div class="current-book">'+coverHtml(book)+
        '<div><h3>'+escapeHtml(book.title)+'</h3><p>'+escapeHtml(book.author||'Muallif kiritilmagan')+'</p>'+
        '<div class="progress-wrap"><div class="progress-track"><div class="progress-fill" style="width:'+p+'%"></div></div><b>'+p+'%</b></div></div>'+
        '<button class="continue-button" data-book-open="'+book.id+'">Mutolaani davom ettirish →</button></div>';
    }
  }

  function renderBooks(){
    const counts={
      all:state.books.length,
      reading:state.books.filter(b=>statusOf(b)==='reading').length,
      finished:state.books.filter(b=>statusOf(b)==='finished').length,
      wishlist:state.books.filter(b=>statusOf(b)==='wishlist').length
    };
    $('countAll').textContent=counts.all; $('countReading').textContent=counts.reading;
    $('countFinished').textContent=counts.finished; $('countWishlist').textContent=counts.wishlist;

    const q=($('bookSearch')?.value||'').trim().toLowerCase();
    let books=state.books.filter(b=>{
      const hay=[b.title,b.author,b.category,b.publisher,b.notes].join(' ').toLowerCase();
      return (bookFilter==='all'||statusOf(b)===bookFilter) && (!q||hay.includes(q));
    });
    const sort=$('bookSort')?.value||'updated';
    books.sort((a,b)=>{
      if(sort==='title') return a.title.localeCompare(b.title,'uz');
      if(sort==='started') return (b.startedAt||'').localeCompare(a.startedAt||'');
      if(sort==='finished') return (b.finishedAt||'').localeCompare(a.finishedAt||'');
      return String(b.updatedAt||'').localeCompare(String(a.updatedAt||''));
    });

    const list=$('booksList');
    if(!books.length){
      list.innerHTML='<div class="empty-state"><strong>Kitob topilmadi</strong>“+” tugmasi orqali kitob qo‘shing.</div>';
      return;
    }
    list.innerHTML=books.map(book=>{
      const status=statusOf(book), p=progressOf(book);
      const dates=status==='reading'
        ? '<span>'+escapeHtml(book.startedAt||'')+'</span>'
        : status==='finished'
          ? '<span>'+escapeHtml(book.startedAt||'')+' → '+escapeHtml(book.finishedAt||'')+'</span>'
          : '<span>Hali boshlanmagan</span>';
      return '<article class="book-row" data-book-open="'+book.id+'">'+coverHtml(book)+
        '<div><h3>'+escapeHtml(book.title)+'</h3><div class="author">'+escapeHtml(book.author||'Muallif kiritilmagan')+'</div>'+
        '<span class="status-pill '+status+'">'+statusLabel(status)+'</span>'+
        (book.pages?'<div class="progress-wrap"><div class="progress-track"><div class="progress-fill" style="width:'+p+'%"></div></div><b>'+p+'%</b></div>':'')+
        '<div class="book-dates">'+dates+'</div></div>'+
        '<button class="row-menu" data-book-menu="'+book.id+'">⋮</button></article>';
    }).join('');
  }

  function renderBookDetail(){
    const book=state.books.find(b=>b.id===selectedBookId);
    const holder=$('bookDetail');
    if(!book){ holder.innerHTML='<div class="empty-state"><strong>Kitob topilmadi</strong></div>'; return; }
    const status=statusOf(book), p=progressOf(book);
    holder.innerHTML='<div class="detail-top">'+coverHtml(book)+
      '<div class="detail-meta"><h1>'+escapeHtml(book.title)+'</h1><div class="author">'+escapeHtml(book.author||'Muallif kiritilmagan')+'</div>'+
      '<div class="meta-tags">'+[book.category,book.publisher].filter(Boolean).map(x=>'<span>'+escapeHtml(x)+'</span>').join('')+'</div>'+
      '<div class="detail-status-row"><span class="status-pill '+status+'">● '+statusLabel(status)+'</span></div></div></div>'+
      '<div class="detail-progress"><div class="detail-progress-head"><span>Mutolaa progressi</span><b>'+p+'%</b></div>'+
      '<div class="progress-track"><div class="progress-fill" style="width:'+p+'%"></div></div>'+
      '<div class="detail-pages">Sahifalar: '+(book.currentPage||0)+(book.pages?' / '+book.pages:'')+'</div></div>'+
      '<div class="detail-date-grid"><div class="detail-date-card"><small>Mutolaa boshlangan sana</small><b>◫ '+(book.startedAt?formatDate(book.startedAt):'Boshlanmagan')+'</b></div>'+
      '<div class="detail-date-card"><small>Mutolaa tugatilgan sana</small><b>◫ '+(book.finishedAt?formatDate(book.finishedAt):'Hali tugatilmagan')+'</b></div></div>'+
      '<article class="content-card detail-notes"><div class="section-title-row"><h2>Shaxsiy izoh</h2><button class="text-action" data-edit-book="'+book.id+'">Tahrirlash</button></div>'+
      '<p>'+escapeHtml(book.notes||'Hali shaxsiy izoh yozilmagan.')+'</p>'+
      (book.rating?'<div class="book-dates"><span>★ '+book.rating+' / 5</span><span>'+durationDays(book)+' kun</span></div>':'')+'</article>'+
      (status==='wishlist'
        ? '<button class="detail-action" data-start-book="'+book.id+'">▶ Mutolaani boshlash</button>'
        : status==='reading'
          ? '<button class="detail-action" data-progress-book="'+book.id+'">▶ Mutolaani davom ettirish</button><button class="detail-secondary" data-finish-book="'+book.id+'">✓ Tugatdim</button>'
          : '<button class="detail-action" data-edit-book="'+book.id+'">Kitob ma’lumotini tahrirlash</button>');
  }

  function openBookDialog(book=null){
    pendingCover=book?.cover||'';
    $('bookDialogTitle').textContent=book?'Kitobni tahrirlash':'Yangi kitob qo‘shish';
    $('bookId').value=book?.id||'';
    $('bookTitle').value=book?.title||'';
    $('bookAuthor').value=book?.author||'';
    $('bookCategory').value=book?.category||'';
    $('bookPublisher').value=book?.publisher||'';
    $('bookPages').value=book?.pages||'';
    $('bookCurrentPage').value=book?.currentPage||'';
    $('bookStartedAt').value=book?.startedAt||'';
    $('bookFinishedAt').value=book?.finishedAt||'';
    $('bookRating').value=String(book?.rating||0);
    $('bookNotes').value=book?.notes||'';
    setCoverPreview(pendingCover);
    updateBookStatusPreview();
    $('bookDialog').showModal();
  }

  function setCoverPreview(src){
    const wrap=$('bookCoverFile').closest('.cover-upload');
    const img=$('coverPreview');
    if(src){ img.src=src; wrap.classList.add('has-image'); }
    else { img.removeAttribute('src'); wrap.classList.remove('has-image'); }
  }

  async function compressImage(file){
    return new Promise((resolve,reject)=>{
      const reader=new FileReader();
      reader.onload=()=>{
        const img=new Image();
        img.onload=()=>{
          const max=700;
          const scale=Math.min(1,max/Math.max(img.width,img.height));
          const canvas=document.createElement('canvas');
          canvas.width=Math.max(1,Math.round(img.width*scale));
          canvas.height=Math.max(1,Math.round(img.height*scale));
          canvas.getContext('2d').drawImage(img,0,0,canvas.width,canvas.height);
          resolve(canvas.toDataURL('image/jpeg',.78));
        };
        img.onerror=reject; img.src=reader.result;
      };
      reader.onerror=reject; reader.readAsDataURL(file);
    });
  }

  function updateBookStatusPreview(){
    const status=statusOf({startedAt:$('bookStartedAt').value,finishedAt:$('bookFinishedAt').value});
    const el=$('bookStatusPreview'); el.className='status-pill '+status; el.textContent=statusLabel(status);
  }

  function addReadingLog(book,date,page){
    book.readingLog=Array.isArray(book.readingLog)?book.readingLog:[];
    const existing=book.readingLog.find(x=>x.date===date);
    if(existing) existing.page=Math.max(existing.page||0,page||0);
    else book.readingLog.push({date,page:page||0});
  }

  function saveBook(event){
    event.preventDefault();
    const id=$('bookId').value;
    const title=$('bookTitle').value.trim();
    if(!title) return toast('Kitob nomini kiriting.');
    const startedAt=$('bookStartedAt').value;
    const finishedAt=$('bookFinishedAt').value;
    if(startedAt&&finishedAt&&parseDay(finishedAt)<parseDay(startedAt)) return toast('Tugatilgan sana boshlangan sanadan oldin bo‘la olmaydi.');

    const pages=numOrZero($('bookPages').value);
    let currentPage=numOrZero($('bookCurrentPage').value);
    if(pages) currentPage=Math.min(currentPage,pages);
    if(finishedAt&&pages) currentPage=pages;

    const existing=state.books.find(b=>b.id===id);
    const book={
      id:existing?.id||makeId(),
      title,
      author:$('bookAuthor').value.trim(),
      category:$('bookCategory').value.trim(),
      publisher:$('bookPublisher').value.trim(),
      cover:pendingCover,
      pages,currentPage,startedAt,finishedAt,
      rating:clampInt($('bookRating').value,0,5),
      notes:$('bookNotes').value.trim(),
      readingLog:existing?.readingLog||[],
      createdAt:existing?.createdAt||new Date().toISOString(),
      updatedAt:new Date().toISOString()
    };
    if(startedAt) addReadingLog(book,startedAt,currentPage);
    if(finishedAt) addReadingLog(book,finishedAt,currentPage);
    if(existing) Object.assign(existing,book); else state.books.unshift(book);
    $('bookDialog').close();
    selectedBookId=book.id;
    saveState(existing?'Kitob yangilandi.':'Kitob qo‘shildi.');
    navigate('detail');
  }

  function startBook(id){
    const book=state.books.find(b=>b.id===id); if(!book) return;
    if(!book.startedAt) book.startedAt=today();
    book.finishedAt='';
    book.updatedAt=new Date().toISOString();
    addReadingLog(book,today(),book.currentPage);
    saveState('Mutolaa boshlandi.');
    selectedBookId=id; renderBookDetail();
  }

  function updateProgress(id){
    const book=state.books.find(b=>b.id===id); if(!book) return;
    const value=prompt('Hozir nechanchi sahifadasiz?'+(book.pages?' Jami: '+book.pages:''),
      String(book.currentPage||''));
    if(value===null) return;
    const n=Math.max(0,Math.round(Number(value)||0));
    book.currentPage=book.pages?Math.min(n,book.pages):n;
    if(!book.startedAt) book.startedAt=today();
    book.updatedAt=new Date().toISOString();
    addReadingLog(book,today(),book.currentPage);
    if(book.pages && book.currentPage>=book.pages){
      if(confirm('Oxirgi sahifaga yetdingiz. Kitobni “Tugatilgan” qilaymi?')) book.finishedAt=today();
    }
    saveState('Mutolaa progressi yangilandi.');
    renderBookDetail();
  }

  function finishBook(id){
    const book=state.books.find(b=>b.id===id); if(!book) return;
    if(!book.startedAt) book.startedAt=today();
    book.finishedAt=today();
    if(book.pages) book.currentPage=book.pages;
    book.updatedAt=new Date().toISOString();
    addReadingLog(book,today(),book.currentPage);
    saveState('Kitob tugatildi.');
    renderBookDetail();
  }

  function deleteBook(id){
    const book=state.books.find(b=>b.id===id); if(!book) return;
    if(!confirm('“'+book.title+'” kitobini o‘chirasizmi?')) return;
    state.books=state.books.filter(b=>b.id!==id);
    saveState('Kitob o‘chirildi.');
    navigate('library');
  }

  function openBookMenu(id){
    const book=state.books.find(b=>b.id===id); if(!book) return;
    const status=statusOf(book);
    openSimple('Kitob amallari',
      '<div class="setting-form"><button class="primary-button" data-simple-action="open" data-id="'+id+'">Kitobni ochish</button>'+
      (status==='wishlist'?'<button class="secondary-button" data-simple-action="start" data-id="'+id+'">Mutolaani boshlash</button>':'')+
      (status==='reading'?'<button class="secondary-button" data-simple-action="progress" data-id="'+id+'">Sahifani yangilash</button><button class="secondary-button" data-simple-action="finish" data-id="'+id+'">Tugatdim</button>':'')+
      '<button class="secondary-button" data-simple-action="edit" data-id="'+id+'">Tahrirlash</button>'+
      '<button class="secondary-button" data-simple-action="delete" data-id="'+id+'">O‘chirish</button></div>');
  }

  function renderStats(){
    const years=[...new Set([nowYear,...state.books.flatMap(b=>[parseDay(b.startedAt)?.getFullYear(),parseDay(b.finishedAt)?.getFullYear()]).filter(Boolean)])].sort((a,b)=>b-a);
    const select=$('statsYear');
    const currentValue=Number(select.value)||nowYear;
    select.innerHTML=years.map(y=>'<option value="'+y+'">Yil: '+y+'</option>').join('');
    select.value=String(years.includes(currentValue)?currentValue:nowYear);
    const year=Number(select.value)||nowYear;
    const finishedYear=state.books.filter(b=>statusOf(b)==='finished'&&parseDay(b.finishedAt)?.getFullYear()===year);
    const reading=state.books.filter(b=>statusOf(b)==='reading');
    const wishlist=state.books.filter(b=>statusOf(b)==='wishlist');
    $('statsTotal').textContent=state.books.length;
    $('statsFinished').textContent=finishedYear.length;
    $('statsReading').textContent=reading.length;
    $('statsWishlist').textContent=wishlist.length;
    $('statsPages').textContent=finishedYear.reduce((s,b)=>s+(b.pages||0),0).toLocaleString('en-US');
    const rated=finishedYear.filter(b=>b.rating>0);
    const avg=rated.length?rated.reduce((s,b)=>s+b.rating,0)/rated.length:0;
    $('statsRating').textContent=avg.toFixed(avg?1:0)+' / 5';
    $('statsThisYear').textContent=finishedYear.length+' ta kitob';
    $('statsMonthlyAvg').textContent=(finishedYear.length/12).toFixed(1)+' ta kitob';

    const chart=$('monthlyChart');
    if(statTab==='genres'){
      renderHorizontalStats(chart,groupCount(finishedYear,b=>b.category||'Boshqa'));
    } else if(statTab==='authors'){
      renderHorizontalStats(chart,groupCount(finishedYear,b=>b.author||'Noma’lum'));
    } else {
      const monthCounts=Array(12).fill(0);
      finishedYear.forEach(b=>{ const d=parseDay(b.finishedAt); if(d) monthCounts[d.getMonth()]++; });
      const max=Math.max(1,...monthCounts);
      const labels=['Yan','Fev','Mar','Apr','May','Iyun','Iyul','Avg','Sen','Okt','Noy','Dek'];
      chart.className='bar-chart';
      chart.innerHTML=monthCounts.map((v,i)=>'<div class="month-bar"><b>'+v+'</b><div class="bar" style="height:'+Math.max(3,(v/max)*135)+'px"></div><span>'+labels[i]+'</span></div>').join('');
    }
  }

  function groupCount(list,getter){
    const m={}; list.forEach(x=>{const k=getter(x);m[k]=(m[k]||0)+1;}); return Object.entries(m).sort((a,b)=>b[1]-a[1]).slice(0,8);
  }

  function renderHorizontalStats(holder,entries){
    holder.className='category-bars';
    if(!entries.length){holder.innerHTML='<div class="empty-state">Ma’lumot yetarli emas.</div>';return;}
    const max=Math.max(...entries.map(x=>x[1]),1);
    holder.innerHTML=entries.map(([k,v])=>'<div class="bar-row"><b>'+escapeHtml(k)+'</b><div class="bar-shell"><div class="bar-fill" style="width:'+((v/max)*100)+'%"></div></div><strong>'+v+'</strong></div>').join('');
  }

  function activityDates(){
    const map=new Map();
    state.books.forEach(book=>{
      (book.readingLog||[]).forEach(x=>map.set(x.date,(map.get(x.date)||'read')));
      if(book.startedAt&&!map.has(book.startedAt)) map.set(book.startedAt,'read');
      if(book.finishedAt) map.set(book.finishedAt,'finish');
    });
    return map;
  }

  function renderCalendar(){
    $('calendarMonthLabel').textContent=monthName(calendarDate);
    const year=calendarDate.getFullYear(), month=calendarDate.getMonth();
    const first=new Date(year,month,1);
    const last=new Date(year,month+1,0);
    const offset=(first.getDay()+6)%7;
    const activity=activityDates();
    let html='';
    for(let i=0;i<offset;i++) html+='<div class="day-cell empty"></div>';
    for(let d=1;d<=last.getDate();d++){
      const key=[year,String(month+1).padStart(2,'0'),String(d).padStart(2,'0')].join('-');
      const type=activity.get(key)||'';
      html+='<button class="day-cell '+type+(key===today()?' today':'')+'" data-calendar-day="'+key+'">'+d+'</button>';
    }
    $('calendarGrid').innerHTML=html;
    renderCalendarDay(selectedCalendarDay);
  }

  function renderCalendarDay(date){
    selectedCalendarDay=date;
    const books=state.books.filter(b=>
      b.startedAt===date||b.finishedAt===date||(b.readingLog||[]).some(x=>x.date===date)
    );
    const holder=$('calendarTodayCard');
    holder.innerHTML='<div class="section-title-row"><div><small>'+escapeHtml(formatDate(date))+'</small><h2>Mutolaa</h2></div></div>'+
      (books.length?books.map(b=>'<div class="current-book" data-book-open="'+b.id+'">'+coverHtml(b)+'<div><h3>'+escapeHtml(b.title)+'</h3><p>'+escapeHtml(b.author||'')+'</p><span class="status-pill '+statusOf(b)+'">'+statusLabel(statusOf(b))+'</span></div></div>').join('')
      :'<div class="empty-state">Bu kunda mutolaa qaydi yo‘q.</div>');
  }

  function renderCategories(){
    const holder=$('categoriesGrid');
    const cats=allCategories();
    holder.innerHTML=cats.map(name=>{
      const count=state.books.filter(b=>(b.category||'')===name).length;
      return '<button class="category-card" data-category="'+escapeHtml(name)+'"><span class="category-icon">'+categoryIcon(name)+'</span><b>'+escapeHtml(name)+'</b><small>'+count+' ta</small></button>';
    }).join('');
  }

  function renderCategoryOptions(){
    $('categoryOptions').innerHTML=allCategories().map(c=>'<option value="'+escapeHtml(c)+'"></option>').join('');
  }

  function renderProfile(){
    $('profileDisplayName').textContent=state.profile.name||'Mohirbek Ismoilov';
    $('reminderSub').textContent='Har kuni '+state.profile.reminderTime;
    const finishedYear=state.books.filter(b=>statusOf(b)==='finished'&&parseDay(b.finishedAt)?.getFullYear()===nowYear).length;
    const goal=state.profile.yearlyGoal||24;
    $('goalMenuSub').textContent=nowYear+' yil uchun '+goal+' ta kitob';
    $('yearGoalSubtitle').textContent=nowYear+'-yilda '+goal+' ta kitob o‘qish';
    $('profileGoalValue').textContent=finishedYear+' / '+goal;
    $('profileGoalFill').style.width=Math.min(100,(finishedYear/goal)*100)+'%';
  }

  function filterTransactions(list,period){
    if(period==='all') return [...list];
    const now=new Date(), start=new Date(now.getFullYear(),now.getMonth(),now.getDate());
    if(period==='week'){const day=(start.getDay()+6)%7;start.setDate(start.getDate()-day);}
    else if(period==='month') start.setDate(1);
    else if(period==='year'){start.setMonth(0,1);}
    return list.filter(t=>{const d=parseDay(t.date);return d&&d>=start&&d<=now;});
  }
  function sumTx(rows,type){return rows.filter(t=>t.type===type).reduce((s,t)=>s+(Number(t.amount)||0),0);}
  function formatMoney(amount,currency,signed=false){
    const value=Math.round(Number(amount)||0), abs=Math.abs(value).toLocaleString('en-US');
    const sign=signed?(value>0?'+':value<0?'−':''):(value<0?'−':'');
    return currency==='UZS'?sign+abs+' so‘m':sign+'₩'+abs;
  }

  function renderFinance(){
    const rows=filterTransactions(state.transactions,financePeriod).filter(t=>t.currency===financeCurrency)
      .sort((a,b)=>b.date.localeCompare(a.date)||String(b.updatedAt).localeCompare(String(a.updatedAt)));
    const income=sumTx(rows,'income'), expense=sumTx(rows,'expense');
    $('finIncome').textContent=formatMoney(income,financeCurrency);
    $('finExpense').textContent=formatMoney(expense,financeCurrency);
    $('finNet').textContent=formatMoney(income-expense,financeCurrency,true);
    qsa('#periodFilters button').forEach(b=>b.classList.toggle('active',b.dataset.period===financePeriod));
    qsa('#currencyToggle button').forEach(b=>b.classList.toggle('active',b.dataset.currency===financeCurrency));

    const grouped={}; rows.filter(t=>t.type==='expense').forEach(t=>grouped[t.category]=(grouped[t.category]||0)+t.amount);
    const entries=Object.entries(grouped).sort((a,b)=>b[1]-a[1]), max=Math.max(1,...entries.map(x=>x[1]));
    $('categoryBreakdown').innerHTML=entries.length?entries.map(([k,v])=>'<div class="bar-row"><b>'+escapeHtml(k)+'</b><div class="bar-shell"><div class="bar-fill" style="width:'+((v/max)*100)+'%"></div></div><strong>'+formatMoney(v,financeCurrency)+'</strong></div>').join('')
      :'<div class="empty-state">Tanlangan davrda chiqim yo‘q.</div>';
    $('txList').innerHTML=rows.length?rows.map(t=>'<article class="tx-item '+t.type+'"><div class="tx-icon">'+(t.type==='income'?'↓':'↑')+'</div><div><div class="tx-title">'+escapeHtml(t.category)+'</div><div class="tx-sub">'+formatDate(t.date)+(t.note?' • '+escapeHtml(t.note):'')+'</div></div><div><div class="tx-amount">'+(t.type==='income'?'+':'−')+formatMoney(t.amount,t.currency)+'</div><div class="tx-actions"><button data-tx-edit="'+t.id+'">Tahrir</button><button data-tx-delete="'+t.id+'">O‘chir</button></div></div></article>').join('')
      :'<div class="empty-state">Tranzaksiya yo‘q.</div>';
  }

  function openTxDialog(tx=null){
    $('txId').value=tx?.id||'';
    $('txType').value=tx?.type||'expense';
    $('txCurrency').value=tx?.currency||financeCurrency;
    $('txAmount').value=tx?.amount||'';
    $('txDate').value=tx?.date||today();
    $('txCategory').value=tx?.category||'';
    $('txNote').value=tx?.note||'';
    $('txDialog').showModal();
  }

  function saveTx(event){
    event.preventDefault();
    const id=$('txId').value, amount=Math.round(Number($('txAmount').value)||0);
    if(amount<=0) return toast('Summani to‘g‘ri kiriting.');
    const existing=state.transactions.find(t=>t.id===id);
    const tx={
      id:existing?.id||makeId(),
      type:$('txType').value==='income'?'income':'expense',
      currency:$('txCurrency').value==='UZS'?'UZS':'KRW',
      amount,date:$('txDate').value||today(),
      category:$('txCategory').value.trim()||'Boshqa',
      note:$('txNote').value.trim(),
      createdAt:existing?.createdAt||new Date().toISOString(),
      updatedAt:new Date().toISOString()
    };
    if(existing) Object.assign(existing,tx); else state.transactions.unshift(tx);
    financeCurrency=tx.currency; $('txDialog').close(); saveState(existing?'Tranzaksiya yangilandi.':'Tranzaksiya qo‘shildi.');
  }

  function openSimple(title,html){
    $('simpleDialogTitle').textContent=title;
    $('simpleDialogBody').innerHTML=html;
    $('simpleDialog').showModal();
  }

  function openGoalDialog(){
    openSimple('Mutolaa maqsadi','<div class="setting-form"><label>Yillik kitob maqsadi<input id="goalInput" type="number" min="1" max="500" value="'+state.profile.yearlyGoal+'"></label><div class="setting-actions"><button class="primary-button" data-save-goal>Saqlash</button></div></div>');
  }
  function openReminderDialog(){
    openSimple('Eslatma','<div class="setting-form"><label>Har kunlik mutolaa vaqti<input id="reminderInput" type="time" value="'+escapeHtml(state.profile.reminderTime)+'"></label><div class="setting-actions"><button class="primary-button" data-save-reminder>Saqlash</button></div></div>');
  }
  function openSettingsDialog(){
    openSimple('Ilova sozlamalari','<div class="setting-form"><label>Profil nomi<input id="profileNameInput" value="'+escapeHtml(state.profile.name)+'"></label><div class="setting-actions"><button class="primary-button" data-save-profile>Saqlash</button></div></div>');
  }
  function openBackupDialog(){
    openSimple('Backup / Sinxronlash','<div class="setting-form"><p style="font-size:.75rem;color:var(--muted);line-height:1.5">Kitoblar, mutolaa progressi va moliya ma’lumotlarini bitta faylga saqlang.</p><button class="primary-button" data-export>Backup olish</button><button class="secondary-button" data-import>Backup tiklash</button></div>');
  }

  function exportBackup(){
    const payload={app:'Bek Shaxsiy Yordamchi',version:4,exportedAt:new Date().toISOString(),data:state};
    const blob=new Blob([JSON.stringify(payload,null,2)],{type:'application/json'});
    const a=document.createElement('a'); a.href=URL.createObjectURL(blob); a.download='yordamchi-backup-'+today()+'.json'; a.click();
    setTimeout(()=>URL.revokeObjectURL(a.href),1000);
  }
  function importBackup(file){
    if(!file) return;
    const reader=new FileReader();
    reader.onload=()=>{try{const parsed=JSON.parse(reader.result);state=normalizeState(parsed.data||parsed);saveState('Backup tiklandi.');}catch(_){toast('Backup fayli yaroqsiz.');}};
    reader.readAsText(file);
  }

  function maybeDailyReminder(){
    const key='yordamchi_reminded_'+today();
    if(localStorage.getItem(key)) return;
    const [h,m]=state.profile.reminderTime.split(':').map(Number);
    const now=new Date();
    if(now.getHours()>h || (now.getHours()===h && now.getMinutes()>=m)){
      const reading=state.books.filter(b=>statusOf(b)==='reading');
      if(reading.length){ setTimeout(()=>toast('📚 Bugungi mutolaani unutmang: '+reading[0].title),800); localStorage.setItem(key,'1'); }
    }
  }

  function bindEvents(){
    document.addEventListener('click',e=>{
      const nav=e.target.closest('[data-nav]'); if(nav){navigate(nav.dataset.nav);return;}
      const back=e.target.closest('[data-back]'); if(back){goBack();return;}
      const add=e.target.closest('[data-add-book]'); if(add){openBookDialog();return;}
      const open=e.target.closest('[data-open]'); if(open){navigate(open.dataset.open);return;}
      const homeFilter=e.target.closest('[data-filter-home]'); if(homeFilter){bookFilter=homeFilter.dataset.filter;qsa('#bookFilters button').forEach(b=>b.classList.toggle('active',b.dataset.filter===bookFilter));navigate('library');renderBooks();return;}
      const bookOpen=e.target.closest('[data-book-open]'); if(bookOpen && !e.target.closest('[data-book-menu]')){selectedBookId=bookOpen.dataset.bookOpen;navigate('detail');return;}
      const menu=e.target.closest('[data-book-menu]'); if(menu){e.stopPropagation();openBookMenu(menu.dataset.bookMenu);return;}
      const edit=e.target.closest('[data-edit-book]'); if(edit){openBookDialog(state.books.find(b=>b.id===edit.dataset.editBook));return;}
      const start=e.target.closest('[data-start-book]'); if(start){startBook(start.dataset.startBook);return;}
      const prog=e.target.closest('[data-progress-book]'); if(prog){updateProgress(prog.dataset.progressBook);return;}
      const finish=e.target.closest('[data-finish-book]'); if(finish){finishBook(finish.dataset.finishBook);return;}
      const cal=e.target.closest('[data-calendar-day]'); if(cal){renderCalendarDay(cal.dataset.calendarDay);return;}
      const cat=e.target.closest('[data-category]'); if(cat){$('bookSearch').value=cat.dataset.category;bookFilter='all';navigate('library');renderBooks();return;}
      const txEdit=e.target.closest('[data-tx-edit]'); if(txEdit){openTxDialog(state.transactions.find(t=>t.id===txEdit.dataset.txEdit));return;}
      const txDelete=e.target.closest('[data-tx-delete]'); if(txDelete){if(confirm('Tranzaksiyani o‘chirasizmi?')){state.transactions=state.transactions.filter(t=>t.id!==txDelete.dataset.txDelete);saveState('Tranzaksiya o‘chirildi.');}return;}

      const simple=e.target.closest('[data-simple-action]');
      if(simple){
        $('simpleDialog').close();
        const id=simple.dataset.id, action=simple.dataset.simpleAction;
        if(action==='open'){selectedBookId=id;navigate('detail');}
        if(action==='start')startBook(id);
        if(action==='progress')updateProgress(id);
        if(action==='finish')finishBook(id);
        if(action==='edit')openBookDialog(state.books.find(b=>b.id===id));
        if(action==='delete')deleteBook(id);
        return;
      }

      if(e.target.closest('[data-save-goal]')){
        state.profile.yearlyGoal=clampInt($('goalInput').value,1,500);$('simpleDialog').close();saveState('Maqsad saqlandi.');return;
      }
      if(e.target.closest('[data-save-reminder]')){
        state.profile.reminderTime=$('reminderInput').value||'08:00';$('simpleDialog').close();saveState('Eslatma vaqti saqlandi.');return;
      }
      if(e.target.closest('[data-save-profile]')){
        state.profile.name=$('profileNameInput').value.trim()||'Mohirbek Ismoilov';$('simpleDialog').close();saveState('Profil yangilandi.');return;
      }
      if(e.target.closest('[data-export]')){exportBackup();return;}
      if(e.target.closest('[data-import]')){$('importInput').click();return;}
    });

    qsa('[data-close]').forEach(btn=>btn.addEventListener('click',()=>$(btn.dataset.close).close()));
    $('bookForm').addEventListener('submit',saveBook);
    $('bookStartedAt').addEventListener('change',updateBookStatusPreview);
    $('bookFinishedAt').addEventListener('change',updateBookStatusPreview);
    $('bookCoverFile').addEventListener('change',async e=>{
      const file=e.target.files?.[0]; if(!file) return;
      try{pendingCover=await compressImage(file);setCoverPreview(pendingCover);}catch(_){toast('Rasmni o‘qib bo‘lmadi.');}
    });
    $('bookSearch').addEventListener('input',renderBooks);
    $('bookSort').addEventListener('change',renderBooks);
    $('bookFilters').addEventListener('click',e=>{
      const btn=e.target.closest('[data-filter]'); if(!btn) return;
      bookFilter=btn.dataset.filter;qsa('#bookFilters button').forEach(b=>b.classList.toggle('active',b===btn));renderBooks();
    });
    $('statsYear').addEventListener('change',renderStats);
    $('statTabs').addEventListener('click',e=>{
      const btn=e.target.closest('[data-stat-tab]');if(!btn)return;
      statTab=btn.dataset.statTab;qsa('#statTabs button').forEach(b=>b.classList.toggle('active',b===btn));renderStats();
    });
    $('prevMonth').addEventListener('click',()=>{calendarDate=new Date(calendarDate.getFullYear(),calendarDate.getMonth()-1,1);renderCalendar();});
    $('nextMonth').addEventListener('click',()=>{calendarDate=new Date(calendarDate.getFullYear(),calendarDate.getMonth()+1,1);renderCalendar();});
    $('addCategoryBtn').addEventListener('click',()=>{
      const name=prompt('Yangi kategoriya nomi:'); if(!name?.trim()) return;
      const clean=name.trim(); if(!state.profile.customCategories.includes(clean))state.profile.customCategories.push(clean);saveState('Kategoriya qo‘shildi.');
    });
    $('goalMenu').addEventListener('click',openGoalDialog);
    $('reminderMenu').addEventListener('click',openReminderDialog);
    $('financeMenu').addEventListener('click',()=>navigate('finance'));
    $('backupMenu').addEventListener('click',openBackupDialog);
    $('settingsMenu').addEventListener('click',openSettingsDialog);
    $('themeMenu').addEventListener('click',()=>{state.profile.theme=state.profile.theme==='dark'?'light':'dark';saveState();});
    $('addTxBtn').addEventListener('click',()=>openTxDialog());
    $('txForm').addEventListener('submit',saveTx);
    $('periodFilters').addEventListener('click',e=>{const b=e.target.closest('[data-period]');if(!b)return;financePeriod=b.dataset.period;renderFinance();});
    $('currencyToggle').addEventListener('click',e=>{const b=e.target.closest('[data-currency]');if(!b)return;financeCurrency=b.dataset.currency;renderFinance();});
    $('importInput').addEventListener('change',e=>{importBackup(e.target.files?.[0]);e.target.value='';});
    $('globalSearchBtn').addEventListener('click',()=>{navigate('library');setTimeout(()=>$('bookSearch').focus(),100);});
    $('bellBtn').addEventListener('click',openReminderDialog);
    $('detailMore').addEventListener('click',()=>selectedBookId&&openBookMenu(selectedBookId));
  }

  if('serviceWorker' in navigator){
    window.addEventListener('load',()=>navigator.serviceWorker.register('./sw.js').catch(()=>{}));
  }

  bindEvents();
  renderAll();
  navigate('home',false);
  maybeDailyReminder();
})();