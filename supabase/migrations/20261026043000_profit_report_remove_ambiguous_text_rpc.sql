-- The custom-date profit RPC is the typed (date,date) overload.
-- Avoid a PostgREST ambiguous signature with text/text for the same argument
-- names. Older two-argument clients remain compatible.
drop function if exists public.admin_book_profit_report(text,text,text,text);
