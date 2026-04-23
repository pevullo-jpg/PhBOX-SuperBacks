# PhBOX SUPERBACK HTML

SUPERBACK è una plancia centrale **separata** da FRONT e BACK di PhBOX.

## Obiettivo
Governare da un solo punto:
- creazione farmacia
- blocco/attivazione frontend
- blocco/attivazione backend
- stato tenant
- stato abbonamento
- audit minimo

## Architettura
### SUPERBACK
Applicazione statica HTML/CSS/JS pubblicabile direttamente su GitHub Pages.

### Database = unica fonte di verità
- `superback_config/main`
- `tenants_public/{tenantId}`
- `tenant_control/{tenantId}`
- `tenant_access/{email}`
- `superback_audit/{autoId}`

## Invarianti
1. `backendEnabled` vive solo in `tenant_control`
2. il frontend farmacia non deve leggere `tenant_control`
3. SUPERBACK condivide con FRONT/BACK solo il DB
4. nessuna dipendenza diretta FRONT -> BACKEND
5. ogni modifica tenant deve aggiornare in modo coerente i documenti collegati

## Bootstrap minimo
### 1. Firebase Authentication
Attivare provider **Email/Password**.

### 2. Utente admin
Creare manualmente il proprio utente admin in Firebase Authentication.

### 3. Firestore config
Creare il documento:
- collezione: `superback_config`
- documento: `main`

Campo obbligatorio:
- `adminEmails` = array di email abilitate a usare SUPERBACK

Esempio:
```json
{
  "adminEmails": [
    "tua@email.it"
  ]
}
```

## Struttura dati tenant
### `tenants_public/{tenantId}`
Usato da SUPERBACK e, in futuro, dal frontend farmacia.

Campi principali:
- `tenantId`
- `tenantName`
- `pharmacyEmail`
- `frontendEnabled`
- `tenantStatus`
- `subscriptionStatus`
- `notes`
- `createdAt`, `createdBy`, `updatedAt`, `updatedBy`

### `tenant_control/{tenantId}`
Usato da SUPERBACK e backend farmacia.

Campi principali:
- `tenantId`
- `pharmacyEmail`
- `backendEnabled`
- `tenantStatus`
- `subscriptionStatus`
- `notes`
- `createdAt`, `createdBy`, `updatedAt`, `updatedBy`

### `tenant_access/{email}`
Bridge minimo per futuro login frontend farmacia.

Campi principali:
- `tenantId`
- `tenantName`
- `pharmacyEmail`
- `frontendEnabled`
- `tenantStatus`
- `subscriptionStatus`
- `createdAt`, `createdBy`, `updatedAt`, `updatedBy`

### `superback_audit/{autoId}`
Audit minimo delle operazioni critiche.

## Deploy su GitHub Pages
1. Crea un nuovo repository GitHub separato, ad esempio `phbox-superback-html`
2. Carica tutti i file di questa cartella nella root del repo
3. In GitHub vai su **Settings -> Pages**
4. Seleziona **Deploy from a branch**
5. Branch: `main`
6. Folder: `/ (root)`
7. Salva

## Test esatto
1. Login con utente presente in `adminEmails`
2. Creazione farmacia
3. Verifica documenti creati:
   - `tenants_public`
   - `tenant_control`
   - `tenant_access`
   - `superback_audit`
4. Toggle frontend
5. Toggle backend
6. Blocca tutto
7. Attiva tutto
8. Verifica coerenza dei campi nei documenti aggiornati

## Nota importante
Questo progetto **non** crea utenti Firebase Auth farmacia.
Quella parte resta volutamente fuori da questa V1 per evitare logica privilegiata lato client.
