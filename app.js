import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js';
import {
  getAuth,
  signInWithEmailAndPassword,
  signOut,
  onAuthStateChanged,
} from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-auth.js';
import {
  getFirestore,
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  addDoc,
  writeBatch,
  serverTimestamp,
  onSnapshot,
  query,
  orderBy,
  limit,
} from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js';
import { firebaseConfig } from './firebase-config.js';

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

const state = {
  user: null,
  isAdmin: false,
  adminEmails: [],
  tenantsPublic: new Map(),
  tenantControl: new Map(),
  auditItems: [],
  unsubscribers: [],
  search: '',
};

const els = {
  loginView: document.getElementById('login-view'),
  appView: document.getElementById('app-view'),
  loginForm: document.getElementById('login-form'),
  loginEmail: document.getElementById('login-email'),
  loginPassword: document.getElementById('login-password'),
  loginSubmit: document.getElementById('login-submit'),
  loginMessage: document.getElementById('login-message'),
  logoutButton: document.getElementById('logout-button'),
  refreshButton: document.getElementById('refresh-button'),
  currentUserLine: document.getElementById('current-user-line'),
  createTenantButton: document.getElementById('create-tenant-button'),
  tenantSearch: document.getElementById('tenant-search'),
  tenantsBody: document.getElementById('tenants-body'),
  tenantForm: document.getElementById('tenant-form'),
  editorTitle: document.getElementById('editor-title'),
  tenantId: document.getElementById('tenant-id'),
  tenantOriginalEmail: document.getElementById('tenant-original-email'),
  tenantName: document.getElementById('tenant-name'),
  tenantEmail: document.getElementById('tenant-email'),
  tenantSubscription: document.getElementById('tenant-subscription'),
  tenantStatus: document.getElementById('tenant-status'),
  tenantNotes: document.getElementById('tenant-notes'),
  tenantFrontendEnabled: document.getElementById('tenant-frontend-enabled'),
  tenantBackendEnabled: document.getElementById('tenant-backend-enabled'),
  saveTenantButton: document.getElementById('save-tenant-button'),
  resetTenantButton: document.getElementById('reset-tenant-button'),
  auditList: document.getElementById('audit-list'),
  statTotal: document.getElementById('stat-total'),
  statFront: document.getElementById('stat-front'),
  statBack: document.getElementById('stat-back'),
  statBlocked: document.getElementById('stat-blocked'),
  toast: document.getElementById('toast'),
};

bindEvents();
initAuth();

function bindEvents() {
  els.loginForm.addEventListener('submit', handleLoginSubmit);
  els.logoutButton.addEventListener('click', handleLogout);
  els.refreshButton.addEventListener('click', refreshAdminData);
  els.createTenantButton.addEventListener('click', () => resetTenantEditor());
  els.tenantSearch.addEventListener('input', (event) => {
    state.search = event.target.value.trim().toLowerCase();
    renderTenantTable();
  });
  els.tenantForm.addEventListener('submit', handleTenantFormSubmit);
  els.resetTenantButton.addEventListener('click', () => resetTenantEditor());
}

function initAuth() {
  onAuthStateChanged(auth, async (user) => {
    clearSubscriptions();
    state.user = user;
    state.isAdmin = false;
    state.adminEmails = [];
    state.tenantsPublic.clear();
    state.tenantControl.clear();
    state.auditItems = [];

    if (!user) {
      renderLoggedOut();
      return;
    }

    try {
      const adminConfig = await readAdminConfig();
      const userEmail = normalizeEmail(user.email);
      state.adminEmails = adminConfig.adminEmails;
      state.isAdmin = state.adminEmails.includes(userEmail);

      if (!state.isAdmin) {
        await signOut(auth);
        showLoginMessage('Utente autenticato ma non autorizzato in superback_config/main.adminEmails.', 'error');
        return;
      }

      renderLoggedIn();
      subscribeToData();
      showToast('Login superuser riuscito.');
    } catch (error) {
      console.error(error);
      await signOut(auth);
      showLoginMessage(resolveErrorMessage(error), 'error');
    }
  });
}

