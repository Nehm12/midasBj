# MIDAS-Benin

## Qu'est-ce que MIDAS-Benin ?

**MIDAS (Mobile Identity and Data Autonomy System)** est une plateforme numerique
souveraine concue pour le Benin. Elle permet aux citoyens de :

- Creer une identite numerique auto-souveraine liee a leur NPI (Numero
  d'Identification Personnel)
- Signer numeriquement leurs actions avec une cle privee Ed25519 stockee
  uniquement sur leur telephone
- Gerer leurs consentements : qui peut acceder a leurs donnees, pourquoi,
  et pour combien de temps
- Recevoir des credentials verifiables (VC) emis par des autorites comme
  l'ANIP
- Apparer des appareils IoT (ESP32) et recevoir leurs donnees de
  telemetrique de facon securisee
- Consulter la piste d'audit horodatee et chainee cryptographiquement de
  toutes leurs actions

Le systeme repose sur un principe fondamental : **le citoyen est le seul
proprietaire de ses donnees**. Aucune autorite centrale ne peut usurper son
identite, car la cle privee ne quitte jamais son appareil.

---

## Concretement, ca donne quoi pour un citoyen ?

Vous ouvrez MIDAS. Vous voyez :
> **Bonjour Junior. Votre identite est verifiee.**

### 1. Mon identite numerique (Wallet)
Aujourd'hui vous avez : CIN, Passeport, Permis, Carte electorale -- des bouts de papier.
Demain avec MIDAS : vous ouvrez votre Wallet et vous avez tout dedans :
Carte d'identite, Permis de conduire, Diplomes, Attestations, Carte CNSS,
Carte d'assurance... Plus besoin d'envoyer des PDF. Vous presentez un
**justificatif numerique verifiable** -- l'entreprise verifie la signature
en 1 seconde.

### 2. Controle des donnees
Aujourd'hui une entreprise recupere vos donnees sans que vous voyiez
precisement ce qui est partage. Avec MIDAS vous voyez :
> **Orange demande :**
> Nom . Telephone . Adresse
> Valable 30 jours
> **Autoriser ?** Oui / Non

Vous decidez. Pas de fuite invisible.

### 3. Revocation
Vous pouvez dire : **Je retire l'autorisation**. L'entreprise perd
immediatement l'acces. Fini les donnees partagees a vie.

### 4. Historique
Vous consultez :
> Hier -- ANIP -- Consultation identite -- 10h23 -- Autorisee
> CNSS -- Consultation -- 15h11

Tout est trace. Rien n'est cache.

### 5. Signature electronique
Aujourd'hui : vous imprimez, vous signez, vous scannez.
Demain : **Signer** -> empreinte digitale -> signature Ed25519 -> document valide.

### 6. Diplomes
Vous postulez. L'entreprise recoit :
> Diplome + signature de l'universite -> verifie automatiquement.
Plus besoin d'appeler l'universite pour confirmer.

### 7. Sante
Le medecin demande l'acces a votre groupe sanguin et allergies pour 48 heures.
Vous acceptez. Apres 48h, l'acces disparait tout seul.

### 8. IoT (Appareils connectes)
Vous installez un capteur agricole. Le telephone detecte :
Temperature, Humidite, Position GPS.
Toutes les donnees sont chiffrees avant d'etre envoyees.

### 9. APDP (Protection des donnees)
L'APDP peut repondre a des questions comme :
- Qui a consulte mes donnees ?
- Quand ?
- Avec quel consentement ?
- Y a-t-il eu une violation ?
Sans pouvoir modifier l'historique.

---

## Architecture

```
+-----------------------------------------------------+
|                    MOBILE (Flutter)                   |
|  Auth  .  Wallet  .  Consent  .  IoT  .  Audit       |
|  +-----------------------------------------------+  |
|  | Cryptographie Ed25519  .  Stockage securise   |  |
|  +-----------------------------------------------+  |
+-------------------------+---------------------------+
                          | HTTPS / JWT
                          v
+-----------------------------------------------------+
|              BACKEND (Node.js / Fastify)              |
|  +---------+ +----------+ +-------+ +-----------+   |
|  | Auth    | | Wallet   | |Consent| | IoT       |   |
|  | Service | | Service  | |Service| | Service   |   |
|  +----+----+ +----+-----+ +---+---+ +-----+-----+   |
|       |           |           |           |          |
|  +----v-----------v-----------v-----------v------+   |
|  |          MQTT Broker . Middleware JWT         |   |
|  +-------------------+--------------------------+   |
|                      |                              |
|  +-------------------v--------------------------+   |
|  |           Prisma ORM / PostgreSQL             |   |
|  +-------------------+--------------------------+   |
+----------------------+---------------------------+
                       |
           +-----------+-----------+
           v                       v
    +----------+            +----------+
    |PostgreSQL|            | Keycloak |
    |   16     |            |   24     |
    +----------+            +----------+
```

### Stack technique

| Couche          | Technologie                                  |
|-----------------|----------------------------------------------|
| Mobile          | Flutter 3.38, Dart 3.10, Riverpod, GoRouter  |
| Backend         | Node.js 20, Fastify, TypeScript, Prisma 5    |
| Base de donnees | PostgreSQL 16                                |
| IAM / SSO       | Keycloak 24                                  |
| IoT             | MQTT (Aedes broker), ESP32                   |
| Cryptographie   | Ed25519, X25519, ChaCha20-Poly1305           |
| Conteneurs      | Docker, Docker Compose                       |

---

## Structure du projet

```
midasbenin/
+-- backend/                        # Backend Node.js/TypeScript
|   +-- prisma/
|   |   +-- schema.prisma           # Modele de donnees (User, Consent, IoT, Audit...)
|   |   +-- migrations/             # Migrations PostgreSQL
|   +-- src/
|   |   +-- index.ts                # Point d'entree du serveur
|   |   +-- seed.ts                 # Script d'amorcage (donnees de demo)
|   |   +-- config/index.ts         # Configuration (variables d'environnement)
|   |   +-- api/routes/index.ts     # Regroupement de toutes les routes API
|   |   +-- infrastructure/
|   |   |   +-- auth/middleware.ts   # Middleware JWT d'authentification
|   |   |   +-- auth/types.d.ts     # Types TypeScript pour l'auth
|   |   |   +-- crypto/ed25519.ts   # Fonctions de signature Ed25519
|   |   |   +-- db/client.ts        # Client Prisma (base de donnees)
|   |   |   +-- mqtt/broker.ts      # Broker MQTT Aedes
|   |   |   +-- logs/collector.ts   # Systeme de collecte de logs
|   |   |   +-- ws/alerts.ts        # WebSocket alertes temps reel
|   |   +-- modules/
|   |       +-- auth/               # Enrolement, connexion, session
|   |       +-- wallet/             # DID, credentials verifiables
|   |       +-- consent/            # Gestion des consentements
|   |       +-- iot/                # Appareils IoT, telemetrie
|   |       +-- audit/              # Journal d'audit chainee
|   |       +-- admin/              # Console APDP (routes admin)
|   |       +-- processing-register/ # Registre RGPD des traitements
|   +-- web/                        # Console APDP (HTML/CSS/JS)
|   |   +-- index.html              # Interface d'administration
|   |   +-- app.js                  # Logique client
|   |   +-- style.css               # Styles
|   +-- docker-compose.yml          # Services Docker (PostgreSQL, Keycloak)
|   +-- Dockerfile                  # Image Docker du backend
|   +-- .env                        # Variables d'environnement
|   +-- package.json                # Dependances Node.js
|   +-- tsconfig.json               # Configuration TypeScript
|
+-- mobile/                         # Application mobile Flutter
|   +-- lib/
|       +-- main.dart               # Point d'entree
|       +-- app/
|       |   +-- app.dart            # Widget racine MaterialApp
|       |   +-- router.dart         # Configuration GoRouter
|       +-- core/
|       |   +-- crypto/crypto_service.dart   # Ed25519, X25519, ChaCha20
|       |   +-- network/api_client.dart      # Client HTTP (Dio)
|       |   +-- network/mqtt_service.dart    # Client MQTT
|       |   +-- network/backend_config.dart  # Configuration serveur
|       |   +-- storage/storage_service.dart # Stockage securise
|       +-- features/
|           +-- auth/               # Ecran d'enrolement et connexion
|           +-- wallet/             # Portefeuille DID et VCs
|           +-- consent/            # Gestion des consentements
|           +-- iot/                # Appareils IoT
|           +-- audit/              # Journal d'audit
|
+-- README.md                       # Ce fichier
```

---

## Guide d'installation pas a pas

### 1. Pre-requis

Avant de commencer, installez ces logiciels sur votre machine :

| Logiciel        | Version | Utilite                                      |
|-----------------|---------|----------------------------------------------|
| Docker          | >= 24   | Conteneurisation PostgreSQL + Keycloak        |
| Docker Compose  | >= 2.40 | Orchestration des conteneurs                  |
| Node.js         | >= 20   | Execution du backend                          |
| npm             | >= 10   | Gestion des dependances backend               |
| Flutter         | >= 3.38 | Compilation de l'application mobile           |

> Si vous debutez :
> - Node.js : https://nodejs.org (telechargez la version LTS)
> - Docker : https://docs.docker.com/engine/install/
> - Flutter : https://docs.flutter.dev/get-started/install

### 2. Lancer l'infrastructure (Base de donnees + Keycloak)

```bash
# Se placer dans le dossier du projet
cd midasbenin

# Demarrer PostgreSQL et Keycloak avec Docker
docker compose -f backend/docker-compose.yml up -d postgres keycloak
```

> Premier lancement : Docker va telecharger les images
> (PostgreSQL 16 et Keycloak 24). Cela peut prendre 2 a 5 minutes selon
> votre connexion.
>
> Pour verifier que tout est OK :
> ```bash
> docker ps
> ```
> Vous devez voir `midas-postgres` (healthy) et `midas-keycloak` (Up).

### 3. Installer les dependances du backend

```bash
cd backend
npm install
```

### 4. Configurer la base de donnees

```bash
# Creer les tables dans PostgreSQL
npx prisma db push --force-reset
```

> Cette commande cree toutes les tables a partir du fichier
> `prisma/schema.prisma` (User, Consent, IoTDevice, AuditEvent...).

### 5. Ajouter des donnees de demonstration

```bash
# Lance le script seed qui cree :
# - Alice (citoyenne)
# - Bob (citoyen)
# - Un credential verifiable pour Alice
# - Un appareil IoT
npx tsx src/seed.ts
```

> Important : Le seed cree les utilisateurs dans la base de donnees
> mais leurs cles privees sont generees cote serveur et affichees dans
> la console. L'application mobile ne peut PAS se connecter avec les
> utilisateurs du seed (Alice/Bob) car leurs cles privees ne sont pas
> stockees sur le telephone.
>
> **Pour tester l'app**, suivez l'etape 8 : enrolez-vous avec un
> **nouveau NPI** directement depuis l'ecran d'accueil.

### 6. Demarrer le backend

```bash
# Le serveur ecoute sur http://localhost:3000
npm run dev
```

> Testez que tout fonctionne :
> ```bash
> curl http://localhost:3000/api/v1/health
> # Reponse attendue : {"status":"ok","timestamp":"..."}
> ```

### 7. Lancer l'application mobile

```bash
# Dans un autre terminal
cd mobile

# Verifier les appareils disponibles
flutter devices

# Lancer sur Linux Desktop
flutter run -d linux

# OU lancer sur Chrome Web
flutter run -d chrome

# OU lancer sur un telephone Android branche en USB
flutter run -d android
```

> Important pour Android (emulateur) :
> L'application est pre-configuree pour se connecter au backend sur
> `10.0.2.2:3000` (l'adresse de la machine hote depuis l'emulateur).
> Si vous utilisez un vrai telephone ou le web, elle utilise
> `localhost:3000` automatiquement.

### 8. Tester l'application

1. **Ecran d'accueil** : appuyez sur **"S'enroler avec mon NPI"**
2. **Entrez un NOUVEAU NPI** (qui n'existe pas encore en base, par exemple
   `TEST99`). Ne pas utiliser `ALICE` ou `NPIBENIN202400001` -- ces
   comptes seed n'ont pas de cle privee stockee sur votre telephone.
3. **L'application** : genere une paire de cles Ed25519 sur votre appareil,
   stocke la cle privee dans le stockage securise, et envoie la cle
   publique au serveur
4. **Vous etes connecte** : le wallet, les consentements et l'audit sont
   accessibles depuis la barre de navigation en bas
5. **Prochaine connexion** : appuyez sur **"Se connecter"** avec le meme NPI
   -- l'app signe le NPI avec votre cle privee locale et le serveur verifie

---

### 9. Console APDP (Administration)

La console d'administration est accessible sur `/console/`.

**Connexion :**
- Utilisateur : `admin`
- Mot de passe : `midas-admin-2024` (configurable via `ADMIN_PASSWORD`)

**Fonctionnalites :**
- Tableau de bord avec statistiques en temps reel
- Piste d'audit complete (recherche, filtres, export)
- Journal serveur (logs HTTP, auth, IoT, erreurs)
- Gestion des utilisateurs, consentements, donnees IoT
- Verification d'integrite de la chaine d'audit

---

### 10. Commandes utiles -- Base de donnees

```bash
# Lister les bases de donnees PostgreSQL
docker exec midas-postgres psql -U midas -l

# Lister les tables
docker exec midas-postgres psql -U midas -d midasbenin -c "\dt"

# Voir tous les utilisateurs enregistres
docker exec midas-postgres psql -U midas -d midasbenin -c "SELECT npi, did, LEFT(\"publicKey\", 20) as pubkey FROM \"User\";"

# Voir les credentials verifiables
docker exec midas-postgres psql -U midas -d midasbenin -c "SELECT id, type, issuer FROM \"VerifiableCredential\";"

# Voir les consentements
docker exec midas-postgres psql -U midas -d midasbenin -c "SELECT id, purpose, status FROM \"Consent\";"

# Voir les appareils IoT
docker exec midas-postgres psql -U midas -d midasbenin -c "SELECT id, \"deviceId\", status FROM \"IoTDevice\";"

# Connexion interactive a PostgreSQL
docker exec -it midas-postgres psql -U midas -d midasbenin
```

---

## API REST (endpoints principaux)

Toutes les routes sont prefixees par `/api/v1`.

### Authentification

| Methode | Route                | Description                          | Auth |
|---------|----------------------|--------------------------------------|------|
| `GET`   | `/health`            | Etat du serveur                      | Non  |
| `POST`  | `/auth/register`     | Enrolement (NPI + cle publique)      | Non  |
| `POST`  | `/auth/login`        | Connexion (signature NPI)            | Non  |
| `POST`  | `/auth/login-simple` | Connexion simplifiee (NPI seul)      | Non  |
| `POST`  | `/auth/keycloak`     | Connexion via Keycloak OIDC          | Non  |
| `GET`   | `/auth/session`      | Validation du token JWT              | Non  |
| `POST`  | `/auth/rotate-key`   | Rotation de cle publique             | Oui  |
| `GET`   | `/auth/roles`        | Roles de l'utilisateur               | Oui  |

### Portefeuille

| Methode | Route                | Description                          | Auth |
|---------|----------------------|--------------------------------------|------|
| `POST`  | `/wallet/create`     | Creer un portefeuille DID            | Oui  |
| `POST`  | `/wallet/issue-vc`   | Emettre un credential verifiable     | Oui  |
| `GET`   | `/wallet/vcs`        | Liste des credentials                | Oui  |

### Consentements

| Methode | Route                | Description                          | Auth |
|---------|----------------------|--------------------------------------|------|
| `POST`  | `/consent/grant`     | Accorder un consentement             | Oui  |
| `POST`  | `/consent/revoke`    | Revouer un consentement              | Oui  |
| `GET`   | `/consent/history`   | Historique des consentements         | Oui  |

### IoT

| Methode | Route                | Description                          | Auth |
|---------|----------------------|--------------------------------------|------|
| `POST`  | `/iot/pair`          | Apparer un appareil                  | Oui  |
| `GET`   | `/iot/devices`       | Liste des appareils                  | Oui  |
| `GET`   | `/iot/qr-challenge`  | Generer un defi pour appairage QR    | Oui  |
| `POST`  | `/iot/pair-qr`       | Appairage par QR code                | Oui  |

### Audit

| Methode | Route                    | Description                          | Auth |
|---------|--------------------------|--------------------------------------|------|
| `POST`  | `/audit/event`           | Enregistrer un evenement             | Oui  |
| `GET`   | `/audit/trail/:id`       | Piste d'audit d'une entite           | Non  |
| `POST`  | `/audit/verify`          | Verifier la chaine cryptographique   | Non  |
| `GET`   | `/audit/violations`      | Violations detectees                 | Non  |
| `GET`   | `/audit/search`          | Recherche d'evenements               | Non  |
| `GET`   | `/audit/export/:id`      | Export preuve JSON-LD                | Non  |
| `GET`   | `/audit/entity-types`    | Types d'entites suivies              | Non  |

### Administration (console APDP)

| Methode | Route                    | Description                          | Auth |
|---------|--------------------------|--------------------------------------|------|
| `POST`  | `/admin/login`           | Connexion admin                      | Non  |
| `GET`   | `/admin/session`         | Verifier session admin               | Admin|
| `GET`   | `/admin/dashboard`       | Donnees agregees dashboard           | Admin|
| `GET`   | `/admin/logs`            | Journal des evenements serveur       | Admin|
| `GET`   | `/admin/logs/stats`      | Statistiques des logs                | Admin|
| `DELETE`| `/admin/logs`            | Vider le journal                     | Admin|
| `GET`   | `/admin/audit/search`    | Recherche avancee audit              | Admin|
| `GET`   | `/admin/audit/trail/:id` | Piste d'audit complete               | Admin|
| `GET`   | `/admin/audit/violations`| Violations detectees                 | Admin|
| `GET`   | `/admin/users`           | Liste des utilisateurs               | Admin|
| `GET`   | `/admin/consents`        | Liste des consentements              | Admin|
| `GET`   | `/admin/iot-data`        | Donnees IoT                          | Admin|
| `GET`   | `/admin/processing-registers` | Registre RGPD                  | Admin|

---

## Comment fonctionne la securite ?

### Signature Ed25519

1. A l'enrolement, le telephone genere une **paire de cles Ed25519**
2. La **cle publique** est envoyee au serveur et stockee
3. La **cle privee** reste dans le stockage securise du telephone
4. Pour se connecter, le telephone **signe son NPI** avec sa cle privee
5. Le serveur **verifie la signature** avec la cle publique enregistree

```
Telephone                             Serveur
   |                                     |
   |-- enrolement (NPI + pubKey) ------->|  Stocke pubKey
   |                                     |
   |-- connexion (NPI + signature) ----->|  Verifie : ed25519.verify(NPI, signature, pubKey)
   |                                     |
   |<-- JWT (token d'acces) -------------|
```

### Chaine d'audit

Chaque evenement d'audit est lie au precedent par un hash cryptographique,
formant une chaine impossible a modifier sans etre detecte.

---

## Commandes utiles

```bash
# Backend
cd backend
npm run dev          # Demarrer en mode developpement (rechargement automatique)
npm run build        # Compiler le TypeScript
npx tsc --noEmit     # Verifier le typage sans compiler
npx prisma studio    # Interface web pour voir/modifier la base de donnees

# Mobile
cd mobile
flutter analyze      # Verifier le code Dart
flutter run -d chrome  # Lancer dans le navigateur
flutter build apk    # Compiler pour Android

# Console APDP
# Accessible sur http://localhost:3000/console/
# Identifiants : admin / midas-admin-2024
```

---

## Journal de construction -- Phase 0 (Fondations)

Voici les etapes suivies pour construire la Phase 0 du projet MIDAS-Benin,
de zero jusqu'au MVP fonctionnel :

### 1. Initialisation du projet
- Creation du monorepo avec deux dossiers : `backend/` et `mobile/`
- Initialisation du backend : `npm init`, TypeScript, Fastify, Prisma
- Initialisation du mobile : `flutter create`, Riverpod, GoRouter, Dio

### 2. Infrastructure Docker
- Redaction de `docker-compose.yml` avec PostgreSQL 16 et Keycloak 24
- Installation de Docker Compose v2 sur la machine
- Lancement des conteneurs via `docker compose up -d postgres keycloak`
- Verification : `docker ps` -> conteneurs healthy

### 3. Base de donnees (Prisma)
- Definition du schema Prisma : User, IoTDevice, IoTData, Consent, AuditEvent, ProcessingRegister
- Premier `prisma db push` -> erreur FK `IoTData.deviceId` : ajout de `@db.Uuid`
- `prisma db push --force-reset` -> tables creees
- Script `seed.ts` : creation d'Alice (NPIBENIN202400001), Bob, VC de demo, appareil IoT
- Execution : `npx tsx src/seed.ts`

### 4. Backend (Node.js / Fastify / TypeScript)
- Structure modulaire dans `backend/src/modules/` : auth, wallet, consent, iot, audit, processing-register
- Implementation de l'enrolement et connexion avec signature Ed25519 reelle
- Middleware JWT pour proteger les routes sensibles
- Broker MQTT Aedes integre pour l'IoT
- 21 fichiers `.ts` commentes
- Lancement : `nohup npm run dev` sur le port 3000
- Tests API valides avec curl

### 5. Application mobile (Flutter)
- Correction de toutes les erreurs de compilation
- Polissage UI professionnel (Material 3) :
  - `auth_screen.dart` : gradient vert, animations, formulaire NPI
  - `wallet_screen.dart` : carte identite, QR code, skeleton loading
  - `consent_screen.dart` : status chips colores, Wrap data classes
  - `iot_screen.dart` : device cards, scanner QR, time ago
  - `audit_screen.dart` : badge integrite/violation, pull-to-refresh
  - `scaffold_shell.dart` : NavigationBar Material 3
- Auto-detection Web vs Android dans `api_client.dart`
- 18 fichiers `.dart` commentes
- Resultat : `flutter analyze` -> 0 erreurs, 0 warnings

### 6. Console APDP
- Interface d'administration web (`/console/`)
- Authentification admin avec mot de passe
- Dashboard agrege (stats en temps reel)
- Journal serveur (logs HTTP, auth, IoT, systeme)
- Piste d'audit complete avec recherche et filtres
- Pages dediees : utilisateurs, consentements, donnees IoT

### 7. Documentation
- Redaction complete du README.md (ce fichier)
- Commentaires ajoutes a l'ensemble du code backend
- Commentaires ajoutes a l'ensemble du code mobile

### Phases suivantes

#### Phase 1 -- Identite & Auth
- Integration Keycloak (SSO, OIDC, gestion des roles)
- Portefeuille DID avance : resolution DID universelle, rotation de cles
- Credentials multi-emetteurs : ANIP (CIN), CNA (Permis), Universite (Diplomes)
- Chiffrement de bout en bout du wallet avec cle derivee du NPI
- Authentification biometrique (empreinte, reconnaissance faciale)

#### Phase 2 -- Consentement & Partage de donnees
- Moteur BPMN (Workflow) pour les flux de consentement
- Interface granulaire : choisir precisement chaque donnee partagee
- Signature du consentement par l'utilisateur (Ed25519)
- Consentement contextuel : temporaire, permanent, a usage unique
- Portabilite des donnees (export JSON/LD)

#### Phase 3 -- IoT Bridge
- Firmware ESP32 avec attestation materielle (secure boot)
- Appairage par QR code signe + tunnel chiffre
- Collecte et horodatage des donnees telemetriques
- Alertes temps reel via WebSocket/MQTT
- Tableau de bord IoT avec historique et seuils configurables

#### Phase 4 -- Audit & Gouvernance
- Chaine cryptographique complete (hash chain) des evenements
- Signature individuelle de chaque evenement d'audit
- Console APDP : visualisation, recherche, export
- Detection automatique de violations (intrusion, acces non autorise)
- Preuve juridique exportable (PDF horodate + signature)

#### Phase 5 -- Securite, Tests & Conformite
- Tests unitaires et d'integration (Jest, Flutter test)
- Tests de penetration : injection, rejeu, usurpation
- Scan de vulnerabilites (npm audit, Trivy, Snyk)
- Conformite RGPD / LPDB (Loi Protection Donnees Benin)
- Durcissement Docker : images signees, reseau isole, secrets manager

#### Phase 6 -- Deploiement MVP & Documentation
- CI/CD : GitHub Actions (lint, analyse, build, test)
- Deploiement cloud (OVH / AWS) avec HTTPS (Let's Encrypt)
- Documentation technique complete (ADR, diagrammes, API docs)
- Video de demonstration et guide utilisateur
- Mise en production progressive (sandbox -> pilote -> national)

---

Developpe dans le cadre de l'initiative d'identite numerique souveraine
du Benin.
