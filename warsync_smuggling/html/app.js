// WarSync smuggling NUI: toasts, crafting menu, progress bar, motion tablet radar.
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'warsync_smuggling';
const post = (name, data = {}) => fetch(`https://${RES}/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data),
}).catch(() => {});
const $ = (id) => document.getElementById(id);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = (ms) => { const s = Math.max(0, Math.ceil(ms / 1000)); return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`; };

/* ---------------- Toasts ---------------- */
function notify({ text, type = 'info', title }) {
    const el = document.createElement('div');
    const life = 5000;
    el.className = `toast ${type}`;
    el.innerHTML = `<div class="t-title">${esc(title || ({ success: 'Success', error: 'Error', warning: 'Warning' }[type] || 'Info'))}</div>
        <div class="t-text">${esc(text)}</div><div class="t-life" style="animation-duration:${life}ms"></div>`;
    $('toasts').appendChild(el);
    setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 300); }, life);
    while ($('toasts').children.length > 5) $('toasts').firstChild.remove();
}

/* ---------------- Crafting ---------------- */
let craftItems = [];
function renderCraft(filter = '') {
    const f = filter.toLowerCase();
    $('craft-list').innerHTML = craftItems
        .filter((i) => !f || i.label.toLowerCase().includes(f) || i.description.toLowerCase().includes(f))
        .map((i, idx) => `<div class="card ${esc(i.tier)}" data-name="${esc(i.name)}" style="animation-delay:${idx * 35}ms">
            <div class="tier">${esc(i.tier)}</div>
            <div class="name">${esc(i.label)}</div>
            <div class="desc">${esc(i.description)}</div>
            <div class="meta"><span class="chip">⏱ ${fmt(i.time * 1000)}</span><span class="chip">⚖ ${(i.weight / 1000).toFixed(1)} kg</span></div>
        </div>`).join('');
}
$('craft-list').addEventListener('click', (e) => {
    const card = e.target.closest('.card');
    if (card) post('craft:select', { name: card.dataset.name });
});
$('craft-filter').addEventListener('input', (e) => renderCraft(e.target.value));
$('craft-close').addEventListener('click', () => post('craft:close'));

/* ---------------- Progress ---------------- */
let progTimer = null;
function progress({ label, duration }) {
    const p = $('progress');
    clearInterval(progTimer);
    p.className = '';
    $('progress-label').textContent = label;
    const fill = $('progress-fill');
    fill.style.transition = 'none'; fill.style.width = '0%';
    void fill.offsetWidth;
    fill.style.transition = `width ${duration}ms linear`; fill.style.width = '100%';
    const end = Date.now() + duration;
    const tick = () => { $('progress-time').textContent = fmt(end - Date.now()); };
    tick(); progTimer = setInterval(tick, 250);
}
function progressEnd(success) {
    clearInterval(progTimer);
    const p = $('progress'), fill = $('progress-fill');
    fill.style.width = getComputedStyle(fill).width; // freeze where it is
    if (success) fill.style.width = '100%';
    p.classList.add(success ? 'done' : 'fail');
    setTimeout(() => p.classList.add('hidden'), success ? 450 : 800);
}

/* ---------------- Tablet ---------------- */
const radar = $('radar'), ctx = radar.getContext('2d');
const tab = { on: false, blips: [], remaining: 60000, total: 60000, radius: 60, sweep: 0, last: 0, endAt: 0, broken: false };

