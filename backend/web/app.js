/* ════════════════════════════════════════════════════════════ */
/* MIDAS-Bénin Console — Application JavaScript              */
/* ════════════════════════════════════════════════════════════ */
const API = '/api/v1';
let ADMIN_TOKEN = localStorage.getItem('midas_admin_token') || null;
let logAutoRefreshInterval = null;

// ── Helpers ──
function $(id) { return document.getElementById(id); }
function showLoading(show) { $('loadingOverlay').classList.toggle('hidden', !show); }
function esc(s) {
  if (s == null) return '';
  return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

async function api(path, options = {}) {
  const url = `${API}${path}`;
  const headers = { 'Content-Type': 'application/json', ...options.headers };
  if (ADMIN_TOKEN) headers['Authorization'] = `Bearer ${ADMIN_TOKEN}`;
  const res = await fetch(url, { ...options, headers });
  if (res.status === 401) { handleLogout(); throw new Error('Session expirée'); }
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`${res.status}: ${text}`);
  }
  return res.json();
}

// ── Auth ──
async function handleLogin(e) {
  e.preventDefault();
  const username = $('loginUser').value.trim();
  const password = $('loginPass').value;
  const btn = $('loginBtn');
  const errEl = $('loginError');

  btn.disabled = true;
  btn.textContent = 'Connexion...';
  errEl.style.display = 'none';

  try {
    const res = await fetch(`${API}/admin/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Erreur de connexion');
    ADMIN_TOKEN = data.token;
    localStorage.setItem('midas_admin_token', data.token);
    showApp();
  } catch (err) {
    errEl.textContent = err.message;
    errEl.style.display = 'block';
  } finally {
    btn.disabled = false;
    btn.textContent = 'Connexion';
  }
  return false;
}

function handleLogout() {
  ADMIN_TOKEN = null;
  localStorage.removeItem('midas_admin_token');
  $('loginPage').style.display = 'flex';
  $('appShell').style.display = 'none';
  if (logAutoRefreshInterval) { clearInterval(logAutoRefreshInterval); logAutoRefreshInterval = null; }
}

async function showApp() {
  $('loginPage').style.display = 'none';
  $('appShell').style.display = 'flex';
  loadDashboard();
}

async function checkSession() {
  if (!ADMIN_TOKEN) return false;
  try {
    const res = await fetch(`${API}/admin/session`, {
      headers: { 'Authorization': `Bearer ${ADMIN_TOKEN}` },
    });
    if (res.ok) return true;
    handleLogout();
    return false;
  } catch { return false; }
}

// ── Navigation ──
document.querySelectorAll('.nav-item').forEach(el => {
  el.addEventListener('click', e => {
    e.preventDefault();
    document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
    el.classList.add('active');
    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    const page = el.dataset.page;
    $(`page-${page}`).classList.add('active');
    $('pageTitle').textContent = el.textContent.trim();
    loadPage(page);
  });
});

function refreshCurrentPage() {
  const active = document.querySelector('.nav-item.active');
  if (active) loadPage(active.dataset.page);
}

function loadPage(page) {
  switch(page) {
    case 'dashboard': loadDashboard(); break;
    case 'audit': loadAuditPage(); break;
    case 'violations': loadViolations(); break;
    case 'logs': loadLogs(); loadLogStats(); break;
    case 'entities': loadEntityTypes(); break;
    case 'users': loadUsers(); break;
    case 'consents': loadConsents(); break;
    case 'iot': loadIotData(); break;
  }
}

// ── Dashboard ──
async function loadDashboard() {
  showLoading(true);
  try {
    const data = await api('/admin/dashboard');
    const s = data.stats;

    $('totalAuditEvents').textContent = s.totalAuditEvents.toLocaleString();
    $('totalViolations').textContent = s.totalViolations;
    $('totalUsers').textContent = s.totalUsers;
    $('totalConsents').textContent = s.totalConsents;
    $('totalIotDevices').textContent = s.totalIotDevices;

    const chainOk = s.chainStatus === 'integre';
    $('chainStatus').textContent = chainOk ? 'Intègre' : 'Altérée';
    $('chainStatus').style.color = chainOk ? 'var(--green)' : 'var(--red)';

    // Log stats
    const l = data.logs;
    $('logsTotal24h').textContent = l.last24h;
    $('logsErrors24h').textContent = l.errors24h;
    $('logsWarnings24h').textContent = l.warnings24h;

    const breakdown = $('logBreakdown');
    breakdown.innerHTML = [
      `<span class="chip chip-http">HTTP: ${l.byCategory.http}</span>`,
      `<span class="chip chip-auth">Auth: ${l.byCategory.auth}</span>`,
      `<span class="chip chip-audit">Audit: ${l.byCategory.audit}</span>`,
      `<span class="chip chip-iot">IoT: ${l.byCategory.iot}</span>`,
      `<span class="chip chip-system">Système: ${l.byCategory.system}</span>`,
      `<span class="chip chip-admin">Admin: ${l.byCategory.admin}</span>`,
    ].join('');

    // Entity breakdown
    const eb = $('entityBreakdown');
    if (s.entityTypes.length === 0) {
      eb.innerHTML = '<p class="muted">Aucune entité</p>';
    } else {
      eb.innerHTML = s.entityTypes.map(t => `
        <div class="entity-chip">
          <span class="entity-type">${esc(t.type)}</span>
          <span class="entity-count">${t.count}</span>
        </div>
      `).join('');
    }

    // Recent events
    const events = data.recentEvents || [];
    const re = $('recentEvents');
    if (events.length === 0) {
      re.innerHTML = '<p class="muted">Aucun événement récent.</p>';
    } else {
      re.innerHTML = events.map(e => eventCard(e)).join('');
    }

    $('statusDot').className = 'status-dot';
    $('statusText').textContent = 'Connecté';
  } catch (err) {
    $('statusDot').className = 'status-dot error';
    $('statusText').textContent = 'Erreur';
  }
  showLoading(false);
}

// ── Audit ──
async function loadAuditPage() {
  try {
    const types = await api('/admin/audit/entity-types');
    const sel = $('auditEntityType');
    sel.innerHTML = '<option value="">Tous les types</option>' +
      types.map(t => `<option value="${t.type}">${t.type} (${t.count})</option>`).join('');
  } catch (_) {}
}

async function searchAudit() {
  showLoading(true);
  try {
    const params = new URLSearchParams();
    const entityType = $('auditEntityType').value;
    const action = $('auditAction').value;
    const from = $('auditFrom').value;
    const to = $('auditTo').value;
    const search = $('auditSearch').value.trim();

    if (entityType) params.set('entityType', entityType);
    if (action) params.set('action', action);
    if (from) params.set('from', new Date(from).toISOString());
    if (to) params.set('to', new Date(to + 'T23:59:59').toISOString());
    if (search) params.set('entityId', search);
    params.set('limit', '100');

    const data = await api(`/admin/audit/search?${params}`);
    const events = data.events || [];
    const total = data.total || 0;

    if (events.length === 0) {
      $('auditResults').innerHTML = `<p class="muted">Aucun résultat (${total} total).</p>`;
    } else {
      $('auditResults').innerHTML = `<p style="margin-bottom:10px;font-size:11px;color:var(--text-muted)">${events.length} événements affichés sur ${total}</p>` +
        events.map(e => eventCard(e)).join('');
    }
  } catch (err) {
    $('auditResults').innerHTML = `<p class="muted" style="color:var(--red)">Erreur: ${err.message}</p>`;
  }
  showLoading(false);
}

// ── Violations ──
async function loadViolations() {
  showLoading(true);
  try {
    const violations = await api('/admin/audit/violations');
    if (violations.length === 0) {
      $('violationsList').innerHTML = '<p class="muted">Aucune violation détectée. La chaîne d\'audit est intégrée.</p>';
    } else {
      $('violationsList').innerHTML = violations.map(v => `
        <div class="violation-card">
          <div class="violation-action">${esc(v.action)}</div>
          <div class="violation-reason">Raison: <strong>${esc(v.reason)}</strong> — Entité: ${esc(v.entityId || v.entityType)}</div>
          <div class="violation-meta">
            Acteur: ${esc(v.actorDID || 'N/A')} · ${new Date(v.timestamp).toLocaleString()}
          </div>
        </div>
      `).join('');
    }
    $('totalViolations').textContent = violations.length;
  } catch (err) {
    $('violationsList').innerHTML = `<p class="muted" style="color:var(--red)">Erreur: ${err.message}</p>`;
  }
  showLoading(false);
}

// ── Logs ──
async function loadLogStats() {
  try {
    const stats = await api('/admin/logs/stats');
    $('logStatTotal').textContent = stats.total;
    $('logStatErrors').textContent = stats.errors24h;
    $('logStatHttp').textContent = stats.byCategory.http;
    $('logStatAuth').textContent = stats.byCategory.auth;
  } catch (_) {}
}

async function loadLogs() {
  try {
    const params = new URLSearchParams();
    const level = $('logLevel').value;
    const category = $('logCategory').value;
    const search = $('logSearch').value.trim();

    if (level) params.set('level', level);
    if (category) params.set('category', category);
    if (search) params.set('search', search);
    params.set('limit', '200');

    const data = await api(`/admin/logs?${params}`);
    const entries = data.logs || [];
    const el = $('logEntries');

    if (entries.length === 0) {
      el.innerHTML = '<p class="muted">Aucun log trouvé.</p>';
    } else {
      el.innerHTML = entries.map(l => logEntry(l)).join('');
    }
  } catch (err) {
    $('logEntries').innerHTML = `<p class="muted" style="color:var(--red)">Erreur: ${err.message}</p>`;
  }
}

async function clearLogs() {
  if (!confirm('Vider tous les logs du serveur ?')) return;
  try {
    await api('/admin/logs', { method: 'DELETE' });
    loadLogs();
    loadLogStats();
  } catch (err) {
    alert('Erreur: ' + err.message);
  }
}

function setupAutoRefresh() {
  const cb = $('logAutoRefresh');
  if (cb.checked) {
    logAutoRefreshInterval = setInterval(() => {
      if ($('page-logs').classList.contains('active')) {
        loadLogs();
        loadLogStats();
      }
    }, 5000);
  } else {
    if (logAutoRefreshInterval) { clearInterval(logAutoRefreshInterval); logAutoRefreshInterval = null; }
  }
}

document.addEventListener('change', e => {
  if (e.target.id === 'logAutoRefresh') setupAutoRefresh();
});

// ── Entity Types ──
async function loadEntityTypes() {
  showLoading(true);
  try {
    const types = await api('/admin/audit/entity-types');
    if (types.length === 0) {
      $('entityTypesList').innerHTML = '<p class="muted">Aucun type d\'entité enregistré.</p>';
    } else {
      $('entityTypesList').innerHTML = types.map(t => `
        <div class="entity-chip">
          <span class="entity-type">${esc(t.type)}</span>
          <span class="entity-count">${t.count} événement${t.count > 1 ? 's' : ''}</span>
        </div>
      `).join('');
    }
  } catch (err) {
    $('entityTypesList').innerHTML = `<p class="muted" style="color:var(--red)">Erreur: ${err.message}</p>`;
  }
  showLoading(false);
}

// ── Users ──
async function loadUsers() {
  showLoading(true);
  try {
    const users = await api('/admin/users');
    if (users.length === 0) {
      $('usersList').innerHTML = '<p class="muted">Aucun utilisateur enregistré.</p>';
    } else {
      $('usersList').innerHTML = `
        <table class="data-table">
          <thead><tr><th>NPI</th><th>DID</th><th>Clé publique</th><th>Créé le</th></tr></thead>
          <tbody>${users.map(u => `
            <tr>
              <td><strong>${esc(u.npi)}</strong></td>
              <td class="mono truncate">${esc(u.did)}</td>
              <td class="mono truncate">${esc(u.publicKey?.substring(0, 30))}...</td>
              <td class="mono">${new Date(u.createdAt).toLocaleDateString('fr')}</td>
            </tr>
          `).join('')}</tbody>
        </table>`;
    }
  } catch (err) {
    $('usersList').innerHTML = `<p class="muted" style="color:var(--red)">Erreur: ${err.message}</p>`;
  }
  showLoading(false);
}

// ── Consents ──
async function loadConsents() {
  showLoading(true);
  try {
    const consents = await api('/admin/consents');
    if (consents.length === 0) {
      $('consentsList').innerHTML = '<p class="muted">Aucun consentement enregistré.</p>';
    } else {
      $('consentsList').innerHTML = `
        <table class="data-table">
          <thead><tr><th>ID</th><th>Citoyen</th><th>Finalité</th><th>Domaine</th><th>DID Fournisseur</th><th>Statut</th><th>Date</th></tr></thead>
          <tbody>${consents.map(c => `
            <tr>
              <td class="mono truncate">${esc(c.id?.substring(0, 8))}</td>
              <td class="mono">${esc(c.citizenId?.substring(0, 12))}</td>
              <td>${esc(c.purpose)}</td>
              <td>${esc(c.providerDomain || '—')}</td>
              <td class="mono truncate">${esc(c.providerDID?.substring(0, 30))}</td>
              <td><span class="badge ${c.status === 'GRANTED' ? 'badge-ok' : 'badge-violation'}">${esc(c.status)}</span></td>
              <td class="mono">${new Date(c.createdAt).toLocaleDateString('fr')}</td>
            </tr>
          `).join('')}</tbody>
        </table>`;
    }
  } catch (err) {
    $('consentsList').innerHTML = `<p class="muted" style="color:var(--red)">Erreur: ${err.message}</p>`;
  }
  showLoading(false);
}

// ── IoT Data ──
async function loadIotData() {
  showLoading(true);
  try {
    const data = await api('/admin/iot-data');
    if (data.length === 0) {
      $('iotDataList').innerHTML = '<p class="muted">Aucune donnée IoT.</p>';
    } else {
      $('iotDataList').innerHTML = `
        <table class="data-table">
          <thead><tr><th>Appareil</th><th>Type</th><th>Métrique</th><th>Valeur</th><th>Unité</th><th>Date</th></tr></thead>
          <tbody>${data.map(d => `
            <tr>
              <td class="mono">${esc(d.deviceId?.substring(0, 16))}</td>
              <td>${esc(d.payloadType || '—')}</td>
              <td>${esc(d.metricName || '—')}</td>
              <td><strong>${esc(d.metricValue ?? '—')}</strong></td>
              <td>${esc(d.unit || '—')}</td>
              <td class="mono">${new Date(d.receivedAt).toLocaleString('fr')}</td>
            </tr>
          `).join('')}</tbody>
        </table>`;
    }
  } catch (err) {
    $('iotDataList').innerHTML = `<p class="muted" style="color:var(--red)">Erreur: ${err.message}</p>`;
  }
  showLoading(false);
}

// ── Renderers ──
function eventCard(e) {
  const action = e.action || '—';
  const isViolation = /DENIED|FAILED|BREACH|UNAUTHORIZED/.test(action);
  const actionClass = isViolation ? 'denied' : /CREATE|REGISTER|PAIR/.test(action) ? 'create' : 'ok';
  const hash = e.hash || '';
  const userSig = e.userSignature ? ' · Signé par l\'utilisateur' : '';
  return `<div class="event-card">
    <div class="event-header">
      <span class="event-action ${actionClass}">${esc(action)}</span>
      <span class="badge ${isViolation ? 'badge-violation' : 'badge-ok'}">${isViolation ? 'VIOLATION' : 'OK'}</span>
    </div>
    <div class="event-meta">
      ${esc(e.entityType || '')} · ${esc(e.entityId?.substring(0, 20) || '')}
      ${e.actorDID ? ' · ' + esc(e.actorDID.substring(0, 24)) : ''}
    </div>
    <div class="event-detail">
      ${new Date(e.createdAt || e.timestamp).toLocaleString()} · Hash: ${hash.substring(0, 12)}${hash.length > 12 ? '...' : ''}
      ${userSig}
    </div>
  </div>`;
}

function logEntry(l) {
  const time = new Date(l.timestamp).toLocaleTimeString('fr');
  const categoryClass = `chip-${l.category}`;
  return `<div class="log-entry">
    <span class="log-time">${time}</span>
    <span class="log-level log-level-${l.level}">${l.level.toUpperCase()}</span>
    <span class="log-category chip ${categoryClass}">${l.category}</span>
    <span class="log-msg">${esc(l.message)}</span>
    ${l.meta ? `<button class="log-meta-toggle" onclick="this.nextElementSibling.style.display=this.nextElementSibling.style.display==='none'?'block':'none'">details</button><div class="log-meta" style="display:none">${esc(JSON.stringify(l.meta, null, 2))}</div>` : ''}
  </div>`;
}

// ── Init ──
(async () => {
  const valid = await checkSession();
  if (valid) showApp();
})();
