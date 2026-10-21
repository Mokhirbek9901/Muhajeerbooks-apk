# Web purchase count v2

The badge now reads “N marta xarid qilingan”, uses 12px text, a 15px icon and a 32px minimum visual height. The padded tap target is preserved. Other metadata remains unchanged.

The versioned RPC counts distinct confirmed order IDs and one event per legacy history row (historical rows have no original order identity). The old RPC and native releases remain unchanged. The legacy count is therefore a recorded-sales approximation, not a unique-buyer count.

Title matching removes apostrophe/punctuation/spacing differences and normalizes standalone Roman I/II, lowercase l/ll and Arabic part numbers. Reviewed spelling and shortened-title aliases are explicit, never an open fuzzy similarity rule. Partless Binafsha and Savdogarlar remain unresolved. Catalog ambiguity prevents a historical row from counting toward multiple books. Other books absent from the current catalog remain unassigned. No order, inventory, sales or financial source rows are rewritten.

Validation: transactional title regressions cover equivalent variants and unrelated books/parts; lifecycle fixtures cover pending/accepted/repeated acceptance/cancelled orders, two copies counted once, ambiguous catalog titles, inactive/unknown books and anonymous access. Every fixture rolls back.

Real historical examples verified before deployment: Binafsha I: 28 legacy events, II: 35; Tunda hibsni kutib: 11; Pul psixologiyasi: 21. Ten unnumbered Binafsha events are deliberately not assigned.
