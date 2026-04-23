SUPERBACK V1

OBIETTIVO
Plancia centrale separata da FRONT e BACK.
Tutta la logica di controllo passa da Firestore.
Il frontend farmacia non deve leggere backendEnabled.

STATO CONSEGNATO
- login superuser con Firebase Auth
- verifica superuser su Firestore
- creazione tenant
- gestione frontendEnabled
- gestione backendEnabled
- gestione tenantStatus
- gestione subscriptionStatus
- audit minimo
- separazione pubblico/privato:
  - tenants_public
  - tenant_control
  - tenant_access

BOOTSTRAP MINIMO
1. Abilitare Email/Password in Firebase Auth.
2. Creare in Firestore il documento:
   superback_config/main
   con campo:
   adminEmails = ["TUA_EMAIL"]
3. Creare in Firebase Auth il tuo utente superuser con la stessa email.
4. Pubblicare SUPERBACK.
5. Accedere.

CONTRATTO DB V1
1) superback_config/main
{
  adminEmails: ["email@dominio.it"]
}

2) tenants_public/{tenantId}
{
  tenantId: "farmacia_rossi",
  tenantName: "Farmacia Rossi",
  loginEmail: "farmacia.rossi@email.it",
  frontendEnabled: true,
  subscriptionStatus: "trial|active|suspended|expired",
  tenantStatus: "active|blocked",
  createdAt: "ISO_DATE",
  updatedAt: "ISO_DATE"
}

3) tenant_control/{tenantId}
{
  tenantId: "farmacia_rossi",
  backendEnabled: true,
  updatedAt: "ISO_DATE"
}

4) tenant_access/{loginEmail}
{
  loginEmail: "farmacia.rossi@email.it",
  tenantId: "farmacia_rossi",
  frontendEnabled: true,
  tenantStatus: "active|blocked",
  subscriptionStatus: "trial|active|suspended|expired",
  updatedAt: "ISO_DATE"
}

5) superback_audit/{autoId}
{
  actorEmail: "superuser@email.it",
  action: "tenant_created|tenant_frontend_enabled_changed|tenant_backend_enabled_changed|tenant_status_changed|tenant_subscription_changed|tenant_identity_updated",
  tenantId: "farmacia_rossi",
  payload: {...},
  createdAt: "ISO_DATE"
}

NOTE ARCHITETTURALI
- backendEnabled vive solo in tenant_control.
- il frontend farmacia dovra leggere solo tenant_access e i dati applicativi del proprio tenant.
- tenant_access e tenants_public sono i soli documenti da esporre al frontend farmacia.
- tenant_control resta area privata di SUPERBACK + backend farmacia.
- in questa V1 la creazione dell'utente Firebase Auth della farmacia resta manuale da console, con la stessa email registrata in loginEmail.
- scelta voluta per evitare provisioning auth non reversibile lato client.

REGOLE FIRESTORE DA APPLICARE DOPO
- frontend farmacia: deny totale su tenant_control
- superback: accesso pieno ai documenti di controllo
- backend farmacia: read tenant_control solo per il proprio tenant

TEST MANUALE
1. creare superback_config/main con tua email
2. login con il tuo utente Firebase Auth
3. creare una farmacia
4. verificare creazione coerente di:
   - tenants_public/{tenantId}
   - tenant_control/{tenantId}
   - tenant_access/{loginEmail}
   - superback_audit/{autoId}
5. spegnere backendEnabled e verificare che il documento tenant_control venga aggiornato
6. spegnere frontendEnabled e verificare aggiornamento anche di tenant_access
7. cambiare loginEmail e verificare spostamento del documento tenant_access
