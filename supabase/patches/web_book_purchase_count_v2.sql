-- Versioned aggregate: existing clients keep their old endpoint/units.
-- Additive functions only: never updates orders, stock, finance or source history.
create or replace function public.purchase_title_key_v2(v text)
returns text language plpgsql immutable set search_path = '' as $fn$
declare k text;
begin
  k := lower(coalesce(v,''));
  k := replace(replace(k,'ⅱ',' ii '),'ⅰ',' i ');
  k := regexp_replace(k, '[''’‘`ʻʼʹ]+', '', 'g');
  k := trim(regexp_replace(k, '[^[:alnum:]]+', ' ', 'g'));
  -- Roman digits (and lowercase L entered instead of I) are whole tokens only.
  k := regexp_replace(k, '\m(ii|ll)\M', '2', 'g');
  k := regexp_replace(k, '\m(i|l)\M', '1', 'g');
  k := regexp_replace(k, '([0-9]+)\s*qism\M', '\1', 'g');
  k := regexp_replace(k, '\mqism\s*([0-9]+)\M', '\1', 'g');
  return trim(regexp_replace(k, '\s+', ' ', 'g'));
end;
$fn$;
revoke all on function public.purchase_title_key_v2(text) from public, anon, authenticated;

-- Reviewed spelling/abbreviation aliases, never an unrestricted fuzzy join.
-- Unnumbered Binafsha and Savdogarlar records intentionally remain unresolved.
-- Different explicit bindings/languages are not silently treated as the same edition.
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

create or replace function public.web_book_purchase_count_v2(p_book_id uuid)
returns jsonb language plpgsql stable security definer
set search_path = '' set statement_timeout = '3s' as $fn$
declare
  target_key text;
  target_telegram_id bigint;
  unique_title boolean;
  recorded bigint;
  historical bigint := 0;
begin
  select public.purchase_title_key_v2(b.title),b.telegram_id
    into target_key,target_telegram_id
    from public.books b where b.id=p_book_id and b.is_active;
  if not found then return null; end if;
  select count(*)=1 into unique_title from public.books b
    where public.purchase_title_key_v2(b.title)=target_key;
  select count(distinct s.order_id) into recorded
    from public.sales_log s join public.orders o on o.id=s.order_id
    where (s.book_id=p_book_id
      or (s.book_id is null and s.telegram_book_id=target_telegram_id)
      or (unique_title and s.book_id is null and s.telegram_book_id is null
        and public.purchase_title_match_key_v2(s.title)=target_key))
      and (o.status='shipping' or (coalesce(o.source,'app') in ('app','telegram','instagram')
        and o.status in ('accepted','paid')));
  if unique_title then
    select count(*) into historical from public.legacy_sales_history h
      where public.purchase_title_match_key_v2(h.title)=target_key;
  end if;
  return jsonb_build_object('recorded_count',recorded,'historical_count',historical);
end;
$fn$;
revoke all on function public.web_book_purchase_count_v2(uuid) from public;
grant execute on function public.web_book_purchase_count_v2(uuid) to anon, authenticated, service_role;
comment on function public.web_book_purchase_count_v2(uuid) is
  'Purchase events: distinct confirmed orders plus one event per imported historical row. Only aggregate counts are public. Reviewed title aliases preserve numbered parts; no source rows are modified.';