async function handleLoginSubmit(event) {
  event.preventDefault();
  clearLoginMessage();
  const email = els.loginEmail.value.trim();
  const password = els.loginPassword.value;

  if (!email || !password) {
    showLoginMessage('Inserisci email e password.', 'error');
    return;
  }

  disableLogin(true);
  try {
    await signInWithEmailAndPassword(auth, email, password);
  } catch (error) {
    console.error(error);
    showLoginMessage(resolveErrorMessage(error), 'error');
  } finally {
    disableLogin(false);
  }
}

async function handleLogout() {
  try {
    await signOut(auth);
  } catch (error) {
    console.error(error);
    showToast(resolveErrorMessage(error), true);
  }
}

async function refreshAdminData() {
  if (!state.user || !state.isAdmin) return;
  clearSubscriptions();
  subscribeToData();
  showToast('Snapshot riagganciati.');
}

async function handleTenantFormSubmit(event) {
  event.preventDefault();
  if (!state.user || !state.isAdmin) return;

  const actorEmail = normalizeEmail(state.user.email);
  const tenantId = (els.tenantId.value || '').trim();
  const originalEmail = normalizeEmail(els.tenantOriginalEmail.value || '');
  const tenantName = cleanText(els.tenantName.value);
  const pharmacyEmail = normalizeEmail(els.tenantEmail.value);
  const subscriptionStatus = els.tenantSubscription.value;
  const tenantStatus = els.tenantStatus.value;
  const notes = cleanText(els.tenantNotes.value);
  const frontendEnabled = els.tenantFrontendEnabled.checked;
  const backendEnabled = els.tenantBackendEnabled.checked;

  if (!tenantName) {
    showToast('Nome farmacia obbligatorio.', true);
    return;
  }
  if (!pharmacyEmail) {
    showToast('Email farmacia obbligatoria.', true);
    return;
  }

  const finalTenantId = tenantId || buildTenantId(tenantName);
  const publicRef = doc(db, 'tenants_public', finalTenantId);
  const controlRef = doc(db, 'tenant_control', finalTenantId);
  const newAccessRef = doc(db, 'tenant_access', pharmacyEmail);
  const oldAccessRef = originalEmail && originalEmail !== pharmacyEmail ? doc(db, 'tenant_access', originalEmail) : null;

  const publicPayload = {
    tenantId: finalTenantId,
    tenantName,
    pharmacyEmail,
    frontendEnabled,
    tenantStatus,
    subscriptionStatus,
    notes,
    updatedAt: serverTimestamp(),
    updatedBy: actorEmail,
  };

  const controlPayload = {
    tenantId: finalTenantId,
    pharmacyEmail,
    backendEnabled,
    tenantStatus,
    subscriptionStatus,
    notes,
    updatedAt: serverTimestamp(),
    updatedBy: actorEmail,
  };

  const accessPayload = {
    tenantId: finalTenantId,
    tenantName,
    pharmacyEmail,
    frontendEnabled,
    tenantStatus,
    subscriptionStatus,
    updatedAt: serverTimestamp(),
    updatedBy: actorEmail,
  };

  const isCreate = !tenantId;
  const batch = writeBatch(db);

  if (isCreate) {
    publicPayload.createdAt = serverTimestamp();
    publicPayload.createdBy = actorEmail;
    controlPayload.createdAt = serverTimestamp();
    controlPayload.createdBy = actorEmail;
    accessPayload.createdAt = serverTimestamp();
    accessPayload.createdBy = actorEmail;
    batch.set(publicRef, publicPayload);
    batch.set(controlRef, controlPayload);
    batch.set(newAccessRef, accessPayload);
  } else {
    batch.update(publicRef, publicPayload);
    batch.update(controlRef, controlPayload);
    batch.set(newAccessRef, accessPayload, { merge: true });
    if (oldAccessRef) batch.delete(oldAccessRef);
  }

  try {
    await batch.commit();
    await writeAudit({
      action: isCreate ? 'tenant_create' : 'tenant_update',
      tenantId: finalTenantId,
      tenantName,
      pharmacyEmail,
      payload: {
        frontendEnabled,
        backendEnabled,
        tenantStatus,
        subscriptionStatus,
        emailChanged: !!oldAccessRef,
      },
    });
    resetTenantEditor();
    showToast(isCreate ? 'Farmacia creata.' : 'Farmacia aggiornata.');
  } catch (error) {
    console.error(error);
    showToast(resolveErrorMessage(error), true);
  }
}

