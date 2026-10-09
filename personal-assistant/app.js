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
      dailyPageGoal: 32,
      dailyMinutesGoal: 20,
      dailyPlanBookId: '',
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
  let statsPeriod='year';
  let statsPeriodMonth=new Date().getMonth();
  let statsPeriodDay=today();
  let detailTab = 'general';
  const readingTimer={bookId:'',startedAt:0,interval:null};
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
  const bookTitleLookup={
    request:0,timer:null,candidates:[],autoValues:new Map(),
    manuallyEdited:new Set(),autoCover:false,coverLocked:false,appliedTitle:''
  };

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
        dailyPageGoal: clampInt(profile.dailyPageGoal ?? 32, 1, 300),
        dailyMinutesGoal: clampInt(profile.dailyMinutesGoal ?? 20, 5, 240),
        dailyPlanBookId: String(profile.dailyPlanBookId || '').trim(),
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
          .map(x => ({
            date: normalizeDate(x.date),
            page: numOrZero(x.page),
            ...(Number.isFinite(Number(x.readPages)) && x.readPages !== undefined && x.readPages !== null
              ? {readPages: Math.max(0,Math.round(Number(x.readPages)))} : {}),
            ...(Number.isFinite(Number(x.minutes)) && x.minutes !== undefined && x.minutes !== null
              ? {minutes:Math.max(0,Math.round(Number(x.minutes)))} : {})
          }))
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
  // YYYY-MM-DD sanalari orasini soat mintaqasi/DST ta'sirisiz hisoblaymiz.
  function calendarDayNumber(value){
    const text=String(value||'');
    if(!/^\d{4}-\d{2}-\d{2}$/.test(text))return null;
    const [year,month,day]=text.split('-').map(Number);
    if(year<1900||year>2100||month<1||month>12||day<1||day>31)return null;
    const time=Date.UTC(year,month-1,day);
    const verified=new Date(time);
    if(verified.getUTCFullYear()!==year||verified.getUTCMonth()!==month-1||verified.getUTCDate()!==day)return null;
    return Math.round(time/86400000);
  }

  function readingDurationInfo(book,referenceDate=today()){
    const status=statusOf(book);
    if(status!=='reading'&&status!=='finished')return null;
    const start=calendarDayNumber(book.startedAt);
    const end=calendarDayNumber(status==='finished'?book.finishedAt:referenceDate);
    if(start===null||end===null||end<start)return null;
    if(status==='reading'){
      const days=end-start;
      return {days,label:'Boshlanganiga '+days+' kun bo‘ldi',status};
    }
    // Boshlagan va tugatgan kun ham mutolaa kuni hisoblanadi.
    const days=end-start+1;
    return {days,label:days+' kunda tugatilgan',status};
  }

  function readingDurationHtml(book){
    const info=readingDurationInfo(book);
    if(!info)return '';
    return '<div class="reading-duration '+info.status+'" title="'+
      (info.status==='reading'?'Boshlangan sanadan hozirgacha o‘tgan vaqt':'Boshlangan va tugatilgan kunlar ham hisoblangan')+'">'+
      '<svg class="ui-icon" aria-hidden="true"><use href="#ico-calendar"></use></svg>'+
      '<span>'+escapeHtml(info.label)+'</span></div>';
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

  function selectableDailyBooks(){
    return state.books.filter(book=>statusOf(book)!=='finished')
      .sort((a,b)=>{
        const rank=x=>statusOf(x)==='reading'?0:1;
        return rank(a)-rank(b)||String(b.updatedAt||'').localeCompare(String(a.updatedAt||''))||
          String(a.title||'').localeCompare(String(b.title||''),'uz');
      });
  }

  function getHomeReadingBook(){
    const userChoice=String(state.profile.dailyPlanBookId||'');
    if(userChoice){
      const chosen=state.books.find(book=>String(book.id)===userChoice&&statusOf(book)!=='finished');
      if(chosen) return chosen;
    }
    return selectableDailyBooks().find(book=>statusOf(book)==='reading')||null;
  }

  function dailyBookPages(book){
    // Sahifa raqami kumulyativ: 25 -> 45 -> 60 bo‘lsa, +20 va +15 sahifa.
    // readPages maydoni yangi yangilanishlarda aniq farqni saqlaydi.
    // Eski yozuvlarda esa faqat mavjud sana/sahifa snapshotlarining ortishi olinadi.
    const entries=(book.readingLog||[])
      .filter(entry=>/^\d{4}-\d{2}-\d{2}$/.test(entry.date||''))
      .map(entry=>({
        date:entry.date,page:Math.max(0,Math.round(Number(entry.page)||0)),
        readPages:entry.readPages===undefined?null:Math.max(0,Math.round(Number(entry.readPages)||0))
      })).sort((a,b)=>a.date.localeCompare(b.date));
    // Dastlab yuklangan tarixiy kitoblarda boshlanish=0 va tugash=jami sahifa
    // avtomatik yozilgan edi. Buni "o‘sha kuni butun kitob o‘qilgan" demaymiz.
    const importedHistory=String(book.id||'').startsWith('history-') &&
      entries.length===2 && entries.every(e=>e.readPages===null) &&
      entries[0].page===0 && entries[0].date===book.startedAt &&
      entries[1].date===book.finishedAt && entries[1].page===Number(book.pages||0);
    if(importedHistory)return new Map();
    const byDay=new Map();
    let previousMax=0;
    for(const entry of entries){
      const prior=byDay.get(entry.date);
      const priorPage=prior?.page||0;
      const effectiveMax=Math.max(previousMax,priorPage);
      const inferred=Math.max(0,entry.page-effectiveMax);
      const pages=entry.readPages===null?inferred:entry.readPages;
      if(prior){
        // Ikkita legacy snapshot bo‘lsa, bir kundagi ortishlar qo‘shiladi.
        // Explicit readPages esa jamlanma raqam; uni ikki marta qo‘shmaymiz.
        prior.pages=entry.readPages===null?prior.pages+pages:
          Math.max(prior.pages,pages);
        prior.page=Math.max(prior.page,entry.page);
      }else{
        byDay.set(entry.date,{pages,page:entry.page});
      }
      previousMax=Math.max(previousMax,entry.page);
    }
    return new Map([...byDay.entries()].map(([date,v])=>[date,Math.max(0,v.pages)]));
  }

  function dailyReadingPages(){
    const byDay=new Map();
    for(const book of state.books){
      const pages=dailyBookPages(book);
      for(const [date,count] of pages){
        if(!byDay.has(date))byDay.set(date,{pages:0,books:new Map()});
        if(count<=0)continue;
        const summary=byDay.get(date);
        summary.pages+=count;
        summary.books.set(book.id,count);
      }
    }
    return byDay;
  }

  function pagesReadOnDate(date){
    return dailyReadingPages().get(date)?.pages||0;
  }

  function minutesReadOnDate(date){
    return state.books.reduce((sum,book)=>sum+(book.readingLog||[])
      .filter(entry=>entry.date===date)
      .reduce((n,entry)=>n+Math.max(0,Number(entry.minutes)||0),0),0);
  }

  function totalReadingMinutes(book){
    return (book.readingLog||[]).reduce((sum,entry)=>sum+
      Math.max(0,Number(entry.minutes)||0),0);
  }

  function saveReadingMinutes(bookId,elapsedMinutes){
    const book=state.books.find(b=>b.id===bookId);
    if(!book)return false;
    const minutes=Math.max(0,Math.round(Number(elapsedMinutes)||0));
    if(!minutes)return false;
    book.readingLog=Array.isArray(book.readingLog)?book.readingLog:[];
    const date=today();
    let log=book.readingLog.find(entry=>entry.date===date);
    if(!log){
      log={date,page:Math.max(0,Number(book.currentPage)||0),readPages:0,minutes:0};
      book.readingLog.push(log);
    }
    log.minutes=Math.max(0,Number(log.minutes)||0)+minutes;
    book.updatedAt=new Date().toISOString();
    saveState(minutes+' daqiqa mutolaa vaqti saqlandi.');
    return true;
  }

  function stopReadingTimer(save=true){
    if(readingTimer.interval!==null){
      clearInterval(readingTimer.interval);
      readingTimer.interval=null;
    }
    if(!readingTimer.bookId)return;
    const bookId=readingTimer.bookId;
    const elapsed=Math.max(0,Date.now()-readingTimer.startedAt);
    readingTimer.bookId='';
    readingTimer.startedAt=0;
    if(save && elapsed>=1000)saveReadingMinutes(bookId,Math.max(1,Math.ceil(elapsed/60000)));
    if(currentView==='detail')renderBookDetail();
  }

  function toggleReadingTimer(bookId){
    if(readingTimer.bookId===bookId){stopReadingTimer(true);return;}
    if(readingTimer.bookId)stopReadingTimer(true);
    readingTimer.bookId=bookId;
    readingTimer.startedAt=Date.now();
    readingTimer.interval=setInterval(()=>{
      const label=$('readingTimerClock');
      if(label && readingTimer.bookId===bookId){
        const elapsed=Math.max(0,Math.floor((Date.now()-readingTimer.startedAt)/1000));
        label.textContent=String(Math.floor(elapsed/60)).padStart(2,'0')+':'+
          String(elapsed%60).padStart(2,'0');
      }
    },1000);
    renderBookDetail();
  }

  function readingHistoryRows(book){
    const byDay=dailyBookPages(book);
    const dates=[...new Set([
      ...(book.readingLog||[]).map(entry=>entry.date),
      book.startedAt,book.finishedAt
    ].filter(Boolean))].sort((a,b)=>b.localeCompare(a));
    if(!dates.length)return '<div class="empty-state"><strong>Mutolaa tarixi yo‘q</strong>Sahifangizni yangilang yoki vaqt hisoblagichini yoqing.</div>';
    return '<div class="reading-timeline">'+dates.map(date=>{
      const pages=byDay.get(date)||0;
      const entries=(book.readingLog||[]).filter(entry=>entry.date===date);
      const minutes=entries.reduce((sum,entry)=>sum+Math.max(0,Number(entry.minutes)||0),0);
      const lastPage=Math.max(0,...entries.map(entry=>Number(entry.page)||0));
      const pieces=[];
      if(pages>0)pieces.push('+'+pages+' sahifa');
      if(minutes>0)pieces.push(minutes+' daqiqa');
      if(!pieces.length)pieces.push(book.finishedAt===date?'Tugatilgan':'Qayd');
      return '<div class="reading-timeline-day"><span class="reading-timeline-dot" aria-hidden="true"></span>'+
        '<div><b>'+escapeHtml(formatDate(date))+'</b>'+
        '<small>'+(lastPage?lastPage+'-sahifagacha · ':'')+
        (book.startedAt===date?'Boshlangan · ':'')+
        (book.finishedAt===date?'Tugatilgan':'')+'</small></div>'+
        '<strong>'+pieces.join(' · ')+'</strong></div>';
    }).join('')+'</div>';
  }

  function currentReadingStreak(day=today()){
    const active=dailyReadingPages();
    const start=parseDay(day);
    if(!start) return 0;
    // Izchillikka faqat haqiqiy o‘qilgan sahifalari bor kunlar kiradi.
    if(!(active.get(day)?.pages>0))start.setDate(start.getDate()-1);
    let days=0;
    for(let index=0;index<3660;index++){
      const date=[start.getFullYear(),String(start.getMonth()+1).padStart(2,'0'),
        String(start.getDate()).padStart(2,'0')].join('-');
      if(!(active.get(date)?.pages>0))break;
      days++;
      start.setDate(start.getDate()-1);
    }
    return days;
  }

  function renderDailyHero(reading,book){
    const pagesGoal=state.profile.dailyPageGoal||32;
    const minuteGoal=state.profile.dailyMinutesGoal||20;
    const readToday=pagesReadOnDate(today());
    const left=Math.max(0,pagesGoal-readToday);
    $('homeHeroHeadline').innerHTML=(left?left+' sahifa o‘qing':'Bugungi reja bajarildi!')+
      ' <span aria-hidden="true">'+(left?'🎯':'✅')+'</span>';
    $('homeHeroBook').textContent=book?.title||'Kitob tanlang';
    $('homeHeroChangeBook').disabled=selectableDailyBooks().length===0;
    $('homeHeroChangeBook').title=book?'Bugungi kitobni almashtirish':'Bugungi kitobni tanlash';
    $('homeHeroPages').textContent='Bugun: '+readToday+' / '+pagesGoal+' sahifa';
    $('homeHeroBookPages').textContent=book?
      (book.currentPage||0)+' / '+(book.pages||'—')+' sahifa':'Kitob tanlang';
    $('homeHeroMinutes').textContent=minuteGoal+' daqiqa';
    $('homeHeroStreak').textContent=currentReadingStreak()+' kunlik';
    $('homeHeroReading').textContent=reading.length+' kitob';
    const cta=$('homeHeroContinue');
    $('homeHeroContinueLabel').textContent=book?'Davom etish':'Kitob tanlash';
    cta.setAttribute('aria-label',book?'Mutolaani davom ettirish: '+book.title:'O‘qish uchun kitob tanlash');
    const art=$('homeHeroCover');
    art.innerHTML=book?coverHtml(book,'hero-book-cover'):'<span class="daily-empty-book">📚</span>';
    if(book?.pages){
      const start=progressOf(book);
      const next=Math.min(100,Math.round(Math.min(book.pages,Number(book.currentPage||0)+left)/book.pages*100));
      $('homeHeroProgressStart').textContent=start+'%';
      $('homeHeroProgressEnd').textContent=Math.max(start,next)+'%';
      $('homeHeroProgressLabels').hidden=false;
      $('homeHeroProgressFill').style.width=start+'%';
      $('homeHeroProgressFill').parentElement.setAttribute('aria-label',
        'Kitobning '+start+' foizi o‘qilgan. Bugungi maqsad bajarilsa '+Math.max(start,next)+' foiz bo‘ladi.');
    }else{
      $('homeHeroProgressStart').textContent=book?'Sahifalar noma’lum':'Boshlashga tayyor';
      $('homeHeroProgressEnd').textContent='';
      $('homeHeroProgressLabels').hidden=!book;
      $('homeHeroProgressFill').style.width='0%';
      $('homeHeroProgressFill').parentElement.setAttribute('aria-label','O‘qish progressi hali mavjud emas.');
    }
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
    const book=getHomeReadingBook();
    renderDailyHero(reading,book);
    const todayPages=pagesReadOnDate(today());
    const percentage=Math.min(100,Math.round(todayPages/(state.profile.dailyPageGoal||32)*100));
    $('homeActivityPages').textContent=todayPages;
    $('homeActivityStreak').textContent=currentReadingStreak()+' kun';
    $('homeActivityMinutes').textContent=minutesReadOnDate(today())+' daq';
    $('homeActivityGoalText').textContent='Kunlik reja: '+(state.profile.dailyPageGoal||32)+' sahifa';
    $('homeActivityGoalPercent').textContent=percentage+'%';
    $('homeActivityGoalFill').style.width=percentage+'%';
    const holder=$('homeCurrentReading');
    if(!book){
      holder.innerHTML='<div class="empty-state"><strong>Hozir o‘qilayotgan kitob yo‘q</strong>Kitob qo‘shib, mutolaa boshlangan sanani kiriting.</div>';
    } else {
      const p=progressOf(book);
      holder.innerHTML='<div class="current-book">'+coverHtml(book)+
        '<div><h3>'+escapeHtml(book.title)+'</h3><p>'+escapeHtml(book.author||'Muallif kiritilmagan')+'</p>'+
        '<div class="progress-wrap"><div class="progress-track"><div class="progress-fill" style="width:'+p+'%"></div></div><b>'+p+'%</b></div></div>'+
        '<button class="continue-button" data-book-open="'+escapeHtml(book.id)+'">'+
        (statusOf(book)==='reading'?'Mutolaani davom ettirish →':'Kitobni ochish →')+'</button></div>';
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
        '<div class="book-dates">'+dates+'</div>'+readingDurationHtml(book)+
        '<div class="library-book-today">◷ Bugun '+(dailyBookPages(book).get(today())||0)+
        ' sahifa'+(totalReadingMinutes(book)?' · '+totalReadingMinutes(book)+' daqiqa mutolaa':'')+'</div></div>'+
        '<button class="row-menu" data-book-menu="'+book.id+'" aria-label="Kitob menyusi"><svg class="ui-icon" aria-hidden="true"><use href="#ico-more"></use></svg></button></article>';
    }).join('');
  }

  function renderBookDetail(){
    const book=state.books.find(b=>b.id===selectedBookId);
    const holder=$('bookDetail');
    if(!book){holder.innerHTML='<div class="empty-state"><strong>Kitob topilmadi</strong></div>';return;}
    const status=statusOf(book),p=progressOf(book);
    const todayPages=dailyBookPages(book).get(today())||0;
    const totalMinutes=totalReadingMinutes(book);
    const progress='<div class="detail-progress"><div class="detail-progress-head">'+
      '<span>Mutolaa progressi</span><b>'+p+'%</b></div>'+
      '<div class="progress-track"><div class="progress-fill" style="width:'+p+'%"></div></div>'+
      '<div class="detail-pages">Sahifalar: '+(book.currentPage||0)+(book.pages?' / '+book.pages:'')+'</div></div>';
    const tabs='<div class="detail-sections" role="tablist" aria-label="Kitob bo‘limlari">'+
      [['general','Umumiy'],['history','Tarix'],['notes','Eslatmalar']]
      .map(([id,name])=>'<button type="button" role="tab" data-detail-tab="'+id+
        '" class="'+(detailTab===id?'active':'')+'" aria-selected="'+(detailTab===id)+'">'+name+'</button>')
      .join('')+'</div>';
    const timerActive=readingTimer.bookId===book.id;
    const timerElapsed=timerActive?Math.max(0,Math.floor((Date.now()-readingTimer.startedAt)/1000)):0;
    const clock=String(Math.floor(timerElapsed/60)).padStart(2,'0')+':'+
      String(timerElapsed%60).padStart(2,'0');
    const timePanel='<div class="detail-reading-timer"><div class="detail-timer-top">'+
      '<span class="detail-timer-icon">◷</span>'+
      '<div><strong>Mutolaa vaqti</strong><small>Bugun '+minutesReadOnDate(today())+
      ' daqiqa · Shu kitob '+totalMinutes+' daqiqa</small></div>'+
      '<b id="readingTimerClock">'+clock+'</b></div>'+
      '<button type="button" class="detail-timer-button'+(timerActive?' running':'')+
      '" data-reading-timer="'+escapeHtml(book.id)+'">'+
      (timerActive?'■ To‘xtatish va saqlash':'▶ Vaqtni boshlash')+'</button>'+
      '<small class="detail-timer-help">Vaqtni to‘xtatganingizda shu kitobning bugungi qaydiga yoziladi.</small></div>';
    const general=progress+
      '<div class="detail-reading-numbers">'+
      '<div><small>Bugun o‘qilgan</small><b>'+todayPages+' sahifa</b></div>'+
      '<div><small>Jami mutolaa vaqti</small><b>'+totalMinutes+' daqiqa</b></div></div>'+
      '<div class="detail-date-grid"><div class="detail-date-card"><small>Mutolaa boshlangan sana</small><b>◫ '+
      (book.startedAt?escapeHtml(formatDate(book.startedAt)):
        (status==='finished'?'Sana kiritilmagan':'Boshlanmagan'))+'</b></div>'+
      '<div class="detail-date-card"><small>Mutolaa tugatilgan sana</small><b>◫ '+
      (book.finishedAt?escapeHtml(formatDate(book.finishedAt)):
        (status==='finished'?'Sana kiritilmagan':'Hali tugatilmagan'))+'</b></div></div>'+
      readingDurationHtml(book)+
      (book.description?'<article class="content-card detail-notes"><h2>Kitob haqida</h2><p>'+
        escapeHtml(book.description)+'</p></article>':'');
    const diary='<article class="content-card book-timeline-panel">'+
      '<div class="section-title-row"><div><small>KUNLIK TARIX</small><h2>Mutolaa kundaligi</h2></div>'+
      '<b class="book-timeline-count">'+totalMinutes+' daqiqa</b></div>'+
      '<p>Qaysi kuni nechta sahifa o‘qiganingiz va vaqt qaydlari.</p>'+
      readingHistoryRows(book)+'</article>';
    const note='<article class="content-card detail-notes"><div class="section-title-row"><h2>Shaxsiy eslatmalar</h2>'+
      '<button class="text-action" data-edit-book="'+escapeHtml(book.id)+'">Tahrirlash</button></div>'+
      '<p>'+escapeHtml(book.notes||'Hali shaxsiy izoh yozilmagan.')+'</p>'+
      (book.rating?'<div class="book-dates"><span>★ '+book.rating+' / 5</span></div>':'')+'</article>';
    holder.innerHTML='<div class="detail-top detail-premium-top">'+coverHtml(book)+
      '<div class="detail-meta"><h1>'+escapeHtml(book.title)+'</h1><div class="author">'+
      escapeHtml(book.author||'Muallif kiritilmagan')+'</div>'+
      '<div class="meta-tags">'+[book.category,book.publisher,book.publishedYear?String(book.publishedYear):'',book.pages?book.pages+' bet':'',book.isbn?'ISBN '+book.isbn:'']
      .filter(Boolean).map(x=>'<span>'+escapeHtml(x)+'</span>').join('')+'</div>'+
      '<div class="detail-status-row"><span class="status-pill '+status+'">● '+
      statusLabel(status)+'</span></div></div></div>'+tabs+
      (detailTab==='history'?diary:detailTab==='notes'?note:general)+
      (status!=='finished'?timePanel:'')+
      (status==='wishlist'
        ?'<button class="detail-action" data-start-book="'+escapeHtml(book.id)+'">▶ Mutolaani boshlash</button>'
        :status==='reading'
          ?'<button class="detail-action" data-progress-book="'+escapeHtml(book.id)+'">▶ Sahifani yangilash</button>'+
           '<button class="detail-secondary" data-finish-book="'+escapeHtml(book.id)+'">✓ Tugatdim</button>'
          :'<button class="detail-action" data-edit-book="'+escapeHtml(book.id)+'">Kitob ma’lumotini tahrirlash</button>');
  }

  function openBookDialog(book=null){
    pendingCover=book?.cover||'';
    $('bookDialogTitle').textContent=book?'Kitobni tahrirlash':'Yangi kitob qo‘shish';
    resetBookTitleLookup(book);
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

  function coverSearchLines(text){
    return [...new Set(String(text||'').split(/\r?\n/)
      .map(cleanCoverText)
      .filter(line=>line.length>=3&&line.length<=95&&
        /[\p{L}]{3}/u.test(line)&&
        !/^(isbn|www[.]|https?[:]|nashriyot|publish|copyright|kitoblar|@|©)/i.test(line)&&
        !/^[\d\s.,:()-]+$/.test(line))
    )].slice(0,9);
  }

  function extractCoverSearchTerm(text){
    // OCR satrlarini saqlaymiz: kitob nomi / muallif alohida qidiriladi.
    return coverSearchLines(text).slice(0,4).join('\n').slice(0,210);
  }

  async function scanPhotoIsbn(file){
    // Qurilmada BarcodeDetector mavjud bo‘lsa serverga rasm uzatilmaydi.
    if(typeof window.BarcodeDetector==='function'){
      let bitmap=null;
      try{
        const reader=new window.BarcodeDetector({formats:['ean_13','code_128','ean_8']});
        bitmap=await createImageBitmap(file);
        const found=await reader.detect(bitmap);
        for(const entry of found||[]){
          const isbn=normalizedIsbn(entry.rawValue);
          if(validIsbn(isbn))return isbn;
        }
      }catch(_){}
      finally{try{bitmap?.close();}catch(_){}}
    }
    // iOS va boshqa brauzerlarda ISBN foto-skanerlash kutubxonasi.
    let scanner=null,host=null;
    try{
      await Promise.race([
        loadScannerLibrary(),
        new Promise((_,reject)=>setTimeout(()=>reject(new Error('scan timeout')),6500))
      ]);
      host=document.createElement('div');
      host.id='photo-barcode-reader';
      host.style.cssText='position:fixed;left:-9999px;top:0;width:360px;height:260px;overflow:hidden;opacity:.01;pointer-events:none;';
      document.body.appendChild(host);
      const F=window.Html5QrcodeSupportedFormats;
      scanner=new window.Html5Qrcode(host.id,{formatsToSupport:
        [F.EAN_13,F.CODE_128,F.QR_CODE],verbose:false});
      const value=await Promise.race([
        scanner.scanFile(file,true),
        new Promise((_,reject)=>setTimeout(()=>reject(new Error('barcode not found')),6000))
      ]);
      const isbn=normalizedIsbn(value);
      return validIsbn(isbn)?isbn:'';
    }catch(_){return '';}
    finally{
      if(scanner){try{await scanner.clear();}catch(_){}}
      host?.remove();
    }
  }

  async function loadCoverPhoto(file){
    if(!file)return;
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
    $('photoFindBtn').disabled=false;
    photoBusy=true;
    let worker=null;
    setPhotoStatus('Rasm tayyorlanmoqda...');
    try{
      const cover=await compressImage(file);
      if(ticket!==photoOperation||!$('bookDialog').open)return;
      photoOriginalCover=cover;
      if(!$('bookId').value||!pendingCover){pendingCover=cover;setCoverPreview(pendingCover);}
      $('photoPreview').src=cover;
      $('photoPreviewWrap').hidden=false;
      setPhotoStatus('Avval ISBN shtrix-kodi tekshirilmoqda...');
      const isbn=await scanPhotoIsbn(file);
      if(ticket!==photoOperation||!$('bookDialog').open)return;
      if(isbn){
        $('scanIsbnInput').value=isbn;
        $('bookIsbn').value=isbn;
        setPhotoStatus('ISBN '+isbn+' topildi. Kitob haqida ma’lumot qidirilmoqda...');
        const info=await findIsbnMetadata(isbn);
        if(ticket!==photoOperation||!$('bookDialog').open)return;
        if(info?.title){
          photoCandidates=[{...info,isbn,source:'ISBN katalogi'}];
          chooseCoverCandidate(0);
          return;
        }
        setPhotoStatus('ISBN saqlandi, ammo katalogda nashr topilmadi. Muqova matni tekshirilmoqda...');
      }
      setPhotoStatus('Muqovadagi o‘zbekcha yoki kirill yozuvlar o‘qilmoqda...');
      await loadPhotoOcrLibrary();
      if(ticket!==photoOperation||!$('bookDialog').open)return;
      try{
        worker=await window.Tesseract.createWorker(['uzb','rus','eng'],1);
      }catch(_){
        // Til modellari qurilmada yuklanmasa oddiy OCR ham ishlasin.
        worker=await window.Tesseract.createWorker(['eng','rus'],1);
      }
      const result=await worker.recognize(file);
      if(ticket!==photoOperation||!$('bookDialog').open)return;
      const raw=String(result?.data?.text||'').trim();
      const foundIsbn=raw.match(/97[89](?:[\s-]*\d){10}|(?:\d[\s-]*){9}[\dX]/i)?.[0]||'';
      const ocrIsbn=normalizedIsbn(foundIsbn);
      if(!isbn && validIsbn(ocrIsbn)){
        $('scanIsbnInput').value=ocrIsbn;
        $('bookIsbn').value=ocrIsbn;
        const info=await findIsbnMetadata(ocrIsbn);
        if(ticket!==photoOperation||!$('bookDialog').open)return;
        if(info?.title){
          photoCandidates=[{...info,isbn:ocrIsbn,source:'ISBN katalogi'}];
          chooseCoverCandidate(0);
          return;
        }
      }
      const guess=extractCoverSearchTerm(raw);
      if(photoManualSearchRequested||$('photoSearchText').value.trim())return;
      $('photoSearchText').value=guess;
      if(!guess){
        setPhotoStatus('Rasmdagi matn aniq o‘qilmadi. Muqovadan tiniqroq surat olib ko‘ring yoki Google rasmlardan izlang.',true);
        showCoverCandidates([]);
        return;
      }
      setPhotoStatus('Muqovadagi satrlar o‘qildi. Internetdan mos kitob qidirilmoqda...');
      await findCoverByText(guess,ticket);
    }catch(_){
      if(ticket===photoOperation&&$('bookDialog').open&&!photoManualSearchRequested){
        setPhotoStatus('Rasmni avtomatik o‘qish ishlamadi. Google va Instagram orqali qidirish tugmalaridan foydalaning.',true);
        showCoverCandidates([]);
      }
    }finally{
      if(worker){try{await worker.terminate();}catch(_){}}
      if(ticket===photoOperation)photoBusy=false;
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

  function searchQuality(query,record){
    const q=bookMatchKey(query);
    const title=bookMatchKey(record.title);
    if(!q||!title)return 0;
    if(q===title)return 110;
    if(title.startsWith(q)&&q.length>=4)return 91;
    if(q.includes(title)&&title.length>=5)return 88;
    const queryTokens=q.split(' ').filter(x=>x.length>=3);
    const titleTokens=title.split(' ').filter(x=>x.length>=3);
    if(!queryTokens.length||!titleTokens.length)return 0;
    const matched=titleTokens.filter(token=>queryTokens.some(word=>
      word===token||(word.length>=4&&token.startsWith(word))||(token.length>=4&&word.startsWith(token))
    )).length;
    const coverage=matched/titleTokens.length;
    const queryCoverage=matched/queryTokens.length;
    if(!matched||coverage<.50||queryCoverage<.45)return 0;
    return Math.round(40+coverage*35+queryCoverage*12);
  }

  function catalogVariants(query){
    const raw=cleanCoverText(query).slice(0,130).trim();
    const normalized=bookMatchKey(raw);
    const candidates=[raw];
    // Google Books/Open Library ba'zan o'zbekcha tutuq belgisini ajrata olmaydi.
    const noMarks=raw.replace(/[’‘ʻʼ']/g,'').replace(/'/g,'');
    if(noMarks!==raw)candidates.push(noMarks);
    const cyrillic=/[\u0400-\u052f]/.test(raw);
    if(cyrillic && normalized!==raw.toLowerCase())candidates.push(normalized);
    // Shovqinli OCR matnida muallif bilan birga kelgan nomni ham izlash.
    return [...new Set(candidates.map(v=>v.trim()).filter(x=>x.length>=3))].slice(0,3);
  }

  function mergeCatalogMatches(query,records){
    const unique=new Map();
    for(const book of records){
      if(!book?.title)continue;
      const quality=searchQuality(query,book);
      if(quality<50)continue;
      // Bitta asarning turli nashrlari (ISBN/nashriyot) aralashtirilmasin.
      const key=bookMatchKey(book.title)+'|'+bookMatchKey(book.author||'')+
        '|'+(book.isbn?String(book.isbn):bookMatchKey(book.publisher||''));
      const completeness=entry=>Number(Boolean(entry.cover))*4+
        Number(Boolean(entry.description))*2+Number(Boolean(entry.publisher))+
        Number(Boolean(entry.pages))+Number(Boolean(entry.isbn));
      const next={...book,score:quality,source:book.source||'Katalog'};
      const old=unique.get(key);
      if(!old||completeness(next)>completeness(old))unique.set(key,next);
    }
    return [...unique.values()].sort((a,b)=>b.score-a.score||
      Number(Boolean(b.cover))-Number(Boolean(a.cover))||
      Number(Boolean(b.description))-Number(Boolean(a.description))).slice(0,22);
  }

  async function findCoverCandidates(query){
    const q=cleanCoverText(query).slice(0,130).trim();
    if(bookMatchKey(q).length<3)return [];
    const local=localBookCandidates(q).map(b=>({...b,source:b.source||'Kutubxona'}));
    const terms=catalogVariants(q);
    const variants=terms.length>1?[terms[0],terms[1]]:[terms[0]];
    const searches=[
      ...variants.map(term=>
        fetchIsbnJson('https://www.googleapis.com/books/v1/volumes?q='+
          encodeURIComponent(term)+'&maxResults=30&printType=books')),
      fetchIsbnJson('https://openlibrary.org/search.json?q='+encodeURIComponent(q)+
        '&limit=24&fields=title,author_name,publisher,first_publish_year,number_of_pages_median,isbn,cover_i,language'),
      fetchIsbnJson('https://openlibrary.org/search.json?title='+encodeURIComponent(q)+
        '&limit=18&fields=title,author_name,publisher,first_publish_year,number_of_pages_median,isbn,cover_i,language')
    ];
    // Har bir katalog mustaqil so'raladi. Ulardan biri ishlamasa qolganlari ishlaydi.
    const batches=await Promise.all(searches);
    const results=[...local];
    const addGoogle=json=>{
      for(const entry of json?.items||[]){
        const v=entry?.volumeInfo||{};
        if(!v.title)continue;
        const image=v.imageLinks||{};
        results.push({
          title:v.title,author:(v.authors||[]).join(', '),
          publisher:v.publisher||'',year:yearFromText(v.publishedDate),
          pages:Number(v.pageCount||0),category:(v.categories||[])[0]||'',
          description:plainDescription(v.description),
          isbn:(v.industryIdentifiers||[]).map(item=>normalizedIsbn(item.identifier)).find(validIsbn)||'',
          cover:httpsImage(image.extraLarge||image.large||image.medium||image.thumbnail||image.smallThumbnail),
          source:'Google Books'
        });
      }
    };
    const addOpenLib=json=>{
      for(const entry of json?.docs||[]){
        if(!entry?.title)continue;
        results.push({
          title:entry.title,author:(entry.author_name||[]).join(', '),
          publisher:(entry.publisher||[])[0]||'',year:Number(entry.first_publish_year||0),
          pages:Number(entry.number_of_pages_median||0),category:'',description:'',
          isbn:(entry.isbn||[]).map(normalizedIsbn).find(validIsbn)||'',
          cover:entry.cover_i?'https://covers.openlibrary.org/b/id/'+entry.cover_i+'-L.jpg':'',
          source:'Open Library'
        });
      }
    };
    variants.forEach((_,i)=>addGoogle(batches[i]));
    addOpenLib(batches[variants.length]);
    addOpenLib(batches[variants.length+1]);
    const good=mergeCatalogMatches(q,results);
    if(good.length)return good;
    // Muallif yoki qo'shimcha so'zlar bilan yozilgan nom uchun soddaroq izlash.
    const shorter=q.split(/\s+/).slice(0,3).join(' ');
    if(shorter.length>=4 && bookMatchKey(shorter)!==bookMatchKey(q)){
      const fallback=await Promise.all([
        fetchIsbnJson('https://www.googleapis.com/books/v1/volumes?q='+
          encodeURIComponent(shorter)+'&maxResults=20&printType=books'),
        fetchIsbnJson('https://openlibrary.org/search.json?title='+
          encodeURIComponent(shorter)+'&limit=15&fields=title,author_name,publisher,first_publish_year,number_of_pages_median,isbn,cover_i')
      ]);
      addGoogle(fallback[0]);addOpenLib(fallback[1]);
      return mergeCatalogMatches(shorter,results);
    }
    return good;
  }

  function externalBookSearchLinks(query){
    const q=cleanCoverText(query).slice(0,130).trim();
    if(q.length<3)return '';
    const sources=[
      ['Google',q+' kitob muallif nashriyot'],
      ['Google rasmlar',q+' kitob muqova'],
      ['Instagram',q+' kitob site:instagram.com'],
      ['Asaxiy',q+' site:asaxiy.uz kitob'],
      ['Hilol',q+' site:hilolnashr.uz kitob'],
      ['Kitobxon',q+' site:kitobxon.com']
    ];
    return '<div class="book-web-sources" aria-label="Qo‘shimcha internet qidiruvi">'+
      '<small>Yana manbalardan izlash (tashqi sahifada ochiladi):</small>'+
      '<div>'+sources.map(([label,term])=>{
        const img=label==='Google rasmlar'?'&udm=2':'';
        const url='https://www.google.com/search?q='+encodeURIComponent(term)+img;
        return '<a href="'+escapeHtml(url)+'" target="_blank" rel="noopener noreferrer">'+
          escapeHtml(label)+' ↗</a>';
      }).join('')+'</div>'+
      '</div>';
  }

  function showCoverCandidates(results){
    photoCandidates=results;
    const holder=$('photoResults');
    if(!results.length){
      holder.innerHTML='<p class="photo-empty">Kataloglarda aniq kitob topilmadi. Google, Instagram yoki o‘zbek do‘konlarida kengroq tekshiring.</p>'+
        externalBookSearchLinks($('photoSearchText').value||$('bookTitle').value);
      return;
    }
    holder.innerHTML='<strong class="photo-results-heading">Topilgan kitoblar — mosini tanlang</strong>'+
      results.map((item,i)=>'<button type="button" class="photo-result" data-photo-result="'+i+'">'+
      (item.cover?'<img loading="lazy" src="'+escapeHtml(item.cover)+'" alt="">':'<span class="photo-result-no-cover">📖</span>')+
      '<span class="photo-result-text"><b>'+escapeHtml(item.title)+'</b><small>'+escapeHtml(item.author||'Muallif noma’lum')+'</small>'+
      '<small>'+escapeHtml([item.publisher,item.year||'',item.source||'Katalog'].filter(Boolean).join(' · '))+'</small></span>'+
      '<span class="photo-result-arrow">›</span></button>').join('')+
      externalBookSearchLinks($('photoSearchText').value||$('bookTitle').value);
  }

  async function findCoverByText(text,expectedTicket=photoOperation){
    const lines=coverSearchLines(text);
    const q=cleanCoverText(text);
    if(!q||q.length<3){
      setPhotoStatus('Muqovadagi nomni yozing yoki boshqa surat yuklang.',true);
      showCoverCandidates([]);return;
    }
    $('photoFindBtn').disabled=true;
    setPhotoStatus('Kitoblar kataloglari tekshirilmoqda...');
    try{
      const options=lines.length>1
        ?[lines.slice(0,2).join(' '),...lines.slice(0,3)]
        :[q];
      if(!options.includes(q)&&options.length<4)options.push(q);
      const unique=[...new Set(options.map(x=>cleanCoverText(x)).filter(x=>x.length>=3))].slice(0,4);
      const first=await Promise.all(unique.slice(0,2).map(findCoverCandidates));
      if(expectedTicket!==photoOperation||!$('bookDialog').open)return;
      let candidates=first.flat();
      if(!candidates.length && unique.length>2){
        const second=await Promise.all(unique.slice(2).map(findCoverCandidates));
        candidates.push(...second.flat());
      }
      if(expectedTicket!==photoOperation||!$('bookDialog').open)return;
      const uniqueResults=new Map();
      for(const item of candidates){
        const key=bookMatchKey(item.title)+'|'+bookMatchKey(item.author||'')+'|'+String(item.isbn||'');
        if(!uniqueResults.has(key) || (item.cover&&!uniqueResults.get(key)?.cover))
          uniqueResults.set(key,item);
      }
      const matches=[...uniqueResults.values()].sort((a,b)=>Number(b.score||0)-Number(a.score||0)).slice(0,16);
      showCoverCandidates(matches);
      setPhotoStatus(matches.length
        ?matches.length+' ta mos variant topildi. To‘g‘ri muqova va nashrni tanlang.'
        :'Kataloglarda mos kitob topilmadi. Google, Instagram va o‘zbek do‘konlarida izlash havolalari quyida.',!matches.length);
    }catch(_){
      if(expectedTicket===photoOperation){
        setPhotoStatus('Internet kataloglari vaqtincha ishlamayapti. Qo‘shimcha qidiruv havolalaridan foydalaning.',true);
        showCoverCandidates([]);
      }
    }finally{
      if(expectedTicket===photoOperation)$('photoFindBtn').disabled=false;
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


  // Yangi kitob kiritilayotganda nomdan metadata topish.
  // Mosligi aniq bo‘lmagan natijalar maydonlarga majburan yozilmaydi.
  function resetBookTitleLookup(book=null){
    clearTimeout(bookTitleLookup.timer);
    bookTitleLookup.request++;
    bookTitleLookup.candidates=[];
    bookTitleLookup.autoValues.clear();
    bookTitleLookup.manuallyEdited.clear();
    bookTitleLookup.autoCover=false;
    bookTitleLookup.coverLocked=Boolean(book?.cover);
    bookTitleLookup.appliedTitle='';
    $('bookAutoLookupResults').hidden=true;
    $('bookAutoLookupResults').replaceChildren();
    $('bookAutoLookupStatus').textContent=book
      ?'Kitob nomini o‘zgartirsangiz, mos nashrlarni qidirish mumkin.'
      :'Kitob nomini yozing — ma’lumotlari va muqovasi qidiriladi.';
  }

  function clearBookAutoValues(){
    for(const [id,value] of bookTitleLookup.autoValues){
      if($(id)?.value===value && !bookTitleLookup.manuallyEdited.has(id))$(id).value='';
    }
    bookTitleLookup.autoValues.clear();
    if(bookTitleLookup.autoCover && !bookTitleLookup.coverLocked){
      pendingCover='';
      setCoverPreview('');
    }
    bookTitleLookup.autoCover=false;
    bookTitleLookup.appliedTitle='';
  }

  function titleMatchScore(query,book){
    const q=bookMatchKey(query),title=bookMatchKey(book?.title||'');
    if(!q||!title)return 0;
    if(q===title)return 100;
    if(title.startsWith(q)&&q.length>=4)return 85;
    const words=q.split(' ').filter(w=>w.length>=2);
    const matched=words.filter(w=>title.split(' ').some(t=>t===w||t.startsWith(w)&&w.length>=4)).length;
    const ratio=words.length?matched/words.length:0;
    return words.length>=2 && ratio>=.75 && title.length<=q.length*2.3?Math.round(60+ratio*16):0;
  }

  function filterTitleMatches(query,candidates){
    const unique=new Map();
    for(const book of candidates){
      const score=titleMatchScore(query,book);
      if(score<60)continue;
      const key=bookMatchKey(book.title)+'|'+bookMatchKey(book.author||'');
      if(!key.trim())continue;
      const previous=unique.get(key);
      // Mavjud katalog nashrida yaxshiroq tavsif va muqova bo‘lishi mumkin.
      const richness=x=>Number(Boolean(x.cover))*3+Number(Boolean(x.publisher))*2+
        Number(Boolean(x.description))+Number(Boolean(x.pages));
      const candidate={...book,titleScore:score};
      if(!previous || score>previous.titleScore ||
        (score===previous.titleScore && richness(candidate)>richness(previous))){
        unique.set(key,candidate);
      }
    }
    return [...unique.values()].sort((a,b)=>b.titleScore-a.titleScore ||
      (Number(Boolean(b.cover))-Number(Boolean(a.cover)))).slice(0,7);
  }

  function showTitleAutoMatches(matches,query){
    const holder=$('bookAutoLookupResults');
    bookTitleLookup.candidates=matches;
    if(!matches.length){
      holder.innerHTML='<div class="book-auto-empty">Kataloglarda mos nashr aniqlanmadi. '+
        'Google, Instagram va o‘zbek do‘konlarini ham tekshiring. Ma’lumotni qo‘lda saqlash mumkin.</div>'+
        externalBookSearchLinks(query);
      holder.hidden=false;
      return;
    }
    holder.innerHTML=matches.map((book,index)=>
      '<button type="button" class="book-auto-result" data-book-auto-index="'+index+'" '+
      'aria-label="Kitob ma’lumotlarini to‘ldirish: '+escapeHtml(book.title)+'">'+
      (book.cover?'<img class="book-auto-result-cover" src="'+escapeHtml(book.cover)+'" loading="lazy" alt="">':
        '<span class="book-auto-result-cover book-auto-cover-placeholder" aria-hidden="true">📚</span>')+
      '<span class="book-auto-result-copy"><strong>'+escapeHtml(book.title)+'</strong>'+
      '<small>'+escapeHtml(book.author||'Muallif ko‘rsatilmagan')+'</small>'+
      '<em>'+escapeHtml([book.publisher,book.year||'',book.source||'Katalog'].filter(Boolean).join(' · '))+'</em></span>'+
      '<span class="book-auto-result-action">Tanlash</span></button>'
    ).join('')+externalBookSearchLinks(query);
    holder.hidden=false;
  }

  function applyTitleAutoCandidate(book,explicit=false){
    if(!book || !$('bookDialog').open)return false;
    const isEdit=Boolean($('bookId').value);
    if(isEdit && !explicit)return false;
    const typed=$('bookTitle').value.trim();
    const score=titleMatchScore(typed,book);
    if(!explicit && score!==100)return false;
    if(!explicit && bookTitleLookup.manuallyEdited.has('bookTitle'))return false;
    if(explicit && !isEdit){
      $('bookTitle').value=String(book.title||typed);
    }
    // Qo‘lda o‘zgartirilgan yoki oldin saqlangan maydonlarga tegmaymiz.
    const fields={
      bookAuthor:book.author,bookCategory:book.category,
      bookPublisher:book.publisher,bookIsbn:book.isbn,
      bookPublishedYear:book.year,bookPages:book.pages,
      bookDescription:book.description
    };
    let filled=0;
    for(const [id,value] of Object.entries(fields)){
      if(value===null||value===undefined||value===''||value===0)continue;
      if(bookTitleLookup.manuallyEdited.has(id))continue;
      const input=$(id),oldAuto=bookTitleLookup.autoValues.get(id);
      if(!input)continue;
      if(isEdit && input.value && oldAuto===undefined)continue;
      if(input.value && oldAuto===undefined)continue;
      if(oldAuto!==undefined && input.value!==oldAuto)continue;
      const next=String(value).slice(0,Number(input.maxLength)>0?input.maxLength:1600);
      input.value=next;
      bookTitleLookup.autoValues.set(id,next);
      filled++;
    }
    if(book.cover && !bookTitleLookup.coverLocked &&
      (!pendingCover||bookTitleLookup.autoCover)){
      pendingCover=book.cover;
      bookTitleLookup.autoCover=true;
      setCoverPreview(pendingCover);
      filled++;
    }
    if(filled){
      bookTitleLookup.appliedTitle=bookMatchKey($('bookTitle').value);
      $('bookAutoLookupStatus').textContent=explicit
        ?'Tanlangan kitob ma’lumotlari qo‘yildi. Maydonlarni tekshirib, xohlasangiz tahrirlang.'
        :'Aniq mos kitob topildi! Ma’lumotlari to‘ldirildi. Tekshirib, Saqlashni bosing.';
      return true;
    }
    $('bookAutoLookupStatus').textContent='Bu nashr topildi. Mavjud qo‘lda yozilgan ma’lumotlar saqlandi.';
    return false;
  }

  async function runBookTitleLookup(query,request){
    if(!$('bookDialog').open || bookTitleLookup.request!==request)return;
    $('bookAutoLookupStatus').textContent='Kitob internet kataloglaridan qidirilmoqda…';
    $('bookAutoLookupResults').hidden=true;
    try{
      const candidates=await findCoverCandidates(query);
      if(bookTitleLookup.request!==request || !$('bookDialog').open ||
        bookMatchKey($('bookTitle').value)!==bookMatchKey(query))return;
      const matches=filterTitleMatches(query,candidates);
      showTitleAutoMatches(matches,query);
      const exact=matches.filter(book=>book.titleScore===100);
      const authorTyped=bookMatchKey($('bookAuthor').value);
      const sameAuthor=authorTyped?exact.filter(b=>bookMatchKey(b.author)===authorTyped):[];
      // Bir xil nomli manbalar bitta muallifga tegishli bo'lsa eng to'liq nashrni tanlash.
      const authors=[...new Set(exact.map(x=>bookMatchKey(x.author)).filter(Boolean))];
      const ranked=[...exact].sort((a,b)=>
        Number(b.source==='shaxsiy kutubxona'||b.source==='Kutubxona')-
          Number(a.source==='shaxsiy kutubxona'||a.source==='Kutubxona') ||
        Number(Boolean(b.cover))-Number(Boolean(a.cover)) ||
        Number(Boolean(b.description))-Number(Boolean(a.description)));
      const chosen=sameAuthor.length===1?sameAuthor[0]:
        (exact.length===1?exact[0]:(!authorTyped&&authors.length<=1?ranked[0]||null:null));
      if(chosen && !$('bookId').value)applyTitleAutoCandidate(chosen,false);
      else $('bookAutoLookupStatus').textContent=matches.length
        ?matches.length+' ta mos variant topildi. To‘g‘ri nashrni bosing — ma’lumotlari to‘ldiriladi.'
        :'Kataloglarda topilmadi. Google, Instagram yoki o‘zbek saytlarda qo‘shimcha izlang.';
    }catch(_){
      if(bookTitleLookup.request!==request)return;
      $('bookAutoLookupStatus').textContent='Qidiruvda xatolik. Internetni tekshiring; kitobni qo‘lda saqlash mumkin.';
      $('bookAutoLookupResults').hidden=true;
    }
  }

  function onBookTitleTyping(){
    clearTimeout(bookTitleLookup.timer);
    const query=$('bookTitle').value.trim();
    bookTitleLookup.request++;
    const request=bookTitleLookup.request;
    if(bookTitleLookup.appliedTitle &&
      bookMatchKey(query)!==bookTitleLookup.appliedTitle)clearBookAutoValues();
    bookTitleLookup.candidates=[];
    $('bookAutoLookupResults').replaceChildren();
    $('bookAutoLookupResults').hidden=true;
    if(bookMatchKey(query).length<3){
      $('bookAutoLookupStatus').textContent='Qidirish uchun kitob nomidan kamida 3 ta harf yozing.';
      return;
    }
    $('bookAutoLookupStatus').textContent='Yozishni tugating — avtomatik qidiriladi…';
    bookTitleLookup.timer=setTimeout(()=>void runBookTitleLookup(query,request),800);
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

  function addReadingLog(book,date,page,readPagesDelta=0){
    if(!/^\d{4}-\d{2}-\d{2}$/.test(String(date||'')))return;
    book.readingLog=Array.isArray(book.readingLog)?book.readingLog:[];
    const safePage=Math.max(0,Math.round(Number(page)||0));
    const addition=Math.max(0,Math.round(Number(readPagesDelta)||0));
    const oldTotal=dailyBookPages(book).get(date)||0;
    const existing=book.readingLog.find(x=>x.date===date);
    if(existing){
      existing.page=Math.max(existing.page||0,safePage);
      existing.readPages=oldTotal+addition;
    }else{
      book.readingLog.push({date,page:safePage,readPages:addition});
    }
  }

  function readingProgressIncrement(book,page,referenceDate=today()){
    const seen=Math.max(
      Math.max(0,Math.round(Number(book.currentPage)||0)),
      ...(book.readingLog||[])
        .filter(x=>x.date<=referenceDate).map(x=>Math.max(0,Math.round(Number(x.page)||0)))
    );
    return Math.max(0,page-seen);
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
    const typedPage=numOrZero($('bookCurrentPage').value);
    const explicitIncrease=existing && typedPage>Number(existing.currentPage||0)
      ?readingProgressIncrement(existing,Math.min(typedPage,pages||typedPage)):0;
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
    // Yangi kitob qo‘shish yoki sanani o‘zgartirish avval o‘qilgan sahifalarni
    // hech qaysi kunga taxminan qo‘shmaydi. Faqat aniq sahifa ortishi qayd etiladi.
    if(explicitIncrease>0) addReadingLog(book,today(),currentPage,explicitIncrease);
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
    addReadingLog(book,today(),book.currentPage,0);
    saveState('Mutolaa boshlandi.');
    selectedBookId=id; renderBookDetail();
  }

  function updateProgress(id){
    const book=state.books.find(b=>b.id===id); if(!book) return;
    const value=prompt('Hozir nechanchi sahifadasiz?'+(book.pages?' Jami: '+book.pages:''),
      String(book.currentPage||''));
    if(value===null) return;
    const n=Math.max(0,Math.round(Number(value)||0));
    const nextPage=book.pages?Math.min(n,book.pages):n;
    const newlyRead=readingProgressIncrement(book,nextPage);
    book.currentPage=nextPage;
    if(!book.startedAt) book.startedAt=today();
    book.updatedAt=new Date().toISOString();
    addReadingLog(book,today(),book.currentPage,newlyRead);
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
    // "Tugatdim" tugmasi qolgan sahifalar o‘sha kuni o‘qildi degani emas.
    addReadingLog(book,today(),book.currentPage,0);
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

  function annualReadingSummary(year,activity=readingActivity(),dayPages=dailyReadingPages()){
    const started=state.books.filter(b=>b.startedAt?.startsWith(String(year)+'-'));
    const finished=booksCompletedInYear(year);
    const activityDays=[...dayPages.entries()].filter(([date,data])=>
      date.startsWith(String(year)+'-') && data.pages>0).map(([date])=>date);
    const monthTotals=Array.from({length:12},(_,month)=>{
      const prefix=String(year)+'-'+String(month+1).padStart(2,'0')+'-';
      const finishedMonth=finished.filter(b=>b.finishedAt.startsWith(prefix));
      const startedMonth=started.filter(b=>b.startedAt.startsWith(prefix));
      const days=activityDays.filter(d=>d.startsWith(prefix));
      const pages=days.reduce((sum,d)=>sum+(dayPages.get(d)?.pages||0),0);
      return {month,finished:finishedMonth.length,started:startedMonth.length,days:days.length,pages};
    });
    return {
      year,started,finished,activityDays,monthTotals,
      pages:monthTotals.reduce((sum,x)=>sum+x.pages,0),
      streak:longestReadingStreak(activityDays)
    };
  }

  function renderStats(){
    statsSelectedYear=syncYearSelect($('statsYear'),statsSelectedYear);
    $('statsPeriodMonth').value=String(statsPeriodMonth);
    if(!statsPeriodDay.startsWith(String(statsSelectedYear)+'-')){
      statsPeriodDay=statsSelectedYear+'-'+String(statsPeriodMonth+1).padStart(2,'0')+'-01';
    }
    $('statsPeriodDay').value=statsPeriodDay;
    $('statsMonthPicker').hidden=statsPeriod!=='month';
    $('statsDayPicker').hidden=statsPeriod!=='day';
    qsa('#statsPeriodSwitch [data-stats-period]').forEach(button=>
      button.classList.toggle('active',button.dataset.statsPeriod===statsPeriod));
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
    const pageDays=dailyReadingPages();
    const yearRecords=[...pageDays.entries()].filter(([date,data])=>
      date.startsWith(String(year)+'-')&&data.pages>0);
    $('statsPages').textContent=(yearRecords.length?
      Math.max(...yearRecords.map(([,data])=>data.pages)):0)+' sahifa';
    $('statsTodayPages').textContent=pagesReadOnDate(today())+' sahifa';
    $('statsAvgPagesPerDay').textContent=(summary.activityDays.length
      ?Math.round(summary.pages/summary.activityDays.length):0)+' sahifa';
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
        '<span class="monthly-result-details">'+row.days+' faol kun · '+row.pages+' sahifa</span>'+
        '<b>'+row.finished+' tugatilgan</b><span aria-hidden="true">›</span></button>'
      ).join('');
    } else if(statTab==='pages'){
      renderPagesPeriodChart(year,summary,chart);
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
    const readingGenres=state.books.filter(book=>statusOf(book)==='reading' &&
      Number(book.currentPage||0)>0 &&
      (book.startedAt?.startsWith(String(year)+'-') ||
        (book.readingLog||[]).some(entry=>entry.date.startsWith(String(year)+'-'))));
    renderGenreDonut([...summary.finished,...readingGenres]);
  }

  function renderPagesPeriodChart(year,summary,chart){
    const labels=['Yan','Fev','Mar','Apr','May','Iyun','Iyul','Avg','Sen','Okt','Noy','Dek'];
    const pageRecords=dailyReadingPages();
    const makeBars=(rows,compact=false)=>{
      const max=Math.max(1,...rows.map(x=>x.count));
      const unit=compact?'':' sahifa';
      const bars=rows.map(row=>{
        const value=Math.max(0,Number(row.count)||0);
        const height=Math.max(value?10:3,Math.round(value/max*100));
        return '<div class="period-page-bar" title="'+escapeHtml(row.full||row.label)+': '+value+' sahifa">'+
          '<b>'+value+'</b><span class="period-page-bar-track"><i style="height:'+height+'%"></i></span>'+
          '<small>'+escapeHtml(row.label)+'</small></div>';
      }).join('');
      chart.className='reading-range-scroll'+(compact?' compact':'');
      chart.innerHTML='<div class="reading-range-bars">'+bars+'</div>';
    };
    if(statsPeriod==='month'){
      const month=statsPeriodMonth;
      const dates=new Date(year,month+1,0).getDate();
      const prefix=year+'-'+String(month+1).padStart(2,'0')+'-';
      const rows=Array.from({length:dates},(_,i)=>{
        const date=prefix+String(i+1).padStart(2,'0');
        return {label:String(i+1),full:date,count:pageRecords.get(date)?.pages||0};
      });
      $('statsChartTitle').textContent=labels[month]+' · kunlik sahifalar';
      $('statsChartEyebrow').textContent=year+'-YIL · KUNMA-KUN';
      makeBars(rows,true);
      return;
    }
    if(statsPeriod==='day'){
      const date=statsPeriodDay;
      const rows=state.books.map(book=>({
        title:book.title,
        author:book.author||'',
        pages:dailyBookPages(book).get(date)||0,
        cover:book
      })).filter(x=>x.pages>0).sort((a,b)=>b.pages-a.pages);
      const total=rows.reduce((n,x)=>n+x.pages,0);
      $('statsChartTitle').textContent='Tanlangan kun mutolaasi';
      $('statsChartEyebrow').textContent=date+' · KUNLIK NATIJA';
      chart.className='reading-day-summary';
      chart.innerHTML='<div class="reading-day-total"><b>'+total+'</b><span> sahifa o‘qilgan · '+rows.length+' kitob</span></div>'+
        (rows.length?rows.map(x=>'<div class="reading-day-book">'+coverHtml(x.cover)+
          '<div><b>'+escapeHtml(x.title)+'</b><small>'+escapeHtml(x.author)+'</small></div>'+
          '<strong>+'+x.pages+' sahifa</strong></div>').join('')
          :'<p class="genre-donut-empty">Bu kun uchun sahifa qaydi yo‘q.</p>');
      return;
    }
    if(statsPeriod==='all'){
      const years=datedReadingYears().slice().reverse();
      const rows=years.map(y=>({label:String(y),count:annualReadingSummary(y).pages}));
      $('statsChartTitle').textContent='Barcha yillar · o‘qilgan sahifalar';
      $('statsChartEyebrow').textContent='BARCHA YILLAR';
      makeBars(rows);
      return;
    }
    $('statsChartTitle').textContent='Oylar bo‘yicha o‘qilgan sahifalar';
    $('statsChartEyebrow').textContent=year+'-YIL · 12 OY';
    makeBars(summary.monthTotals.map(x=>({label:labels[x.month],count:x.pages})));
  }

  function renderGenreDonut(finished){
    const root=$('genreDonut'),legend=$('genreDonutLegend');
    if(!root||!legend)return;
    const entries=groupCount(finished,book=>book.category||'Boshqa').slice(0,5);
    const total=entries.reduce((sum,[,n])=>sum+n,0);
    if(!total){
      root.style.background='var(--surface2)';
      root.innerHTML='<div class="genre-donut-center"><b>0</b><small>kitob</small></div>';
      legend.innerHTML='<p class="genre-donut-empty">Bu yil o‘qilgan kitoblar bo‘yicha janr statistikasi hali yo‘q.</p>';
      root.setAttribute('aria-label','Tugatilgan kitoblar hali yo‘q');
      return;
    }
    const colors=['#0c6a62','#1fa88e','#3b95b6','#bb79a7','#d8c39d'];
    let start=0;
    const gradients=entries.map(([,n],index)=>{
      const next=start+n/total*100;
      const segment=colors[index]+' '+start.toFixed(3)+'% '+next.toFixed(3)+'%';
      start=next;
      return segment;
    });
    root.style.background='conic-gradient('+gradients.join(',')+')';
    root.innerHTML='<div class="genre-donut-center"><b>'+total+'</b><small>kitob</small></div>';
    root.setAttribute('aria-label','Janrlar: '+entries.map(([name,n])=>name+' '+n+' ta').join(', '));
    legend.innerHTML=entries.map(([name,n],i)=>
      '<div class="genre-donut-legend-row"><i style="background:'+colors[i]+'"></i>'+
      '<span>'+escapeHtml(name)+'</span><b>'+Math.round(n/total*100)+'%</b></div>').join('');
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
    const dayPages=dailyReadingPages();
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
        const pages=dayPages.get(key)?.pages||0;
        const cls=['year-mini-day'];
        if(pages>0)cls.push('read');
        if(pages>=20)cls.push('read-strong');
        if(events?.finished.size)cls.push('finish');
        if(key===today())cls.push('today');
        const title=day+'-'+shortMonths[month]+': '+pages+' sahifa'+
          (events?.finished.size?' · Kitob tugatilgan':'');
        days+='<span class="'+cls.join(' ')+'" title="'+title+'">'+day+'</span>';
      }
      const total=offset+last;
      for(let pad=total;pad<42;pad++)days+='<span class="year-mini-day empty" aria-hidden="true"></span>';
      return '<button type="button" class="year-calendar-month" data-year-month="'+month+
        '" aria-label="'+year+'-yil '+shortMonths[month]+': '+row.pages+' sahifa, '+row.days+' faol kun, '+row.finished+' ta tugatilgan">'+
        '<span class="year-calendar-month-heading"><b>'+shortMonths[month]+'</b><span>'+row.days+' faol kun</span></span>'+
        '<span class="year-mini-weekdays" aria-hidden="true"><span>D</span><span>S</span><span>Ch</span><span>P</span><span>J</span><span>Sh</span><span>Y</span></span>'+
        '<span class="year-mini-grid" aria-hidden="true">'+days+'</span>'+
        '<span class="year-calendar-month-footer"><b>'+row.pages+' sahifa</b><span>'+row.finished+' kitob ✓</span></span>'+
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
    $('calReadPages').textContent=yearMode?summary.pages:monthData.pages;
    $('calPagesPeriod').textContent=yearMode?year+'-yil':'Tanlangan oy';
    $('calActivePeriod').textContent=yearMode?year+'-yil':'Tanlangan oy';
    $('calFinishedPeriod').textContent=yearMode?'Shu yilda':'Tanlangan oy';
    $('calStreakPeriod').textContent=year+'-yil';

    if(yearMode){
      renderYearOverview(year,summary,activity);
      return;
    }
    const dayPages=dailyReadingPages();
    const first=new Date(year,month,1),last=new Date(year,month+1,0);
    const offset=(first.getDay()+6)%7;
    const todayKey=today(),prefix=year+'-'+String(month+1).padStart(2,'0')+'-';
    if(!selectedCalendarDay.startsWith(prefix))selectedCalendarDay=prefix+'01';
    let html='';
    for(let i=0;i<offset;i++)html+='<span class="day-cell empty" aria-hidden="true"></span>';
    for(let day=1;day<=last.getDate();day++){
      const key=prefix+String(day).padStart(2,'0'),events=activity.get(key);
      const readPages=dayPages.get(key)?.pages||0;
      const finished=Boolean(events?.finished.size);
      const active=readPages>0;
      const classes=['day-cell'];
      if(active)classes.push('read');
      if(readPages>=20)classes.push('read-strong');
      if(finished)classes.push('finish');
      if(key===todayKey)classes.push('today');
      if(key===selectedCalendarDay)classes.push('selected');
      const aria=key+' — '+readPages+' sahifa o‘qilgan'+(finished?', kitob tugatilgan':'');
      html+='<button type="button" class="'+classes.join(' ')+'" data-calendar-day="'+key+
        '" aria-label="'+aria+'" aria-pressed="'+(key===selectedCalendarDay)+'">'+day+
        (active?'<small class="day-pages" aria-hidden="true">'+readPages+'</small>':'')+'</button>';
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
      '<span class="day-events-count">'+pagesReadOnDate(date)+' sahifa · '+
      minutesReadOnDate(date)+' daq · '+books.length+' kitob</span></div>'+
      (books.length?'<div class="calendar-book-events">'+books.map(book=>{
        const notes=[];
        if(book.startedAt===date)notes.push('Mutolaa boshlangan');
        if(book.finishedAt===date)notes.push('Kitob tugatilgan');
        const entry=(book.readingLog||[]).find(x=>x.date===date);
        const readPages=dailyBookPages(book).get(date)||0;
        const readMinutes=(book.readingLog||[]).filter(x=>x.date===date)
          .reduce((s,x)=>s+Math.max(0,Number(x.minutes)||0),0);
        if(readMinutes)notes.push(readMinutes+' daqiqa');
        if(readPages>0)notes.push('Bugun '+readPages+' sahifa o‘qilgan');
        if(entry && entry.page>0)notes.push(entry.page+'-sahifagacha yetilgan');
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

  function openDailyBookPicker(search=''){
    const current=String(state.profile.dailyPlanBookId||'');
    const books=selectableDailyBooks();
    const q=String(search||'').trim().toLocaleLowerCase();
    const result=books.filter(book=>
      !q||[book.title,book.author,book.category].some(x=>String(x||'').toLocaleLowerCase().includes(q))
    );
    const rows=result.map(book=>{
      const active=current===String(book.id);
      return '<button type="button" class="daily-plan-book-option'+(active?' selected':'')+
        '" data-select-daily-book="'+escapeHtml(book.id)+'" aria-pressed="'+active+'">'+
        coverHtml(book,'daily-plan-option-cover')+
        '<span class="daily-plan-book-meta"><strong>'+escapeHtml(book.title)+'</strong>'+
        '<small>'+escapeHtml(book.author||'Muallif kiritilmagan')+'</small>'+
        '<em>'+statusLabel(statusOf(book))+'</em></span>'+
        '<span class="daily-plan-book-check" aria-hidden="true">'+(active?'✓':'›')+'</span></button>';
    }).join('');
    const html='<div class="daily-plan-picker">'+
      '<p class="daily-plan-picker-info">Bugungi rejaga kutubxonangizdan kitob tanlang. Tanlov saqlanadi; o‘qish tarixi va kitob holati o‘zgarmaydi.</p>'+
      '<label class="daily-plan-search-label">Kitob qidirish'+
      '<input type="search" id="dailyPlanBookSearch" autocomplete="off" placeholder="Kitob yoki muallif nomi" value="'+escapeHtml(search)+'"></label>'+
      '<div class="daily-plan-book-list">'+
      '<button type="button" class="daily-plan-book-option daily-plan-auto-option'+(!current?' selected':'')+
      '" data-select-daily-book="" aria-pressed="'+(!current)+'">'+
      '<span class="daily-plan-auto-icon" aria-hidden="true">↻</span>'+
      '<span class="daily-plan-book-meta"><strong>Avtomatik tanlash</strong><small>Oxirgi faol mutolaa</small></span>'+
      '<span class="daily-plan-book-check" aria-hidden="true">'+(!current?'✓':'›')+'</span></button>'+
      (rows||'<p class="daily-plan-no-books">'+(books.length?'Qidiruvga mos kitob topilmadi.':'O‘qilayotgan yoki rejalashtirilgan kitob mavjud emas.')+'</p>')+
      '</div></div>';
    // The search control must keep its focus and cursor while results are refreshed.
    if($('simpleDialog').open && $('simpleDialogTitle').textContent==='Bugungi kitobni tanlash'){
      const holder=$('simpleDialogBody');
      const oldInput=$('dailyPlanBookSearch');
      const pos=oldInput?.selectionStart??null;
      holder.innerHTML=html;
      const next=$('dailyPlanBookSearch');
      if(oldInput){next.focus();try{if(pos!==null)next.setSelectionRange(pos,pos);}catch(_){}}
    }else{
      openSimple('Bugungi kitobni tanlash',html);
    }
  }

  function openDailyGoalDialog(){
    openSimple('Bugungi mutolaa rejasi',
      '<div class="setting-form">'+
      '<p class="daily-goal-note">Bu raqamlar reja hisoblanadi. Haqiqiy o‘qilgan sahifalar mutolaa qaydlaridan olinadi.</p>'+
      '<label>Kunlik sahifa maqsadi<input id="dailyPageGoalInput" type="number" min="1" max="300" value="'+state.profile.dailyPageGoal+'"></label>'+
      '<label>Kunlik mutolaa vaqti (daqiqa)<input id="dailyMinutesGoalInput" type="number" min="5" max="240" value="'+state.profile.dailyMinutesGoal+'"></label>'+
      '<div class="setting-actions"><button type="button" class="primary-button" data-save-daily-goal>Saqlash</button></div></div>');
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
      const bookOpen=e.target.closest('[data-book-open]'); if(bookOpen && !e.target.closest('[data-book-menu]')){selectedBookId=bookOpen.dataset.bookOpen;detailTab='general';navigate('detail');return;}
      const tab=e.target.closest('[data-detail-tab]');
      if(tab){detailTab=tab.dataset.detailTab;renderBookDetail();return;}
      const timer=e.target.closest('[data-reading-timer]');
      if(timer){toggleReadingTimer(timer.dataset.readingTimer);return;}
      const menu=e.target.closest('[data-book-menu]'); if(menu){e.stopPropagation();openBookMenu(menu.dataset.bookMenu);return;}
      const edit=e.target.closest('[data-edit-book]'); if(edit){openBookDialog(state.books.find(b=>b.id===edit.dataset.editBook));return;}
      const start=e.target.closest('[data-start-book]'); if(start){startBook(start.dataset.startBook);return;}
      const prog=e.target.closest('[data-progress-book]'); if(prog){updateProgress(prog.dataset.progressBook);return;}
      const finish=e.target.closest('[data-finish-book]'); if(finish){finishBook(finish.dataset.finishBook);return;}
      const cal=e.target.closest('[data-calendar-day]'); if(cal){renderCalendarDay(cal.dataset.calendarDay);return;}
      const cat=e.target.closest('[data-category]'); if(cat){$('bookSearch').value=cat.dataset.category;bookFilter='all';navigate('library');renderBooks();return;}
      const txEdit=e.target.closest('[data-tx-edit]'); if(txEdit){openTxDialog(state.transactions.find(t=>t.id===txEdit.dataset.txEdit));return;}
      const txDelete=e.target.closest('[data-tx-delete]'); if(txDelete){if(confirm('Tranzaksiyani o‘chirasizmi?')){state.transactions=state.transactions.filter(t=>t.id!==txDelete.dataset.txDelete);saveState('Tranzaksiya o‘chirildi.');}return;}

      const dailyPick=e.target.closest('[data-select-daily-book]');
      if(dailyPick){
        const id=String(dailyPick.dataset.selectDailyBook||'');
        if(id && !selectableDailyBooks().some(book=>String(book.id)===id)){
          toast('Bu kitobni tanlab bo‘lmaydi.');return;
        }
        state.profile.dailyPlanBookId=id;
        $('simpleDialog').close();
        saveState(id?'Bugungi rejadagi kitob o‘zgartirildi.':'Avtomatik tanlash yoqildi.');
        return;
      }

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

      if(e.target.closest('[data-save-daily-goal]')){
        state.profile.dailyPageGoal=clampInt($('dailyPageGoalInput').value,1,300);
        state.profile.dailyMinutesGoal=clampInt($('dailyMinutesGoalInput').value,5,240);
        $('simpleDialog').close();
        saveState('Kunlik reja saqlandi.');
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
    $('bookTitle').addEventListener('input',onBookTitleTyping);
    $('bookAutoLookupResults').addEventListener('click',event=>{
      const button=event.target.closest('[data-book-auto-index]');
      if(!button)return;
      const book=bookTitleLookup.candidates[Number(button.dataset.bookAutoIndex)];
      if(book){
        clearTimeout(bookTitleLookup.timer);
        bookTitleLookup.request++;
        applyTitleAutoCandidate(book,true);
        $('bookAutoLookupResults').hidden=true;
      }
    });
    for(const id of ['bookAuthor','bookCategory','bookPublisher','bookIsbn',
      'bookPublishedYear','bookPages','bookDescription']){
      $(id).addEventListener('input',()=>{
        bookTitleLookup.manuallyEdited.add(id);
        bookTitleLookup.autoValues.delete(id);
      });
    }
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
      clearTimeout(bookTitleLookup.timer);
      bookTitleLookup.request++;
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
      try{
        pendingCover=await compressImage(file);
        bookTitleLookup.coverLocked=true;
        bookTitleLookup.autoCover=false;
        setCoverPreview(pendingCover);
      }catch(_){toast('Rasmni o‘qib bo‘lmadi.');}
    });
    $('bookSearch').addEventListener('input',renderBooks);
    $('bookSort').addEventListener('change',renderBooks);
    $('bookFilters').addEventListener('click',e=>{
      const btn=e.target.closest('[data-filter]'); if(!btn) return;
      bookFilter=btn.dataset.filter;qsa('#bookFilters button').forEach(b=>b.classList.toggle('active',b===btn));renderBooks();
    });
    $('statsYear').addEventListener('change',event=>{statsSelectedYear=Number(event.target.value)||nowYear;renderStats();});
    $('statsPeriodSwitch').addEventListener('click',event=>{
      const button=event.target.closest('[data-stats-period]');
      if(!button)return;
      statsPeriod=button.dataset.statsPeriod;
      statTab='pages';
      qsa('#statTabs button').forEach(b=>b.classList.toggle('active',b.dataset.statTab==='pages'));
      renderStats();
    });
    $('statsPeriodMonth').addEventListener('change',event=>{
      statsPeriodMonth=Number(event.target.value)||0;
      statsPeriod='month';statTab='pages';renderStats();
    });
    $('statsPeriodDay').addEventListener('change',event=>{
      if(!event.target.value)return;
      const chosenYear=Number(event.target.value.slice(0,4));
      if(!datedReadingYears().includes(chosenYear)){
        toast('Bu yilda mutolaa qaydlari topilmadi.');
        renderStats();return;
      }
      statsSelectedYear=chosenYear;
      statsPeriodDay=event.target.value;
      statsPeriod='day';statTab='pages';renderStats();
    });
    $('genreDonutToggle').addEventListener('click',()=>{
      statTab='genres';
      qsa('#statTabs button').forEach(button=>button.classList.toggle('active',button.dataset.statTab==='genres'));
      renderStats();
      $('monthlyChart').scrollIntoView({behavior:'smooth',block:'nearest'});
    });
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
    $('homeHeroChangeBook').addEventListener('click',()=>openDailyBookPicker());
    $('homeHeroContinue').addEventListener('click',()=>{
      const book=getHomeReadingBook();
      if(book){selectedBookId=book.id;navigate('detail');}
      else navigate('library');
    });
    $('homeHeroStreakBtn').addEventListener('click',()=>navigate('calendar'));
    $('homeHeroGoalBtn').addEventListener('click',openDailyGoalDialog);
    $('simpleDialogBody').addEventListener('input',event=>{
      if(event.target.id==='dailyPlanBookSearch')openDailyBookPicker(event.target.value);
    });
    $('globalSearchBtn').addEventListener('click',()=>{navigate('library');setTimeout(()=>$('bookSearch').focus(),100);});
    $('bellBtn').addEventListener('click',openReminderDialog);
    $('detailMore').addEventListener('click',()=>selectedBookId&&openBookMenu(selectedBookId));
    document.addEventListener('visibilitychange',()=>{
      if(document.hidden && readingTimer.bookId)stopReadingTimer(true);
    });
  }

  if('serviceWorker' in navigator){
    window.addEventListener('load',()=>navigator.serviceWorker.register('./sw.js').catch(()=>{}));
  }

  bindEvents();
  renderAll();
  navigate('home',false);
  maybeDailyReminder();
})();