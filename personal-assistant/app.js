(() => {
  'use strict';

  const STORAGE_KEY = 'bek_personal_assistant_v4';
  const LEGACY_KEYS = ['bek_personal_assistant_v3','bek_personal_assistant_v2','shaxsiy_yordamchi','personalAssistantData'];
  const $ = (id) => document.getElementById(id);
  const qsa = (selector, root=document) => [...root.querySelectorAll(selector)];
  const nowYear = new Date().getFullYear();

  const DEFAULT_CATEGORIES = ['Roman','Diniy','Tarixiy','Psixologiya','Motivatsiya','Shaxsiy rivojlanish','Detektiv','Badiiy adabiyot'];

  // Mohirbekning avval o‘qib bo‘lgan kitoblari. Tugatilgan sana aniq
  // berilmagan joylarda sana bo‘sh qoladi, lekin kitob "Tugatilgan" holatida.
  const READ_LIBRARY_SEED = [
    {id:'history-001',title:'O‘gay ona',author:'Ahmad Lutfiy Qozonchi',category:'Roman',publisher:'Book Media Nashr',publishedYear:2019,pages:192,cover:'https://cdn.asaxiy.uz/asaxiy-content/product/items/desktop/bca82e41ee7b0833588399b1fcd177c720220615114843583200ZYOxYI1iZ.jpg.webp',startedAt:'2022-04-07',finishedAt:''},
    {id:'history-002',title:'Iskanja',author:'Omina Shenliko‘g‘li',category:'Roman',publisher:'Ilm-ziyo-zakovat',publishedYear:2021,pages:224,cover:'https://assets.asaxiy.uz/product/items/desktop/76dc611d6ebaafc66cc0879c71b5db5c2022061213371742964SMVxjjT8cX.jpg.webp',startedAt:'2022-04-15',finishedAt:''},
    {id:'history-003',title:'So‘nggi to‘fon',author:'Ahmad Lutfiy Qozonchi',category:'Roman',publisher:'Yangi Asr Avlodi',publishedYear:2021,pages:208,cover:'https://assets.asaxiy.uz/product/items/desktop/9dcb88e0137649590b755372b040afad20220612153732837805CPkTK5Ue3.jpg.webp',startedAt:'2022-04-22',finishedAt:''},
    {id:'history-004',title:'Hayot yutqazgan joyingdan boshlanar',author:'Mirach Chag‘ri Oqtosh',category:'Shaxsiy rivojlanish',publisher:'Factor Books',publishedYear:2021,pages:240,cover:'https://olcha.uz/image/700x700/products/2022-09-17/mirach-chari-otosh-aet-yutazgan-zhoyingdan-boshlanar-119724-0.jpeg',startedAt:'2022-04-28',finishedAt:''},
    {id:'history-005',title:'Yashash fursati',author:'Mehmet Olaqosh',category:'Diniy',publisher:'Kitobdor Nashr',publishedYear:2022,pages:120,cover:'https://qamar.uz/cdn/shop/files/yashash-fursati-mahmud-olaqosh-_-00000818-1.jpg?v=1754585512',startedAt:'2022-05-14',finishedAt:''},
    {id:'history-006',title:'500 yildan so‘ng',author:'Omina Shenliko‘g‘li',category:'Roman',publisher:'Azon kitoblari',publishedYear:2022,pages:120,cover:'https://assets.asaxiy.uz/product/items/desktop/3fa146219c48a4393aace23e8f3531252022061518071853068KLWlctZFxN.jpg.webp',startedAt:'',finishedAt:''},
    {id:'history-007',title:'Alvido, Vatan!',author:'A’zam Hoshimiy',category:'Roman',publisher:'Azon kitoblari',publishedYear:2020,pages:117,cover:'https://assets.asaxiy.uz/product/items/desktop/62459f4e225e2f4f196c9d42f4ad71112022110517321176002wjMkrBEREV.jpg.webp',startedAt:'',finishedAt:''},
    {id:'history-008',title:'Kaktuslar ham gullaydi',author:'Songul Unsal',category:'Roman',publisher:'Zukko Kitobxon',publishedYear:2022,pages:160,cover:'https://olcha.uz/image/original/products/2022-09-28/songul-unsal-kaktuslar-am-gullaydi-124061-0.jpeg',startedAt:'',finishedAt:''},
    {id:'history-009',title:'Imomning maneken qizi',author:'Omina Shenliko‘g‘li',category:'Roman',publisher:'Azon kitoblari',publishedYear:2021,pages:172,cover:'https://assets.asaxiy.uz/product/items/desktop/f171891aff2c3a9f84532cc5be354cdb2023030318482360283lRTCy1Qzum.jpg.webp',startedAt:'',finishedAt:''},
    {id:'history-010',title:'Iymon va huzun',author:'Said Chamlija',category:'Diniy',publisher:'Muharrir',publishedYear:2021,pages:128,cover:'https://assets.asaxiy.uz/product/items/desktop/8ae659d035234fc38b249672984984cb2022061018364063945jcHRU2ppdE.jpg.webp',startedAt:'',finishedAt:''},
    {id:'history-011',title:'Iqror',author:'Xolid Ertug‘rul',category:'Roman',publisher:'Misbah',publishedYear:2021,pages:160,cover:'https://nashriyot.qamar.uz/cdn/shop/files/14_13.png?v=1734433535&width=416',startedAt:'',finishedAt:''},
    {id:'history-012',title:'Chunki Sen Allohsan',author:'Ali ibn Jobir Fayfiy',category:'Diniy',publisher:'Munir',publishedYear:2021,pages:240,cover:'https://cdn.asaxiy.uz/asaxiy-content/product/items/desktop/d38ee19a4815c4aeba48227913092a6e2022050812210851736PcAqwale7t.jpg.webp',startedAt:'',finishedAt:''},
    {id:'history-013',title:'Jannatga taklifnoma',author:'Adam Uzkusa',category:'Diniy',publisher:'Kitobdor Nashr',publishedYear:2022,pages:128,cover:'https://olcha.uz/image/original/products/2022-03-02/adam-uzkusa-zhannatga-taklifnoma-38930-0.jpeg',startedAt:'',finishedAt:''},
    {id:'history-014',title:'Boshimning toji',author:'Xadicha Kubro Tongar',category:'Diniy',publisher:'Yangi Asr Avlodi',publishedYear:2022,pages:96,cover:'https://assets.asaxiy.uz/product/items/desktop/27669f3f141da48bfe5e6b7aa37c38f92022071213385623478HBoFf7cWum.jpg.webp',startedAt:'',finishedAt:''},
    {id:'history-015',title:'Huzur eshigi',author:'Abdukarim Mirzayev',category:'Shaxsiy rivojlanish',publisher:'Yasira Bookshop',publishedYear:2022,pages:224,cover:'https://cdn.asaxiy.uz/asaxiy-content/product/items/mobile/26657d5ff9020d2abefe558796b995842022061211375152623CkR7Pa2ocq.jpg.webp',startedAt:'',finishedAt:''},
    {id:'history-016',title:'Hayotimiz kengurulari',author:'Sanjar Xo‘ja',category:'Shaxsiy rivojlanish',publisher:'Muharrir nashriyoti',publishedYear:2022,pages:160,cover:'https://cdn.asaxiy.uz/asaxiy-content/product/items/mobile/37a749d808e46495a8da1e5352d03cae2022061214254669310xRZFUClJQm.jpg.webp',startedAt:'',finishedAt:''},
    {id:'history-017',title:'O‘zini qidirgan odam',author:'Xolid Ertug‘rul',category:'Roman',publisher:'Misbah',publishedYear:2021,pages:144,cover:'https://olcha.uz/image/700x700/products/2022-11-10/kholid-erturul-zini-idirgan-odam-167961-0.jpeg',startedAt:'',finishedAt:''},
    {id:'history-018',title:'Katta Shahzoda',author:'Mikoil Adiguzel',category:'Roman',publisher:'Huzur',publishedYear:2024,pages:70,cover:'https://nashriyot.qamar.uz/cdn/shop/files/102.png?v=1733749685&width=416',startedAt:'2024-12-08',finishedAt:''},
    {id:'history-019',title:'Qiyomat va oxirat',author:'Abu Homid G‘azzoliy',category:'Diniy',publisher:'Munir',publishedYear:2022,pages:192,cover:'https://olcha.uz/image/700x700/products/2022-09-24/iemat-va-okhirat-122927-0.jpeg',startedAt:'2024-12-10',finishedAt:'2024-12-13'},
    {id:'history-020',title:'Zalolatdan qutulish',author:'Abu Homid G‘azzoliy',category:'Diniy',publisher:'Munir',publishedYear:2021,pages:96,cover:'https://hilolnashr.uz/image/cache/catalog/001-Kitoblar/003_boshqalar/001_diniy/2022/zalolatdan-qutilish-web-500x750.jpg',startedAt:'2024-12-16',finishedAt:'2024-12-19'},
    {id:'history-021',title:'Men (Bas qil, ey nafs!)',author:'Fotih Duman',category:'Diniy',publisher:'Nasim Kutub',publishedYear:2023,pages:299,cover:'https://assets.asaxiy.uz/product/items/desktop/2f93aebfae41c062f7ee6a140116a74c2025082012461054813QZBWtCwd66.jpg.webp',startedAt:'2025-02-08',finishedAt:'2025-02-13'},
    {id:'history-022',title:'Umringizni o‘g‘irlayotgan illatlar',author:'Oysha Oydo‘g‘du',category:'Shaxsiy rivojlanish',publisher:'Misbah',publishedYear:2024,pages:176,cover:'https://library.softly.uz/files/95a0a06a-16cd-4682-9e56-c2a029bb9ccb.jpg',startedAt:'',finishedAt:''},
    {id:'history-023',title:'Ochlik',author:'Knut Hamsun',category:'Roman',publisher:'Huzur',publishedYear:2025,pages:266,cover:'https://assets.asaxiy.uz/product/main_image/desktop/68107b3a5c31e.jpg.webp',startedAt:'2025-03-29',finishedAt:'2025-04-06'},
    {id:'history-024',title:'O‘limdan keyingi hayot',author:'Reymond Mudi',category:'Psixologiya',publisher:'Tahlil',publishedYear:2025,pages:192,cover:'https://rytfhjvhjxnbhgitowho.supabase.co/storage/v1/object/public/book-covers/covers/1789466629272-370d329f-135c-4445-9a4f-0153fe7a624c-optimized-5062bc32-2e27-4d27-af6a-750286513981-0.jpg',startedAt:'2025-04-07',finishedAt:'2025-04-11'},
    {id:'history-025',title:'Allohga chinakam bandalik',author:'Muhammad Amin Yildirim',category:'Diniy',publisher:'Nasim Kutub',publishedYear:2023,pages:176,cover:'https://olcha.uz/image/675x900/products/supplier/stores/1/2024-02-23/Q4vDvBqnx2koJY6ig7syWduO5pjuMkCzxrCMJ1seaiDXIKtwxVBbK7PxR1aJ.jpg',startedAt:'2025-04-11',finishedAt:'2025-04-17'},
    {id:'history-026',title:'Maymunlar sayyorasi',author:'Pyer Bul',category:'Roman',publisher:'Huzur',publishedYear:2024,pages:225,cover:'https://nashriyot.qamar.uz/cdn/shop/files/33333.png?v=1735975252&width=1946',startedAt:'2025-04-17',finishedAt:'2025-04-25'}
  ];

  // Kitobning umumiy tavsifi shaxsiy o‘qish qaydlaridan alohida saqlanadi.
  const READ_LIBRARY_DESCRIPTIONS = {
    'history-001': "Fotima ismli yosh qizning ikki farzandli otaga turmushga chiqishi orqali o‘gay onalik, mehr-oqibat, tarbiya va oilaviy mas’uliyat haqida hikoya qilinadi.",
    'history-002': "Asarda kommunistik zulm ostida qolgan uyg‘ur musulmon oilasining qismati, diniy va milliy o‘zlikni saqlash yo‘lidagi kurashi tasvirlanadi.",
    'history-003': "Hasan va uning onasi boshiga tushgan qiyinchiliklar, mehrsiz insonlarning zulmi hamda beg‘araz yordam va umidning kuchi haqida roman.",
    'history-004': "Hayotdagi mag‘lubiyat va qiyinchiliklardan keyin qayta kuch topish, sabr, shukr, yaxshilik va kechirimlilik haqida mulohazalar.",
    'history-005': "Og‘ir sinovlar ichida hayoti uchun muhim qaror qabul qilishga majbur bo‘lgan insonlar qismati orqali vaqt va umrning qadrini yoritadi.",
    'history-006': "Omina Shenliko‘g‘lining inson taqdiri va hayotiy tanlovlar haqida o‘ylashga undaydigan badiiy asari.",
    'history-007': "Vatan, ayriliq va insonning o‘z ildizlariga munosabati haqida mulohaza uyg‘otadigan badiiy asar.",
    'history-008': "Ko‘ngildagi iztirob va yo‘qotishlardan keyin ham hayotni davom ettirish, o‘zini tiklash va umidni yo‘qotmaslik haqida.",
    'history-009': "Imomning qizi Fotimaning tanlovlari, oilasi bilan ziddiyatlari va o‘zligini izlash jarayoni orqali tarbiya hamda qadriyatlar masalasi yoritiladi.",
    'history-010': "Tushkunlik, xavotir va umidsizlikni yengishda iymon, sabr, shukr va qalb xotirjamligining o‘rni haqida diniy-ma’rifiy kitob.",
    'history-011': "Xolid Ertug‘rul qalamiga mansub, insonning ichki kechinmalari va hayotiy qarorlari ustida fikr yuritishga chorlaydigan asar.",
    'history-012': "Allohning go‘zal ismlari va sifatlarini tushunish orqali imonni mustahkamlash, Unga yaqinlashish va qalbga taskin topish haqida.",
    'history-013': "Turli mamlakat va e’tiqod vakillarining Islomni qabul qilishiga oid haqiqiy hayotiy hikoyalar to‘plami.",
    'history-014': "Qizlar uchun hayo, iffat, o‘z qadrini bilish va ma’naviy poklik tushunchalarini sodda va tushunarli tarzda yorituvchi kitob.",
    'history-015': "O‘zini anglash, hayotga teranroq nazar tashlash va ko‘ngil xotirjamligiga yetaklovchi savollar hamda kundalik mulohazalar.",
    'history-016': "Jamiyat, kundalik hayot va insoniy munosabatlarga doir kuzatuvlar, savollar hamda tanqidiy mulohazalar jamlangan asar.",
    'history-017': "Inson o‘zini tanishi, o‘zligi va hayotdagi o‘rnini izlashi haqidagi ruhiy-ma’naviy mulohazalarga boy badiiy asar.",
    'history-018': "Kichkina shahzoda ulg‘ayib, qaytadan safarga chiqadi. Asar uning katta bo‘lgach dunyoga va insoniy munosabatlarga boshqa ko‘z bilan qarashi, bolalikdagi poklikni asrash haqidagi falsafiy savollarini yoritadi.",
    'history-019': "Qabr hayoti, Qiyomat va oxiratga oid voqealar Qur’on hamda hadislar asosida bayon qilingan diniy-ma’rifiy risola.",
    'history-020': "Imom G‘azzoliyning haqiqat va ma’rifat izlash yo‘lidagi ruhiy-ilmiy tajribalari, shubha va ishonch haqidagi mulohazalari.",
    'history-021': "Insonning o‘z nafsi bilan kurashi va Aziz Mahmud Xudoiy hayotidan ilhomlangan voqealar orqali ma’naviy poklanish haqida.",
    'history-022': "Inson vaqtini va umrini behuda sarflaydigan odatlarni anglash, ulardan qutulish va mazmunli yashash haqida mulohazalar.",
    'history-023': "Ochlik va qashshoqlik girdobida yashashga urinayotgan yosh ijodkorning ruhiy kechinmalari tasvirlangan psixologik roman.",
    'history-024': "Reymond Mudi klinik o‘limga yaqin tajribalarni boshdan kechirgan odamlarning hikoyalarini tahlil qilib, hayot va o‘lim haqidagi savollarni o‘rtaga qo‘yadi.",
    'history-025': "Ibodat, Allohdan yordam so‘rash va tavakkul tushunchalarini kundalik hayot hamda inson amallari bilan bog‘lab sharhlovchi kitob.",
    'history-026': "Aqlli maymunlar hukmron bo‘lgan g‘ayrioddiy sayyoradagi voqealar orqali insoniyat, jamiyat va ustunlik haqidagi tasavvurlarni so‘roqqa tutuvchi fantastik roman."
  };

  const defaultState = () => ({
    version: 4,
    profile: {
      name: 'Mohirbek Ismoilov',
      yearlyGoal: 24,
      theme: 'light',
      reminderTime: '08:00',
      customCategories: [],
      seedReadLibrary20261008: false,
      seedBookMetadata20261008v2: false,
      seedBookDescriptions20261008v1: false,
      seedBookCatalogSync20261008v3: false
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
  let statsSelectedYear = nowYear;
  let calendarMode = 'year';
  let calendarDate = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
  let selectedCalendarDay = today();
  let pendingCover = '';
  let isbnScanner=null;
  let scannerLibraryPromise=null;
  let scannerBusy=false;
  let photoBusy=false;
  let photoCandidates=[];
  let photoOriginalCover='';
  let photoOcrLibraryPromise=null;
  let photoOperation=0;
  let photoManualSearchRequested=false;

  function loadState(){
    for(const key of [STORAGE_KEY, ...LEGACY_KEYS]){
      const raw = localStorage.getItem(key);
      if(!raw) continue;
      try{
        const normalized = normalizeState(JSON.parse(raw));
        mergeReadLibrarySeed(normalized);
        localStorage.setItem(STORAGE_KEY, JSON.stringify(normalized));
        return normalized;
      }catch(_){}
    }
    const fresh = defaultState();
    mergeReadLibrarySeed(fresh);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(fresh));
    return fresh;
  }

  function titleKey(value){
    return String(value||'')
      .toLowerCase()
      .replace(/[’‘ʻʼ']/g,'')
      .replace(/[^a-z0-9\u0400-\u04ff]+/g,'')
      .trim();
  }

  function mergeReadLibrarySeed(target){
    // Avval saqlangan localStorage yozuvlariga bibliografik yangilanish.
    const catalogSynced=target?.profile?.seedBookCatalogSync20261008v3 === true;
    if(catalogSynced) return false;
    target.books=Array.isArray(target.books)?target.books:[];
    target.profile=target.profile||{};
    const byId=new Map(target.books.map(b=>[b.id,b]));
    const byTitle=new Map(target.books.map(b=>[titleKey(b.title),b]));
    const seedTime='2026-10-08T00:00:00.000Z';
    let changed=false;
    READ_LIBRARY_SEED.forEach((item,index)=>{
      const existing=byId.get(item.id)||byTitle.get(titleKey(item.title));
      const description=READ_LIBRARY_DESCRIPTIONS[item.id]||'';
      if(existing){
        // O‘qish holati, sanalar, joriy sahifa, baho, shaxsiy izoh va log saqlanadi.
        for(const key of ['author','category','publisher','publishedYear','pages']){
          if(item[key] && existing[key]!==item[key]){existing[key]=item[key];changed=true;}
        }
        // Shaxsiy yuklangan data-image muqovasiga tegilmaydi.
        const userUploaded=/^data:image\//i.test(existing.cover||'');
        if(item.cover && !userUploaded && existing.cover!==item.cover){
          existing.cover=item.cover;changed=true;
        }
        if(description && existing.description!==description){existing.description=description;changed=true;}
        return;
      }
      const book={
        ...item,
        id:item.id||('history-'+String(index+1).padStart(3,'0')),
        description,statusOverride:'finished',currentPage:item.pages||0,
        rating:0,notes:'',readingLog:[],createdAt:seedTime,updatedAt:seedTime
      };
      if(item.startedAt) book.readingLog.push({date:item.startedAt,page:0});
      if(item.finishedAt) book.readingLog.push({date:item.finishedAt,page:item.pages||0});
      target.books.push(book);
      byId.set(book.id,book);
      byTitle.set(titleKey(book.title),book);
      changed=true;
    });
    target.profile.seedReadLibrary20261008=true;
    target.profile.seedBookMetadata20261008v2=true;
    target.profile.seedBookDescriptions20261008v1=true;
    target.profile.seedBookCatalogSync20261008v3=true;
    return changed;
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
        customCategories: Array.isArray(profile.customCategories) ? profile.customCategories.map(String).filter(Boolean) : [],
        seedReadLibrary20261008: profile.seedReadLibrary20261008 === true,
        seedBookMetadata20261008v2: profile.seedBookMetadata20261008v2 === true,
        seedBookDescriptions20261008v1: profile.seedBookDescriptions20261008v1 === true,
        seedBookCatalogSync20261008v3: profile.seedBookCatalogSync20261008v3 === true
      },
      books: books.map(b => ({
        id: String(b.id || makeId()),
        title: String(b.title || b.name || '').trim(),
        author: String(b.author || '').trim(),
        category: String(b.category || '').trim(),
        publisher: String(b.publisher || b.nashriyot || '').trim(),
        isbn: String(b.isbn || '').replace(/[^0-9Xx]/g,'').slice(0,13),
        description: String(b.description || '').trim(),
        publishedYear: clampInt(b.publishedYear || b.publishYear || 0, 0, 2100),
        statusOverride: ['wishlist','reading','finished'].includes(b.statusOverride) ? b.statusOverride : '',
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
  function statusOf(book){
    if(book.finishedAt) return 'finished';
    if(['wishlist','reading','finished'].includes(book.statusOverride)) return book.statusOverride;
    if(book.startedAt) return 'reading';
    return 'wishlist';
  }
  function bookFinishedYear(book){
    const date = book.finishedAt || (statusOf(book)==='finished' ? book.startedAt : '');
    return parseDay(date)?.getFullYear() || null;
  }
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
    const letter=escapeHtml((book.title||'K').slice(0,1).toUpperCase());
    if(book.cover) return '<div class="cover '+cls+'"><img loading="lazy" decoding="async" src="'+escapeHtml(book.cover)+'" alt="'+escapeHtml((book.title||'Kitob')+' muqovasi')+'"><span class="cover-fallback" hidden>'+letter+'</span></div>';
    return '<div class="cover '+cls+'"><span>'+letter+'</span></div>';
  }

  document.addEventListener('error',event=>{
    const img=event.target;
    if(img?.tagName!=='IMG' || !img.closest('.cover')) return;
    img.hidden=true;
    const placeholder=img.parentElement?.querySelector('.cover-fallback');
    if(placeholder) placeholder.hidden=false;
  },true);

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
    const finishedYear=finished.filter(b=>bookFinishedYear(b)===nowYear);
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
        ? '<span>◫ '+(book.startedAt?escapeHtml(formatDate(book.startedAt)):'Boshlangan sana kiritilmagan')+'</span>'
        : status==='finished'
          ? '<span>✓ '+(book.finishedAt?escapeHtml(formatDate(book.finishedAt)):'Tugatilgan sana kiritilmagan')+'</span>'+
            (book.startedAt?'<span>▶ '+escapeHtml(formatDate(book.startedAt))+'</span>':'')
          : '<span>Hali boshlanmagan</span>';
      const edition=[book.publisher,book.publishedYear?String(book.publishedYear):'',book.pages?book.pages+' bet':'']
        .filter(Boolean).map(x=>'<span>'+escapeHtml(x)+'</span>').join('');
      return '<article class="book-row" data-book-open="'+book.id+'">'+coverHtml(book)+
        '<div class="book-row-main"><h3>'+escapeHtml(book.title)+'</h3><div class="author">'+escapeHtml(book.author||'Muallif kiritilmagan')+'</div>'+
        (edition?'<div class="book-edition">'+edition+'</div>':'')+
        '<span class="status-pill '+status+'">'+statusLabel(status)+'</span>'+
        (book.pages?'<div class="progress-wrap"><div class="progress-track"><div class="progress-fill" style="width:'+p+'%"></div></div><b>'+p+'%</b></div>':'')+
        '<div class="book-dates">'+dates+'</div></div>'+
        '<button class="row-menu" data-book-menu="'+book.id+'" aria-label="Kitob menyusi"><svg class="ui-icon" aria-hidden="true"><use href="#ico-more"></use></svg></button></article>';
    }).join('');
  }

  function renderBookDetail(){
    const book=state.books.find(b=>b.id===selectedBookId);
    const holder=$('bookDetail');
    if(!book){ holder.innerHTML='<div class="empty-state"><strong>Kitob topilmadi</strong></div>'; return; }
    const status=statusOf(book), p=progressOf(book);
    holder.innerHTML='<div class="detail-top">'+coverHtml(book)+
      '<div class="detail-meta"><h1>'+escapeHtml(book.title)+'</h1><div class="author">'+escapeHtml(book.author||'Muallif kiritilmagan')+'</div>'+
      '<div class="meta-tags">'+[book.category,book.publisher,book.publishedYear?String(book.publishedYear):'',book.pages?book.pages+' bet':'',book.isbn?'ISBN '+book.isbn:''].filter(Boolean).map(x=>'<span>'+escapeHtml(x)+'</span>').join('')+'</div>'+
      '<div class="detail-status-row"><span class="status-pill '+status+'">● '+statusLabel(status)+'</span></div></div></div>'+
      '<div class="detail-progress"><div class="detail-progress-head"><span>Mutolaa progressi</span><b>'+p+'%</b></div>'+
      '<div class="progress-track"><div class="progress-fill" style="width:'+p+'%"></div></div>'+
      '<div class="detail-pages">Sahifalar: '+(book.currentPage||0)+(book.pages?' / '+book.pages:'')+'</div></div>'+
      (book.description?'<article class="content-card detail-notes"><h2>Kitob haqida</h2><p>'+escapeHtml(book.description)+'</p></article>':'')+
      '<div class="detail-date-grid"><div class="detail-date-card"><small>Mutolaa boshlangan sana</small><b>◫ '+(book.startedAt?formatDate(book.startedAt):(status==='finished'?'Sana kiritilmagan':'Boshlanmagan'))+'</b></div>'+
      '<div class="detail-date-card"><small>Mutolaa tugatilgan sana</small><b>◫ '+(book.finishedAt?formatDate(book.finishedAt):(status==='finished'?'Sana kiritilmagan':'Hali tugatilmagan'))+'</b></div></div>'+
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
    $('bookIsbn').value=book?.isbn||'';
    $('bookPublishedYear').value=book?.publishedYear||'';
    $('bookStatusOverride').value=book?.statusOverride||'';
    $('bookPages').value=book?.pages||'';
    $('bookCurrentPage').value=book?.currentPage||'';
    $('bookStartedAt').value=book?.startedAt||'';
    $('bookFinishedAt').value=book?.finishedAt||'';
    $('bookRating').value=String(book?.rating||0);
    $('bookNotes').value=book?.notes||'';
    $('bookDescription').value=book?.description||'';
    $('scanIsbnInput').value=book?.isbn||'';
    photoOperation++;
    photoManualSearchRequested=false;
    photoCandidates=[];
    photoOriginalCover='';
    $('photoPreviewWrap').hidden=true;
    $('photoPreview').removeAttribute('src');
    $('photoSearchText').value='';
    $('photoResults').replaceChildren();
    $('photoCameraInput').value='';
    $('photoGalleryInput').value='';
    $('photoReplaceCover').checked=true;
    setPhotoStatus('Kitob muqovasini rasmga oling yoki galereyadan tanlang.');
    setBookEntryMode('manual');
    setCoverPreview(pendingCover);
    updateBookStatusPreview();
    $('bookDialog').showModal();
  }


  function setScannerStatus(message,isError=false){
    const el=$('scanStatus');
    if(!el) return;
    el.textContent=message;
    el.dataset.error=String(Boolean(isError));
  }

  function setBookEntryMode(mode){
    const scanning=mode==='scanner',photo=mode==='photo',manual=!scanning&&!photo;
    $('bookManualTab').setAttribute('aria-selected',String(manual));
    $('bookScannerTab').setAttribute('aria-selected',String(scanning));
    $('bookPhotoTab').setAttribute('aria-selected',String(photo));
    $('bookManualPanel').hidden=!manual;
    $('bookScannerPanel').hidden=!scanning;
    $('bookPhotoPanel').hidden=!photo;
    if(!scanning) void stopIsbnScanner();
  }

  function normalizedIsbn(input){
    const raw=String(input||'').toUpperCase();
    const candidate=raw.match(/97[89][\s-]*\d(?:[\s-]*\d){9,10}/)?.[0] ||
      raw.match(/(?:\d[\s-]*){9}[\dX]/)?.[0] || raw.trim();
    return candidate.replace(/[^0-9X]/g,'');
  }

  function validIsbn(isbn){
    if(/^\d{13}$/.test(isbn)){
      if(!/^97[89]/.test(isbn)) return false;
      const sum=isbn.split('').reduce((s,c,i)=>s+Number(c)*(i%2?3:1),0);
      return sum%10===0;
    }
    if(/^\d{9}[\dX]$/.test(isbn)){
      const sum=isbn.split('').reduce((s,c,i)=>s+(c==='X'?10:Number(c))*(10-i),0);
      return sum%11===0;
    }
    return false;
  }

  async function stopIsbnScanner(){
    const instance=isbnScanner;
    isbnScanner=null;
    $('scanStopBtn').hidden=true;
    $('scanCameraBtn').disabled=false;
    if(!instance) return;
    try{if(instance.isScanning) await instance.stop();}catch(_){}
    try{await instance.clear();}catch(_){}
  }

  async function loadScannerLibrary(){
    if(window.Html5Qrcode) return;
    if(scannerLibraryPromise) return scannerLibraryPromise;
    scannerLibraryPromise=new Promise((resolve,reject)=>{
      const script=document.createElement('script');
      script.src='https://cdn.jsdelivr.net/npm/html5-qrcode@2.3.8/html5-qrcode.min.js';
      script.async=true;
      script.onload=()=>window.Html5Qrcode?resolve():reject(new Error('Skaner kutubxonasi ochilmadi.'));
      script.onerror=()=>reject(new Error('Skaner yuklanmadi. Internetni tekshiring.'));
      document.head.appendChild(script);
    }).catch(error=>{scannerLibraryPromise=null;throw error;});
    return scannerLibraryPromise;
  }

  async function startIsbnScanner(){
    if(isbnScanner || scannerBusy) return;
    if(!navigator.mediaDevices?.getUserMedia){
      setScannerStatus('Brauzer kameraga ruxsat bermadi. HTTPS orqali kiring yoki ISBNni qo‘lda kiriting.',true);
      return;
    }
    $('scanCameraBtn').disabled=true;
    setScannerStatus('Kamera ishga tushirilmoqda. Ruxsat so‘ralsa, tasdiqlang.');
    try{
      await loadScannerLibrary();
      if(!$('bookDialog').open || $('bookScannerPanel').hidden) return;
      const F=window.Html5QrcodeSupportedFormats;
      isbnScanner=new window.Html5Qrcode('isbnScannerReader',{
        formatsToSupport:[F.EAN_13,F.EAN_8,F.UPC_A,F.QR_CODE,F.CODE_128],
        verbose:false
      });
      await isbnScanner.start(
        {facingMode:'environment'},
        {fps:10,qrbox:{width:230,height:140}},
        text=>{
          const isbn=normalizedIsbn(text);
          if(!validIsbn(isbn)){
            if(!scannerBusy) setScannerStatus('Kod o‘qildi, lekin ISBN aniqlanmadi. 978 yoki 979 bilan boshlanuvchi kitob shtrix-kodini ko‘rsating.',true);
            return;
          }
          if(scannerBusy) return;
          scannerBusy=true;
          $('scanIsbnInput').value=isbn;
          void (async()=>{
            await stopIsbnScanner();
            scannerBusy=false;
            await lookupIsbnAndFill(isbn);
          })();
        },
        ()=>{}
      );
      if(!$('bookDialog').open || $('bookScannerPanel').hidden){
        await stopIsbnScanner();return;
      }
      $('scanStopBtn').hidden=false;
      $('scanCameraBtn').disabled=true;
      setScannerStatus('Kamera tayyor. Kitob orqasidagi ISBN shtrix-kodini ramkaga tuting.');
    }catch(e){
      await stopIsbnScanner();
      setScannerStatus('Kamera ochilmadi. Ruxsatni tekshiring yoki ISBNni qo‘lda kiriting.',true);
    }finally{
      if(!isbnScanner) $('scanCameraBtn').disabled=false;
    }
  }

  function openUzbekIsbnWebSearch(){
    const isbn=normalizedIsbn($('scanIsbnInput').value||$('bookIsbn').value);
    const search=isbn || $('bookTitle').value.trim();
    if(!search){setScannerStatus('Qidirish uchun avval ISBN kiriting.',true);return;}
    const query=isbn?isbn+' kitob nashriyot asaxiy ISBN':search+' kitob O‘zbekiston muqova';
    const url='https://www.google.com/search?q='+encodeURIComponent(query);
    const link=document.createElement('a');
    link.href=url;
    link.target='_blank';
    link.rel='noopener noreferrer';
    link.click();
  }


  async function scanBarcodeFromImage(file){
    if(!file)return;
    if(!file.type.startsWith('image/')){
      setScannerStatus('Shtrix-kod rasmini tanlang.',true);return;
    }
    let reader=null;
    $('scanBarcodePhotoBtn').disabled=true;
    try{
      await stopIsbnScanner();
      setScannerStatus('Rasmdagi shtrix-kod o‘qilmoqda...');
      await loadScannerLibrary();
      if(!$('bookDialog').open)return;
      const F=window.Html5QrcodeSupportedFormats;
      reader=new window.Html5Qrcode('isbnScannerReader',{
        formatsToSupport:[F.EAN_13,F.EAN_8,F.UPC_A,F.QR_CODE,F.CODE_128],verbose:false
      });
      const value=await reader.scanFile(file,true);
      const isbn=normalizedIsbn(value);
      if(!validIsbn(isbn)){
        setScannerStatus('Shtrix-kod o‘qildi, ammo kitob ISBN raqami aniqlanmadi. 978 yoki 979 bilan boshlanuvchi kodni oling.',true);
        return;
      }
      $('scanIsbnInput').value=isbn;
      $('bookIsbn').value=isbn;
      setScannerStatus('ISBN '+isbn+' aniqlandi. Kitob kataloglardan tekshirilmoqda...');
      await lookupIsbnAndFill(isbn);
    }catch(_){
      setScannerStatus('Rasmdan shtrix-kod o‘qilmadi. Yaqinroq va yorug‘roq rasm oling yoki ISBNni qo‘lda kiriting.',true);
    }finally{
      if(reader){try{await reader.clear();}catch(_){}}
      $('scanBarcodePhotoBtn').disabled=false;
    }
  }

  function openPhotoWebSearch(){
    const query=$('photoSearchText').value.trim()||$('bookTitle').value.trim();
    if(!query){
      setPhotoStatus('Avval kitob nomini yozing yoki muqovani rasmga oling.',true);
      $('photoSearchText').focus();
      return;
    }
    const url='https://www.google.com/search?q='+encodeURIComponent(query+' kitob o‘zbekcha nashriyot muqova');
    const link=document.createElement('a');
    link.href=url;
    link.target='_blank';
    link.rel='noopener noreferrer';
    link.click();
  }

  function yearFromText(value){
    const m=String(value||'').match(/(?:18|19|20)\d{2}/g);
    return m?Number(m[m.length-1]):0;
  }

  function plainDescription(value){
    const input=typeof value==='string'?value:(value?.value||'');
    if(!input) return '';
    const doc=new DOMParser().parseFromString(input,'text/html');
    doc.querySelectorAll('script,style,iframe,object').forEach(el=>el.remove());
    return String(doc.body?.textContent||'').replace(/\s+/g,' ').trim().slice(0,1550);
  }

  function httpsImage(value){
    const src=String(value||'').replace(/^http:\/\//,'https://');
    return /^https:\/\//.test(src)?src:'';
  }

  async function fetchIsbnJson(url){
    const controller=new AbortController();
    const timeout=setTimeout(()=>controller.abort(),10000);
    try{
      const response=await fetch(url,{signal:controller.signal});
      if(!response.ok) return null;
      return await response.json();
    }catch(_){return null;}
    finally{clearTimeout(timeout);}
  }

  async function findIsbnMetadata(isbn){
    // Avval shu telefondagi mavjud kitoblarning ISBN ma’lumotlarini tekshiramiz.
    const ownBook=(state.books||[]).find(b=>b.isbn&&normalizedIsbn(b.isbn)===isbn);
    if(ownBook) return {
      title:ownBook.title,author:ownBook.author||'',publisher:ownBook.publisher||'',
      year:Number(ownBook.publishedYear||0),pages:Number(ownBook.pages||0),
      category:ownBook.category||'',description:ownBook.description||'',
      cover:ownBook.cover||''
    };
    // Xalqaro kataloglar O‘zbekistondagi nashrlarni har doim ham qamramaydi.
    const [google,edition,search]=await Promise.all([
      fetchIsbnJson('https://www.googleapis.com/books/v1/volumes?q=isbn:'+encodeURIComponent(isbn)+'&maxResults=10'),
      fetchIsbnJson('https://openlibrary.org/isbn/'+encodeURIComponent(isbn)+'.json'),
      fetchIsbnJson('https://openlibrary.org/search.json?isbn='+encodeURIComponent(isbn)+'&limit=3&fields=title,author_name,publisher,first_publish_year,number_of_pages_median,isbn,cover_i,subject')
    ]);
    const googleItems=Array.isArray(google?.items)?google.items:[];
    const g=googleItems.map(item=>item.volumeInfo||{}).find(v=>
      (v.industryIdentifiers||[]).some(id=>String(id.identifier||'').replace(/[^0-9X]/g,'')===isbn)
    )||null;
    const exactEdition=edition?.title?edition:null;
    const olDocs=Array.isArray(search?.docs)?search.docs:[];
    const s=olDocs.find(d=>d.isbn?.includes(isbn))||null;
    let olAuthor='';
    if(exactEdition?.authors?.length){
      const authorKey=exactEdition.authors[0]?.key;
      if(authorKey?.startsWith('/authors/')){
        const a=await fetchIsbnJson('https://openlibrary.org'+authorKey+'.json');
        olAuthor=a?.name||'';
      }
    }
    const title=exactEdition?.title||g?.title||s?.title||'';
    const coverId=exactEdition?.covers?.find(n=>Number(n)>0);
    const urlFromId=coverId?'https://covers.openlibrary.org/b/id/'+coverId+'-L.jpg':'';
    const img=g?.imageLinks||{};
    const image=httpsImage(urlFromId||img.extraLarge||img.large||img.medium||img.thumbnail||img.smallThumbnail||(s?.cover_i?'https://covers.openlibrary.org/b/id/'+s.cover_i+'-L.jpg':''));
    return {
      title,
      author:(Array.isArray(g?.authors)?g.authors.join(', '):'')||olAuthor||(Array.isArray(s?.author_name)?s.author_name.join(', '):''),
      publisher:(exactEdition?.publishers?.[0]||g?.publisher||s?.publisher?.[0]||''),
      year:yearFromText(exactEdition?.publish_date)||yearFromText(g?.publishedDate)||0,
      pages:Number(exactEdition?.number_of_pages||g?.pageCount||s?.number_of_pages_median||0),
      category:g?.categories?.[0]||'',
      description:plainDescription(g?.description||exactEdition?.description),
      cover:image
    };
  }

  async function lookupIsbnAndFill(input){
    const isbn=normalizedIsbn(input);
    if(!validIsbn(isbn)){
      setScannerStatus('ISBN raqami noto‘g‘ri. 10 yoki 13 xonali haqiqiy ISBN kiriting.',true);
      return;
    }
    if(scannerBusy)return;
    scannerBusy=true;
    $('scanLookupBtn').disabled=true;
    $('scanIsbnInput').value=isbn;
    $('bookIsbn').value=isbn;
    await stopIsbnScanner();
    setScannerStatus('ISBN '+isbn+' bo‘yicha kitob qidirilmoqda...');
    try{
      const info=await findIsbnMetadata(isbn);
      if(!info.title){
        setScannerStatus('Bu ISBN xalqaro kataloglardan topilmadi. “O‘zbek saytlardan qidirish” yoki “Muqovadan qidirish” tugmasidan foydalaning. ISBN saqlandi.',true);
        return;
      }
      const values={
        bookTitle:info.title,bookAuthor:info.author,bookPublisher:info.publisher,
        bookPublishedYear:info.year,bookPages:info.pages,bookCategory:info.category,
        bookDescription:info.description
      };
      for(const [id,value] of Object.entries(values)){
        if(value && (!$('bookId').value || !$(id).value)){
          $(id).value=String(value);
        }
      }
      const fromCoverPhoto=photoOriginalCover && pendingCover===photoOriginalCover;
      if(info.cover && (!pendingCover || (fromCoverPhoto && $('photoReplaceCover').checked))){
        pendingCover=info.cover;
        setCoverPreview(pendingCover);
      }
      setBookEntryMode('manual');
      toast('Kitob topildi! Ma’lumotlarni tekshirib saqlang.');
    }catch(_){
      setScannerStatus('Qidiruvda xatolik. Internetni tekshiring yoki qo‘lda kiriting.',true);
    }finally{
      scannerBusy=false;
      $('scanLookupBtn').disabled=false;
    }
  }


  function setPhotoStatus(message,isError=false){
    const el=$('photoStatus');
    if(!el) return;
    el.textContent=message;
    el.dataset.error=String(Boolean(isError));
  }

  async function loadPhotoOcrLibrary(){
    if(window.Tesseract?.createWorker) return;
    if(photoOcrLibraryPromise) return photoOcrLibraryPromise;
    photoOcrLibraryPromise=new Promise((resolve,reject)=>{
      const script=document.createElement('script');
      script.async=true;
      script.src='https://cdn.jsdelivr.net/npm/tesseract.js@5.1.1/dist/tesseract.min.js';
      script.onload=()=>window.Tesseract?.createWorker?resolve():reject(new Error('Matn aniqlash kutubxonasi yuklanmadi.'));
      script.onerror=()=>reject(new Error('OCR kutubxonasi yuklanmadi.'));
      document.head.appendChild(script);
    }).catch(error=>{photoOcrLibraryPromise=null;throw error;});
    return photoOcrLibraryPromise;
  }

  function cleanCoverText(text){
    return String(text||'').replace(/[^\p{L}\p{N}\s'‘’ʻʼ.,:!()\-]/gu,' ')
      .replace(/\s+/g,' ').trim();
  }

  function extractCoverSearchTerm(text){
    const lines=String(text||'').split(/\r?\n/)
      .map(cleanCoverText)
      .filter(line=>line.length>=3 && line.length<=90 &&
        !/^(isbn|www\.|http|nashriyot|publish|kitoblar|copyright|©)/i.test(line) &&
        /[\p{L}]{3}/u.test(line));
    const unique=[...new Set(lines)];
    return unique.slice(0,3).join('\n').slice(0,135);
  }

  async function loadCoverPhoto(file){
    if(!file) return;
    if(!file.type.startsWith('image/')){
      setPhotoStatus('Faqat rasm faylini tanlang.',true);return;
    }
    if(file.size>20*1024*1024){
      setPhotoStatus('Rasm juda katta. 20 MB dan kichik rasm tanlang.',true);return;
    }
    const ticket=++photoOperation;
    photoManualSearchRequested=false;
    photoCandidates=[];
    $('photoResults').replaceChildren();
    $('photoSearchText').value='';
    // OCR sekin yuklansa ham foydalanuvchining matn bilan qidirish tugmasi faol qoladi.
    $('photoFindBtn').disabled=false;
    photoBusy=true;
    let worker=null;
    setPhotoStatus('Rasm tayyorlanmoqda...');
    try{
      const cover=await compressImage(file);
      if(ticket!==photoOperation || !$('bookDialog').open) return;
      photoOriginalCover=cover;
      if(!$('bookId').value || !pendingCover){pendingCover=cover;setCoverPreview(pendingCover);}
      $('photoPreview').src=cover;
      $('photoPreviewWrap').hidden=false;
      setPhotoStatus('Muqovadagi yozuv aniqlanmoqda. Birinchi urinish biroz vaqt olishi mumkin...');
      await loadPhotoOcrLibrary();
      if(ticket!==photoOperation || !$('bookDialog').open) return;
      worker=await window.Tesseract.createWorker(['eng','rus'],1);
      const result=await worker.recognize(file);
      if(ticket!==photoOperation || !$('bookDialog').open) return;
      const raw=String(result?.data?.text||'').trim();
      const possibleIsbn=raw.match(/(?:97[89][\s-]*)?(?:\d[\s-]*){9}[\dX]/i)?.[0];
      if(possibleIsbn && validIsbn(normalizedIsbn(possibleIsbn))){
        const isbn=normalizedIsbn(possibleIsbn);
        $('scanIsbnInput').value=isbn;
        $('bookIsbn').value=isbn;
        setPhotoStatus('Rasmdan ISBN topildi: '+isbn+'. Katalog tekshirilmoqda...');
        await lookupIsbnAndFill(isbn);
        return;
      }
      const guess=extractCoverSearchTerm(raw);
      if(photoManualSearchRequested || $('photoSearchText').value.trim())return;
      $('photoSearchText').value=guess;
      if(!guess){
        setPhotoStatus('Rasmdagi yozuvni aniqlab bo‘lmadi. Kitob nomini pastga qo‘lda yozib qidiring.',true);
        return;
      }
      setPhotoStatus('Matn aniqlandi. Topilgan nomni tekshiring, kerak bo‘lsa tahrirlang.');
      await findCoverByText(guess,ticket);
    }catch(error){
      if(ticket===photoOperation && $('bookDialog').open && !photoManualSearchRequested)
        setPhotoStatus('Rasmdagi yozuvni o‘qib bo‘lmadi. Kitob nomini qo‘lda yozib qidiring.',true);
    }finally{
      if(worker){try{await worker.terminate();}catch(_){}}
      if(ticket===photoOperation){photoBusy=false;}
    }
  }

  function bookMatchKey(value){
    // O‘zbek kirill va lotin kitob nomlarini bir xil shaklga keltiramiz.
    const cyr={а:'a',б:'b',в:'v',г:'g',ғ:'g',д:'d',е:'e',ё:'yo',ж:'j',з:'z',
      и:'i',й:'y',к:'k',қ:'q',л:'l',м:'m',н:'n',о:'o',п:'p',р:'r',с:'s',т:'t',
      у:'u',ф:'f',х:'x',ҳ:'h',ц:'ts',ч:'ch',ш:'sh',щ:'sh',ъ:'',ь:'',ы:'i',
      э:'e',ю:'yu',я:'ya',ў:'o',і:'i'};
    return String(value||'').toLocaleLowerCase()
      .replace(/[\u0400-\u052f]/g,ch=>cyr[ch]??ch).normalize('NFD')
      .replace(/[\u0300-\u036f]/g,'')
      .replace(/[‘’ʻʼ']/g,'').replace(/[^\p{L}\p{N}]+/gu,' ').trim();
  }

  function localBookCandidates(query){
    const queryLines=String(query||'').split(/[\r\n]+/).map(bookMatchKey).filter(Boolean);
    const complete=bookMatchKey(query);
    const words=complete.split(' ').filter(w=>w.length>=3);
    const candidates=[...(state?.books||[]),...READ_LIBRARY_SEED];
    const unique=new Map(),found=[];
    for(const item of candidates){
      const title=bookMatchKey(item.title);
      if(!title||unique.has(title))continue;
      unique.set(title,true);
      const titleWords=title.split(' ').filter(w=>w.length>=3);
      if(!titleWords.length)continue;
      const exactLine=queryLines.some(line=>line===title||line.includes(title));
      const matched=titleWords.filter(w=>words.includes(w)||complete.includes(w)).length;
      const coverage=matched/titleWords.length;
      if(!exactLine && (matched<1||coverage<0.65))continue;
      const score=(exactLine?80:40)+matched*6+bookMatchScore(query,item);
      found.push({
        title:item.title,author:item.author||'',publisher:item.publisher||'',
        year:Number(item.publishedYear||0),pages:Number(item.pages||0),
        category:item.category||'',description:item.description||READ_LIBRARY_DESCRIPTIONS[item.id]||'',
        isbn:item.isbn||'',cover:item.cover||'',score,source:'shaxsiy kutubxona'
      });
    }
    return found.sort((a,b)=>b.score-a.score).slice(0,8);
  }

  function bookMatchScore(query,record){
    const words=bookMatchKey(query).split(' ').filter(s=>s.length>=3);
    const title=bookMatchKey(record.title),author=bookMatchKey(record.author);
    const matches=words.filter(word=>title.includes(word)).length;
    const authorMatches=words.filter(word=>author.includes(word)).length;
    return matches*3+authorMatches+(title.length?1:0);
  }

  async function findCoverCandidates(query){
    const q=cleanCoverText(query).slice(0,150);
    if(q.length<3) return [];
    const local=localBookCandidates(q);
    if(local.length && local[0].score>=80) return local;
    const [google,openlib]=await Promise.all([
      fetchIsbnJson('https://www.googleapis.com/books/v1/volumes?q='+encodeURIComponent(q)+'&maxResults=18&printType=books'),
      fetchIsbnJson('https://openlibrary.org/search.json?q='+encodeURIComponent(q)+'&limit=16&fields=title,author_name,publisher,first_publish_year,number_of_pages_median,isbn,cover_i')
    ]);
    const results=[...local];
    for(const entry of google?.items||[]){
      const v=entry?.volumeInfo||{};
      if(!v.title) continue;
      const ident=(v.industryIdentifiers||[]).map(o=>normalizedIsbn(o.identifier)).find(validIsbn)||'';
      const images=v.imageLinks||{};
      results.push({
        title:v.title,author:(v.authors||[]).join(', '),
        publisher:v.publisher||'',year:yearFromText(v.publishedDate),pages:Number(v.pageCount||0),
        category:(v.categories||[])[0]||'',description:plainDescription(v.description),
        isbn:ident,
        cover:httpsImage(images.extraLarge||images.large||images.medium||images.thumbnail||images.smallThumbnail)
      });
    }
    for(const entry of openlib?.docs||[]){
      if(!entry?.title) continue;
      results.push({
        title:entry.title,author:(entry.author_name||[]).join(', '),
        publisher:(entry.publisher||[])[0]||'',year:Number(entry.first_publish_year||0),
        pages:Number(entry.number_of_pages_median||0),category:'',description:'',
        isbn:(entry.isbn||[]).map(normalizedIsbn).find(validIsbn)||'',
        cover:entry.cover_i?'https://covers.openlibrary.org/b/id/'+entry.cover_i+'-L.jpg':''
      });
    }
    const unique=new Map();
    for(const rec of results){
      const key=bookMatchKey(rec.title)+'|'+bookMatchKey(rec.author).slice(0,40);
      if(!key.trim()||unique.has(key))continue;
      rec.score=bookMatchScore(q,rec);
      unique.set(key,rec);
    }
    return [...unique.values()].sort((a,b)=>b.score-a.score).slice(0,12);
  }

  function showCoverCandidates(results){
    photoCandidates=results;
    const holder=$('photoResults');
    if(!results.length){
      holder.innerHTML='<p class="photo-empty">Mos kitob topilmadi. Qidiruv matnini o‘zgartirib qayta urinib ko‘ring yoki qo‘lda kiriting.</p>';
      return;
    }
    holder.innerHTML='<strong class="photo-results-heading">Topilgan kitoblar — mosini tanlang</strong>'+
      results.map((item,i)=>'<button type="button" class="photo-result" data-photo-result="'+i+'">'+
      (item.cover?'<img loading="lazy" src="'+escapeHtml(item.cover)+'" alt="">':'<span class="photo-result-no-cover">📖</span>')+
      '<span class="photo-result-text"><b>'+escapeHtml(item.title)+'</b><small>'+escapeHtml(item.author||'Muallif noma’lum')+'</small>'+
      '<small>'+escapeHtml([item.publisher,item.year||''].filter(Boolean).join(' · '))+'</small></span>'+
      '<span class="photo-result-arrow">›</span></button>').join('');
  }

  async function findCoverByText(text,expectedTicket=photoOperation){
    const q=cleanCoverText(text);
    if(q.length<3){
      setPhotoStatus('Qidirish uchun kitob nomini kiriting.',true);return;
    }
    $('photoFindBtn').disabled=true;
    setPhotoStatus('Google Books va Open Library kataloglaridan mos kitoblar izlanmoqda...');
    try{
      let matches=await findCoverCandidates(q);
      if(!matches.length){
        const lines=String(text||'').split(/[\r\n]+/)
          .map(cleanCoverText).filter(line=>line.length>=4);
        const alternatives=[...new Set([...lines,q.split(/\s+/).slice(0,4).join(' ')])]
          .filter(part=>part&&part!==q).slice(0,3);
        for(const part of alternatives){
          const extra=await findCoverCandidates(part);
          if(extra.length){matches=extra;break;}
        }
      }
      if(expectedTicket!==photoOperation || !$('bookDialog').open) return;
      showCoverCandidates(matches);
      setPhotoStatus(matches.length
        ?matches.length+' ta variant topildi. To‘g‘ri kitobni tanlang.'
        :'Kitob topilmadi. Nom yoki muallifni tuzatib qayta urinib ko‘ring.',!matches.length);
    }catch(_){
      if(expectedTicket===photoOperation) setPhotoStatus('Internetdan qidirib bo‘lmadi. Keyinroq urinib ko‘ring.',true);
    }finally{
      if(expectedTicket===photoOperation) $('photoFindBtn').disabled=false;
    }
  }

  function chooseCoverCandidate(index){
    const item=photoCandidates[index];
    if(!item)return;
    // Qo‘lda kiritilgan yozuvlar, shaxsiy izoh va mutolaa holati saqlanadi.
    const fields={
      bookTitle:item.title,bookAuthor:item.author,bookPublisher:item.publisher,
      bookPublishedYear:item.year,bookPages:item.pages,bookCategory:item.category,
      bookDescription:item.description,bookIsbn:item.isbn
    };
    for(const [id,value] of Object.entries(fields)){
      if(value && (!$('bookId').value || !$(id).value)) $(id).value=String(value);
    }
    if(item.isbn) $('scanIsbnInput').value=item.isbn;
    if(item.cover && $('photoReplaceCover').checked){
      pendingCover=item.cover;
      setCoverPreview(pendingCover);
    }else if(photoOriginalCover && !pendingCover){
      pendingCover=photoOriginalCover;
      setCoverPreview(pendingCover);
    }
    setBookEntryMode('manual');
    toast('Kitob tanlandi. Ma’lumotlarni tekshiring va saqlang.');
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
    const status=statusOf({
      startedAt:$('bookStartedAt').value,
      finishedAt:$('bookFinishedAt').value,
      statusOverride:$('bookStatusOverride').value
    });
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
    const statusOverride=$('bookStatusOverride').value;
    if((finishedAt||statusOverride==='finished')&&pages) currentPage=pages;

    const existing=state.books.find(b=>b.id===id);
    const book={
      id:existing?.id||makeId(),
      title,
      author:$('bookAuthor').value.trim(),
      category:$('bookCategory').value.trim(),
      publisher:$('bookPublisher').value.trim(),
      isbn:$('bookIsbn').value.replace(/[^0-9Xx]/g,''),
      publishedYear:clampInt($('bookPublishedYear').value,0,2100),
      statusOverride,
      cover:pendingCover,
      pages,currentPage,startedAt,finishedAt,
      rating:clampInt($('bookRating').value,0,5),
      notes:$('bookNotes').value.trim(),
      description:$('bookDescription').value.trim(),
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
    book.statusOverride='';
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
    book.statusOverride='';
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

  // Faqat foydalanuvchi kiritgan real sanalar asosida yillik natija hisoblanadi.
  function datedReadingYears(){
    // Faqat foydalanuvchining haqiqiy boshlash/tugatish va mutolaa qaydi bor yillar.
    // Kalendarda oldinga-orqaga yurish menyuga yangi, bo‘sh yillar qo‘shmaydi.
    const years=new Set();
    for(const book of state.books){
      const dates=[book.startedAt,book.finishedAt,...(Array.isArray(book.readingLog)?book.readingLog.map(entry=>entry.date):[])];
      for(const date of dates){
        const value=String(date||'');
        if(!/^\d{4}-\d{2}-\d{2}$/.test(value))continue;
        const [y,m,d]=value.split('-').map(Number);
        if(y<1900||y>2100||m<1||m>12||d<1||d>31)continue;
        const parsed=new Date(y,m-1,d);
        if(parsed.getFullYear()===y&&parsed.getMonth()===m-1&&parsed.getDate()===d)years.add(y);
      }
    }
    return [...years].sort((x,y)=>y-x);
  }

  function syncYearSelect(element,year){
    const years=datedReadingYears();
    const signature=years.join(',');
    if(element.dataset.years!==signature){
      element.innerHTML=years.length
        ? years.map(y=>'<option value="'+y+'">'+y+'-yil</option>').join('')
        : '<option value="">O‘qilgan yil yo‘q</option>';
      element.dataset.years=signature;
    }
    element.disabled=!years.length;
    if(!years.length){
      element.value='';
      return nowYear;
    }
    const choice=years.includes(Number(year))?Number(year):years[0];
    element.value=String(choice);
    return choice;
  }

  function readingActivity(){
    const activity=new Map();
    const get=(date)=>{
      if(!/^\d{4}-\d{2}-\d{2}$/.test(String(date||'')))return null;
      if(!activity.has(date))activity.set(date,{books:new Set(),finished:new Set(),started:new Set(),logs:0});
      return activity.get(date);
    };
    for(const book of state.books){
      const start=get(book.startedAt);
      if(start){start.started.add(book.id);start.books.add(book.id);}
      const end=get(book.finishedAt);
      if(end){end.finished.add(book.id);end.books.add(book.id);}
      const logDays=new Set();
      for(const entry of book.readingLog||[]){
        const date=entry.date;
        const day=get(date);
        if(day){day.books.add(book.id);if(!logDays.has(date))day.logs++;logDays.add(date);}
      }
    }
    return activity;
  }

  function activityYearDays(activity,year){
    return [...activity.keys()].filter(date=>date.startsWith(String(year)+'-'));
  }

  function longestReadingStreak(dates){
    if(!dates.length)return 0;
    const timestamps=[...new Set(dates)].sort().map(key=>{
      const [y,m,d]=key.split('-').map(Number);
      return Math.round(Date.UTC(y,m-1,d)/86400000);
    });
    let best=1,run=1;
    for(let i=1;i<timestamps.length;i++){
      run=timestamps[i]===timestamps[i-1]+1?run+1:1;
      best=Math.max(best,run);
    }
    return best;
  }

  function booksCompletedInYear(year){
    return state.books.filter(b=>b.finishedAt?.startsWith(String(year)+'-'));
  }

  function annualReadingSummary(year,activity=readingActivity()){
    const started=state.books.filter(b=>b.startedAt?.startsWith(String(year)+'-'));
    const finished=booksCompletedInYear(year);
    const activityDays=activityYearDays(activity,year);
    const monthTotals=Array.from({length:12},(_,month)=>{
      const prefix=String(year)+'-'+String(month+1).padStart(2,'0')+'-';
      const finishedMonth=finished.filter(b=>b.finishedAt.startsWith(prefix));
      const startedMonth=started.filter(b=>b.startedAt.startsWith(prefix));
      return {month,finished:finishedMonth.length,started:startedMonth.length,days:activityDays.filter(d=>d.startsWith(prefix)).length};
    });
    return {
      year,started,finished,activityDays,monthTotals,
      pages:finished.reduce((sum,b)=>sum+(Number(b.pages)||0),0),
      streak:longestReadingStreak(activityDays)
    };
  }

  function renderStats(){
    statsSelectedYear=syncYearSelect($('statsYear'),statsSelectedYear);
    const year=statsSelectedYear,activity=readingActivity();
    const summary=annualReadingSummary(year,activity);
    const goal=state.profile.yearlyGoal||24;
    const progress=Math.min(100,Math.round(summary.finished.length/goal*100));
    $('statsYearLabel').textContent=year+' YIL NATIJASI';
    $('statsHeroFinished').textContent=summary.finished.length;
    $('statsHeroSubtitle').textContent=year+'-yilda yakunlangan mutolaa';
    $('statsGoalFill').style.width=progress+'%';
    $('statsGoalText').textContent=goal+' ta kitoblik yillik maqsad';
    $('statsGoalPercent').textContent=progress+'%';
    $('statsTotal').textContent=summary.started.length;
    $('statsFinished').textContent=summary.finished.length;
    $('statsReading').textContent=summary.activityDays.length;
    $('statsWishlist').textContent=summary.pages.toLocaleString('en-US');
    $('statsPages').textContent=summary.pages.toLocaleString('en-US');
    const rated=summary.finished.filter(b=>Number(b.rating)>0);
    const avg=rated.length?rated.reduce((s,b)=>s+Number(b.rating),0)/rated.length:0;
    $('statsRating').textContent=rated.length?avg.toFixed(1)+' / 5':'—';
    $('statsThisYear').textContent=summary.finished.length+' ta kitob';
    const now=new Date();
    const periods=year===nowYear?now.getMonth()+1:12;
    $('statsMonthlyAvg').textContent=(summary.finished.length/periods).toFixed(1)+' ta kitob';
    const chart=$('monthlyChart');
    if(statTab==='genres'){
      $('statsChartTitle').textContent='Eng ko‘p o‘qilgan janrlar';
      $('statsChartEyebrow').textContent=year+'-YIL · JANRLAR';
      renderHorizontalStats(chart,groupCount(summary.finished,b=>b.category||'Boshqa'));
    } else if(statTab==='authors'){
      $('statsChartTitle').textContent='Eng ko‘p o‘qilgan mualliflar';
      $('statsChartEyebrow').textContent=year+'-YIL · MUALLIFLAR';
      renderHorizontalStats(chart,groupCount(summary.finished,b=>b.author||'Noma’lum'));
    } else if(statTab==='months'){
      $('statsChartTitle').textContent='Oyma-oy natijalar';
      $('statsChartEyebrow').textContent=year+'-YIL · 12 OY';
      chart.className='monthly-list';
      const labels=['Yanvar','Fevral','Mart','Aprel','May','Iyun','Iyul','Avgust','Sentabr','Oktabr','Noyabr','Dekabr'];
      chart.innerHTML=summary.monthTotals.map(row=>
        '<button type="button" class="monthly-result" data-calendar-month="'+row.month+'">'+
        '<span class="monthly-result-month">'+labels[row.month]+'</span>'+
        '<span class="monthly-result-details">'+row.started+' boshlangan · '+row.days+' faol kun</span>'+
        '<b>'+row.finished+' tugatilgan</b><span aria-hidden="true">›</span></button>'
      ).join('');
    } else {
      $('statsChartTitle').textContent='Oylar bo‘yicha tugatilgan kitoblar';
      $('statsChartEyebrow').textContent=year+'-YIL · YILLIK KO‘RSATKICH';
      const max=Math.max(1,...summary.monthTotals.map(x=>x.finished));
      const labels=['Yan','Fev','Mar','Apr','May','Iyun','Iyul','Avg','Sen','Okt','Noy','Dek'];
      chart.className='bar-chart';
      chart.innerHTML=summary.monthTotals.map(row=>{
        const percent=Math.max(row.finished?8:3,Math.round(row.finished/max*100));
        const title=labels[row.month]+': '+row.finished+' ta tugatilgan';
        return '<button type="button" class="month-bar" data-calendar-month="'+row.month+'" aria-label="'+title+'" title="'+title+'">'+
          '<b>'+row.finished+'</b><span class="bar" style="height:'+percent+'%"></span><span>'+labels[row.month]+'</span></button>';
      }).join('');
    }
  }

  function groupCount(list,getter){
    const m={};list.forEach(x=>{const k=getter(x);m[k]=(m[k]||0)+1;});
    return Object.entries(m).sort((a,b)=>b[1]-a[1]).slice(0,8);
  }

  function renderHorizontalStats(holder,entries){
    holder.className='category-bars stat-category-bars';
    if(!entries.length){
      holder.innerHTML='<div class="empty-state"><strong>Hozircha ma’lumot yo‘q</strong>Bu yilda tugatilgan sanasi kiritilgan kitoblar bo‘yicha natija chiqadi.</div>';
      return;
    }
    const max=Math.max(...entries.map(x=>x[1]),1);
    holder.innerHTML=entries.map(([k,v])=>'<div class="bar-row">'+
      '<b title="'+escapeHtml(k)+'">'+escapeHtml(k)+'</b>'+
      '<div class="bar-shell"><div class="bar-fill" style="width:'+((v/max)*100)+'%"></div></div><strong>'+v+'</strong></div>').join('');
  }

  function setCalendarMonth(year,month){
    calendarMode='month';
    const requested=new Date(Number(year),Number(month),1);
    const eligible=datedReadingYears();
    if(eligible.length && !eligible.includes(requested.getFullYear())){
      // Bo‘sh yillar orqali navigatsiyada eng yaqin mutolaa qilingan yilga o‘tish.
      const direction=requested>calendarDate?1:-1;
      const candidates=eligible.filter(y=>direction>0?y>calendarDate.getFullYear():y<calendarDate.getFullYear());
      if(!candidates.length){renderCalendar();return;}
      const closest=direction>0?Math.min(...candidates):Math.max(...candidates);
      calendarDate=new Date(closest,direction>0?0:11,1);
    } else {
      calendarDate=requested;
    }
    const nowPrefix=today().slice(0,7);
    const prefix=String(calendarDate.getFullYear())+'-'+String(calendarDate.getMonth()+1).padStart(2,'0');
    if(!selectedCalendarDay.startsWith(prefix))
      selectedCalendarDay=prefix===nowPrefix?today():prefix+'-01';
    renderCalendar();
  }

  function setCalendarYear(year){
    calendarMode='year';
    calendarDate=new Date(Number(year),calendarDate.getMonth(),1);
    renderCalendar();
  }

  function setCalendarMode(mode){
    calendarMode=mode==='month'?'month':'year';
    renderCalendar();
  }

  function showCalendarFromStats(month=null){
    const year=statsSelectedYear;
    const hasMonth=month!==null;
    calendarMode=hasMonth?'month':'year';
    const calendarMonth=hasMonth?Number(month):(year===nowYear?new Date().getMonth():0);
    calendarDate=new Date(year,calendarMonth,1);
    selectedCalendarDay=year===nowYear&&calendarMonth===new Date().getMonth()
      ?today()
      :year+'-'+String(calendarMonth+1).padStart(2,'0')+'-01';
    navigate('calendar');
  }

  function renderYearOverview(year,summary,activity){
    const shortMonths=['Yanvar','Fevral','Mart','Aprel','May','Iyun',
      'Iyul','Avgust','Sentabr','Oktabr','Noyabr','Dekabr'];
    $('calendarYearOverview').innerHTML=summary.monthTotals.map(row=>{
      const month=row.month;
      const last=new Date(year,month+1,0).getDate();
      const offset=(new Date(year,month,1).getDay()+6)%7;
      const prefix=year+'-'+String(month+1).padStart(2,'0')+'-';
      let days='';
      for(let pad=0;pad<offset;pad++)days+='<span class="year-mini-day empty" aria-hidden="true"></span>';
      for(let day=1;day<=last;day++){
        const key=prefix+String(day).padStart(2,'0');
        const events=activity.get(key);
        const cls=['year-mini-day'];
        if(events?.books.size)cls.push('read');
        if(events?.finished.size)cls.push('finish');
        if(key===today())cls.push('today');
        const title=day+'-'+shortMonths[month]+': '+(
          events?.finished.size?'Kitob tugatilgan':events?.books.size?'Mutolaa qaydi':'Qayd yo‘q');
        days+='<span class="'+cls.join(' ')+'" title="'+title+'">'+day+'</span>';
      }
      const total=offset+last;
      for(let pad=total;pad<42;pad++)days+='<span class="year-mini-day empty" aria-hidden="true"></span>';
      return '<button type="button" class="year-calendar-month" data-year-month="'+month+
        '" aria-label="'+year+'-yil '+shortMonths[month]+': '+row.days+' faol kun, '+row.finished+' ta tugatilgan">'+
        '<span class="year-calendar-month-heading"><b>'+shortMonths[month]+'</b><span>'+row.days+' faol kun</span></span>'+
        '<span class="year-mini-weekdays" aria-hidden="true"><span>D</span><span>S</span><span>Ch</span><span>P</span><span>J</span><span>Sh</span><span>Y</span></span>'+
        '<span class="year-mini-grid" aria-hidden="true">'+days+'</span>'+
        '<span class="year-calendar-month-footer"><b>'+row.finished+' tugatilgan</b><span>Oyni ochish ↗</span></span>'+
        '</button>';
    }).join('');
  }

  function renderCalendar(){
    // Kalendar yili faqat real qaydlar mavjud bo‘lgan yildan tanlanadi.
    const year=syncYearSelect($('calendarYear'),calendarDate.getFullYear());
    if(year!==calendarDate.getFullYear())calendarDate=new Date(year,calendarDate.getMonth(),1);
    const month=calendarDate.getMonth();
    const yearMode=calendarMode==='year';
    $('calendarFullYearBtn').classList.toggle('active',yearMode);
    $('calendarFullYearBtn').setAttribute('aria-pressed',String(yearMode));
    $('calendarSingleMonthBtn').classList.toggle('active',!yearMode);
    $('calendarSingleMonthBtn').setAttribute('aria-pressed',String(!yearMode));
    $('calendarMonthView').hidden=yearMode;
    $('calendarYearOverview').closest('.calendar-year-card').hidden=!yearMode;
    $('calendarTodayCard').hidden=yearMode;
    $('calendarMonth').value=String(month);
    $('calendarMonthLabel').textContent=monthName(calendarDate);
    $('calYearOverviewTitle').textContent=year+'-yil: barcha 12 oy';
    const activity=readingActivity();
    const summary=annualReadingSummary(year,activity);
    const monthData=summary.monthTotals[month];
    $('calMonthActive').textContent=yearMode?summary.activityDays.length:monthData.days;
    $('calMonthFinished').textContent=yearMode?summary.finished.length:monthData.finished;
    $('calStreak').textContent=summary.streak;
    $('calActivePeriod').textContent=yearMode?year+'-yil':'Tanlangan oy';
    $('calFinishedPeriod').textContent=yearMode?'Shu yilda':'Tanlangan oy';
    $('calStreakPeriod').textContent=year+'-yil';

    if(yearMode){
      renderYearOverview(year,summary,activity);
      return;
    }
    const first=new Date(year,month,1),last=new Date(year,month+1,0);
    const offset=(first.getDay()+6)%7;
    const todayKey=today(),prefix=year+'-'+String(month+1).padStart(2,'0')+'-';
    if(!selectedCalendarDay.startsWith(prefix))selectedCalendarDay=prefix+'01';
    let html='';
    for(let i=0;i<offset;i++)html+='<span class="day-cell empty" aria-hidden="true"></span>';
    for(let day=1;day<=last.getDate();day++){
      const key=prefix+String(day).padStart(2,'0'),events=activity.get(key);
      const finished=Boolean(events?.finished.size);
      const active=Boolean(events?.books.size);
      const classes=['day-cell'];
      if(active)classes.push('read');
      if(finished)classes.push('finish');
      if(key===todayKey)classes.push('today');
      if(key===selectedCalendarDay)classes.push('selected');
      const aria=key+' — '+(finished?'Kitob tugatilgan':active?'Mutolaa qayd qilingan':'Qayd yo‘q');
      html+='<button type="button" class="'+classes.join(' ')+'" data-calendar-day="'+key+
        '" aria-label="'+aria+'" aria-pressed="'+(key===selectedCalendarDay)+'">'+day+
        (active?'<i class="day-indicator" aria-hidden="true"></i>':'')+'</button>';
    }
    const total=offset+last.getDate();
    for(let i=total;i<42;i++)html+='<span class="day-cell empty" aria-hidden="true"></span>';
    $('calendarGrid').innerHTML=html;
    renderCalendarDay(selectedCalendarDay);
  }

  function renderCalendarDay(date){
    selectedCalendarDay=date;
    document.querySelectorAll('#calendarGrid [data-calendar-day]').forEach(button=>{
      const selected=button.dataset.calendarDay===date;
      button.classList.toggle('selected',selected);
      button.setAttribute('aria-pressed',String(selected));
    });
    const books=state.books.filter(b=>
      b.startedAt===date||b.finishedAt===date||(b.readingLog||[]).some(x=>x.date===date)
    );
    const holder=$('calendarTodayCard');
    holder.innerHTML='<div class="section-title-row"><div><small>KUN TAFSILOTLARI</small><h2>'+escapeHtml(formatDate(date))+'</h2></div>'+
      '<span class="day-events-count">'+books.length+' kitob</span></div>'+
      (books.length?'<div class="calendar-book-events">'+books.map(book=>{
        const notes=[];
        if(book.startedAt===date)notes.push('Mutolaa boshlangan');
        if(book.finishedAt===date)notes.push('Kitob tugatilgan');
        const entry=(book.readingLog||[]).find(x=>x.date===date);
        if(entry && entry.page>0)notes.push(entry.page+'-sahifagacha qayd');
        if(!notes.length)notes.push('Mutolaa qaydi');
        return '<button type="button" class="calendar-book-event" data-book-open="'+escapeHtml(book.id)+'">'+
          coverHtml(book)+'<span><b>'+escapeHtml(book.title)+'</b><small>'+escapeHtml(book.author||'Muallif kiritilmagan')+'</small>'+
          '<em>'+notes.map(escapeHtml).join(' · ')+'</em></span><span class="calendar-event-arrow">›</span></button>';
      }).join('')+'</div>'
      :'<div class="empty-state"><strong>Bu kuni qayd yo‘q</strong>Mutolaa boshlangan yoki tugatilgan sanani kiritishingiz mumkin.</div>');
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
    const finishedYear=state.books.filter(b=>statusOf(b)==='finished'&&bookFinishedYear(b)===nowYear).length;
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
      const open=e.target.closest('[data-open]'); if(open){if(open.dataset.open==='calendar'&&currentView==='stats')showCalendarFromStats();else navigate(open.dataset.open);return;}
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
    $('bookManualTab').addEventListener('click',()=>setBookEntryMode('manual'));
    $('bookScannerTab').addEventListener('click',()=>setBookEntryMode('scanner'));
    $('bookPhotoTab').addEventListener('click',()=>setBookEntryMode('photo'));
    $('photoCameraBtn').addEventListener('click',()=>$('photoCameraInput').click());
    $('photoGalleryBtn').addEventListener('click',()=>$('photoGalleryInput').click());
    for(const id of ['photoCameraInput','photoGalleryInput']){
      $(id).addEventListener('change',event=>{
        const file=event.target.files?.[0];
        if(file)void loadCoverPhoto(file);
        event.target.value='';
      });
    }
    $('photoSearchText').addEventListener('input',()=>{photoManualSearchRequested=true;});
    $('photoFindBtn').addEventListener('click',()=>{
      photoManualSearchRequested=true;
      void findCoverByText($('photoSearchText').value);
    });
    $('photoResults').addEventListener('click',event=>{
      const row=event.target.closest('[data-photo-result]');
      if(row)chooseCoverCandidate(Number(row.dataset.photoResult));
    });
    $('scanCameraBtn').addEventListener('click',()=>void startIsbnScanner());
    $('scanStopBtn').addEventListener('click',()=>void stopIsbnScanner());
    $('scanLookupBtn').addEventListener('click',()=>void lookupIsbnAndFill($('scanIsbnInput').value));
    $('scanWebSearchBtn').addEventListener('click',()=>openUzbekIsbnWebSearch());
    $('scanToPhotoBtn').addEventListener('click',()=>setBookEntryMode('photo'));
    $('scanBarcodePhotoBtn').addEventListener('click',()=>$('scanBarcodePhotoInput').click());
    $('scanBarcodePhotoInput').addEventListener('change',event=>{
      const file=event.target.files?.[0];
      if(file)void scanBarcodeFromImage(file);
      event.target.value='';
    });
    $('photoWebSearchBtn').addEventListener('click',openPhotoWebSearch);
    $('scanIsbnInput').addEventListener('keydown',event=>{
      if(event.key==='Enter'){event.preventDefault();void lookupIsbnAndFill(event.target.value);}
    });
    $('bookDialog').addEventListener('close',()=>{
      photoOperation++;
      photoManualSearchRequested=false;
      void stopIsbnScanner();
      setBookEntryMode('manual');
    });
    $('bookStartedAt').addEventListener('change',updateBookStatusPreview);
    $('bookFinishedAt').addEventListener('change',updateBookStatusPreview);
    $('bookStatusOverride').addEventListener('change',updateBookStatusPreview);
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
    $('statsYear').addEventListener('change',event=>{statsSelectedYear=Number(event.target.value)||nowYear;renderStats();});
    $('statTabs').addEventListener('click',e=>{
      const btn=e.target.closest('[data-stat-tab]');if(!btn)return;
      statTab=btn.dataset.statTab;qsa('#statTabs button').forEach(b=>b.classList.toggle('active',b===btn));renderStats();
    });
    $('prevMonth').addEventListener('click',()=>setCalendarMonth(calendarDate.getFullYear(),calendarDate.getMonth()-1));
    $('nextMonth').addEventListener('click',()=>setCalendarMonth(calendarDate.getFullYear(),calendarDate.getMonth()+1));
    $('calendarYear').addEventListener('change',event=>setCalendarYear(Number(event.target.value))); 
    $('calendarFullYearBtn').addEventListener('click',()=>setCalendarMode('year'));
    $('calendarSingleMonthBtn').addEventListener('click',()=>setCalendarMode('month'));
    $('calendarMonth').addEventListener('change',event=>setCalendarMonth(calendarDate.getFullYear(),Number(event.target.value)));
    $('calendarTodayBtn').addEventListener('click',()=>{
      if(!datedReadingYears().includes(nowYear)){
        toast('Bu yil hali mutolaa qaydi yo‘q.');
        return;
      }
      calendarMode='month';
      calendarDate=new Date(nowYear,new Date().getMonth(),1);
      selectedCalendarDay=today();
      renderCalendar();
    });
    $('calendarYearOverview').addEventListener('click',event=>{
      const month=event.target.closest('[data-year-month]');
      if(month)setCalendarMonth(calendarDate.getFullYear(),Number(month.dataset.yearMonth));
    });
    $('monthlyChart').addEventListener('click',event=>{
      const month=event.target.closest('[data-calendar-month]');
      if(month)showCalendarFromStats(Number(month.dataset.calendarMonth));
    });
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