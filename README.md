# MIDAS-Bénin

## 🇧🇯 Qu'est-ce que MIDAS-Bénin ?

**MIDAS (Mobile Identity and Data Autonomy System)** est une plateforme numérique
souveraine conçue pour le Bénin. Elle permet aux citoyens de :

- **Créer une identité numérique auto-souveraine** liée à leur NPI (Numéro
  d'Identification Personnel)
- **Signer numériquement** leurs actions avec une clé privée Ed25519 stockée
  uniquement sur leur téléphone
- **Gérer leurs consentements** : qui peut accéder à leurs données, pourquoi,
  et pour combien de temps
- **Recevoir des credentials vérifiables** (VC) émis par des autorités comme
  l'ANIP
- **Appairer des appareils IoT** (ESP32) et recevoir leurs données de
  télémétrie de façon sécurisée
- **Consulter la piste d'audit** horodatée et chaînée cryptographiquement de
  toutes leurs actions

Le système repose sur un principe fondamental : **le citoyen est le seul
propriétaire de ses données**. Aucune autorité centrale ne peut usurper son
identité, car la clé privée ne quitte jamais son appareil.

---

## 🇧🇯 Concrètement, ça donne quoi pour un citoyen ?

Vous ouvrez MIDAS. Vous voyez :
> **Bonjour Junior. Votre identité est vérifiée.**

### 1. Mon identité numérique (Wallet)
Aujourd'hui vous avez : CIN, Passeport, Permis, Carte électorale — des bouts de papier.
Demain avec MIDAS : vous ouvrez votre Wallet et vous avez tout dedans :
Carte d'identité, Permis de conduire, Diplômes, Attestations, Carte CNSS,
Carte d'assurance... Plus besoin d'envoyer des PDF. Vous présentez un
**justificatif numérique vérifiable** — l'entreprise vérifie la signature
en 1 seconde.

### 2. Contrôle des données
Aujourd'hui une entreprise récupère vos données sans que vous voyiez
précisément ce qui est partagé. Avec MIDAS vous voyez :
> **Orange demande :**
> Nom · Téléphone · Adresse
> Valable 30 jours
> **Autoriser ?** Oui / Non

Vous décidez. Pas de fuite invisible.

### 3. Révocation
Vous pouvez dire : **Je retire l'autorisation**. L'entreprise perd
immédiatement l'accès. Fini les données partagées à vie.

### 4. Historique
Vous consultez :
> Hier — ANIP — Consultation identité — 10h23 — Autorisée
> CNSS — Consultation — 15h11

Tout est tracé. Rien n'est caché.

### 5. Signature électronique
Aujourd'hui : vous imprimez, vous signez, vous scannez.
Demain : **Signer** → empreinte digitale → signature Ed25519 → document valide.

### 6. Diplômes
Vous postulez. L'entreprise reçoit :
> Diplôme + signature de l'université → vérifié automatiquement.
Plus besoin d'appeler l'université pour confirmer.

### 7. Santé
Le médecin demande l'accès à votre groupe sanguin et allergies pour 48 heures.
Vous acceptez. Après 48h, l'accès disparaît tout seul.

### 8. IoT (Appareils connectés)
Vous installez un capteur agricole. Le téléphone détecte :
Température, Humidité, Position GPS.
Toutes les données sont chiffrées avant d'être envoyées.

### 9. APDP (Protection des données)
L'APDP peut répondre à des questions comme :
- Qui a consulté mes données ?
- Quand ?
- Avec quel consentement ?
- Y a-t-il eu une violation ?
Sans pouvoir modifier l'historique.

---

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────┐
│                    MOBILE (Flutter)                  │
│  Auth  ·  Wallet  ·  Consent  ·  IoT  ·  Audit      │
│  ┌───────────────────────────────────────────────┐  │
│  │ Cryptographie Ed25519  ·  Stockage sécurisé   │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────┬───────────────────────────────┘
                      │ HTTPS / JWT
                      ▼
┌─────────────────────────────────────────────────────┐
│              BACKEND (Node.js / Fastify)             │
│  ┌─────────┐ ┌──────────┐ ┌───────┐ ┌───────────┐  │
│  │ Auth    │ │ Wallet   │ │Consent│ │ IoT       │  │
│  │ Service │ │ Service  │ │Service│ │ Service   │  │
│  └────┬────┘ └────┬─────┘ └───┬───┘ └─────┬─────┘  │
│       │           │           │           │         │
│  ┌────▼───────────▼───────────▼───────────▼─────┐  │
│  │          MQTT Broker · Middleware JWT         │  │
│  └───────────────────┬──────────────────────────┘  │
│                      │                             │
│  ┌───────────────────▼──────────────────────────┐  │
│  │           Prisma ORM / PostgreSQL             │  │
│  └───────────────────┬──────────────────────────┘  │
└──────────────────────┼────────────────────────────┘
                       │
          ┌────────────┴────────────┐
          ▼                         ▼
   ┌──────────┐            ┌──────────┐
   │PostgreSQL│            │ Keycloak │
   │   16     │            │   24     │
   └──────────┘            └──────────┘
```

### Stack technique

| Couche | Technologie |
|--------|-------------|
| **Mobile** | Flutter 3.38, Dart 3.10, Riverpod, GoRouter, Dio |
| **Backend** | Node.js 20, Fastify, TypeScript, Prisma 5 |
| **Base de données** | PostgreSQL 16 |
| **IAM / SSO** | Keycloak 24 |
| **IoT** | MQTT (Aedes broker), ESP32 |
| **Cryptographie** | Ed25519, X25519, ChaCha20-Poly1305 |
| **Conteneurs** | Docker, Docker Compose |

---

## 📁 Structure du projet

```
midasbenin/
├── backend/                        # Backend Node.js/TypeScript
│   ├── prisma/
│   │   ├── schema.prisma           # Modèle de données (User, Consent, IoT, Audit...)
│   │   └── migrations/             # Migrations PostgreSQL
│   ├── src/
│   │   ├── index.ts                # Point d'entrée du serveur
│   │   ├── seed.ts                 # Script d'amorçage (données de démo)
│   │   ├── config/index.ts         # Configuration (variables d'environnement)
│   │   ├── api/routes/index.ts     # Regroupement de toutes les routes API
│   │   ├── infrastructure/
│   │   │   ├── auth/middleware.ts   # Middleware JWT d'authentification
│   │   │   ├── auth/types.d.ts     # Types TypeScript pour l'auth
│   │   │   ├── crypto/ed25519.ts   # Fonctions de signature Ed25519
│   │   │   ├── db/client.ts        # Client Prisma (base de données)
│   │   │   └── mqtt/broker.ts      # Broker MQTT Aedes
│   │   └── modules/
│   │       ├── auth/               # Enrôlement, connexion, session
│   │       ├── wallet/             # DID, credentials vérifiables
│   │       ├── consent/            # Gestion des consentements
│   │       ├── iot/                # Appareils IoT, télémétrie
│   │       ├── audit/              # Journal d'audit chaîné
│   │       └── processing-register/ # Registre RGPD des traitements
│   ├── docker-compose.yml          # Services Docker (PostgreSQL, Keycloak)
│   ├── Dockerfile                  # Image Docker du backend
│   ├── .env                        # Variables d'environnement
│   ├── package.json                # Dépendances Node.js
│   └── tsconfig.json               # Configuration TypeScript
│
├── mobile/                         # Application mobile Flutter
│   └── lib/
│       ├── main.dart               # Point d'entrée
│       ├── app/
│       │   ├── app.dart            # Widget racine MaterialApp
│       │   └── router.dart         # Configuration GoRouter
│       ├── core/
│       │   ├── crypto/crypto_service.dart   # Ed25519, X25519, ChaCha20
│       │   ├── network/api_client.dart      # Client HTTP (Dio)
│       │   ├── network/mqtt_service.dart    # Client MQTT
│       │   └── storage/storage_service.dart # Stockage sécurisé
│       ├── features/
│       │   ├── auth/               # Écran d'enrôlement et connexion
│       │   ├── wallet/             # Portefeuille DID et VCs
│       │   ├── consent/            # Gestion des consentements
│       │   ├── iot/                # Appareils IoT
│       │   └── audit/              # Journal d'audit
│       └── shared/widgets/         # Widgets réutilisables
│
└── README.md                       # Ce fichier
```

---

## 🚀 Guide d'installation pas à pas

### 1. Prérequis

Avant de commencer, installez ces logiciels sur votre machine :

| Logiciel | Version | Utilité |
|----------|---------|---------|
| **Docker** | ≥ 24 | Conteneurisation PostgreSQL + Keycloak |
| **Docker Compose** | ≥ 2.40 | Orchestration des conteneurs |
| **Node.js** | ≥ 20 | Exécution du backend |
| **npm** | ≥ 10 | Gestion des dépendances backend |
| **Flutter** | ≥ 3.38 | Compilation de l'application mobile |

> 💡 **Si vous débutez :** 
> - Node.js : https://nodejs.org (téléchargez la version LTS)
> - Docker : https://docs.docker.com/engine/install/
> - Flutter : https://docs.flutter.dev/get-started/install

### 2. Lancer l'infrastructure (Base de données + Keycloak)

```bash
# Se placer dans le dossier du projet
cd midasbenin

# Démarrer PostgreSQL et Keycloak avec Docker
docker compose -f backend/docker-compose.yml up -d postgres keycloak
```

> ⏳ **Premier lancement :** Docker va télécharger les images
> (PostgreSQL 16 et Keycloak 24). Cela peut prendre 2 à 5 minutes selon
> votre connexion.
>
> Pour vérifier que tout est OK :
> ```bash
> docker ps
> ```
> Vous devez voir `midas-postgres` (healthy) et `midas-keycloak` (Up).

### 3. Installer les dépendances du backend

```bash
cd backend
npm install
```

### 4. Configurer la base de données

```bash
# Créer les tables dans PostgreSQL
npx prisma db push --force-reset
```

> Cette commande crée toutes les tables à partir du fichier
> `prisma/schema.prisma` (User, Consent, IoTDevice, AuditEvent...).

### 5. Ajouter des données de démonstration

```bash
# Lance le script seed qui crée :
# - Alice (citoyenne)
# - Bob (citoyen)
# - Un credential vérifiable pour Alice
# - Un appareil IoT
npx tsx src/seed.ts
```

> ⚠️ **Important :** Le seed crée les utilisateurs dans la base de données
> mais leurs **clés privées** sont générées côté serveur et affichées dans
> la console. L'application mobile ne peut PAS se connecter avec les
> utilisateurs du seed (Alice/Bob) car leurs clés privées ne sont pas
> stockées sur le téléphone.
>
> **Pour tester l'app**, suivez l'étape 8 : enrôlez-vous avec un
> **nouveau NPI** directement depuis l'écran d'accueil.

---

> 💡 **Si vous débutez :** 
> - Node.js : https://nodejs.org (téléchargez la version LTS)
> - Docker : https://docs.docker.com/engine/install/
> - Flutter : https://docs.flutter.dev/get-started/install

### 2. Lancer l'infrastructure (Base de données + Keycloak)

```bash
# Se placer dans le dossier du projet
cd midasbenin

# Démarrer PostgreSQL et Keycloak avec Docker
docker compose -f backend/docker-compose.yml up -d postgres keycloak
```

> ⏳ **Premier lancement :** Docker va télécharger les images
> (PostgreSQL 16 et Keycloak 24). Cela peut prendre 2 à 5 minutes selon
> votre connexion.
>
> Pour vérifier que tout est OK :
> ```bash
> docker ps
> ```
> Vous devez voir `midas-postgres` (healthy) et `midas-keycloak` (Up).

### 3. Installer les dépendances du backend

```bash
cd backend
npm install
```

### 4. Configurer la base de données

```bash
# Créer les tables dans PostgreSQL
npx prisma db push --force-reset
```

> Cette commande crée toutes les tables à partir du fichier
> `prisma/schema.prisma` (User, Consent, IoTDevice, AuditEvent...).

### 5. Ajouter des données de démonstration

```bash
# Lance le script seed qui crée :
# - Alice (citoyenne)
# - Bob (citoyen)
# - Un credential vérifiable pour Alice
# - Un appareil IoT
npx tsx src/seed.ts
```

### 6. Démarrer le backend

```bash
# Le serveur écoute sur http://localhost:3000
npm run dev
```

> ✅ **Testez que tout fonctionne :**
> ```bash
> curl http://localhost:3000/api/v1/health
> # Réponse attendue : {"status":"ok","timestamp":"..."}
> ```

### 7. Lancer l'application mobile

```bash
# Dans un autre terminal
cd mobile

# Vérifier les appareils disponibles
flutter devices

# Lancer sur Linux Desktop
flutter run -d linux

# OU lancer sur Chrome Web
flutter run -d chrome

# OU lancer sur un téléphone Android branché en USB
flutter run -d android
```

> 🌐 **Important pour Android (émulateur) :**
> L'application est pré-configurée pour se connecter au backend sur
> `10.0.2.2:3000` (l'adresse de la machine hôte depuis l'émulateur).
> Si vous utilisez un vrai téléphone ou le web, elle utilise
> `localhost:3000` automatiquement.

### 8. Tester l'application

1. **Écran d'accueil** : appuyez sur **"S'enrôler avec mon NPI"**
2. **Entrez un NOUVEAU NPI** (qui n'existe pas encore en base, par exemple
   `TEST99`). **Ne pas utiliser `ALICE` ou `NPIBENIN202400001`** — ces
   comptes seed n'ont pas de clé privée stockée sur votre téléphone.
3. **L'application** : génère une paire de clés Ed25519 sur votre appareil,
   stocke la clé privée dans le stockage sécurisé, et envoie la clé
   publique au serveur
4. ✅ **Vous êtes connecté** : le wallet, les consentements et l'audit sont
   accessibles depuis la barre de navigation en bas
5. **Prochaine connexion** : appuyez sur **"Se connecter"** avec le même NPI
   — l'app signe le NPI avec votre clé privée locale et le serveur vérifie

---

### 9. Commandes utiles — Base de données

```bash
# Lister les bases de données PostgreSQL
docker exec midas-postgres psql -U midas -l

# Lister les tables
docker exec midas-postgres psql -U midas -d midasbenin -c "\dt"

# Voir tous les utilisateurs enregistrés
docker exec midas-postgres psql -U midas -d midasbenin -c "SELECT npi, did, LEFT(\"publicKey\", 20) as pubkey FROM \"User\";"

# Voir les credentials vérifiables
docker exec midas-postgres psql -U midas -d midasbenin -c "SELECT id, type, issuer FROM \"VerifiableCredential\";"

# Voir les consentements
docker exec midas-postgres psql -U midas -d midasbenin -c "SELECT id, purpose, status FROM \"Consent\";"

# Voir les appareils IoT
docker exec midas-postgres psql -U midas -d midasbenin -c "SELECT id, \"deviceId\", status FROM \"IoTDevice\";"

# Connexion interactive à PostgreSQL
docker exec -it midas-postgres psql -U midas -d midasbenin

---

## 📡 API REST (endpoints principaux)

Toutes les routes sont préfixées par `/api/v1`.

| Méthode | Route | Description | Auth |
|---------|-------|-------------|------|
| `GET` | `/health` | État du serveur | ❌ |
| `POST` | `/auth/register` | Enrôlement (NPI + clé publique) | ❌ |
| `POST` | `/auth/login` | Connexion (signature NPI) | ❌ |
| `GET` | `/auth/session` | Validation du token JWT | ❌ |
| `POST` | `/wallet/create` | Créer un portefeuille DID | ✅ |
| `POST` | `/wallet/issue-vc` | Émettre un credential vérifiable | ✅ |
| `GET` | `/wallet/vcs` | Liste des credentials | ✅ |
| `POST` | `/consent/grant` | Accorder un consentement | ✅ |
| `POST` | `/consent/revoke` | Révoquer un consentement | ✅ |
| `GET` | `/consent/history` | Historique des consentements | ✅ |
| `POST` | `/iot/pair` | Appairer un appareil | ✅ |
| `GET` | `/iot/devices` | Liste des appareils | ✅ |
| `GET` | `/audit/trail/:id` | Piste d'audit d'une entité | ❌ |
| `POST` | `/audit/verify` | Vérifier la chaîne cryptographique | ❌ |
| `GET` | `/audit/violations` | Violations détectées | ❌ |

---

## 🔐 Comment fonctionne la sécurité ?

### Signature Ed25519

1. À l'enrôlement, le téléphone génère une **paire de clés Ed25519**
2. La **clé publique** est envoyée au serveur et stockée
3. La **clé privée** reste dans le stockage sécurisé du téléphone
4. Pour se connecter, le téléphone **signe son NPI** avec sa clé privée
5. Le serveur **vérifie la signature** avec la clé publique enregistrée

```
Téléphone                            Serveur
   │                                    │
   │── enrôlement (NPI + pubKey) ──────>│  Stocke pubKey
   │                                    │
   │── connexion (NPI + signature) ────>│  Vérifie : ed25519.verify(NPI, signature, pubKey)
   │                                    │
   │<── JWT (token d'accès) ────────────│
```

### Chaîne d'audit

Chaque événement d'audit est lié au précédent par un hash cryptographique,
formant une chaîne impossible à modifier sans être détecté.

---

## 🛠 Commandes utiles

```bash
# Backend
cd backend
npm run dev          # Démarrer en mode développement (rechargement automatique)
npm run build        # Compiler le TypeScript
npx tsc --noEmit     # Vérifier le typage sans compiler
npx prisma studio    # Interface web pour voir/modifier la base de données

# Mobile
cd mobile
flutter analyze     # Vérifier le code Dart
flutter run -d chrome  # Lancer dans le navigateur
flutter build apk   # Compiler pour Android
```

---

## 📜 Journal de construction — Phase 0 (Fondations)

Voici les étapes suivies pour construire la Phase 0 du projet MIDAS-Bénin,
de zéro jusqu'au MVP fonctionnel :

### 1. Initialisation du projet
- Création du monorepo avec deux dossiers : `backend/` et `mobile/`
- Initialisation du backend : `npm init`, TypeScript, Fastify, Prisma
- Initialisation du mobile : `flutter create`, Riverpod, GoRouter, Dio

### 2. Infrastructure Docker
- Rédaction de `docker-compose.yml` avec PostgreSQL 16 et Keycloak 24
- Installation de Docker Compose v2 sur la machine (via `apt-get install docker-compose-v2`)
- Lancement des conteneurs via `sg docker -c "docker compose up -d postgres keycloak"`
- Vérification : `docker ps` → conteneurs healthy

### 3. Base de données (Prisma)
- Définition du schéma Prisma : User, IoTDevice, IoTData, Consent, AuditEvent, ProcessingRegister
- Premier `prisma db push` → erreur FK `IoTData.deviceId` : ajout de `@db.Uuid`
- `prisma db push --force-reset` → tables créées
- Script `seed.ts` : création d'Alice (NPIBENIN202400001), Bob, VC de démo, appareil IoT
- Exécution : `npx tsx src/seed.ts`

### 4. Backend (Node.js / Fastify / TypeScript)
- Structure modulaire dans `backend/src/modules/` : auth, wallet, consent, iot, audit, processing-register
- Implémentation de l'enrôlement et connexion avec signature Ed25519 réelle
- Middleware JWT pour protéger les routes sensibles
- Broker MQTT Aedes intégré pour l'IoT
- 21 fichiers `.ts` commentés
- Lancement : `nohup npm run dev` sur le port 3000
- Tests API validés avec curl :
  - `POST /auth/register` → DID + UserID
  - `POST /auth/login` → JWT (signature Ed25519)
  - `POST /wallet/create` → DID Document W3C
  - `POST /wallet/issue-vc` → VerifiableCredential signé

### 5. Application mobile (Flutter)
- Correction de toutes les erreurs de compilation :
  - `ChaCha20.poly1305()` → `Chacha20.poly1305Aead()`
  - Appels de méthodes Ed25519 avec paramètres nommés
  - `SharedSecretKey` → `SecretKey`
  - `FilledButton.tonal.icon` → `FilledButton.tonal(child: Row(...))`
- Polissage UI professionnel (Material 3) :
  - `auth_screen.dart` : gradient vert, animations, formulaire NPI
  - `wallet_screen.dart` : carte identité, QR code, skeleton loading, bottom sheet VC
  - `consent_screen.dart` : status chips colorés, Wrap data classes, menu contextuel
  - `iot_screen.dart` : device cards, scanner QR, time ago
  - `audit_screen.dart` : badge intégrité/violation, pull-to-refresh
  - `scaffold_shell.dart` : NavigationBar Material 3
- Auto-détection Web vs Android dans `api_client.dart`
- 18 fichiers `.dart` commentés
- Résultat : `flutter analyze` → 0 erreurs, 0 warnings

### 6. Documentation
- Rédaction complète du README.md (ce fichier)
- Commentaires ajoutés à l'intégralité du code backend (21 fichiers)
- Commentaires ajoutés à l'intégralité du code mobile (18 fichiers)

### Phases suivantes

#### Phase 1 — Identité & Auth
- Intégration Keycloak (SSO, OIDC, gestion des rôles)
- Portefeuille DID avancé : résolution DID universelle, rotation de clés
- Credentials multi-émetteurs : ANIP (CIN), CNA (Permis), Université (Diplômes)
- Chiffrement de bout en bout du wallet avec clé dérivée du NPI
- Authentification biométrique (empreinte, reconnaissance faciale)

#### Phase 2 — Consentement & Partage de données
- Moteur BPMN (Workflow) pour les flux de consentement
- Interface granulaire : choisir précisément chaque donnée partagée
- Signature du consentement par l'utilisateur (Ed25519)
- Consentement contextuel : temporaire, permanent, à usage unique
- Portabilité des données (export JSON/LD)

#### Phase 3 — IoT Bridge
- Firmware ESP32 avec attestation matérielle (secure boot)
- Appairage par QR code signé + tunnel chiffré
- Collecte et horodatage des données télémétriques
- Alertes temps réel via WebSocket/MQTT
- Tableau de bord IoT avec historique et seuils configurables

#### Phase 4 — Audit & Gouvernance
- Chaîne cryptographique complète (hash chain) des événements
- Signature individuelle de chaque événement d'audit
- Console APDP : visualisation, recherche, export
- Détection automatique de violations (intrusion, accès non autorisé)
- Preuve juridique exportable (PDF horodaté + signature)

#### Phase 5 — Sécurité, Tests & Conformité
- Tests unitaires et d'intégration (Jest, Flutter test)
- Tests de pénétration : injection, rejeu, usurpation
- Scan de vulnérabilités (npm audit, Trivy, Snyk)
- Conformité RGPD / LPDB (Loi Protection Données Bénin)
- Durcissement Docker : images signées, réseau isolé, secrets manager

#### Phase 6 — Déploiement MVP & Documentation
- CI/CD : GitHub Actions (lint, analyse, build, test)
- Déploiement cloud (OVH / AWS) avec HTTPS (Let's Encrypt)
- Documentation technique complète (ADR, diagrammes, API docs)
- Vidéo de démonstration et guide utilisateur
- Mise en production progressive (sandbox → pilote → national)

---

Développé dans le cadre de l'initiative d'identité numérique souveraine
du Bénin. 🇧🇯
