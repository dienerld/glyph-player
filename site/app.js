(() => {
  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
  const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const EDGE_DELAY = 300; // same rest time as the app

  // Same ordering the app uses: digit runs compare as numbers.
  const chunks = /\d+|\D+/g;
  function naturalCompare(a, b) {
    const x = a.match(chunks) || [], y = b.match(chunks) || [];
    for (let i = 0; i < Math.min(x.length, y.length); i++) {
      const nx = /^\d/.test(x[i]) && /^\d/.test(y[i]);
      const c = nx ? Number(x[i]) - Number(y[i]) : x[i].toLowerCase().localeCompare(y[i].toLowerCase());
      if (c) return c;
    }
    return x.length - y.length;
  }

  // ---------- Hero: the app, library and player ----------
  const GROUPS = [
    { name: 'Notícias', hue: 290, count: 24, ch: ['Aurora', 'Meridiano', 'Farol', 'Pacífico', 'Estação Norte', 'Vale'] },
    { name: 'Esportes', hue: 310, count: 31, ch: ['Arena 1', 'Arena 10', 'Arena 2', 'Arena 100', 'Arena 11', 'Arena 20'] },
    { name: 'Cinema', hue: 330, count: 18, ch: ['Cine Orla', 'Cine Sul', 'Sessão 1', 'Sessão 2', 'Matinê', 'Clássicos'] },
    { name: 'Infantil', hue: 300, count: 12, ch: ['Pipoca', 'Aquarela', 'Turma 1', 'Turma 2', 'Brincar', 'Gibi'] },
    { name: 'Documentários', hue: 280, count: 15, ch: ['Terra', 'Oceano', 'Mundo 1', 'Mundo 2', 'Saber', 'Origem'] },
    { name: 'Música', hue: 320, count: 20, ch: ['Vinil', 'Estúdio', 'Rádio 1', 'Rádio 2', 'Palco', 'Coro'] },
  ];
  // Channel numbers come from the name's own digits when it has them.
  const numberOf = (name, i) => Number((name.match(/\d+/) || [10 + i])[0]);

  const app = $('#app');
  const body = $('[data-lib-body]');
  const play = $('#play');
  const list = $('[data-list]');
  const panel = $('.panel', play);
  const toggle = $('[data-toggle]', play);
  const hint = $('[data-hint]');
  let group = GROUPS[0];
  let queue = [];
  let index = 0;
  let edgeTimer;

  // Numbered names keep their number (A10, A100) so siblings stay distinguishable.
  const initials = (n) => {
    const num = n.match(/\d+/);
    return num ? n[0].toUpperCase() + num[0] : n.split(/\s+/).map((w) => w[0]).join('').slice(0, 2).toUpperCase();
  };
  const sorted = (g) => [...g.ch].sort(naturalCompare);

  function card(g, name, wide, from = 'library') {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'card' + (wide ? ' wide' : '');
    b.innerHTML = `<span class="tile">${wide ? '<span class="live">AO VIVO</span>' : ''}<span class="mono">${initials(name)}</span></span><span class="name">${name}</span>`;
    b.addEventListener('click', () => openChannel(g, name, from));
    return b;
  }
  function row(title, count, items, wide) {
    const r = document.createElement('div');
    r.className = 'row';
    r.innerHTML = `<h3>${title}<small>${count}</small></h3><div class="row-track"></div>`;
    const track = $('.row-track', r);
    items.forEach(([g, n]) => track.append(card(g, n, wide)));
    return r;
  }
  function renderLibrary() {
    body.textContent = '';
    if (app.dataset.mode === 'rows') {
      body.append(row('Recentes', 3, [[GROUPS[0], 'Meridiano'], [GROUPS[1], 'Arena 10'], [GROUPS[2], 'Cine Sul']], true));
      GROUPS.slice(0, 3).forEach((g) => body.append(row(g.name, g.count, sorted(g).map((n) => [g, n]), false)));
    } else {
      const grid = document.createElement('div');
      grid.className = 'cats';
      GROUPS.forEach((g) => {
        const c = document.createElement('button');
        c.type = 'button';
        c.className = 'cat';
        c.style.setProperty('--h', g.hue);
        c.innerHTML = `<b>${g.name}</b><small>${g.count} canais</small>`;
        c.addEventListener('click', () => openGroup(g));
        grid.append(c);
      });
      body.append(grid);
    }
  }
  $$('[data-mode-btn]').forEach((b) =>
    b.addEventListener('click', () => {
      app.dataset.mode = b.dataset.modeBtn;
      $$('[data-mode-btn]').forEach((x) => x.setAttribute('aria-pressed', String(x === b)));
      renderLibrary();
    }));

  function renderPlayer() {
    const name = queue[index];
    $('[data-osd-num]').textContent = numberOf(name, index);
    $('[data-osd-name]').textContent = name;
    $('[data-panel-name]').textContent = name;
    $('[data-panel-group]').textContent = group.name;
    $$('li', list).forEach((li, i) => {
      const b = li.firstChild;
      if (i === index) b.setAttribute('aria-current', 'true'); else b.removeAttribute('aria-current');
    });
    // Scroll only the list: scrollIntoView would also scroll the (off-canvas) panel's
    // ancestors, shifting the whole player and the page.
    const cur = $('[aria-current="true"]', list);
    if (cur) list.scrollTop += cur.getBoundingClientRect().top - list.getBoundingClientRect().top - (list.clientHeight - cur.offsetHeight) / 2;
  }
  function zap(delta) {
    index = (index + delta + queue.length) % queue.length;
    renderPlayer();
  }
  function setOpen(open) {
    play.classList.toggle('open', open);
    toggle.setAttribute('aria-expanded', String(open));
    panel.inert = !open;
  }
  // Categorias -> the category's channels -> the player, as in the app.
  function openGroup(g) {
    group = g;
    $('[data-grp-title]').textContent = g.name;
    const grid = document.createElement('div');
    grid.className = 'grp-grid';
    sorted(g).forEach((n) => grid.append(card(g, n, false, 'group')));
    const gb = $('[data-grp-body]');
    gb.textContent = '';
    gb.append(grid);
    gb.scrollTop = 0;
    app.dataset.view = 'group';
    $('[data-grp-back]').focus({ preventScroll: true });
  }
  $('[data-grp-back]').addEventListener('click', () => { app.dataset.view = 'library'; });
  $('.grp').addEventListener('keydown', (e) => { if (e.key === 'Escape') app.dataset.view = 'library'; });

  function openChannel(g, name, from = 'library') {
    origin = from;
    group = g;
    queue = sorted(g);
    index = queue.indexOf(name);
    list.textContent = '';
    queue.forEach((n, i) => {
      const li = document.createElement('li');
      li.innerHTML = `<button type="button"><i></i><b>${numberOf(n, i)}</b><span>${n}</span></button>`;
      li.firstChild.addEventListener('click', () => zap(i - index));
      list.append(li);
    });
    setOpen(false);
    app.dataset.view = 'player';
    renderPlayer();
    play.focus({ preventScroll: true });
  }
  function closePlayer() {
    setOpen(false);
    app.dataset.view = origin;
  }

  $('[data-edge]', play).addEventListener('mouseenter', () => { edgeTimer = setTimeout(() => setOpen(true), EDGE_DELAY); });
  $('[data-edge]', play).addEventListener('mouseleave', () => clearTimeout(edgeTimer));
  panel.addEventListener('mouseleave', () => setOpen(false));
  toggle.addEventListener('click', () => setOpen(!play.classList.contains('open')));
  $('[data-back]', play).addEventListener('click', closePlayer);
  $$('[data-zap]', play).forEach((b) => b.addEventListener('click', () => zap(Number(b.dataset.zap))));
  play.addEventListener('keydown', (e) => {
    if (e.target.closest('button') && !/^Arrow(Up|Down)$/.test(e.key) && e.key !== 'Escape') return;
    if (e.key === 'ArrowUp') zap(-1);
    else if (e.key === 'ArrowDown') zap(1);
    else if (e.key.toLowerCase() === 'l') setOpen(!play.classList.contains('open'));
    else if (e.key === 'Escape') (play.classList.contains('open') ? setOpen(false) : closePlayer());
    else return;
    e.preventDefault();
  });
  renderLibrary();

  // ---------- Import demo: the line moves, the UI stays usable ----------
  const run = $('[data-import-run]');
  const line = $('[data-import-line]');
  const status = $('[data-import-status]');
  const fmt = (n) => n.toLocaleString('pt-BR');
  run?.addEventListener('click', () => {
    run.disabled = true;
    const total = 220412, start = performance.now(), dur = reduceMotion ? 10 : 3200;
    (function tick(now) {
      const t = Math.min(1, (now - start) / dur);
      line.style.width = `${t * 100}%`;
      status.textContent = `Importando… ${fmt(Math.round(total * t))} itens`;
      if (t < 1) return requestAnimationFrame(tick);
      status.textContent = 'Lista atualizada. 3.312 canais ao vivo.';
      line.style.width = '0';
      run.disabled = false;
    })(start);
  });

  // ---------- Keycap demo ----------
  const keys = $('[data-keys]');
  if (keys) {
    const demo = [[10, 'Aurora'], [11, 'Meridiano'], [12, 'Farol']];
    let k = 1;
    const list2 = $('[data-key-listbox]', keys);
    const paint = () => {
      $('[data-key-num]', keys).textContent = demo[k][0];
      $('[data-key-name]', keys).textContent = demo[k][1];
      $$('span', list2).forEach((s, i) => s.classList.toggle('cur', i === k));
    };
    $$('[data-key]', keys).forEach((b) => b.addEventListener('click', () => {
      k = (k + Number(b.dataset.key) + demo.length) % demo.length;
      paint();
    }));
    const L = $('[data-key-list]', keys);
    L.addEventListener('click', () => {
      list2.hidden = !list2.hidden;
      L.setAttribute('aria-pressed', String(!list2.hidden));
    });
    paint();
  }

  // ---------- Tabs (sections and install) ----------
  function tabs(root) {
    const btns = $$('[role="tab"]', root);
    const show = (btn, focus) => {
      btns.forEach((b) => {
        const on = b === btn;
        b.setAttribute('aria-selected', String(on));
        b.tabIndex = on ? 0 : -1;
        document.getElementById(b.getAttribute('aria-controls')).hidden = !on;
      });
      if (focus) btn.focus();
    };
    btns.forEach((b, i) => {
      b.addEventListener('click', () => show(b));
      b.addEventListener('keydown', (e) => {
        const d = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0;
        if (d) { e.preventDefault(); show(btns[(i + d + btns.length) % btns.length], true); }
      });
    });
    return show;
  }
  $$('.tabs').forEach((t) => tabs(t.parentElement));
  const osTabs = $$('.tabs')[1];

  // Open the install tab for the visitor's system.
  const ua = navigator.userAgent;
  const mine = /Windows/i.test(ua) ? 'o-windows' : null;
  if (mine && osTabs) document.getElementById(mine).click();

  // ---------- Update demo ----------
  const upd = $('[data-updater]');
  if (upd) {
    const text = $('[data-upd-text]', upd);
    const runBtn = $('[data-upd-run]', upd);
    const actions = $('.upd-actions', upd);
    let v = '0.5.0';
    text.textContent = `Nova versão ${v} disponível`;
    runBtn.addEventListener('click', () => {
      actions.innerHTML = '<span class="upd-bar"><i></i></span>';
      text.textContent = `Baixando a versão ${v}…`;
      const bar = $('.upd-bar i', upd), start = performance.now(), dur = reduceMotion ? 10 : 2200;
      (function tick(now) {
        const t = Math.min(1, (now - start) / dur);
        bar.style.width = `${t * 100}%`;
        if (t < 1) return requestAnimationFrame(tick);
        text.textContent = `Pronto: o app reabriria agora na versão ${v}.`;
        actions.innerHTML = '';
      })(start);
    });
  }

  // ---------- Copy buttons ----------
  $$('[data-copy]').forEach((btn) => btn.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(document.getElementById(btn.dataset.copy).textContent);
      btn.textContent = 'Copiado';
    } catch {
      btn.textContent = 'Selecione e copie';
    }
    setTimeout(() => (btn.textContent = 'Copiar'), 1800);
  }));

  // ---------- Latest version and direct download links (page works without) ----------
  fetch('https://api.github.com/repos/dienerld/glyph-player/releases/latest')
    .then((r) => (r.ok ? r.json() : Promise.reject()))
    .then((rel) => {
      const v = rel.tag_name.replace(/^v/, '');
      $('[data-version]').textContent = `Versão ${v} para Linux e Windows`;
      $('[data-version-foot]').textContent = `Glyph Player ${v}`;
      $$('[data-asset]').forEach((a) => {
        const hit = rel.assets.find((x) => x.name.endsWith(a.dataset.asset));
        if (hit) a.href = hit.browser_download_url;
      });
    })
    .catch(() => {});
})();