async function applyQuickAction(tenantId, action) {
  const merged = getMergedTenants().find((tenant) => tenant.tenantId === tenantId);
  if (!merged || !state.user) return;

  const actorEmail = normalizeEmail(state.user.email);
  const publicRef = doc(db, 'tenants_public', tenantId);
  const controlRef = doc(db, 'tenant_control', tenantId);
  const accessRef = doc(db, 'tenant_access', normalizeEmail(merged.pharmacyEmail));
  const batch = writeBatch(db);

  const publicPatch = { updatedAt: serverTimestamp(), updatedBy: actorEmail };
  const controlPatch = { updatedAt: serverTimestamp(), updatedBy: actorEmail };
  const accessPatch = { updatedAt: serverTimestamp(), updatedBy: actorEmail };
  const auditPayload = {};

  if (action === 'toggle_frontend') {
    const next = !merged.frontendEnabled;
    publicPatch.frontendEnabled = next;
    accessPatch.frontendEnabled = next;
    auditPayload.frontendEnabled = next;
  }

  if (action === 'toggle_backend') {
    const next = !merged.backendEnabled;
    controlPatch.backendEnabled = next;
    auditPayload.backendEnabled = next;
  }

  if (action === 'block_all') {
    publicPatch.frontendEnabled = false;
    publicPatch.tenantStatus = 'blocked';
    controlPatch.backendEnabled = false;
    controlPatch.tenantStatus = 'blocked';
    accessPatch.frontendEnabled = false;
    accessPatch.tenantStatus = 'blocked';
    auditPayload.frontendEnabled = false;
    auditPayload.backendEnabled = false;
    auditPayload.tenantStatus = 'blocked';
  }

  if (action === 'activate_all') {
    publicPatch.frontendEnabled = true;
    publicPatch.tenantStatus = 'active';
    controlPatch.backendEnabled = true;
    controlPatch.tenantStatus = 'active';
    accessPatch.frontendEnabled = true;
    accessPatch.tenantStatus = 'active';
    auditPayload.frontendEnabled = true;
    auditPayload.backendEnabled = true;
    auditPayload.tenantStatus = 'active';
  }

  batch.update(publicRef, publicPatch);
  batch.update(controlRef, controlPatch);
  batch.set(accessRef, accessPatch, { merge: true });

  try {
    await batch.commit();
    await writeAudit({
      action,
      tenantId,
      tenantName: merged.tenantName,
      pharmacyEmail: merged.pharmacyEmail,
      payload: auditPayload,
    });
    showToast('Operazione completata.');
  } catch (error) {
    console.error(error);
    showToast(resolveErrorMessage(error), true);
  }
}

