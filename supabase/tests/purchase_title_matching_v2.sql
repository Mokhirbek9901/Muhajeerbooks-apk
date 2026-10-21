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
    array['Til  sayqali', 'Til sayqali']
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
    array['Islom psixologiyasi','Pul psixologiyasi']
  ] loop
    if public.purchase_title_match_key_v2(pair[1]) = public.purchase_title_match_key_v2(pair[2]) then
      raise exception 'Different books/parts were merged: %',pair;
    end if;
  end loop;
end;
$test$;
rollback;
