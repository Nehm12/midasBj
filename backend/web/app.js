const API = '/api/v1';

function showLoading(show) {
  document.getElementById('loadingOverlay').classList.toggle('hidden', !show);
}

function $(id) { return document.getElementById(id); }

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

async function api(path, options = {}) {
  const url = `${API}${path}`;
  const res = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...options.headers },
    ...options,
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`${res.status}: ${text}`);
  }
  return res.json();
}

async function loadPage(page) {
  switch(page) {
    case 'dashboard': loadDashboard(); break;
    case 'audit': loadAuditPage(); break;
    case 'violations': loadViolations(); break;
    case 'entities': loadEntityTypes(); break;
  }
}

async function loadDashboard() {
  showLoading(true);
  try {
    const [search, violations, entityTypes] = await Promise.all([
      api('/audit/search?limit=0'),
      api('/audit/violations').catch(() => []),
      api('/audit/entity-types'),
    ]);
    const totalEvents = search.total || 0;
    const totalViolations = violations.length || 0;
    const totalEntities = entityTypes.length || 0;

    $('totalEvents').textContent = totalEvents.toLocaleString();
    $('totalViolations').textContent = totalViolations;
    $('totalEntities').textContent = totalEntities;

    const chainBad = violations.length > 0;
    $('chainStatus').textContent = chainBad ? 'Alteree' : 'Integre';
    $('chainStatus').style.color = chainBad ? 'var(--red)' : 'var(--green)';

    const recent = await api('/audit/search?limit=10');
    const events = recent.events || [];
    if (events.length === 0) {
      $('recentEvents').innerHTML = '<p class="muted">Aucun evenement recent.</p>';
    } else {
      $('recentEvents').innerHTML = events.map(e => eventCard(e)).join('');
    }
  } catch (err) {
    $('recentEvents').innerHTML = `<p class="muted" style="color:var(--red)">Erreur: ${err.message}</p>`;
  }
  showLoading(false);
}

async function loadAuditPage() {
  try {
    const types = await api('/audit/entity-types');
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

    const data = await api(`/audit/search?${params}`);
    const events = data.events || [];
    const total = data.total || 0;

    if (events.length === 0) {
      $('auditResults').innerHTML = `<p class="muted">Aucun resultat (${total} total).</p>`;
    } else {
      $('auditResults').innerHTML = `<p style="margin-bottom:12px;font-size:13px;color:var(--text-muted)">${events.length} evenements affiches sur ${total}</p>` +
        events.map(e => eventCard(e)).join('');
    }
  } catch (err) {
    $('auditResults').innerHTML = `<p class="muted" style="color:var(--red)">Erreur: ${err.message}</p>`;
  }
  showLoading(false);
}

async function loadViolations() {
  showLoading(true);
  try {
    const violations = await api('/audit/violations');
    if (violations.length === 0) {
      $('violationsList').innerHTML = '<p class="muted">Aucune violation detectee. La chaine d\'audit est integre.</p>';
    } else {
      $('violationsList').innerHTML = violations.map(v => `
        <div class="violation-card">
          <div class="violation-action">${esc(v.action)}</div>
          <div class="violation-reason">Raison: <strong>${esc(v.reason)}</strong> — Entite: ${esc(v.entityId || v.entityType)}</div>
          <div style="font-size:11px;color:var(--text-muted);margin-top:4px">
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

async function verifyChain() {
  const entityId = $('verifyEntityId').value.trim();
  if (!entityId) return;
  showLoading(true);
  try {
    const result = await api('/audit/verify', {
      method: 'POST',
      body: JSON.stringify({ entityId }),
    });
    if (result.valid) {
      $('verifyResult').innerHTML = `
        <div class="verify-valid">
          [OK] Chaine valide — ${result.eventCount} evenements verifies
          <div style="font-weight:normal;font-size:12px;margin-top:4px">
            Premier: ${result.firstEvent?.substring(0,8) || 'N/A'} · Dernier: ${result.lastEvent?.substring(0,8) || 'N/A'}
          </div>
        </div>`;
    } else {
      $('verifyResult').innerHTML = `
        <div class="verify-invalid">
          [KO] Chaine corrompue — ${esc(result.reason)}
          <div style="font-weight:normal;font-size:12px;margin-top:4px">
            Evenement defaillant: ${result.brokenAt?.substring(0,8) || 'N/A'} (index ${result.index || '?'})
          </div>
        </div>`;
    }
  } catch (err) {
    $('verifyResult').innerHTML = `<p style="color:var(--red)">Erreur: ${err.message}</p>`;
  }
  showLoading(false);
}

async function exportProof() {
  const entityId = $('exportEntityId').value.trim();
  if (!entityId) return;
  showLoading(true);
  try {
    const proof = await api(`/audit/export/${entityId}`);
    const chainOk = proof.chainValid ? 'valide' : 'corrompue';
    $('exportResult').innerHTML = `
      <p style="font-size:13px;margin-bottom:8px">
        Preuve exportee — ${proof.eventCount} evenements · Chaine ${chainOk}
        <button class="btn btn-outline" style="margin-left:8px" onclick='copyJson(${JSON.stringify(JSON.stringify(proof, null, 2))})'>Copier</button>
      </p>
      <pre class="json">${esc(JSON.stringify(proof, null, 2))}</pre>`;
  } catch (err) {
    $('exportResult').innerHTML = `<p style="color:var(--red)">Erreur: ${err.message}</p>`;
  }
  showLoading(false);
}

async function loadEntityTypes() {
  showLoading(true);
  try {
    const types = await api('/audit/entity-types');
    if (types.length === 0) {
      $('entityTypesList').innerHTML = '<p class="muted">Aucun type d\'entite enregistre.</p>';
    } else {
      $('entityTypesList').innerHTML = types.map(t => `
        <div class="entity-chip">
          <span class="entity-type">${esc(t.type)}</span>
          <span class="entity-count">${t.count} evenement${t.count > 1 ? 's' : ''}</span>
        </div>
      `).join('');
    }
  } catch (err) {
    $('entityTypesList').innerHTML = `<p class="muted" style="color:var(--red)">Erreur: ${err.message}</p>`;
  }
  showLoading(false);
}

function esc(s) {
  if (s == null) return '';
  return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

function copyJson(text) {
  navigator.clipboard.writeText(text).then(() => {
    alert('Copie effectuee.');
  });
}

function eventCard(e) {
  const action = e.action || '—';
  const isViolation = /DENIED|FAILED|BREACH/.test(action);
  const actionClass = isViolation ? 'denied' : /CREATE|REGISTER|PAIR/.test(action) ? 'create' : 'ok';
  const hash = e.hash || '';
  const userSig = e.userSignature ? '· Signe par l\'utilisateur' : '';
  return `<div class="event-card">
    <div class="event-header">
      <span class="event-action ${actionClass}">${esc(action)}</span>
      <span class="badge ${isViolation ? 'badge-violation' : 'badge-ok'}">${isViolation ? 'VIOLATION' : 'OK'}</span>
    </div>
    <div class="event-meta">
      ${esc(e.entityType || '')} · ${esc(e.entityId?.substring(0, 20) || '')}
      ${e.actorDID ? '· ' + esc(e.actorDID.substring(0, 24)) : ''}
    </div>
    <div class="event-detail">
      ${new Date(e.createdAt || e.timestamp).toLocaleString()} · Hash: ${hash.substring(0, 16)}${hash.length > 16 ? '...' : ''}
      ${userSig}
    </div>
  </div>`;
}

loadDashboard();