function subscribeToData() {
  const publicQuery = query(collection(db, 'tenants_public'), orderBy('updatedAt', 'desc'));
  const controlQuery = query(collection(db, 'tenant_control'), orderBy('updatedAt', 'desc'));
  const auditQuery = query(collection(db, 'superback_audit'), orderBy('createdAt', 'desc'), limit(20));

  state.unsubscribers.push(onSnapshot(publicQuery, (snapshot) => {
    state.tenantsPublic = new Map(snapshot.docs.map((item) => [item.id, item.data()]));
    renderAll();
  }, handleSnapshotError));

  state.unsubscribers.push(onSnapshot(controlQuery, (snapshot) => {
    state.tenantControl = new Map(snapshot.docs.map((item) => [item.id, item.data()]));
    renderAll();
  }, handleSnapshotError));

  state.unsubscribers.push(onSnapshot(auditQuery, (snapshot) => {
    state.auditItems = snapshot.docs.map((item) => ({ id: item.id, ...item.data() }));
    renderAudit();
  }, handleSnapshotError));
}

function handleSnapshotError(error) {
  console.error(error);
  showToast(resolveErrorMessage(error), true);
}

function clearSubscriptions() {
  for (const unsubscribe of state.unsubscribers) {
    try { unsubscribe(); } catch (_) { /* noop */ }
  }
  state.unsubscribers = [];
}

function renderAll() {
  renderStats();
  renderTenantTable();
}

function renderLoggedOut() {
  els.loginForm.reset();
  els.currentUserLine.textContent = '—';
  els.loginView.classList.remove('hidden');
  els.appView.classList.add('hidden');
  resetTenantEditor();
  clearLoginMessage();
}

function renderLoggedIn() {
  els.currentUserLine.textContent = `Connesso come ${state.user.email}`;
  els.loginView.classList.add('hidden');
  els.appView.classList.remove('hidden');
}

function renderStats() {
  const tenants = getMergedTenants();
  els.statTotal.textContent = String(tenants.length);
  els.statFront.textContent = String(tenants.filter((item) => item.frontendEnabled).length);
  els.statBack.textContent = String(tenants.filter((item) => item.backendEnabled).length);
  els.statBlocked.textContent = String(tenants.filter((item) => item.tenantStatus === 'blocked').length);
}

function renderTenantTable() {
  const tenants = getMergedTenants().filter(matchesSearch);
  if (!tenants.length) {
    els.tenantsBody.innerHTML = '<tr><td colspan="9" class="wrap muted">Nessuna farmacia trovata.</td></tr>';
    return;
  }

  els.tenantsBody.innerHTML = tenants.map((tenant) => {
    const updatedAt = formatDate(tenant.updatedAt);
    const frontTagClass = tenant.frontendEnabled ? 'front-on' : 'front-off';
    const backTagClass = tenant.backendEnabled ? 'back-on' : 'back-off';
    const tenantStatusClass = tenant.tenantStatus === 'blocked' ? 'blocked' : 'active';
    const subscriptionClass = `subscription-${tenant.subscriptionStatus || 'trial'}`;
    return `
      <tr>
        <td class="wrap"><strong>${escapeHtml(tenant.tenantName || '—')}</strong></td>
        <td>${escapeHtml(tenant.pharmacyEmail || '—')}</td>
        <td>${escapeHtml(tenant.tenantId)}</td>
        <td><span class="tag ${frontTagClass}">${tenant.frontendEnabled ? 'ON' : 'OFF'}</span></td>
        <td><span class="tag ${backTagClass}">${tenant.backendEnabled ? 'ON' : 'OFF'}</span></td>
        <td><span class="tag ${tenantStatusClass}">${escapeHtml(tenant.tenantStatus || 'active')}</span></td>
        <td><span class="tag ${subscriptionClass}">${escapeHtml(tenant.subscriptionStatus || 'trial')}</span></td>
        <td>${escapeHtml(updatedAt)}</td>
        <td>
          <div class="row-actions">
            <button class="inline-btn secondary" data-action="edit" data-tenant-id="${escapeHtmlAttr(tenant.tenantId)}">Modifica</button>
            <button class="inline-btn secondary" data-action="toggle_frontend" data-tenant-id="${escapeHtmlAttr(tenant.tenantId)}">Front ${tenant.frontendEnabled ? 'OFF' : 'ON'}</button>
            <button class="inline-btn secondary" data-action="toggle_backend" data-tenant-id="${escapeHtmlAttr(tenant.tenantId)}">Back ${tenant.backendEnabled ? 'OFF' : 'ON'}</button>
            <button class="inline-btn ${tenant.tenantStatus === 'blocked' ? 'primary' : 'danger'}" data-action="${tenant.tenantStatus === 'blocked' ? 'activate_all' : 'block_all'}" data-tenant-id="${escapeHtmlAttr(tenant.tenantId)}">${tenant.tenantStatus === 'blocked' ? 'Attiva tutto' : 'Blocca tutto'}</button>
          </div>
        </td>
      </tr>
    `;
  }).join('');

  els.tenantsBody.querySelectorAll('button[data-action]').forEach((button) => {
    button.addEventListener('click', () => {
      const tenantId = button.dataset.tenantId;
      const action = button.dataset.action;
      if (action === 'edit') {
        loadTenantIntoEditor(tenantId);
        return;
      }
      applyQuickAction(tenantId, action);
    });
  });
}

