(function(root,factory){
  'use strict';
  const api=factory();
  if(typeof module==='object'&&module.exports)module.exports=api;
  else root.YordamchiWorkspaces=api;
})(typeof globalThis==='object'?globalThis:this,function(){
  'use strict';
  const MODES=Object.freeze({
    reading:{title:'Kitoblarim',subtitle:'Mutolaa va o‘qish statistikasi',root:'home',icon:'book'},
    costs:{title:'Kitob tan narxi',subtitle:'Xarid, yetkazish va foyda hisobi',root:'book-costs',icon:'wallet'},
    products:{title:'Koreya mahsulotlari',subtitle:'Mahsulotlar va tan narxi hisobi',root:'korea-products',icon:'bag'},
    finance:{title:'Kirim-chiqim',subtitle:'Shaxsiy moliya va statistika',root:'finance',icon:'chart'}
  });
  const READING_VIEWS=['home','library','detail','stats','calendar','categories'];
  const MODES_ORDER=['reading','costs','products','finance'];
  function modeOfView(view){
    if(READING_VIEWS.includes(view))return 'reading';
    if(view==='book-costs')return 'costs';
    if(view==='korea-products')return 'products';
    if(view==='finance')return 'finance';
    return null;
  }
  function safeMode(value){return Object.hasOwn(MODES,value)?value:'reading';}
  function rootView(mode){return MODES[safeMode(mode)].root;}
  function navTab(mode,view,options={}){
    const m=safeMode(mode);
    if(view==='profile')return 'profile';
    if(m==='reading')return ['library','stats'].includes(view)?view:'home';
    if(m==='costs')return options.costView==='report'?'report':options.costView==='settings'?'settings':options.costView==='entry'?'entry':options.costView==='list'?'list':'main';
    if(m==='products')return ['entry','list','stats'].includes(options.productView)?options.productView:'overview';
    if(m==='finance')return ['stats','history'].includes(options.financeView)?options.financeView:'overview';
    return 'home';
  }
  return {MODES,MODES_ORDER,READING_VIEWS,safeMode,modeOfView,rootView,navTab};
});
