-- Approved 33 groups of equivalent book titles. No orders, quantities, prices or dates modified.
-- Human-reviewed 2026-10-31. Names not in the explicit mapping remain unchanged.
create table if not exists private.approved_sales_title_backup_20261031 (
 source_table text not null check (source_table in ('legacy_sales_history','sales_log')),
 row_id bigint not null,
 group_no integer not null,
 old_title text not null,
 new_title text not null,
 captured_at timestamptz not null default now(),
 primary key (source_table,row_id)
);
revoke all on private.approved_sales_title_backup_20261031 from public, anon, authenticated;

do $apply$
declare
 h bigint;
 r bigint;
begin
 -- The exact, approved source labels only; never a fuzzy update.
 with mapping(group_no,old_title,new_title) as (values (1,'Tajvidli Qur’oni Karim','Qur’oni Karim — Tajvidli Mushaf'),
(1,'Qur’oni Karim — Tajvidli Mushaf','Qur’oni Karim — Tajvidli Mushaf'),
(2,'Nikoh ostonasi','Nikoh ostonasida'),
(2,'Nikoh ostonasida','Nikoh ostonasida'),
(3,'Umrga tatigulik safar','Umrga tatigulik safar'),
(3,'Umrga tatigulik','Umrga tatigulik safar'),
(3,'Urga tatigulik','Umrga tatigulik safar'),
(3,'Unrga tatigulik s','Umrga tatigulik safar'),
(3,'Umrga tatigu','Umrga tatigulik safar'),
(4,'Ichingdagi ichingda','Ichingdagi ichingdadir'),
(4,'Ichingdagi ichingdadir','Ichingdagi ichingdadir'),
(5,'Yaralangan qush','Yaralangan qush hamon'),
(5,'Yaralangan qush hamon','Yaralangan qush hamon'),
(6,'Manipulyativ','Manipulyativ diktatorlar'),
(6,'Manipulyativ d','Manipulyativ diktatorlar'),
(6,'Manipulyativ dik','Manipulyativ diktatorlar'),
(6,'Manipulytaiv d','Manipulyativ diktatorlar'),
(6,'Manipulyativ diktarorl','Manipulyativ diktatorlar'),
(7,'Hayot binosi','Hayot binosi'),
(7,'Hayot binosining','Hayot binosi'),
(7,'Hayot binosining ij','Hayot binosi'),
(8,'Mo’jiza sodir','Mo‘jiza sodir bo‘lmaydi'),
(8,'Mo’jiza sodir bo’lm','Mo‘jiza sodir bo‘lmaydi'),
(9,'O’lsang kim','O‘lsang, kim yig‘laydi?'),
(9,'O’lsang kim y','O‘lsang, kim yig‘laydi?'),
(9,'O’lsang kim yig','O‘lsang, kim yig‘laydi?'),
(10,'Umringizni o’g’irlagan','Umringizni o’g’irlagan'),
(10,'Umringizni o’','Umringizni o’g’irlagan'),
(10,'Umringizni og','Umringizni o’g’irlagan'),
(10,'Umringizni','Umringizni o’g’irlagan'),
(11,'Seni toliqtirayotgan','Seni toliqtirayotgan hamma narsadan voz kech'),
(11,'Seni toliqtir','Seni toliqtirayotgan hamma narsadan voz kech'),
(11,'Seni toliq','Seni toliqtirayotgan hamma narsadan voz kech'),
(12,'Yo’qotilgan jannat','Yo’qotilgan jannat'),
(12,'Yoqotilgan jann','Yo’qotilgan jannat'),
(12,'Yo’qotilgan ja','Yo’qotilgan jannat'),
(13,'Sulton Abdulhamidxon siri','Sulton Abdulhamidxon siri'),
(13,'Sulton Abdulhamidxon','Sulton Abdulhamidxon siri'),
(13,'Sulton abdulhamid','Sulton Abdulhamidxon siri'),
(14,'Jannat bostoni','Jannat bostoni'),
(14,'Jannat bo’stonidagi','Jannat bostoni'),
(14,'Jannat bo’stonidagi oilaviy','Jannat bostoni'),
(15,'Rasulullohdan go’zal nasihat','Rasulullohdan go’zal nasihat'),
(15,'Rasulullohdan go’zal','Rasulullohdan go’zal nasihat'),
(16,'Davinchi siri','Da Vinchi siri'),
(16,'Davinchi','Da Vinchi siri'),
(17,'Muhabbat haqida 101','Muhabbat haqida 101'),
(17,'101 muhabbat haqida','Muhabbat haqida 101'),
(17,'Muhabbat h 101','Muhabbat haqida 101'),
(18,'Hokimiyatning 48 qoidasi','Hokimiyatning 48 qoidasi'),
(18,'Hokimiyatning','Hokimiyatning 48 qoidasi'),
(19,'O‘tkan kunlar: roman','O‘tkan kunlar: roman'),
(19,'O’tkan kunlar','O‘tkan kunlar: roman'),
(20,'Ulamolar nazdida vaqtning qadri','Ulamolar nazdida vaqtning qadri'),
(20,'Ulamolar nazdida vaqt','Ulamolar nazdida vaqtning qadri'),
(21,'Jannat va do’zax','Jannat va do’zax'),
(21,'Jannat va doz','Jannat va do’zax'),
(22,'Sivilizatsiyalar to’qnashuv','Sivilizatsiyalar to‘qnashuvi va yangi dunyo tartibi'),
(22,'Sivilizatsiyalar','Sivilizatsiyalar to‘qnashuvi va yangi dunyo tartibi'),
(23,'Sof tabiat dini','Sof tabiat dini'),
(23,'Sof tabiat','Sof tabiat dini'),
(24,'Men ham kitob oqiy','Men ham kitob o‘qiyman'),
(24,'Men ham kitob','Men ham kitob o‘qiyman'),
(25,'Tasavvuf haqida tasavvur','Tasavvuf haqida tasavvur'),
(25,'Tasavvuf haqida','Tasavvuf haqida tasavvur'),
(26,'Xarobadan chiqqan','Xarobadan chiqqan'),
(26,'Xarobadan ch','Xarobadan chiqqan'),
(27,'Jimjitlik','Jimjitlik'),
(27,'Jim jitlik romani','Jimjitlik'),
(28,'Saodatga yetaklovchi toplam','Saodatga yetaklovchi hikmatlar (1–4-kitoblar to‘plami)'),
(28,'Saodatga yetaklovchi 4 ta','Saodatga yetaklovchi hikmatlar (1–4-kitoblar to‘plami)'),
(29,'Muqaddima 1 qattiq','Muqaddima 1 qattiq'),
(29,'Muqaddima qattiq','Muqaddima 1 qattiq'),
(30,'O’zingni angla','O‘zingni o‘ngla'),
(30,'O‘zingni o‘ngla','O‘zingni o‘ngla'),
(30,'O’zingni o’ngla','O‘zingni o‘ngla'),
(31,'Yashamoq sokinlik istar','Yashamoq sokinlik istar'),
(31,'Yashamoq sokinlik','Yashamoq sokinlik istar'),
(32,'Atrof to’la','Atrof to’la'),
(32,'Atrof t','Atrof to’la'),
(33,'Rasululloh s.a.v ha 101','Rasululloh (s.a.v.) hayotlaridan 101 qissa'),
(33,'Rasululloh s.a.v ha.101','Rasululloh (s.a.v.) hayotlaridan 101 qissa'),
(33,'Rasululloh s.a.v hay 101.','Rasululloh (s.a.v.) hayotlaridan 101 qissa'))
 insert into private.approved_sales_title_backup_20261031(source_table,row_id,group_no,old_title,new_title)
 select 'legacy_sales_history',h.id,m.group_no,h.title,m.new_title
 from public.legacy_sales_history h join mapping m on h.title=m.old_title
 where h.title is distinct from m.new_title
 on conflict (source_table,row_id) do nothing;

 with mapping(group_no,old_title,new_title) as (values (1,'Tajvidli Qur’oni Karim','Qur’oni Karim — Tajvidli Mushaf'),
(1,'Qur’oni Karim — Tajvidli Mushaf','Qur’oni Karim — Tajvidli Mushaf'),
(2,'Nikoh ostonasi','Nikoh ostonasida'),
(2,'Nikoh ostonasida','Nikoh ostonasida'),
(3,'Umrga tatigulik safar','Umrga tatigulik safar'),
(3,'Umrga tatigulik','Umrga tatigulik safar'),
(3,'Urga tatigulik','Umrga tatigulik safar'),
(3,'Unrga tatigulik s','Umrga tatigulik safar'),
(3,'Umrga tatigu','Umrga tatigulik safar'),
(4,'Ichingdagi ichingda','Ichingdagi ichingdadir'),
(4,'Ichingdagi ichingdadir','Ichingdagi ichingdadir'),
(5,'Yaralangan qush','Yaralangan qush hamon'),
(5,'Yaralangan qush hamon','Yaralangan qush hamon'),
(6,'Manipulyativ','Manipulyativ diktatorlar'),
(6,'Manipulyativ d','Manipulyativ diktatorlar'),
(6,'Manipulyativ dik','Manipulyativ diktatorlar'),
(6,'Manipulytaiv d','Manipulyativ diktatorlar'),
(6,'Manipulyativ diktarorl','Manipulyativ diktatorlar'),
(7,'Hayot binosi','Hayot binosi'),
(7,'Hayot binosining','Hayot binosi'),
(7,'Hayot binosining ij','Hayot binosi'),
(8,'Mo’jiza sodir','Mo‘jiza sodir bo‘lmaydi'),
(8,'Mo’jiza sodir bo’lm','Mo‘jiza sodir bo‘lmaydi'),
(9,'O’lsang kim','O‘lsang, kim yig‘laydi?'),
(9,'O’lsang kim y','O‘lsang, kim yig‘laydi?'),
(9,'O’lsang kim yig','O‘lsang, kim yig‘laydi?'),
(10,'Umringizni o’g’irlagan','Umringizni o’g’irlagan'),
(10,'Umringizni o’','Umringizni o’g’irlagan'),
(10,'Umringizni og','Umringizni o’g’irlagan'),
(10,'Umringizni','Umringizni o’g’irlagan'),
(11,'Seni toliqtirayotgan','Seni toliqtirayotgan hamma narsadan voz kech'),
(11,'Seni toliqtir','Seni toliqtirayotgan hamma narsadan voz kech'),
(11,'Seni toliq','Seni toliqtirayotgan hamma narsadan voz kech'),
(12,'Yo’qotilgan jannat','Yo’qotilgan jannat'),
(12,'Yoqotilgan jann','Yo’qotilgan jannat'),
(12,'Yo’qotilgan ja','Yo’qotilgan jannat'),
(13,'Sulton Abdulhamidxon siri','Sulton Abdulhamidxon siri'),
(13,'Sulton Abdulhamidxon','Sulton Abdulhamidxon siri'),
(13,'Sulton abdulhamid','Sulton Abdulhamidxon siri'),
(14,'Jannat bostoni','Jannat bostoni'),
(14,'Jannat bo’stonidagi','Jannat bostoni'),
(14,'Jannat bo’stonidagi oilaviy','Jannat bostoni'),
(15,'Rasulullohdan go’zal nasihat','Rasulullohdan go’zal nasihat'),
(15,'Rasulullohdan go’zal','Rasulullohdan go’zal nasihat'),
(16,'Davinchi siri','Da Vinchi siri'),
(16,'Davinchi','Da Vinchi siri'),
(17,'Muhabbat haqida 101','Muhabbat haqida 101'),
(17,'101 muhabbat haqida','Muhabbat haqida 101'),
(17,'Muhabbat h 101','Muhabbat haqida 101'),
(18,'Hokimiyatning 48 qoidasi','Hokimiyatning 48 qoidasi'),
(18,'Hokimiyatning','Hokimiyatning 48 qoidasi'),
(19,'O‘tkan kunlar: roman','O‘tkan kunlar: roman'),
(19,'O’tkan kunlar','O‘tkan kunlar: roman'),
(20,'Ulamolar nazdida vaqtning qadri','Ulamolar nazdida vaqtning qadri'),
(20,'Ulamolar nazdida vaqt','Ulamolar nazdida vaqtning qadri'),
(21,'Jannat va do’zax','Jannat va do’zax'),
(21,'Jannat va doz','Jannat va do’zax'),
(22,'Sivilizatsiyalar to’qnashuv','Sivilizatsiyalar to‘qnashuvi va yangi dunyo tartibi'),
(22,'Sivilizatsiyalar','Sivilizatsiyalar to‘qnashuvi va yangi dunyo tartibi'),
(23,'Sof tabiat dini','Sof tabiat dini'),
(23,'Sof tabiat','Sof tabiat dini'),
(24,'Men ham kitob oqiy','Men ham kitob o‘qiyman'),
(24,'Men ham kitob','Men ham kitob o‘qiyman'),
(25,'Tasavvuf haqida tasavvur','Tasavvuf haqida tasavvur'),
(25,'Tasavvuf haqida','Tasavvuf haqida tasavvur'),
(26,'Xarobadan chiqqan','Xarobadan chiqqan'),
(26,'Xarobadan ch','Xarobadan chiqqan'),
(27,'Jimjitlik','Jimjitlik'),
(27,'Jim jitlik romani','Jimjitlik'),
(28,'Saodatga yetaklovchi toplam','Saodatga yetaklovchi hikmatlar (1–4-kitoblar to‘plami)'),
(28,'Saodatga yetaklovchi 4 ta','Saodatga yetaklovchi hikmatlar (1–4-kitoblar to‘plami)'),
(29,'Muqaddima 1 qattiq','Muqaddima 1 qattiq'),
(29,'Muqaddima qattiq','Muqaddima 1 qattiq'),
(30,'O’zingni angla','O‘zingni o‘ngla'),
(30,'O‘zingni o‘ngla','O‘zingni o‘ngla'),
(30,'O’zingni o’ngla','O‘zingni o‘ngla'),
(31,'Yashamoq sokinlik istar','Yashamoq sokinlik istar'),
(31,'Yashamoq sokinlik','Yashamoq sokinlik istar'),
(32,'Atrof to’la','Atrof to’la'),
(32,'Atrof t','Atrof to’la'),
(33,'Rasululloh s.a.v ha 101','Rasululloh (s.a.v.) hayotlaridan 101 qissa'),
(33,'Rasululloh s.a.v ha.101','Rasululloh (s.a.v.) hayotlaridan 101 qissa'),
(33,'Rasululloh s.a.v hay 101.','Rasululloh (s.a.v.) hayotlaridan 101 qissa'))
 insert into private.approved_sales_title_backup_20261031(source_table,row_id,group_no,old_title,new_title)
 select 'sales_log',s.id,m.group_no,s.title,m.new_title
 from public.sales_log s join mapping m on s.title=m.old_title
 where s.title is distinct from m.new_title
 on conflict (source_table,row_id) do nothing;

 update public.legacy_sales_history h set title=b.new_title
 from private.approved_sales_title_backup_20261031 b
 where b.source_table='legacy_sales_history' and h.id=b.row_id and h.title=b.old_title;
 get diagnostics h = row_count;

 update public.sales_log s set title=b.new_title
 from private.approved_sales_title_backup_20261031 b
 where b.source_table='sales_log' and s.id=b.row_id and s.title=b.old_title;
 get diagnostics r = row_count;

 if h=0 or r=0 then
   raise exception 'Unexpected sales title updates: legacy=%, recent=%',h,r;
 end if;

 -- Verify every backed-up row reached its approved title, without editing other columns.
 if exists (select 1 from private.approved_sales_title_backup_20261031 b join public.legacy_sales_history h on b.source_table='legacy_sales_history' and h.id=b.row_id where h.title is distinct from b.new_title)
 or exists (select 1 from private.approved_sales_title_backup_20261031 b join public.sales_log s on b.source_table='sales_log' and s.id=b.row_id where s.title is distinct from b.new_title)
 then raise exception 'An approved sale title was not updated'; end if;
 raise notice 'Approved title corrections: historical %, newer sales %',h,r;