function renderAudit() {
  if (!state.auditItems.length) {
    els.auditList.innerHTML = '<div class="audit-item"><strong>Nessun audit.</strong><p>Le azioni critiche appariranno qui.</p></div>';
    return;
  }

  els.auditList.innerHTML = state.auditItems.map((item) => {
    return `
      <article class="audit-item">
        <strong>${escapeHtml(item.action || 'audit')}</strong>
        <div class="muted">${escapeHtml(item.actorEmail || '—')} · ${escapeHtml(formatDate(item.createdAt))}</div>
        <p>Tenant: ${escapeHtml(item.tenantName || item.tenantId || '—')}</p>
        <p>Payload: ${escapeHtml(JSON.stringify(item.payload || {}))}</p>
      </article>
    `;
  }).join('');
}

function loadTenantIntoEditor(tenantId) {
  const tenant = getMergedTenants().find((item) => item.tenantId === tenantId);
  if (!tenant) return;

  els.editorTitle.textContent = 'Modifica farmacia';
  els.tenantId.value = tenant.tenantId;
  els.tenantOriginalEmail.value = tenant.pharmacyEmail || '';
  els.tenantName.value = tenant.tenantName || '';
  els.tenantEmail.value = tenant.pharmacyEmail || '';
  els.tenantSubscription.value = tenant.subscriptionStatus || 'trial';
  els.tenantStatus.value = tenant.tenantStatus || 'active';
  els.tenantNotes.value = tenant.notes || '';
  els.tenantFrontendEnabled.checked = !!tenant.frontendEnabled;
  els.tenantBackendEnabled.checked = !!tenant.backendEnabled;
  els.tenantName.focus();
}

function resetTenantEditor() {
  els.editorTitle.textContent = 'Nuova farmacia';
  els.tenantForm.reset();
  els.tenantId.value = '';
  els.tenantOriginalEmail.value = '';
  els.tenantSubscription.value = 'trial';
  els.tenantStatus.value = 'active';
  els.tenantFrontendEnabled.checked = true;
  els.tenantBackendEnabled.checked = true;
}

async function readAdminConfig() {
  const configRef = doc(db, 'superback_config', 'main');
  const configSnap = await getDoc(configRef);
  if (!configSnap.exists()) {
    throw new Error('Manca Firestore: superback_config/main');
  }

  const data = configSnap.data() || {};
  const adminEmails = Array.isArray(data.adminEmails)
    ? data.adminEmails.map(normalizeEmail).filter(Boolean)
    : [];

  if (!adminEmails.length) {
    throw new Error('superback_config/main.adminEmails è vuoto o non è un array.');
  }

  return { adminEmails };
}

async function writeAudit({ action, tenantId, tenantName, pharmacyEmail, payload }) {
  if (!state.user) return;
  await addDoc(collection(db, 'superback_audit'), {
    action,
    tenantId: tenantId || '',
    tenantName: tenantName || '',
    pharmacyEmail: pharmacyEmail || '',
    actorEmail: normalizeEmail(state.user.email),
    payload: payload || {},
    createdAt: serverTimestamp(),
  });
}

