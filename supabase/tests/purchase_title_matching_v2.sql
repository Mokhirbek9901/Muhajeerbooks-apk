begin;
do $test$
declare pair text[];
begin
  foreach pair slice 1 in array array[
    array['Binafsha shulasi 1-qism', 'Binafsha shu’lasi I'],
    array['Binafsha shu’lasi l', 'Binafsha shu’lasi 1-qism'],
    array['Binafsha shu’lasi ll', 'Binafsha shu’lasi 2-qism'],
    array['Binafsha 2-', 'Binafsha shu’lasi II'],
    array['Binafsga 1', 'Binafsha shu’lasi 1-qism'],
    array['Savdogarlar ustizi 2', 'Haqiqiy omad kaliti yoxud Savdogarlar ustozi: 2-qism'],
    array['Tunda xibsni kutib', 'Tunda hibsni kutib'],
    array['Puls psixologiyasi', 'Pul psixologiyasi yoxud boylik, ochko‘zlik va baxt haqida eskirmas saboqlar'],
    array['Chumolilar saltanati', '🐜Chumolilar saltanati'],
    array['Til  sayqali', 'Til sayqali'],
    array['Tajvidli mushxaf', 'Qur’oni Karim — Tajvidli Mushaf'],
    array['Tajvidli musxaf', 'Qur’oni Karim — Tajvidli Mushaf'],
    array['Tajvidli', 'Qur’oni Karim — Tajvidli Mushaf'],
    array['Tajvidli mushaf', 'Qur’oni Karim — Tajvidli Mushaf']
  ] loop
    if public.purchase_title_match_key_v2(pair[1]) <> public.purchase_title_key_v2(pair[2]) then
      raise exception 'Title variant mismatch: %',pair;
    end if;
  end loop;
  foreach pair slice 1 in array array[
    array['Binafsha shulasi 1-qism','Binafsha shu’lasi II'],
    array['Binafsha shulasi','Binafsha shu’lasi 1-qism'],
    array['Binafsha shulasi','Binafsha shu’lasi II'],
    array['Savdogarlar ustozi','Haqiqiy omad kaliti yoxud Savdogarlar ustozi: 1-qism'],
    array['Yashamoq sokinlik istar','Yashamoq'],
    array['Yuksalish san’ati','Yuksalish strategiyasi'],
    array['Islom psixologiyasi','Pul psixologiyasi'],
    array['Tajvidsiz Qur’oni Karim', 'Qur’oni Karim — Tajvidli Mushaf']
  ] loop
    if public.purchase_title_match_key_v2(pair[1]) = public.purchase_title_match_key_v2(pair[2]) then
      raise exception 'Different books/parts were merged: %',pair;
    end if;
  end loop;
end;
$test$;
rollback;


