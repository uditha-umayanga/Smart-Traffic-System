// ---------- Shared helpers for all pages ----------
const VIOLATION_NAMES = {
  speeding: 'Over-Speeding',
  red_light: 'Red Light Signal Violation',
  lane_departure: 'Reckless Lane Drift / Road Departure',
  dui: 'Driving Under Influence (DUI)',
  belt: 'No Seatbelt / Protective Helmet'
};
const DEMERIT_LIMIT = 24;

function esc(text) {
  const d = document.createElement('div');
  d.textContent = text ?? '';
  return d.innerHTML;
}

async function api(url, options = {}) {
  const init = { method: options.method || 'GET', headers: {} };
  if (options.body !== undefined) {
    init.headers['Content-Type'] = 'application/json';
    init.body = JSON.stringify(options.body);
  }
  const res = await fetch(url, init);
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = new Error(data.error || `Request failed (${res.status})`);
    err.status = res.status;
    throw err;
  }
  return data;
}

function renderDutyBanner(session) {
  const el = document.getElementById('dutyBanner');
  if (!el) return;
  const d = session.duty;
  el.innerHTML = `
    <div>
      <strong>Officer:</strong> ${esc(session.officer.badgeId)} (${esc(session.officer.fullName)}) |
      <strong>Location:</strong> ${esc(d ? d.dutyLocation : 'Not set')} |
      <strong>Nearby Officer:</strong> ${esc(d ? d.nearbyOfficer : 'Not set')}
    </div>
    <span class="status-pill">● ${d ? 'DUTY SESSION ACTIVE' : 'NO DUTY SESSION'}</span>`;
}

// Makes sure the officer is logged in (and has set a duty location). Redirects otherwise.
async function guardPage({ needDuty = true } = {}) {
  const session = await api('/api/session');
  if (!session.officer) { location.replace('index.html'); return null; }
  if (needDuty && !session.duty) { location.replace('location-setup.html'); return null; }
  renderDutyBanner(session);
  return session;
}

// Logout links end the server session
document.addEventListener('click', async (e) => {
  const link = e.target.closest('a.btn-logout');
  if (!link) return;
  e.preventDefault();
  await api('/api/logout', { method: 'POST' }).catch(() => {});
  location.href = 'index.html';
});