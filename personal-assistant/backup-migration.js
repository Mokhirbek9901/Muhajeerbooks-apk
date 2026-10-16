(function(root,factory){
  'use strict';
  const helper=factory();
  if(typeof module==='object'&&module.exports)module.exports=helper;
  else root.YordamchiBackupMigration=helper;
})(typeof globalThis==='object'?globalThis:this,function(){
  'use strict';
  const fields=['books','bookCosts','transactions'];
  const label='Bek Shaxsiy Yordamchi';
  const isRecord=value=>value!==null&&typeof value==='object'&&!Array.isArray(value);
  function summary(value){
    const safe=isRecord(value)?value:{};
    const arr=name=>Array.isArray(safe[name])?safe[name]:[];
    const books=arr('books');
    return {
      books:books.length,
      readingRecords:books.reduce((sum,row)=>sum+(Array.isArray(row?.readingLog)?row.readingLog.length:0),0),
      bookCosts:arr('bookCosts').length,
      transactions:arr('transactions').length,
      products:arr('koreaProducts').length
    };
  }
  function inspect(payload){
    if(!isRecord(payload))throw new Error('Backup fayli JSON obyekt bo‘lishi kerak.');
    if(payload.app&&payload.app!==label)throw new Error('Bu fayl Yordamchi ilovasining Backup fayli emas.');
    const data=isRecord(payload.data)?payload.data:payload;
    if(!isRecord(data)||fields.some(field=>!Array.isArray(data[field]))){
      throw new Error('To‘liq Yordamchi Backup fayli kerak: kitoblar, tan narxlari va moliya ro‘yxatlari bo‘lishi shart.');
    }
    for(const field of fields){
      if(data[field].some(item=>!isRecord(item)))throw new Error('Backup ichidagi '+field+' ro‘yxati buzilgan.');
    }
    return {data,counts:summary(data)};
  }
  function assertNotLost(source,target){
    const actual=summary(target);
    for(const key of ['books','readingRecords','bookCosts','transactions','products']){
      if(actual[key]<source[key])throw new Error(key+' yozuvlari kamaymoqda. Hech narsa tiklanmadi.');
    }
    return actual;
  }
  function describe(counts){
    return counts.books+' ta kitob, '+counts.readingRecords+' ta mutolaa qaydi, '+
      counts.bookCosts+' ta tan narxi, '+counts.transactions+' ta moliya yozuvi, '+
      counts.products+' ta Koreya mahsuloti';
  }
  return {inspect,summary,assertNotLost,describe};
});