-- User-approved 33 groups, including source titles already in canonical form.
begin;
do $approved_title_aliases$
declare pair text[];
begin
 foreach pair slice 1 in array array[
    array['Tajvidli Qur’oni Karim', 'Qur’oni Karim — Tajvidli Mushaf'],
    array['Qur’oni Karim — Tajvidli Mushaf', 'Qur’oni Karim — Tajvidli Mushaf'],
    array['Nikoh ostonasi', 'Nikoh ostonasida'],
    array['Nikoh ostonasida', 'Nikoh ostonasida'],
    array['Umrga tatigulik safar', 'Umrga tatigulik safar'],
    array['Umrga tatigulik', 'Umrga tatigulik safar'],
    array['Urga tatigulik', 'Umrga tatigulik safar'],
    array['Unrga tatigulik s', 'Umrga tatigulik safar'],
    array['Umrga tatigu', 'Umrga tatigulik safar'],
    array['Ichingdagi ichingda', 'Ichingdagi ichingdadir'],
    array['Ichingdagi ichingdadir', 'Ichingdagi ichingdadir'],
    array['Yaralangan qush', 'Yaralangan qush hamon'],
    array['Yaralangan qush hamon', 'Yaralangan qush hamon'],
    array['Manipulyativ', 'Manipulyativ diktatorlar'],
    array['Manipulyativ d', 'Manipulyativ diktatorlar'],
    array['Manipulyativ dik', 'Manipulyativ diktatorlar'],
    array['Manipulytaiv d', 'Manipulyativ diktatorlar'],
    array['Manipulyativ diktarorl', 'Manipulyativ diktatorlar'],
    array['Hayot binosi', 'Hayot binosi'],
    array['Hayot binosining', 'Hayot binosi'],
    array['Hayot binosining ij', 'Hayot binosi'],
    array['Mo’jiza sodir', 'Mo‘jiza sodir bo‘lmaydi'],
    array['Mo’jiza sodir bo’lm', 'Mo‘jiza sodir bo‘lmaydi'],
    array['O’lsang kim', 'O‘lsang, kim yig‘laydi?'],
    array['O’lsang kim y', 'O‘lsang, kim yig‘laydi?'],
    array['O’lsang kim yig', 'O‘lsang, kim yig‘laydi?'],
    array['Umringizni o’g’irlagan', 'Umringizni o’g’irlagan'],
    array['Umringizni o’', 'Umringizni o’g’irlagan'],
    array['Umringizni og', 'Umringizni o’g’irlagan'],
    array['Umringizni', 'Umringizni o’g’irlagan'],
    array['Seni toliqtirayotgan', 'Seni toliqtirayotgan hamma narsadan voz kech'],
    array['Seni toliqtir', 'Seni toliqtirayotgan hamma narsadan voz kech'],
    array['Seni toliq', 'Seni toliqtirayotgan hamma narsadan voz kech'],
    array['Yo’qotilgan jannat', 'Yo’qotilgan jannat'],
    array['Yoqotilgan jann', 'Yo’qotilgan jannat'],
    array['Yo’qotilgan ja', 'Yo’qotilgan jannat'],
    array['Sulton Abdulhamidxon siri', 'Sulton Abdulhamidxon siri'],
    array['Sulton Abdulhamidxon', 'Sulton Abdulhamidxon siri'],
    array['Sulton abdulhamid', 'Sulton Abdulhamidxon siri'],
    array['Jannat bostoni', 'Jannat bostoni'],
    array['Jannat bo’stonidagi', 'Jannat bostoni'],
    array['Jannat bo’stonidagi oilaviy', 'Jannat bostoni'],
    array['Rasulullohdan go’zal nasihat', 'Rasulullohdan go’zal nasihat'],
    array['Rasulullohdan go’zal', 'Rasulullohdan go’zal nasihat'],
    array['Davinchi siri', 'Da Vinchi siri'],
    array['Davinchi', 'Da Vinchi siri'],
    array['Muhabbat haqida 101', 'Muhabbat haqida 101'],
    array['101 muhabbat haqida', 'Muhabbat haqida 101'],
    array['Muhabbat h 101', 'Muhabbat haqida 101'],
    array['Hokimiyatning 48 qoidasi', 'Hokimiyatning 48 qoidasi'],
    array['Hokimiyatning', 'Hokimiyatning 48 qoidasi'],
    array['O‘tkan kunlar: roman', 'O‘tkan kunlar: roman'],
    array['O’tkan kunlar', 'O‘tkan kunlar: roman'],
    array['Ulamolar nazdida vaqtning qadri', 'Ulamolar nazdida vaqtning qadri'],
    array['Ulamolar nazdida vaqt', 'Ulamolar nazdida vaqtning qadri'],
    array['Jannat va do’zax', 'Jannat va do’zax'],
    array['Jannat va doz', 'Jannat va do’zax'],
    array['Sivilizatsiyalar to’qnashuv', 'Sivilizatsiyalar to‘qnashuvi va yangi dunyo tartibi'],
    array['Sivilizatsiyalar', 'Sivilizatsiyalar to‘qnashuvi va yangi dunyo tartibi'],
    array['Sof tabiat dini', 'Sof tabiat dini'],
    array['Sof tabiat', 'Sof tabiat dini'],
    array['Men ham kitob oqiy', 'Men ham kitob o‘qiyman'],
    array['Men ham kitob', 'Men ham kitob o‘qiyman'],
    array['Tasavvuf haqida tasavvur', 'Tasavvuf haqida tasavvur'],
    array['Tasavvuf haqida', 'Tasavvuf haqida tasavvur'],
    array['Xarobadan chiqqan', 'Xarobadan chiqqan'],
    array['Xarobadan ch', 'Xarobadan chiqqan'],
    array['Jimjitlik', 'Jimjitlik'],
    array['Jim jitlik romani', 'Jimjitlik'],
    array['Saodatga yetaklovchi toplam', 'Saodatga yetaklovchi hikmatlar (1–4-kitoblar to‘plami)'],
    array['Saodatga yetaklovchi 4 ta', 'Saodatga yetaklovchi hikmatlar (1–4-kitoblar to‘plami)'],
    array['Muqaddima 1 qattiq', 'Muqaddima 1 qattiq'],
    array['Muqaddima qattiq', 'Muqaddima 1 qattiq'],
    array['O’zingni angla', 'O‘zingni o‘ngla'],
    array['O‘zingni o‘ngla', 'O‘zingni o‘ngla'],
    array['O’zingni o’ngla', 'O‘zingni o‘ngla'],
    array['Yashamoq sokinlik istar', 'Yashamoq sokinlik istar'],
    array['Yashamoq sokinlik', 'Yashamoq sokinlik istar'],
    array['Atrof to’la', 'Atrof to’la'],
    array['Atrof t', 'Atrof to’la'],
    array['Rasululloh s.a.v ha 101', 'Rasululloh (s.a.v.) hayotlaridan 101 qissa'],
    array['Rasululloh s.a.v ha.101', 'Rasululloh (s.a.v.) hayotlaridan 101 qissa'],
    array['Rasululloh s.a.v hay 101.', 'Rasululloh (s.a.v.) hayotlaridan 101 qissa']
 ] loop
   if public.purchase_title_match_key_v2(pair[1]) is distinct from
      public.purchase_title_key_v2(pair[2]) then
     raise exception 'Approved alias did not resolve: % => %', pair[1],pair[2];
   end if;
 end loop;
 if public.purchase_title_match_key_v2('Tajvidsiz Qur’oni Karim') =
    public.purchase_title_match_key_v2('Qur’oni Karim — Tajvidli Mushaf')
 then raise exception 'Tajvidsiz falsely merged'; end if;
 if public.purchase_title_match_key_v2('Muqaddima 2') =
    public.purchase_title_match_key_v2('Muqaddima 1 qattiq')
 then raise exception 'Muqaddima parts falsely merged'; end if;
 if public.purchase_title_match_key_v2('Yashamoq') =
    public.purchase_title_match_key_v2('Yashamoq sokinlik istar')
 then raise exception 'Yashamoq titles falsely merged'; end if;
 if public.purchase_title_match_key_v2('Atrof to‘la ahmoqlar') =
    public.purchase_title_match_key_v2('Atrof to’la')
 then raise exception 'Unapproved Atrof editions falsely merged'; end if;
end;
$approved_title_aliases$;
rollback;
