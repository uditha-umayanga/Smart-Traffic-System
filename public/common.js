// ---------- Shared helpers for all pages ----------
const VIOLATION_NAMES = {
  speeding: 'Over-Speeding',
  red_light: 'Red Light Signal Violation',
  lane_departure: 'Reckless Lane Drift / Road Departure',
  dui: 'Driving Under Influence (DUI)',
  belt: 'No Seatbelt / Protective Helmet'
};
const DEMERIT_LIMIT = 24;

const API_SERVER = window.location.protocol === 'file:' ? 'http://localhost:3000' : '';

// ---------- Auto-fill Session Storage Helpers ----------
const SCAN_STORAGE_KEYS = {
  vehNo: 'traffix_scanned_vehNo',
  licNo: 'traffix_scanned_licNo'
};

function saveScannedData(key, value) {
  if (value && String(value).trim()) {
    sessionStorage.setItem(SCAN_STORAGE_KEYS[key], String(value).trim());
  }
}

function getScannedData(key) {
  return sessionStorage.getItem(SCAN_STORAGE_KEYS[key]) || '';
}

function clearAllScannedData() {
  sessionStorage.removeItem(SCAN_STORAGE_KEYS.vehNo);
  sessionStorage.removeItem(SCAN_STORAGE_KEYS.licNo);
}

// Navigation bar ekata "Clear Data" button eka ibema ekathu karanawa
function injectClearDataButton() {
  const nav = document.querySelector('header nav');
  if (!nav || document.getElementById('navClearDataBtn')) return;

  const logoutBtn = nav.querySelector('a.btn-logout, a[href="index.html"]');
  const clearBtn = document.createElement('button');
  clearBtn.type = 'button';
  clearBtn.id = 'navClearDataBtn';
  clearBtn.className = 'btn-clear-data';
  clearBtn.textContent = 'Clear Data';

  clearBtn.addEventListener('click', () => {
    clearAllScannedData();

    // URL parameters (?vehNo=... / ?licNo=...) thiyenawanam ewa clean karanawa
    if (window.location.search) {
      window.history.replaceState({}, document.title, window.location.pathname);
    }

    // Danata open wela thiyena page eke fill wechcha fields clear karanawa
    const page = window.location.pathname.split('/').pop();
    if (page === 'vehicle-scan.html') {
      const plateInput = document.getElementById('plateInput');
      if (plateInput) plateInput.value = '';
      ['fModel', 'fOwner', 'fRevenue', 'fInsurance', 'fFines', 'fUnpaid'].forEach(id => {
        const el = document.getElementById(id);
        if (el) el.value = '';
      });
      const preview = document.getElementById('preview');
      const placeholder = document.getElementById('camPlaceholder');
      const scanStatus = document.getElementById('scanStatus');
      const vehStatus = document.getElementById('vehStatus');
      const violationLink = document.getElementById('violationLink');
      if (preview) { preview.src = ''; preview.hidden = true; }
      if (placeholder) placeholder.hidden = false;
      if (scanStatus) scanStatus.textContent = '';
      if (vehStatus) vehStatus.textContent = '';
      if (violationLink) violationLink.hidden = true;
    } else if (page === 'driver-search.html') {
      const driverInput = document.getElementById('driverId');
      const result = document.getElementById('result');
      if (driverInput) driverInput.value = '';
      if (result) result.hidden = true;
    } else if (page === 'add-violation.html') {
      ['licNo', 'vehNo', 'violationType', 'notes'].forEach(id => {
        const el = document.getElementById(id);
        if (el) el.value = '';
      });
      const dStatus = document.getElementById('driverStatus');
      const vStatus = document.getElementById('vehicleStatus');
      if (dStatus) dStatus.textContent = '';
      if (vStatus) vStatus.textContent = '';
    }

    alert('Scanned vehicle & driver data cleared.');
  });

  if (logoutBtn) {
    nav.insertBefore(clearBtn, logoutBtn);
  } else {
    nav.appendChild(clearBtn);
  }
}

document.addEventListener('DOMContentLoaded', injectClearDataButton);

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
  const fullUrl = (url.startsWith('/') && API_SERVER) ? (API_SERVER + url) : url;
  const res = await fetch(fullUrl, init);
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
  if (!el || !session || !session.officer) return;
  const d = session.duty;
  const nearbyText = d
    ? (d.nearbyOfficerName ? `${d.nearbyOfficer} (${d.nearbyOfficerName})` : d.nearbyOfficer)
    : 'Not set';

  el.innerHTML = `
    <div>
      <strong>Officer:</strong> ${esc(session.officer.badgeId)} (${esc(session.officer.fullName)}) |
      <strong>Location:</strong> ${esc(d ? d.dutyLocation : 'Not set')} |
      <strong>Nearby Officer:</strong> ${esc(nearbyText)}
    </div>
    <span class="status-pill">● ${d ? 'DUTY SESSION ACTIVE' : 'NO DUTY SESSION'}</span>`;
}

// Makes sure the officer is logged in (and has set a duty location). Redirects otherwise.
async function guardPage({ needDuty = true } = {}) {
  try {
    const session = await api('/api/session');
    if (!session.officer) {
      if (window.location.protocol !== 'file:') location.replace('index.html');
      return null;
    }
    if (needDuty && !session.duty) {
      if (window.location.protocol !== 'file:') location.replace('location-setup.html');
      return null;
    }
    renderDutyBanner(session);
    return session;
  } catch (e) {
    console.warn('Session check skipped:', e.message);
    return null;
  }
}

// Logout links end the server session
document.addEventListener('click', async (e) => {
  const link = e.target.closest('a.btn-logout');
  if (!link) return;
  e.preventDefault();
  clearAllScannedData();
  await api('/api/logout', { method: 'POST' }).catch(() => { });
  location.href = 'index.html';
});