function drawRadar(t) {
    const W = radar.width, C = W / 2, R = C - 12;
    ctx.clearRect(0, 0, W, W);
    // grid
    ctx.strokeStyle = 'rgba(73,242,140,.18)'; ctx.lineWidth = 1.5;
    for (let i = 1; i <= 4; i++) { ctx.beginPath(); ctx.arc(C, C, (R / 4) * i, 0, Math.PI * 2); ctx.stroke(); }
    ctx.beginPath(); ctx.moveTo(C, C - R); ctx.lineTo(C, C + R); ctx.moveTo(C - R, C); ctx.lineTo(C + R, C); ctx.stroke();
    ctx.fillStyle = 'rgba(73,242,140,.45)'; ctx.font = '600 16px Rajdhani';
    ctx.fillText(`${Math.round(tab.radius)}m`, C + 6, C - R + 18);

    if (tab.on) {
        // sweep
        tab.sweep = (tab.sweep + (t - tab.last) * 0.0035) % (Math.PI * 2);
        const g = ctx.createConicGradient ? ctx.createConicGradient(tab.sweep - Math.PI / 2 - 0.9, C, C) : null;
        if (g) {
            g.addColorStop(0, 'rgba(73,242,140,0)'); g.addColorStop(0.14, 'rgba(73,242,140,.35)'); g.addColorStop(0.145, 'rgba(73,242,140,0)');
            ctx.fillStyle = g; ctx.beginPath(); ctx.arc(C, C, R, 0, Math.PI * 2); ctx.fill();
        }
        // blips
        for (const b of tab.blips) {
            const x = C + Math.max(-1, Math.min(1, b.x)) * R, y = C - Math.max(-1, Math.min(1, b.y)) * R;
            const pulse = 1 + Math.sin(t / 180) * 0.25;
            ctx.fillStyle = 'rgba(255,80,70,.25)'; ctx.beginPath(); ctx.arc(x, y, 14 * pulse, 0, Math.PI * 2); ctx.fill();
            ctx.fillStyle = '#ff5046';
            ctx.beginPath();
            if (b.veh) ctx.rect(x - 6, y - 6, 12, 12); else ctx.arc(x, y, 6, 0, Math.PI * 2);
            ctx.fill();
        }
        const rem = tab.endAt - Date.now();
        $('tablet-timer').textContent = fmt(rem);
    }
    // self
    ctx.fillStyle = '#e9ece6'; ctx.beginPath(); ctx.moveTo(C, C - 9); ctx.lineTo(C + 7, C + 7); ctx.lineTo(C - 7, C + 7); ctx.closePath(); ctx.fill();
    tab.last = t;
    if (!$('tablet').classList.contains('hidden')) requestAnimationFrame(drawRadar);
}

function tabletState(on, remaining, total) {
    tab.on = on;
    if (remaining !== undefined) { tab.remaining = remaining; tab.endAt = Date.now() + remaining; }
    if (total) tab.total = total;
    if (!on) tab.blips = [];
    $('tablet-led').classList.toggle('on', on);
    $('tablet-btn').classList.toggle('on', on);
    $('tablet-btn').textContent = on ? 'POWER OFF' : 'POWER ON';
    $('tablet-timer').textContent = fmt(tab.remaining);
    $('tablet-bar').style.width = `${(tab.remaining / tab.total) * 100}%`;
}

$('tablet-btn').addEventListener('click', (e) => { e.preventDefault(); e.stopPropagation(); if (!tab.broken) post('tablet:toggle'); });
// If focus is held and the key is released while the NUI has focus, release the cursor.
window.addEventListener('keyup', (e) => { if (e.key === 'Alt' || e.key === 'Escape') post('tablet:release'); });
window.addEventListener('keydown', (e) => { if (e.key === 'Alt') e.preventDefault(); });

/* ---------------- Router ---------------- */
window.addEventListener('message', ({ data: d }) => {
    switch (d.action) {
        case 'notify': return notify(d);
        case 'craft:open':
            craftItems = d.items || []; $('craft-filter').value = ''; renderCraft();
            return $('craft').classList.remove('hidden');
        case 'craft:close': return $('craft').classList.add('hidden');
        case 'progress': return progress(d);
        case 'progressEnd': return progressEnd(d.success);
        case 'tablet:show':
            tab.radius = d.radius; tab.total = d.total; tab.broken = false;
            $('tablet-key').textContent = (d.key || 'LMENU').replace('LMENU', 'ALT');
            $('tablet-broken').classList.add('hidden');
            $('tablet').classList.remove('hidden', 'leaving');
            tabletState(false);
            return requestAnimationFrame((t) => { tab.last = t; drawRadar(t); });
        case 'tablet:hide':
            $('tablet').classList.add('leaving');
            return setTimeout(() => { $('tablet').classList.add('hidden'); $('tablet').classList.remove('leaving', 'cursor'); }, 300);
        case 'tablet:cursor': return $('tablet').classList.toggle('cursor', d.state);
        case 'tablet:state': return tabletState(d.on, d.remaining, d.total);
        case 'tablet:blips':
            tab.blips = d.blips || [];
            if (d.remaining !== undefined) { tab.remaining = d.remaining; tab.endAt = Date.now() + d.remaining; $('tablet-bar').style.width = `${(d.remaining / tab.total) * 100}%`; }
            return;
        case 'tablet:broken':
            tab.broken = true; tabletState(false, 0);
            return $('tablet-broken').classList.remove('hidden');
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !$('craft').classList.contains('hidden')) post('craft:close');
});
