(() => {
  'use strict';

  const STORAGE_KEY = 'bek_personal_assistant_v3';
  const LEGACY_KEYS = ['bek_personal_assistant_v2', 'shaxsiy_yordamchi', 'personalAssistantData'];
  const $ = (id) => document.getElementById(id);
  const qsa = (selector, root = document) => [...root.querySelectorAll(selector)];

  const defaultState = () => ({
    version: 3,
    profile: { name: 'Mohirbek', yearlyGoal: 24, theme: 'light' },
    books: [],
    transactions: []
  });

  let state = loadState();
  let currentView = 'dashboard';
  let bookFilter = 'all';
  let financePeriod = 'month';
  let financeCurrency = 'KRW';
  let installPrompt = null;

  function loadState() {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) {
      try { return normalizeState(JSON.parse(raw)); } catch (_) {}
    }
    for (const key of LEGACY_KEYS) {
      const legacy = localStorage.getItem(key);
      if (!legacy) continue;
      try {
        const parsed = JSON.parse(legacy);
        const migrated = normalizeState(parsed);
        localStorage.setItem(STORAGE_KEY, JSON.stringify(migrated));
        return migrated;
      } catch (_) {}
    }
    return defaultState();
  }

  function normalizeState(input) {
    const base = defaultState();
    const profile = input?.profile || {};
    const books = Array.isArray(input?.books) ? input.books : [];
    const transactions = Array.isArray(input?.transactions)
      ? input.transactions
      : Array.isArray(input?.finance)
        ? input.finance
        : [];
    return {
      version: 3,
      profile: {
        name: String(profile.name || input?.name || base.profile.name),
        yearlyGoal: clampInt(profile.yearlyGoal ?? input?.yearlyGoal ?? 24, 1, 500),
        theme: profile.theme === 'dark' ? 'dark' : 'light'
      },
      books: books.map((b) => ({
        id: String(b.id || makeId()),
        title: String(b.title || b.name || '').trim(),
        author: String(b.author || '').trim(),
        cover: String(b.cover || b.coverUrl || '').trim(),
        pages: numOrZero(b.pages || b.totalPages),
        currentPage: numOrZero(b.currentPage || b.page),
        startedAt: normalizeDate(b.startedAt || b.startDate || ''),
        finishedAt: normalizeDate(b.finishedAt || b.finishDate || ''),
        rating: clampInt(b.rating || 0, 0, 5),
        notes: String(b.notes || b.note || ''),
        createdAt: b.createdAt || new Date().toISOString(),
        updatedAt: b.updatedAt || new Date().toISOString()
      })).filter((b) => b.title),
      transactions: transactions.map((t) => ({
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

  function saveState(message) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    renderAll();
    if (message) toast(message);
  }

  function makeId() {
    return (crypto?.randomUUID?.() || (Date.now().toString(36) + Math.random().toString(36).slice(2)));
  }

  function clampInt(value, min, max) {
    const n = Math.round(Number(value) || 0);
    return Math.min(max, Math.max(min, n));
  }

  function numOrZero(value) {
    const n = Number(value);
    return Number.isFinite(n) && n > 0 ? Math.round(n) : 0;
  }

  function normalizeDate(value) {
    if (!value) return '';
    const s = String(value).slice(0, 10);
    return /^\d{4}-\d{2}-\d{2}$/.test(s) ? s : '';
  }

  function today() {
    const d = new Date();
    const local = new Date(d.getTime() - d.getTimezoneOffset() * 60000);
    return local.toISOString().slice(0, 10);
  }

  function parseDay(value) {
    if (!value) return null;
    const [y, m, d] = value.split('-').map(Number);
    return new Date(y, m - 1, d);
  }

  function formatDate(value) {
    const d = parseDay(value);
    if (!d) return '—';
    return new Intl.DateTimeFormat('uz-UZ', { day: '2-digit', month: 'short', year: 'numeric' }).format(d);
  }

  function statusOf(book) {
    if (book.finishedAt) return 'finished';
    if (book.startedAt) return 'reading';
    return 'wishlist';
  }

  function statusLabel(status) {
    return status === 'reading' ? 'O‘qiyapman' : status === 'finished' ? 'Tugatdim' : 'O‘qimoqchiman';
  }

  function progressOf(book) {
    if (statusOf(book) === 'finished') return 100;
    if (!book.pages) return 0;
    return Math.max(0, Math.min(100, Math.round((book.currentPage / book.pages) * 100)));
  }

  function durationDays(book) {
    const start = parseDay(book.startedAt);
    if (!start) return 0;
    const end = parseDay(book.finishedAt) || parseDay(today());
    const diff = Math.floor((end - start) / 86400000);
    return Math.max(1, diff + 1);
  }

  function escapeHtml(value) {
    return String(value ?? '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#039;');
  }

  function coverHtml(book) {
    if (book.cover) {
      return `<div class="cover"><img src="${escapeHtml(book.cover)}" alt="" loading="lazy" onerror="this.remove();this.parentElement.textContent='KITOB'"></div>`;
    }
    const initial = escapeHtml(book.title.slice(0, 1).toUpperCase() || 'K');
    return `<div class="cover"><span>${initial}</span></div>`;
  }

  function toast(message) {
    const el = $('toast');
    el.textContent = message;
    el.classList.add('show');
    clearTimeout(toast.timer);
    toast.timer = setTimeout(() => el.classList.remove('show'), 2400);
  }

  function applyTheme() {
    document.documentElement.dataset.theme = state.profile.theme;
    $('themeBtn').textContent = state.profile.theme === 'dark' ? '☀' : '◐';
  }

  function navigate(view) {
    currentView = view;
    qsa('.view').forEach((el) => el.classList.toggle('active', el.id === `view-${view}`));
    qsa('.bottom-nav button[data-view]').forEach((btn) => btn.classList.toggle('active', btn.dataset.view === view));
    const titles = {
      dashboard: `Salom, ${state.profile.name || 'Mohirbek'}`,
      library: 'Shaxsiy kutubxona',
      finance: 'Hisob-kitob',
      settings: 'Mening makonim'
    };
    $('topTitle').textContent = titles[view] || 'Shaxsiy yordamchi';
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function renderAll() {
    applyTheme();
    renderDate();
    renderDashboard();
    renderBooks();
    renderFinance();
    renderSettings();
  }

  function renderDate() {
    $('todayLabel').textContent = new Intl.DateTimeFormat('uz-UZ', {
      weekday: 'long', day: 'numeric', month: 'long', year: 'numeric'
    }).format(new Date());
  }

  function renderDashboard() {
    const reading = state.books.filter((b) => statusOf(b) === 'reading');
    const finished = state.books.filter((b) => statusOf(b) === 'finished');
    const wishlist = state.books.filter((b) => statusOf(b) === 'wishlist');
    const thisYear = new Date().getFullYear();
    const finishedThisYear = finished.filter((b) => parseDay(b.finishedAt)?.getFullYear() === thisYear);

    $('heroReadingCount').textContent = reading.length;
    $('statReading').textContent = reading.length;
    $('statFinished').textContent = finished.length;
    $('statWishlist').textContent = wishlist.length;
    $('statYearFinished').textContent = finishedThisYear.length;

    const goal = Math.max(1, state.profile.yearlyGoal || 24);
    const pct = Math.min(100, Math.round((finishedThisYear.length / goal) * 100));
    $('goalPercent').textContent = `${pct}%`;
    $('goalText').textContent = `${finishedThisYear.length} / ${goal} kitob`;
    $('goalRing').style.setProperty('--p', `${pct * 3.6}deg`);

    const dash = $('dashboardReading');
    if (!reading.length) {
      dash.innerHTML = `<div class="empty"><strong>Hozir faol mutolaa yo‘q</strong><span class="muted">Kitob qo‘shib “Mutolaa boshlangan sana”ni kiritsangiz shu yerda chiqadi.</span></div>`;
    } else {
      dash.innerHTML = reading.slice(0, 3).map((book) => {
        const p = progressOf(book);
        return `<article class="reading-card" data-book="${escapeHtml(book.id)}">
          ${coverHtml(book)}
          <div>
            <h4>${escapeHtml(book.title)}</h4>
            <div class="muted">${escapeHtml(book.author || 'Muallif kiritilmagan')}</div>
            <div class="progress-track"><div class="progress-fill" style="width:${p}%"></div></div>
            <div class="book-facts"><span class="fact">${p}%</span><span class="fact">${durationDays(book)} kun</span></div>
          </div>
        </article>`;
      }).join('');
    }

    const currentMonth = filterTransactions(state.transactions, 'month');
    const finance = $('dashboardFinance');
    finance.innerHTML = ['KRW', 'UZS'].map((currency) => {
      const rows = currentMonth.filter((t) => t.currency === currency);
      const income = sumTx(rows, 'income');
      const expense = sumTx(rows, 'expense');
      return `<div class="snapshot-item"><span>${currency} qoldiq</span><strong>${formatMoney(income - expense, currency, true)}</strong></div>`;
    }).join('');
  }

  function renderBooks() {
    const counts = {
      all: state.books.length,
      reading: state.books.filter((b) => statusOf(b) === 'reading').length,
      wishlist: state.books.filter((b) => statusOf(b) === 'wishlist').length,
      finished: state.books.filter((b) => statusOf(b) === 'finished').length
    };
    $('countAll').textContent = counts.all;
    $('countReading').textContent = counts.reading;
    $('countWishlist').textContent = counts.wishlist;
    $('countFinished').textContent = counts.finished;

    const query = $('bookSearch')?.value?.trim().toLowerCase() || '';
    let books = state.books.filter((book) => {
      const matchFilter = bookFilter === 'all' || statusOf(book) === bookFilter;
      const hay = `${book.title} ${book.author} ${book.notes}`.toLowerCase();
      return matchFilter && (!query || hay.includes(query));
    });

    const sort = $('bookSort')?.value || 'updated';
    books.sort((a, b) => {
      if (sort === 'title') return a.title.localeCompare(b.title, 'uz');
      if (sort === 'started') return (b.startedAt || '').localeCompare(a.startedAt || '');
      if (sort === 'finished') return (b.finishedAt || '').localeCompare(a.finishedAt || '');
      return String(b.updatedAt || '').localeCompare(String(a.updatedAt || ''));
    });

    const grid = $('booksGrid');
    if (!books.length) {
      grid.innerHTML = `<div class="empty"><strong>Bu bo‘limda kitob yo‘q</strong><span class="muted">“Kitob qo‘shish” orqali birinchi kitobingizni kiriting.</span></div>`;
      return;
    }

    grid.innerHTML = books.map((book) => {
      const status = statusOf(book);
      const progress = progressOf(book);
      const facts = [];
      if (book.startedAt) facts.push(`Boshladi: ${formatDate(book.startedAt)}`);
      if (book.finishedAt) facts.push(`Tugatdi: ${formatDate(book.finishedAt)}`);
      if (book.startedAt) facts.push(`${durationDays(book)} kun`);
      if (book.pages) facts.push(`${book.currentPage || 0}/${book.pages} bet`);
      if (book.rating) facts.push(`★ ${book.rating}/5`);

      let quick = '';
      if (status === 'wishlist') quick = `<button class="primary" data-action="start" data-id="${book.id}">Bugun boshlash</button>`;
      if (status === 'reading') quick = `<button class="primary" data-action="progress" data-id="${book.id}">Sahifa yangilash</button><button data-action="finish" data-id="${book.id}">Tugatdim</button>`;

      return `<article class="book-card">
        ${coverHtml(book)}
        <div class="book-meta">
          <h3 title="${escapeHtml(book.title)}">${escapeHtml(book.title)}</h3>
          <div class="author">${escapeHtml(book.author || 'Muallif kiritilmagan')}</div>
          <div class="status-badge ${status}">${statusLabel(status)}</div>
          ${book.pages ? `<div class="progress-track"><div class="progress-fill" style="width:${progress}%"></div></div>` : ''}
          <div class="book-facts">${facts.map((f) => `<span class="fact">${escapeHtml(f)}</span>`).join('')}</div>
          <div class="card-actions">
            ${quick}
            <button data-action="edit" data-id="${book.id}">Tahrirlash</button>
            <button data-action="delete" data-id="${book.id}">O‘chirish</button>
          </div>
        </div>
      </article>`;
    }).join('');
  }

  function openBookDialog(book = null) {
    $('bookDialogTitle').textContent = book ? 'Kitobni tahrirlash' : 'Kitob qo‘shish';
    $('bookId').value = book?.id || '';
    $('bookTitle').value = book?.title || '';
    $('bookAuthor').value = book?.author || '';
    $('bookCover').value = book?.cover || '';
    $('bookPages').value = book?.pages || '';
    $('bookCurrentPage').value = book?.currentPage || '';
    $('bookStartedAt').value = book?.startedAt || '';
    $('bookFinishedAt').value = book?.finishedAt || '';
    $('bookRating').value = String(book?.rating || 0);
    $('bookNotes').value = book?.notes || '';
    updateBookStatusPreview();
    $('bookDialog').showModal();
  }

  function updateBookStatusPreview() {
    const temp = {
      startedAt: $('bookStartedAt').value,
      finishedAt: $('bookFinishedAt').value
    };
    const status = statusOf(temp);
    const el = $('bookStatusPreview');
    el.className = `status-badge ${status}`;
    el.textContent = statusLabel(status);
  }

  function saveBookFromForm(event) {
    event.preventDefault();
    const id = $('bookId').value;
    const title = $('bookTitle').value.trim();
    if (!title) return toast('Kitob nomini kiriting.');

    const startedAt = $('bookStartedAt').value;
    const finishedAt = $('bookFinishedAt').value;
    if (startedAt && finishedAt && parseDay(finishedAt) < parseDay(startedAt)) {
      return toast('Tugatilgan sana boshlangan sanadan oldin bo‘lishi mumkin emas.');
    }

    const pages = numOrZero($('bookPages').value);
    let currentPage = numOrZero($('bookCurrentPage').value);
    if (pages) currentPage = Math.min(currentPage, pages);
    if (finishedAt && pages) currentPage = pages;

    const existing = state.books.find((b) => b.id === id);
    const book = {
      id: existing?.id || makeId(),
      title,
      author: $('bookAuthor').value.trim(),
      cover: $('bookCover').value.trim(),
      pages,
      currentPage,
      startedAt,
      finishedAt,
      rating: clampInt($('bookRating').value, 0, 5),
      notes: $('bookNotes').value.trim(),
      createdAt: existing?.createdAt || new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    if (existing) Object.assign(existing, book);
    else state.books.unshift(book);

    $('bookDialog').close();
    saveState(existing ? 'Kitob yangilandi.' : 'Kitob qo‘shildi.');
  }

  function handleBookAction(action, id) {
    const book = state.books.find((b) => b.id === id);
    if (!book) return;

    if (action === 'edit') return openBookDialog(book);
    if (action === 'delete') {
      if (!confirm(`“${book.title}” kitobini o‘chirasizmi?`)) return;
      state.books = state.books.filter((b) => b.id !== id);
      return saveState('Kitob o‘chirildi.');
    }
    if (action === 'start') {
      book.startedAt = today();
      book.finishedAt = '';
      book.updatedAt = new Date().toISOString();
      return saveState('Mutolaa boshlandi.');
    }
    if (action === 'finish') {
      if (!book.startedAt) book.startedAt = today();
      book.finishedAt = today();
      if (book.pages) book.currentPage = book.pages;
      book.updatedAt = new Date().toISOString();
      return saveState('Kitob “Tugatdim” holatiga o‘tdi.');
    }
    if (action === 'progress') {
      const next = prompt(`Hozir nechanchi sahifadasiz?${book.pages ? ` (jami ${book.pages})` : ''}`, String(book.currentPage || ''));
      if (next === null) return;
      const n = Math.max(0, Math.round(Number(next) || 0));
      book.currentPage = book.pages ? Math.min(n, book.pages) : n;
      book.updatedAt = new Date().toISOString();
      return saveState('Mutolaa progressi yangilandi.');
    }
  }

  function renderFinance() {
    const filtered = filterTransactions(state.transactions, financePeriod)
      .filter((t) => t.currency === financeCurrency)
      .sort((a, b) => b.date.localeCompare(a.date) || String(b.updatedAt).localeCompare(String(a.updatedAt)));

    const income = sumTx(filtered, 'income');
    const expense = sumTx(filtered, 'expense');
    const net = income - expense;
    $('finIncome').textContent = formatMoney(income, financeCurrency);
    $('finExpense').textContent = formatMoney(expense, financeCurrency);
    $('finNet').textContent = formatMoney(net, financeCurrency, true);

    qsa('#periodFilters button').forEach((b) => b.classList.toggle('active', b.dataset.period === financePeriod));
    qsa('#currencyToggle button').forEach((b) => b.classList.toggle('active', b.dataset.currency === financeCurrency));

    const expenses = filtered.filter((t) => t.type === 'expense');
    const grouped = {};
    expenses.forEach((t) => grouped[t.category] = (grouped[t.category] || 0) + t.amount);
    const entries = Object.entries(grouped).sort((a, b) => b[1] - a[1]);
    const max = Math.max(1, ...entries.map(([, v]) => v));
    $('categoryBreakdown').innerHTML = entries.length
      ? entries.map(([name, value]) => `<div class="bar-row">
          <div class="bar-label">${escapeHtml(name)}</div>
          <div class="bar-shell"><div class="bar-fill" style="width:${Math.max(4, (value / max) * 100)}%"></div></div>
          <div class="bar-value">${formatMoney(value, financeCurrency)}</div>
        </div>`).join('')
      : `<div class="empty"><strong>Chiqim yo‘q</strong><span class="muted">Tanlangan davrda xarajat kiritilmagan.</span></div>`;

    $('txList').innerHTML = filtered.length
      ? filtered.map((t) => `<article class="tx-item ${t.type}">
          <div class="tx-icon">${t.type === 'income' ? '↓' : '↑'}</div>
          <div>
            <div class="tx-title">${escapeHtml(t.category)}</div>
            <div class="tx-sub">${formatDate(t.date)}${t.note ? ' • ' + escapeHtml(t.note) : ''}</div>
          </div>
          <div>
            <div class="tx-amount">${t.type === 'income' ? '+' : '−'}${formatMoney(t.amount, t.currency)}</div>
            <div class="tx-actions">
              <button data-tx-action="edit" data-id="${t.id}">Tahrir</button>
              <button data-tx-action="delete" data-id="${t.id}">O‘chir</button>
            </div>
          </div>
        </article>`).join('')
      : `<div class="empty"><strong>Tranzaksiya yo‘q</strong><span class="muted">Tanlangan davr va valyutada ma’lumot topilmadi.</span></div>`;
  }

  function filterTransactions(list, period) {
    if (period === 'all') return [...list];
    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    let start = todayStart;

    if (period === 'week') {
      const day = (todayStart.getDay() + 6) % 7;
      start = new Date(todayStart);
      start.setDate(start.getDate() - day);
    } else if (period === 'month') {
      start = new Date(now.getFullYear(), now.getMonth(), 1);
    } else if (period === 'year') {
      start = new Date(now.getFullYear(), 0, 1);
    }

    return list.filter((t) => {
      const d = parseDay(t.date);
      return d && d >= start && d <= now;
    });
  }

  function sumTx(rows, type) {
    return rows.filter((t) => t.type === type).reduce((sum, t) => sum + (Number(t.amount) || 0), 0);
  }

  function formatMoney(amount, currency, signed = false) {
    const value = Math.round(Number(amount) || 0);
    const abs = Math.abs(value).toLocaleString('en-US');
    const prefix = signed && value > 0 ? '+' : signed && value < 0 ? '−' : value < 0 ? '−' : '';
    return currency === 'UZS' ? `${prefix}${abs} so‘m` : `${prefix}₩${abs}`;
  }

  function openTxDialog(tx = null) {
    $('txDialogTitle').textContent = tx ? 'Tranzaksiyani tahrirlash' : 'Tranzaksiya qo‘shish';
    $('txId').value = tx?.id || '';
    $('txType').value = tx?.type || 'expense';
    $('txCurrency').value = tx?.currency || financeCurrency;
    $('txAmount').value = tx?.amount || '';
    $('txDate').value = tx?.date || today();
    $('txCategory').value = tx?.category || '';
    $('txNote').value = tx?.note || '';
    $('txDialog').showModal();
  }

  function saveTxFromForm(event) {
    event.preventDefault();
    const id = $('txId').value;
    const amount = Math.round(Number($('txAmount').value) || 0);
    if (amount <= 0) return toast('Summani to‘g‘ri kiriting.');

    const existing = state.transactions.find((t) => t.id === id);
    const tx = {
      id: existing?.id || makeId(),
      type: $('txType').value === 'income' ? 'income' : 'expense',
      currency: $('txCurrency').value === 'UZS' ? 'UZS' : 'KRW',
      amount,
      date: $('txDate').value || today(),
      category: $('txCategory').value.trim() || 'Boshqa',
      note: $('txNote').value.trim(),
      createdAt: existing?.createdAt || new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    if (existing) Object.assign(existing, tx);
    else state.transactions.unshift(tx);

    financeCurrency = tx.currency;
    $('txDialog').close();
    saveState(existing ? 'Tranzaksiya yangilandi.' : 'Tranzaksiya qo‘shildi.');
  }

  function handleTxAction(action, id) {
    const tx = state.transactions.find((t) => t.id === id);
    if (!tx) return;
    if (action === 'edit') return openTxDialog(tx);
    if (action === 'delete') {
      if (!confirm('Bu tranzaksiyani o‘chirasizmi?')) return;
      state.transactions = state.transactions.filter((t) => t.id !== id);
      saveState('Tranzaksiya o‘chirildi.');
    }
  }

  function renderSettings() {
    $('profileName').value = state.profile.name;
    $('yearGoal').value = state.profile.yearlyGoal;
  }

  function saveSettings() {
    state.profile.name = $('profileName').value.trim() || 'Mohirbek';
    state.profile.yearlyGoal = clampInt($('yearGoal').value, 1, 500);
    saveState('Sozlamalar saqlandi.');
    navigate(currentView);
  }

  function exportBackup() {
    const payload = {
      app: 'Bek Shaxsiy Yordamchi',
      exportedAt: new Date().toISOString(),
      data: state
    };
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `shaxsiy-yordamchi-backup-${today()}.json`;
    a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  }

  function importBackup(file) {
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      try {
        const parsed = JSON.parse(reader.result);
        const data = parsed?.data || parsed;
        state = normalizeState(data);
        saveState('Backup muvaffaqiyatli tiklandi.');
      } catch (_) {
        toast('Backup fayli yaroqsiz.');
      }
    };
    reader.readAsText(file);
  }

  function clearAll() {
    if (!confirm('Kitoblar, moliya va sozlamalardagi barcha ma’lumotlar o‘chadi. Davom etasizmi?')) return;
    state = defaultState();
    saveState('Barcha ma’lumotlar tozalandi.');
  }

  function bindEvents() {
    qsa('.bottom-nav button[data-view]').forEach((btn) => btn.addEventListener('click', () => navigate(btn.dataset.view)));
    qsa('[data-go]').forEach((btn) => btn.addEventListener('click', () => navigate(btn.dataset.go)));

    $('themeBtn').addEventListener('click', () => {
      state.profile.theme = state.profile.theme === 'dark' ? 'light' : 'dark';
      saveState();
    });

    $('addBookBtn').addEventListener('click', () => openBookDialog());
    $('bookForm').addEventListener('submit', saveBookFromForm);
    $('bookStartedAt').addEventListener('change', updateBookStatusPreview);
    $('bookFinishedAt').addEventListener('change', updateBookStatusPreview);
    $('bookSearch').addEventListener('input', renderBooks);
    $('bookSort').addEventListener('change', renderBooks);

    $('bookFilters').addEventListener('click', (event) => {
      const btn = event.target.closest('button[data-filter]');
      if (!btn) return;
      bookFilter = btn.dataset.filter;
      qsa('#bookFilters button').forEach((b) => b.classList.toggle('active', b === btn));
      renderBooks();
    });

    $('booksGrid').addEventListener('click', (event) => {
      const btn = event.target.closest('button[data-action]');
      if (btn) handleBookAction(btn.dataset.action, btn.dataset.id);
      const card = event.target.closest('.book-card');
      if (!btn && card) {
        const id = card.querySelector('[data-id]')?.dataset.id;
        if (id) openBookDialog(state.books.find((b) => b.id === id));
      }
    });

    $('addTxBtn').addEventListener('click', () => openTxDialog());
    $('txForm').addEventListener('submit', saveTxFromForm);

    $('periodFilters').addEventListener('click', (event) => {
      const btn = event.target.closest('button[data-period]');
      if (!btn) return;
      financePeriod = btn.dataset.period;
      renderFinance();
    });
    $('currencyToggle').addEventListener('click', (event) => {
      const btn = event.target.closest('button[data-currency]');
      if (!btn) return;
      financeCurrency = btn.dataset.currency;
      renderFinance();
    });
    $('txList').addEventListener('click', (event) => {
      const btn = event.target.closest('button[data-tx-action]');
      if (btn) handleTxAction(btn.dataset.txAction, btn.dataset.id);
    });

    qsa('.close-dialog').forEach((btn) => btn.addEventListener('click', () => $(btn.dataset.close).close()));
    $('saveSettingsBtn').addEventListener('click', saveSettings);
    $('editGoalBtn').addEventListener('click', () => navigate('settings'));
    $('exportBtn').addEventListener('click', exportBackup);
    $('importInput').addEventListener('change', (e) => {
      importBackup(e.target.files?.[0]);
      e.target.value = '';
    });
    $('clearAllBtn').addEventListener('click', clearAll);

    window.addEventListener('beforeinstallprompt', (event) => {
      event.preventDefault();
      installPrompt = event;
      $('installBtn').classList.remove('hidden');
    });
    $('installBtn').addEventListener('click', async () => {
      if (!installPrompt) return;
      installPrompt.prompt();
      await installPrompt.userChoice.catch(() => null);
      installPrompt = null;
      $('installBtn').classList.add('hidden');
    });
  }

  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => navigator.serviceWorker.register('./sw.js').catch(() => {}));
  }

  bindEvents();
  renderAll();
  navigate('dashboard');
})();