end;
$apply$;

create or replace function public.purchase_title_match_key_v2(v text)
returns text language sql immutable set search_path = '' as $fn$
  select case public.purchase_title_key_v2(v)
    when public.purchase_title_key_v2('Tajvidli Qur’oni Karim') then public.purchase_title_key_v2('Qur’oni Karim — Tajvidli Mushaf')
    when public.purchase_title_key_v2('Nikoh ostonasi') then public.purchase_title_key_v2('Nikoh ostonasida')
    when public.purchase_title_key_v2('Umrga tatigulik') then public.purchase_title_key_v2('Umrga tatigulik safar')
    when public.purchase_title_key_v2('Urga tatigulik') then public.purchase_title_key_v2('Umrga tatigulik safar')
    when public.purchase_title_key_v2('Unrga tatigulik s') then public.purchase_title_key_v2('Umrga tatigulik safar')
    when public.purchase_title_key_v2('Umrga tatigu') then public.purchase_title_key_v2('Umrga tatigulik safar')
    when public.purchase_title_key_v2('Ichingdagi ichingda') then public.purchase_title_key_v2('Ichingdagi ichingdadir')
    when public.purchase_title_key_v2('Yaralangan qush') then public.purchase_title_key_v2('Yaralangan qush hamon')
    when public.purchase_title_key_v2('Manipulyativ') then public.purchase_title_key_v2('Manipulyativ diktatorlar')
    when public.purchase_title_key_v2('Manipulyativ d') then public.purchase_title_key_v2('Manipulyativ diktatorlar')
    when public.purchase_title_key_v2('Manipulyativ dik') then public.purchase_title_key_v2('Manipulyativ diktatorlar')
    when public.purchase_title_key_v2('Manipulytaiv d') then public.purchase_title_key_v2('Manipulyativ diktatorlar')
    when public.purchase_title_key_v2('Manipulyativ diktarorl') then public.purchase_title_key_v2('Manipulyativ diktatorlar')
    when public.purchase_title_key_v2('Hayot binosining') then public.purchase_title_key_v2('Hayot binosi')
    when public.purchase_title_key_v2('Hayot binosining ij') then public.purchase_title_key_v2('Hayot binosi')
    when public.purchase_title_key_v2('Mo’jiza sodir') then public.purchase_title_key_v2('Mo‘jiza sodir bo‘lmaydi')
    when public.purchase_title_key_v2('Mo’jiza sodir bo’lm') then public.purchase_title_key_v2('Mo‘jiza sodir bo‘lmaydi')
    when public.purchase_title_key_v2('O’lsang kim') then public.purchase_title_key_v2('O‘lsang, kim yig‘laydi?')
    when public.purchase_title_key_v2('O’lsang kim y') then public.purchase_title_key_v2('O‘lsang, kim yig‘laydi?')
    when public.purchase_title_key_v2('O’lsang kim yig') then public.purchase_title_key_v2('O‘lsang, kim yig‘laydi?')
    when public.purchase_title_key_v2('Umringizni o’') then public.purchase_title_key_v2('Umringizni o’g’irlagan')
    when public.purchase_title_key_v2('Umringizni og') then public.purchase_title_key_v2('Umringizni o’g’irlagan')
    when public.purchase_title_key_v2('Umringizni') then public.purchase_title_key_v2('Umringizni o’g’irlagan')
    when public.purchase_title_key_v2('Seni toliqtirayotgan') then public.purchase_title_key_v2('Seni toliqtirayotgan hamma narsadan voz kech')
    when public.purchase_title_key_v2('Seni toliqtir') then public.purchase_title_key_v2('Seni toliqtirayotgan hamma narsadan voz kech')
    when public.purchase_title_key_v2('Seni toliq') then public.purchase_title_key_v2('Seni toliqtirayotgan hamma narsadan voz kech')
    when public.purchase_title_key_v2('Yoqotilgan jann') then public.purchase_title_key_v2('Yo’qotilgan jannat')
    when public.purchase_title_key_v2('Yo’qotilgan ja') then public.purchase_title_key_v2('Yo’qotilgan jannat')
    when public.purchase_title_key_v2('Sulton Abdulhamidxon') then public.purchase_title_key_v2('Sulton Abdulhamidxon siri')
    when public.purchase_title_key_v2('Sulton abdulhamid') then public.purchase_title_key_v2('Sulton Abdulhamidxon siri')
    when public.purchase_title_key_v2('Jannat bo’stonidagi') then public.purchase_title_key_v2('Jannat bostoni')
    when public.purchase_title_key_v2('Jannat bo’stonidagi oilaviy') then public.purchase_title_key_v2('Jannat bostoni')
    when public.purchase_title_key_v2('Rasulullohdan go’zal') then public.purchase_title_key_v2('Rasulullohdan go’zal nasihat')
    when public.purchase_title_key_v2('Davinchi siri') then public.purchase_title_key_v2('Da Vinchi siri')
    when public.purchase_title_key_v2('Davinchi') then public.purchase_title_key_v2('Da Vinchi siri')
    when public.purchase_title_key_v2('101 muhabbat haqida') then public.purchase_title_key_v2('Muhabbat haqida 101')
    when public.purchase_title_key_v2('Muhabbat h 101') then public.purchase_title_key_v2('Muhabbat haqida 101')
    when public.purchase_title_key_v2('Hokimiyatning') then public.purchase_title_key_v2('Hokimiyatning 48 qoidasi')
    when public.purchase_title_key_v2('O’tkan kunlar') then public.purchase_title_key_v2('O‘tkan kunlar: roman')
    when public.purchase_title_key_v2('Ulamolar nazdida vaqt') then public.purchase_title_key_v2('Ulamolar nazdida vaqtning qadri')
    when public.purchase_title_key_v2('Jannat va doz') then public.purchase_title_key_v2('Jannat va do’zax')
    when public.purchase_title_key_v2('Sivilizatsiyalar to’qnashuv') then public.purchase_title_key_v2('Sivilizatsiyalar to‘qnashuvi va yangi dunyo tartibi')
    when public.purchase_title_key_v2('Sivilizatsiyalar') then public.purchase_title_key_v2('Sivilizatsiyalar to‘qnashuvi va yangi dunyo tartibi')
    when public.purchase_title_key_v2('Sof tabiat') then public.purchase_title_key_v2('Sof tabiat dini')
    when public.purchase_title_key_v2('Men ham kitob oqiy') then public.purchase_title_key_v2('Men ham kitob o‘qiyman')
    when public.purchase_title_key_v2('Men ham kitob') then public.purchase_title_key_v2('Men ham kitob o‘qiyman')
    when public.purchase_title_key_v2('Tasavvuf haqida') then public.purchase_title_key_v2('Tasavvuf haqida tasavvur')
    when public.purchase_title_key_v2('Xarobadan ch') then public.purchase_title_key_v2('Xarobadan chiqqan')
    when public.purchase_title_key_v2('Jim jitlik romani') then public.purchase_title_key_v2('Jimjitlik')
    when public.purchase_title_key_v2('Saodatga yetaklovchi toplam') then public.purchase_title_key_v2('Saodatga yetaklovchi hikmatlar (1–4-kitoblar to‘plami)')
    when public.purchase_title_key_v2('Saodatga yetaklovchi 4 ta') then public.purchase_title_key_v2('Saodatga yetaklovchi hikmatlar (1–4-kitoblar to‘plami)')
    when public.purchase_title_key_v2('Muqaddima qattiq') then public.purchase_title_key_v2('Muqaddima 1 qattiq')
    when public.purchase_title_key_v2('O’zingni angla') then public.purchase_title_key_v2('O‘zingni o‘ngla')
    when public.purchase_title_key_v2('O’zingni o’ngla') then public.purchase_title_key_v2('O‘zingni o‘ngla')
    when public.purchase_title_key_v2('Yashamoq sokinlik') then public.purchase_title_key_v2('Yashamoq sokinlik istar')
    when public.purchase_title_key_v2('Atrof t') then public.purchase_title_key_v2('Atrof to’la')
    when public.purchase_title_key_v2('Rasululloh s.a.v ha 101') then public.purchase_title_key_v2('Rasululloh (s.a.v.) hayotlaridan 101 qissa')
    when public.purchase_title_key_v2('Rasululloh s.a.v ha.101') then public.purchase_title_key_v2('Rasululloh (s.a.v.) hayotlaridan 101 qissa')
    when public.purchase_title_key_v2('Rasululloh s.a.v hay 101.') then public.purchase_title_key_v2('Rasululloh (s.a.v.) hayotlaridan 101 qissa')
    when 'tajvidli' then 'quroni karim tajvidli mushaf'
    when 'tajvidli musxaf' then 'quroni karim tajvidli mushaf'
    when 'tajvidli mushxaf' then 'quroni karim tajvidli mushaf'
    when 'tajvidli mushaf' then 'quroni karim tajvidli mushaf'
    when 'er xotinga' then 'er xotinga nasihat'
    when 'er xotinga n' then 'er xotinga nasihat'
    when 'fotimaning' then 'fotimaning bolasi'
    when 'fotimaning b' then 'fotimaning bolasi'
    when 'paygambarlar t' then 'paygambarlar tarixi'
    when '57 polk' then '57 polk falastin'
    when 'barzah hayoti' then 'barzax hayoti'
    when 'mukoshafatul qulb' then 'mukoshafatul qulub'
    when 'mukoshafatul' then 'mukoshafatul qulub'
    when 'mukoshafa' then 'mukoshafatul qulub'
    when 'dalolilul xoyrot' then 'daloilul xoyrot'
    when 'daloilul x' then 'daloilul xoyrot'
    when 'alkimyogar' then 'al kimyogar'
    when 'alkimyogar qattiq' then 'al kimyogar'
    when 'al kimyogar qattiq' then 'al kimyogar'
    when 'savdogaralar ustozi 1' then 'haqiqiy omad kaliti yoxud savdogarlar ustozi 1'
    when 'savdogarlar 1' then 'haqiqiy omad kaliti yoxud savdogarlar ustozi 1'
    when 'savdogarlar ustozi 1' then 'haqiqiy omad kaliti yoxud savdogarlar ustozi 1'
    when 'savdogaralar ustozi 2' then 'haqiqiy omad kaliti yoxud savdogarlar ustozi 2'
    when 'savdogaralr 2' then 'haqiqiy omad kaliti yoxud savdogarlar ustozi 2'
    when 'savdogarlar ustizi 2' then 'haqiqiy omad kaliti yoxud savdogarlar ustozi 2'
    when 'savdogarlar ustozi 2' then 'haqiqiy omad kaliti yoxud savdogarlar ustozi 2'
    when 'daftar hoshiyasi' then 'daftar hoshiyasidagi bitiklar'
    when 'tunda xibsni kutib' then 'tunda hibsni kutib'
    when 'tunda hibsni' then 'tunda hibsni kutib'
    when 'pul psixologiyasi' then 'pul psixologiyasi yoxud boylik ochkozlik va baxt haqida eskirmas saboqlar'
    when 'puls psixologiyasi' then 'pul psixologiyasi yoxud boylik ochkozlik va baxt haqida eskirmas saboqlar'
    when 'pul psxiologiyasi' then 'pul psixologiyasi yoxud boylik ochkozlik va baxt haqida eskirmas saboqlar'
    when 'pul psixolog' then 'pul psixologiyasi yoxud boylik ochkozlik va baxt haqida eskirmas saboqlar'
    when 'pul psixo' then 'pul psixologiyasi yoxud boylik ochkozlik va baxt haqida eskirmas saboqlar'
    when 'pul psix' then 'pul psixologiyasi yoxud boylik ochkozlik va baxt haqida eskirmas saboqlar'
    when 'pul paixo' then 'pul psixologiyasi yoxud boylik ochkozlik va baxt haqida eskirmas saboqlar'
    when 'pul paix' then 'pul psixologiyasi yoxud boylik ochkozlik va baxt haqida eskirmas saboqlar'
    when 'quron qalbiga' then 'quron qalbiga safar'
    when 'sovchilikdan turmushga' then 'sovchilikdan turmushga qadar'
    when 'sovchilikdan turmush' then 'sovchilikdan turmushga qadar'
    when 'masnaviy 40 rivoyat' then 'masnaviy 40 rivoyatga 40 sharh'
    when 'boy ota kambagal' then 'boy ota kambagal ota'
    when 'boy ota' then 'boy ota kambagal ota'
    when 'sotilayotgan kasallik' then 'sotilayotgan kasalliklar'
    when 'sotilayotgan kasal' then 'sotilayotgan kasalliklar'
    when 'temir tavon' then 'temir tovon'
    when 'qanday buyuk bo' then 'qanday buyuk bolishgan'
    when 'qanday buyuk b' then 'qanday buyuk bolishgan'
    when 'qanday buyuk' then 'qanday buyuk bolishgan'
    when 'binafsha 2' then 'binafsha shulasi 2'
    when 'binafsha 1' then 'binafsha shulasi 1'
    when 'binafsga 1' then 'binafsha shulasi 1'
    when 'rizq kalitlari' then 'rizq kalitlari najot keltiruvchi duolar'
    when 'risq kalitlari' then 'rizq kalitlari najot keltiruvchi duolar'
    when 'proganda' then 'propaganda'
    when 'shahmat ustidagi qotillik' then 'shaxmat ustidagi qotillik'
    when 'shaxmt ustidagi qotil' then 'shaxmat ustidagi qotillik'
    when 'shaxmat ustidagi' then 'shaxmat ustidagi qotillik'
    when 'jinoyat ba jazo' then 'jinoyat va jazo'
    when 'jinoyat va jazo yumshoq' then 'jinoyat va jazo'
    when 'suniy intilekt asoslari' then 'suniy intellekt asoslari mashinaviy oqitish'
    when 'suniy intelekt' then 'suniy intellekt asoslari mashinaviy oqitish'
    when 'psixologik urush' then 'psixologik urush kulrang propaganda bizni qanday boshqarishadi'
    when 'psixolik urush' then 'psixologik urush kulrang propaganda bizni qanday boshqarishadi'
    when 'psixologik uruah' then 'psixologik urush kulrang propaganda bizni qanday boshqarishadi'
    when 'mominning meroji' then 'mominning meroji mufassal namoz kitobi'
    when 'mominnung meroji' then 'mominning meroji mufassal namoz kitobi'
    when 'mom ning meroji' then 'mominning meroji mufassal namoz kitobi'
    when 'vavilonlik eng boy odam' then 'vavilondagi eng boy odam'
    when 'vavilondagi eng' then 'vavilondagi eng boy odam'
    when 'vavilonlik eng' then 'vavilondagi eng boy odam'
    when 'vavilonlik' then 'vavilondagi eng boy odam'
    when 'vavilonljk' then 'vavilondagi eng boy odam'
    when 'vavilyonlik' then 'vavilondagi eng boy odam'
    when 'vavilon' then 'vavilondagi eng boy odam'
    when 'buyuk haqiqat' then 'buyuk haqiqat yohud fitrat qichqirigi'
    when 'buyuk haqiqat yoxud' then 'buyuk haqiqat yohud fitrat qichqirigi'
    when 'arosatda 7 kecha' then 'arosatda yetti kecha'
    when 'oqshom gozallik' then 'oqshom gozalliklari'
    when 'men' then 'men bas qil ey nafs'
    when 'men fleksibl' then 'men bas qil ey nafs'
    when 'men flex' then 'men bas qil ey nafs'
    when 'men flexs' then 'men bas qil ey nafs'
    when 'men flexsibl' then 'men bas qil ey nafs'
    when 'men qattiq' then 'men bas qil ey nafs'
    when 'men yumshoq' then 'men bas qil ey nafs'
    else public.purchase_title_key_v2(v) end;
$fn$;

revoke all on function public.purchase_title_match_key_v2(text) from public, anon, authenticated;

-- Guard unrelated edition/titles against overly broad mapping.
do $check$
begin
 if public.purchase_title_match_key_v2('Tajvidsiz Qur’oni Karim') =
    public.purchase_title_match_key_v2('Qur’oni Karim — Tajvidli Mushaf')
 then raise exception 'Tajvidsiz must remain separate'; end if;
 if public.purchase_title_match_key_v2('Yashamoq') =
    public.purchase_title_match_key_v2('Yashamoq sokinlik istar')
 then raise exception 'Yashamoq must remain separate'; end if;
 if public.purchase_title_match_key_v2('Muqaddima 2') =
    public.purchase_title_match_key_v2('Muqaddima 1 qattiq')
 then raise exception 'Muqaddima part 2 must remain separate'; end if;
end;
$check$;
