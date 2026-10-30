# Web purchase count v2

The badge now reads “N marta xarid qilingan”, uses 12px text, a 15px icon and a 32px minimum visual height. The padded tap target is preserved. Other metadata remains unchanged.

The versioned RPC counts distinct confirmed order IDs and one event per legacy history row (historical rows have no original order identity). The old RPC and native releases remain unchanged. The legacy count is therefore a recorded-sales approximation, not a unique-buyer count.

Title matching removes apostrophe/punctuation/spacing differences and normalizes standalone Roman I/II, lowercase l/ll and Arabic part numbers. Reviewed spelling and shortened-title aliases are explicit, never an open fuzzy similarity rule. Partless Binafsha and Savdogarlar remain unresolved. Catalog ambiguity prevents a historical row from counting toward multiple books. Other books absent from the current catalog remain unassigned. No order, inventory, sales or financial source rows are rewritten.

Validation: transactional title regressions cover equivalent variants and unrelated books/parts; lifecycle fixtures cover pending/accepted/repeated acceptance/cancelled orders, two copies counted once, ambiguous catalog titles, inactive/unknown books and anonymous access. Every fixture rolls back.

Real historical examples verified before deployment: Binafsha I: 28 legacy events, II: 35; Tunda hibsni kutib: 11; Pul psixologiyasi: 21. Ten unnumbered Binafsha events are deliberately not assigned.

## Tajvidli Mushaf historical name unification — 2026-10-31

Seven confirmed legacy-history records previously titled **Tajvidli** (3) or **Tajvidli musxaf** (4) were renamed in-place to **Qur’oni Karim — Tajvidli Mushaf**. Historical dates and import batch IDs remain unchanged; this was an explicitly requested correction. Previous IDs/names for recovery: 249, 754, 764 = Tajvidli; 235, 1853, 2090, 2122 = Tajvidli musxaf. The purchase count RPC now returns 7 historical and 2 confirmed order events, **9 total** as verified live. The aliases also handle `Tajvidli mushxaf` and `Tajvidli mushaf` without fuzzy matching. **Tajvidsiz Qur’oni Karim** is explicitly excluded and untouched. Unrequested sales logged as **Tajvidli Qur’oni Karim** have not been merged; edition equivalence was not established.

## Approved 33-group historical title merge — 2026-10-31

- User explicitly classified all 33 groups as the **same book**. A one-time database migration, `20261030202948_approved_33_groups_sales_title_unification.sql`, normalized only their 83 explicitly listed old/title spellings. No fuzzy global rewriting was used.
- Preflight rows in scope: **159 historical** and **10 newer sales-log** records. Only **100 historical** and **4 newer sales-log** rows needed a title change. Other source rows already had the selected canonical title and were left intact. Total counts, orders, timestamps, units, amounts, pricing and stock were not changed.
- Original IDs and original/new text are retained in the **private** `approved_sales_title_backup_20261031` table for exact reversal if needed; public/anon/authenticated privileges on the backup were revoked.
- The reviewed `purchase_title_match_key_v2` function includes explicit aliases for all approved names, preventing future old spellings from splitting the page-level count. SQL regression fixtures cover **all 83 originals** and guard against false merging of Tajvidsiz Mushaf, Muqaddima part 2, standalone Yashamoq, and the separate Atrof-to‘la variants.
- Verified live after migration: *Qur’oni Karim — Tajvidli Mushaf* **4 confirmed order events + 7 legacy rows = 11**; *O‘tkan kunlar: roman* **17** historical events. *Ulamolar nazdida vaqtning qadri* has **8** recorded historical/new sales-log rows but its catalog entry is inactive, so the public purchase-count RPC correctly returns null until reactivated.
- Some historical abbreviations could not establish the full edition-specific name with certainty. For the **Atrof to’la** and **Hayot binosi** groups, retained readable labels from the user's approved source group rather than guessing a longer title. External book catalogs supported expansions to established titles such as *Manipulyativ diktatorlar*, *Mo‘jiza sodir bo‘lmaydi*, *O‘lsang, kim yig‘laydi?*, *Men ham kitob o‘qiyman*, and *Rasululloh (s.a.v.) hayotlaridan 101 qissa*. These external titles were selected only for the exact already-approved group, never for similarly named but unapproved groups.
- The old `orders.items` JSON is **not rewritten**. Any past customer receipt retains its original historical title snapshot while the dedicated sales-history rows and aggregated counts use the merged names.