function getMergedTenants() {
  const ids = new Set([
    ...state.tenantsPublic.keys(),
    ...state.tenantControl.keys(),
  ]);

  return Array.from(ids).map((tenantId) => {
    const pub = state.tenantsPublic.get(tenantId) || {};
    const ctrl = state.tenantControl.get(tenantId) || {};
    return {
      tenantId,
      tenantName: pub.tenantName || ctrl.tenantName || '',
      pharmacyEmail: pub.pharmacyEmail || ctrl.pharmacyEmail || '',
      frontendEnabled: pub.frontendEnabled ?? false,
      backendEnabled: ctrl.backendEnabled ?? false,
      tenantStatus: pub.tenantStatus || ctrl.tenantStatus || 'active',
      subscriptionStatus: pub.subscriptionStatus || ctrl.subscriptionStatus || 'trial',
      notes: pub.notes || ctrl.notes || '',
      updatedAt: pub.updatedAt || ctrl.updatedAt || null,
    };
  }).sort((a, b) => compareTimestampsDesc(a.updatedAt, b.updatedAt));
}

function matchesSearch(item) {
  if (!state.search) return true;
  const haystack = [item.tenantName, item.pharmacyEmail, item.tenantId]
    .join(' ')
    .toLowerCase();
  return haystack.includes(state.search);
}

function buildTenantId(name) {
  const base = (name || 'farmacia')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 28) || 'farmacia';
  const suffix = Math.random().toString(36).slice(2, 7);
  return `${base}-${suffix}`;
}

function normalizeEmail(value) {
  return String(value || '').trim().toLowerCase();
}

function cleanText(value) {
  return String(value || '').trim();
}

function compareTimestampsDesc(a, b) {
  const ta = extractMillis(a);
  const tb = extractMillis(b);
  return tb - ta;
}

function extractMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === 'function') return value.toMillis();
  if (value.seconds) return value.seconds * 1000;
  return 0;
}

function formatDate(value) {
  const millis = extractMillis(value);
  if (!millis) return '—';
  return new Date(millis).toLocaleString('it-IT');
}

function disableLogin(disabled) {
  els.loginSubmit.disabled = disabled;
  els.loginEmail.disabled = disabled;
  els.loginPassword.disabled = disabled;
}

function showLoginMessage(message, type = 'error') {
  els.loginMessage.textContent = message;
  els.loginMessage.className = `message ${type}`;
}

function clearLoginMessage() {
  els.loginMessage.textContent = '';
  els.loginMessage.className = 'message hidden';
}

let toastTimer = null;
function showToast(message, isError = false) {
  els.toast.textContent = message;
  els.toast.style.borderLeftColor = isError ? 'var(--red)' : 'var(--blue)';
  els.toast.classList.remove('hidden');
  window.clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => {
    els.toast.classList.add('hidden');
  }, 3200);
}

function resolveErrorMessage(error) {
  const code = error?.code || '';
  if (code === 'auth/invalid-credential' || code === 'auth/wrong-password' || code === 'auth/user-not-found') {
    return 'Credenziali non valide.';
  }
  if (code === 'auth/invalid-email') {
    return 'Email non valida.';
  }
  if (code === 'auth/too-many-requests') {
    return 'Troppi tentativi. Riprova più tardi.';
  }
  if (code === 'auth/network-request-failed') {
    return 'Errore di rete.';
  }
  if (code === 'auth/operation-not-allowed') {
    return 'Provider Email/Password non attivo in Firebase Authentication.';
  }
  if (code === 'permission-denied') {
    return 'Permessi Firestore insufficienti. Controlla le rules.';
  }
  return error?.message || 'Errore sconosciuto.';
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function escapeHtmlAttr(value) {
  return escapeHtml(value);
}
