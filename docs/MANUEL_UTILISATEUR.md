# Manuel d'Utilisateur — MIDAS-Bénin

**Master Identity and Data Autonomy System — Bénin**

Version 1.0 — Juillet 2026

---

## Table des matières

1. [Introduction](#1-introduction)
2. [Premiers pas](#2-premiers-pas)
3. [Écran d'authentification](#3-écran-dauthentification)
4. [Portefeuille numérique (Wallet)](#4-portefeuille-numérique-wallet)
5. [Gestion des consentements](#5-gestion-des-consentements)
6. [Objets connectés (IoT)](#6-objets-connectés-iot)
7. [Piste d'audit](#7-piste-daudit)
8. [Profil et paramètres](#8-profil-et-paramètres)
9. [Console d'administration web](#9-console-dadministration-web)
10. [Annexes techniques](#10-annexes-techniques)

---

# 1. Introduction

## 1.1 Qu'est-ce que MIDAS-Bénin ?

MIDAS-Bénin (**Master Identity and Data Autonomy System**) est une plateforme souveraine d'identité numérique pour les citoyens du Bénin. Elle vous permet de :

- **Contrôler votre identité numérique** : créer un portefeuille de documents d'identité électroniques (DID, vérifiable credentials)
- **Gérer vos consentements** : décider qui a accès à vos données, pour quelle durée, et révoquer cet accès à tout moment
- **Surveiller vos appareils connectés** : suivre les données de capteurs IoT (température, humidité, pression) en temps réel
- **Consulter votre piste d'audit** : visualiser l'historique complet de toutes les actions effectuées sur vos données
- **S'authentifier de manière sécurisée** : par empreinte digitale, clé cryptographique, ou fédération d'identité (Keycloak)

## 1.2 Architecture de la plateforme

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Application    │────▶│  Serveur Backend  │────▶│  Base de données│
│  Mobile Flutter │     │  Node.js/Fastify  │     │  PostgreSQL     │
└─────────────────┘     └──────────────────┘     └─────────────────┘
        │                        │
        │                 ┌──────┴──────┐
        │                 │             │
        ▼                 ▼             ▼
   ┌─────────┐     ┌───────────┐  ┌──────────┐
   │ QR Code │     │ Keycloak  │  │ MQTT     │
   │ Scanner │     │ SSO       │  │ Broker   │
   └─────────┘     └───────────┘  └──────────┘
```

## 1.3 Composants

| Composant | Description |
|-----------|-------------|
| **Application Mobile** | Interface principale pour les citoyens (Android, iOS, web) |
| **Console d'administration** | Interface web pour les administrateurs (APDP) |
| **Backend API** | Serveur REST avec +55 endpoints |
| **Firmware ESP32** | Simulateur d'appareils IoT capteurs environnementaux |

---

# 2. Premiers pas

## 2.1 Installation de l'application

1. Téléchargez l'application MIDAS-Bénin depuis le store correspondant à votre plateforme
2. Autorisez les permissions demandées :
   - **Caméra** : pour scanner les QR codes d'appairage IoT
   - **Biométrie** : pour le déverrouillage par empreinte digitale
   - **Stockage sécurisé** : pour sauvegarder vos clés cryptographiques localement
3. L'écran d'authentification s'affiche

## 2.2 Comprendre la navigation

Une fois connecté, l'application utilise une barre de navigation inférieure avec 5 onglets :

```
┌──────────────────────────────────────────────┐
│                                              │
│              [Contenu de l'écran]            │
│                                              │
├──────┬──────┬──────┬──────┬──────┤
│  [1]  │  [2]  │  [3]  │  [4]  │  [5]  │
│Wallet│Consent│ IoT  │Audit │Profil│
└──────┴──────┴──────┴──────┴──────┘
```

| Onglet | Icône | Fonction |
|--------|-------|----------|
| **Wallet** | Carte d'identité | Votre portefeuille de credentials numériques |
| **Consent** | Liste | Gestion de vos consentements de données |
| **IoT** | Antenne | Surveillance de vos appareils connectés |
| **Audit** | Graphique | Historique des actions sur vos données |
| **Profil** | Silhouette | Paramètres de votre compte |

---

# 3. Écran d'authentification

## 3.1 Écran d'accueil

Lorsque vous ouvrez l'application pour la première fois (ou après déconnexion), l'écran d'authentification s'affiche avec :

- **Logo MIDAS** : Icône `verified_user_rounded` dans un cercle bordeaux foncé (`#8B1A1A`)
- **Titre** : `MIDASBJ` en gras, avec espacement de lettres élargi
- **Sous-titre** : `Identité Numérique Souveraine`
- **Description** : `Gérez votre identité, vos consentements et vos appareils connectés`
- **Fond** : Gris très clair (`#FAFAFA`)

L'ensemble de l'écran apparaît avec un effet de fondu (fade-in) sur 800 ms.

## 3.2 Méthodes d'authentification

L'application propose jusqu'à **5 méthodes d'authentification** :

### 3.2.1 S'enrôler avec mon NPI (Bouton principal — fond rempli bordeaux)

**C'est la méthode recommandée pour la première utilisation.**

**Fonctionnement :**
1. Appuyez sur `S'enrôler avec mon NPI`
2. Une boîte de dialogue s'affiche avec le titre `Saisir votre NPI`
3. Saisissez votre numéro NPI (Numéro de Pension d'Identité) dans le champ de texte
   - Le champ est pré-rempli en majuscules
   - Indice de saisie : `NPIBENIN2024...`
   - Icône de préfixe : `badge_outlined`
4. Appuyez sur `Enrôler` ou appuyez sur Entrée

**Ce qui se passe :**
- L'application génère une paire de clés Ed25519 (clé publique + clé privée)
- La clé privée est stockée localement dans le stockage sécurisé de l'appareil
- La clé publique est envoyée au serveur avec votre NPI
- Un identifiant décentralisé (DID) est créé : `did:midas:benin:{VOTRE_NPI}`
- Un token JWT est émis pour la session
- Vous êtes automatiquement redirigé vers l'écran Wallet

**Après inscription, vous possédez :**
- Un DID unique (identité décentralisée)
- Une paire de clés cryptographiques
- Un credential d'identité numérique

### 3.2.2 Se connecter (NPI + signature)

**Pour les utilisateurs déjà enrôlés.**

**Fonctionnement :**
1. Appuyez sur `Se connecter (NPI + signature)`
2. Saisissez votre NPI dans la boîte de dialogue
3. Appuyez sur `Connecter`

**Ce qui se passe :**
- L'application récupère la clé privée stockée localement pour ce NPI
- Elle signe cryptographiquement votre NPI avec cette clé
- La signature est envoyée au serveur pour vérification
- Si la signature est valide, un token JWT est émis

**Conditions requises :**
- Vous devez avoir déjà effectué l'enrôlement sur cet appareil
- La paire de clés doit être présente dans le stockage sécurisé

### 3.2.3 Connexion simple (NPI seul)

**Mode développement/test — ne nécessite aucune signature.**

**Fonctionnement :**
1. Appuyez sur `Connexion simple (NPI seul)`
2. Saisissez votre NPI
3. Appuyez sur `Connecter`

**Ce qui se passe :**
- Le NPI est envoyé au serveur sans aucune vérification cryptographique
- Un token JWT est émis directement

> **Note importante :** Cette methode est concue uniquement pour les tests. Elle ne verifie pas votre identite de maniere cryptographique.

### 3.2.4 SSO Keycloak

**Connexion via l'identité fédérée Keycloak (système d'authentification d'entreprise).**

**Fonctionnement :**
1. Appuyez sur `SSO Keycloak` (icône `admin_panel_settings_outlined`)
2. Un navigateur WebView s'ouvre avec la page de connexion Keycloak
3. Entrez vos identifiants Keycloak
4. Le flux PKCE (Proof Key for Code Exchange) sécurise la communication
5. Une fois authentifié, le code d'autorisation est intercepté automatiquement
6. Le token d'accès Keycloak est échangé contre un token MIDAS
7. Vous êtes redirigé vers l'écran Wallet

**Sécurité :**
- Le flux PKCE empêche les attaques par détournement de code
- Le code verifier/challenge sont générés cryptographiquement
- La redirect URL utilise un schéma personnalisé : `midasbenin://callback`

### 3.2.5 Authentification biométrique

**Déverrouillage par empreinte digitale ou reconnaissance faciale.**

**Conditions d'apparition :**
- Le bouton biométrique n'apparaît **que si** l'appareil supporte la biométrie ET qu'une session précédente existe

**Deux états du bouton :**
- `Activer biométrie` (icône `fingerprint_outlined`) : quand la biométrie n'est pas encore configurée
- `Déverrouillage biométrique` (icône `fingerprint`) : quand la biométrie est déjà configurée

**Fonctionnement :**
1. Appuyez sur le bouton biométrique
2. Le système de biométrie natif de l'appareil s'affiche
3. Présentez votre empreinte digitale ou votre visage
4. Si la vérification est OK, la session précédente est restaurée

**Prérequis :**
- Vous devez vous être connecté au moins une fois (pour que le token soit stocké)
- L'appareil doit avoir la biométrie configurée (empreintes ou Face ID)
- Le stockage sécurisé doit contenir les données de session

## 3.3 Indicateurs d'état

| Indicateur | Signification |
|------------|---------------|
| `Opération en cours...` + spinner bordeaux | L'authentification est en cours de traitement |
| SnackBar rouge en bas | Une erreur est survenue (message d'erreur affiché) |
| Redirection automatique vers Wallet | L'authentification a réussi |

## 3.4 Gestion des erreurs

| Message d'erreur | Cause | Solution |
|------------------|-------|----------|
| `Identité non trouvée. Enrôlez-vous d'abord.` | Tentez de vous connecter avec NPI+signature sans avoir préalablement enregistré vos clés | Effectuez d'abord un enrôlement |
| `Aucune session enregistrée. Connectez-vous d'abord.` | Tentez la connexion biométrique sans session préalable | Connectez-vous normalement d'abord |
| `Échec de l'authentification biométrique` | L'empreinte ou le visage n'a pas été reconnu | Réessayez ou utilisez une autre méthode |
| Erreur réseau | Le serveur est inaccessible | Vérifiez votre connexion internet |

---

# 4. Portefeuille numérique (Wallet)

## 4.1 Vue d'ensemble

L'écran Wallet est le cœur de l'application. Il affiche votre identité numérique complète et vos credentials vérifiables.

**Layout :**
```
┌────────────────────────────────────┐
│  [CARTE] Carte d'identite          │
│  ┌──────────────────────────────┐  │
│  │ DID: did:midas:benin:...    │  │
│  │ NPI: NPIBENIN2024...        │  │
│  │ QR Code  │  Clé publique    │  │
│  └──────────────────────────────┘  │
│                                    │
│  [CLES] Chiffrement du portefeuille│
│  ┌──────────────────────────────┐  │
│  │ Mot de passe  │  [Chiffrer] │  │
│  └──────────────────────────────┘  │
│                                    │
│  [DOC] Credentials (12)           │
│  ┌──────────────────────────────┐  │
│  │ Type │ Émetteur │ Date      │  │
│  │ ...                        │  │
│  └──────────────────────────────┘  │
│                                    │
│  [Émettre un credential]           │
└────────────────────────────────────┘
```

## 4.2 Carte d'identité numérique

La partie supérieure affiche votre carte d'identité numérique dans un encadré avec bordure grise :

### Champs affichés

| Champ | Description | Exemple |
|-------|-------------|---------|
| **DID** | Identifiant Décentralisé unique | `did:midas:benin:NPIBENIN202400001` |
| **NPI** | Numéro de Pension d'Identité | `NPIBENIN202400001` |
| **Clé publique** | Votre clé publique Ed25519 (tronquée pour l'affichage) | `base64Encoded...` |
| **QR Code** | QR code contenant votre DID pour partage |

### Actions sur la carte

| Action | Description |
|--------|-------------|
| **Appuyer sur le QR Code** | Génère un QR code plus grand pour le partager avec un tiers |
| **Copier le DID** | Appuyez longuement sur le DID pour le copier dans le presse-papier |
| **Copier la clé publique** | Pour partager avec un émetteur de credentials |

## 4.3 Chiffrement du portefeuille

Le portefeuille peut être chiffré localement pour une sécurité supplémentaire.

### Chiffrer le portefeuille

1. Saisissez un mot de passe dans le champ `Mot de passe`
2. Appuyez sur `Chiffrer`
3. Une clé de chiffrement est dérivée de votre NPI + mot de passe
4. Les données locales du portefeuille sont chiffrées avec AES-CBC + ChaCha20-Poly1305

### Déchiffrer le portefeuille

1. Entrez votre mot de passe de chiffrement
2. Le portefeuille est automatiquement déchiffré
3. Les credentials deviennent visibles

### Dérivation de clé

La clé de chiffrement est dérivée de :
- Votre NPI (identifiant national)
- Un secret de l'application
- Votre mot de passe personnel

> **Attention :** Si vous perdez votre mot de passe, les donnees chiffrees localement sont irrecuperables.

## 4.4 Liste des credentials vérifiables

Sous la section chiffrement, une liste de vos credentials apparaît :

### Types de credentials supportés

| Type | Description | Icône | Émetteurs typiques |
|------|-------------|-------|-------------------|
| **NpiCredential** | Attestation d'identite nationale | [CARTE] | ANIP |
| **Passport** | Passeport biometrique | [LIVRE] | ANIP |
| **DriverLicense** | Permis de conduire | [VOITURE] | ANIP |
| **HealthInsurance** | Assurance maladie | [HOPITAL] | CNSS |
| **SocialSecurity** | Securite sociale | [BOUCLIER] | CNSS |
| **VoterCard** | Carte d'electeur | [URNE] | CENA |
| **Diploma** | Diplome universitaire | [CHAPPEAU] | Universites |
| **BirthCertificate** | Acte de naissance | [ROULEAU] | Etat civil |
| **MarriageCertificate** | Acte de mariage | [ALLIANCE] | Etat civil |
| **BankAccount** | Compte bancaire | [BANQUE] | Banques partenaires |
| **EmploymentAttestation** | Attestation d'emploi | [VALISE] | Employeurs |
| **ProfessionalCard** | Carte professionnelle | [ETIQUETTE] | Ordres professionnels |

### Affichage de chaque credential

Chaque credential est affiché dans une carte avec :
- **Badge coloré** : nom du type de credential
- **Nom de l'émetteur** : ex. "Agence Nationale de l'Identité et des Personnes"
- **Date d'émission** : au format français (jour/mois/année)
- **Statut** : `Actif` (vert) ou `Révoqué` (rouge)

### Actions sur un credential

En appuyant sur un credential, un panneau détaillé apparaît (bottom sheet) avec :

| Action | Description |
|--------|-------------|
| **Voir les détails** | Affiche toutes les informations du credential : type, émetteur, date, signature, preuve |
| **QR Code de partage** | Génère un QR code contenant les données du credential pour vérification par un tiers |
| **Présentation vérifiable** | Génère une Verifiable Presentation (VP) signée pour prouver votre identité |
| **Révoquer** | Supprime le credential de votre portefeuille (action irréversible) |

## 4.5 Émettre un credential

Un bouton en bas de l'écran permet d'émettre un nouveau credential :

1. Appuyez sur `Émettre un credential`
2. Sélectionnez le type parmi les 12 types disponibles
3. Le credential est signé cryptographiquement et ajouté à votre portefeuille
4. Un audit event est enregistré automatiquement

## 4.6 Rotation de clé

Depuis l'écran Wallet, vous pouvez effectuer une rotation de clé :

1. Une nouvelle paire Ed25519 est générée
2. La nouvelle clé publique est envoyée au serveur
3. L'ancienne clé est conservée comme `#keys-1-previous` dans le DID document
4. Un nouveau JWT est émis avec la nouvelle identité

## 4.7 Résolution de DID

Le portefeuille supporte la résolution de DID selon plusieurs méthodes :

| Méthode | Exemple | Résolveur |
|---------|---------|-----------|
| `midas` | `did:midas:benin:NPI...` | Serveur local MIDAS |
| `key` | `did:key:z6Mk...` | dev.uniresolver.io |
| `web` | `did:web:example.com` | dev.uniresolver.io |
| `ethr` | `did:ethr:0x...` | dev.uniresolver.io |
| `ion` | `did:ion:Ei...` | dev.uniresolver.io |

---

# 5. Gestion des consentements

## 5.1 Vue d'ensemble

L'écran Consentements vous permet de contrôler qui a accès à vos données et pour quel usage. C'est le cœur de la conformité RGPD de l'application.

## 5.2 Créer une demande de consentement

### Formulaire de création

Le haut de l'écran affiche un formulaire avec les champs suivants :

| Champ | Type | Obligatoire | Description |
|-------|------|-------------|-------------|
| **Finalité** | Champ texte / Dropdown | Oui | L'objectif de la collecte (ex. "Traitement médical", "Vérification d'identité") |
| **Catégories de données** | Dropdown multiple | Oui | Les types de données concernées |
| **Type de consentement** | Sélection | Non | `TEMPORAIRE`, `USAGE_UNIQUE`, ou `PERMANENT` |
| **Fournisseur** | Champ texte | Non | DID ou domaine du fournisseur de services |
| **Durée** | Nombre | Non | Durée de validité en jours (pour consentements temporaires) |
| **Nombre max d'utilisations** | Nombre | Non | Nombre maximum d'accès (pour usage unique) |

### Catégories de données disponibles

Selon la finalité choisie, les catégories de données varient :

| Finalité | Catégories de données disponibles |
|----------|-----------------------------------|
| **Santé** | historique_médical, ordonnances, résultats_labos, vaccinations |
| **Identité** | photo, empreintes, adresse, état_civil, nationalité |
| **Financier** | revenus, comptes_bancaires, impôts, credits |
| **Éducation** | diplômes, relevés_notes, attestations_fréquentation |
| **Emploi** | contrat_travail, salaire, attestation_employeur |
| **IoT** | données_capteurs, localisation, historique_technique |

### Types de consentement

| Type | Signification | Usage |
|------|---------------|-------|
| **TEMPORAIRE** | Consentement à durée limitée | Accès temporaire à des données pour une procédure spécifique |
| **USAGE_UNIQUE** | Un seul usage autorisé | Vérification ponctuelle, présentation unique |
| **PERMANENT** | Durée indéterminée | Accès continu tant que non révoqué |

### Soumission

1. Remplissez les champs du formulaire
2. Appuyez sur `Envoyer la demande`
3. Un workflow de consentement est automatiquement créé
4. Le consentement passe à l'état `REQUESTED` (en attente)

## 5.3 Liste des consentements

Sous le formulaire, la liste de vos consentements s'affiche avec un système de filtrage.

### Filtres disponibles

| Filtre | Options |
|--------|---------|
| **Tous** | Affiche tous les consentements |
| **En attente** | `REQUESTED` — demandes en attente de traitement |
| **Accordés** | `GRANTED` — consentements acceptés |
| **Actifs** | `ACTIVE` — consentements en cours d'utilisation |
| **Révoqués** | `REVOKED` — consentements retirés |
| **Refusés** | `DENIED` — consentements refusés |

### Affichage de chaque consentement

Chaque consentement est affiché dans une carte avec :

| Élément | Description |
|---------|-------------|
| **Finalité** | Pourquoi les données sont collectées |
| **Catégories** | Tags colorés montrant les types de données |
| **Type** | Badge indiquant TEMPORAIRE / USAGE_UNIQUE / PERMANENT |
| **Statut** | Badge coloré (vert = ACTIF, orange = EN_ATTENTE, rouge = RÉVOQUÉ) |
| **Fournisseur** | DID ou domaine de l'entité demandant l'accès |
| **Date de création** | Date à laquelle le consentement a été créé |
| **Date d'expiration** | Si applicable, date de fin de validité |

## 5.4 Actions sur un consentement

### Accord (Grant)

1. Appuyez sur le bouton `Accorder` (vert) sur un consentement en attente
2. Le consentement est signé cryptographiquement avec votre clé Ed25519
3. La signature couvre : `grant:{consentId}:{citoyenId}:{finalité}:{catégories}:{type}`
4. Le statut passe à `GRANTED` puis `ACTIVE`

### Révoquer (Revoke)

1. Appuyez sur le bouton `Révoquer` (rouge) sur un consentement actif
2. Le consentement est signé cryptographiquement
3. La signature couvre : `revoke:{consentId}:{citoyenId}:{finalité}`
4. Le statut passe à `REVOKED`
5. Le fournisseur perd immédiatement l'accès à vos données

### Refuser (Deny)

1. Appuyez sur `Refuser` sur une demande de consentement
2. Le statut passe à `DENIED`
3. Le fournisseur est notifié du refus

## 5.5 Export de données (Portabilité RGPD)

Un bouton `Exporter mes données` permet de télécharger l'ensemble de vos données :

1. Appuyez sur `Exporter mes données`
2. Un fichier JSON-LD est généré contenant :
   - Tous vos consentements (historique complet)
   - Tous vos credentials vérifiables
   - Une preuve cryptographique de l'intégrité des données
3. Le fichier est prêt à être partagé ou archivé

## 5.6 État du workflow

Chaque consentement suit un cycle de vie :

```
REQUESTED → GRANTED → ACTIVE → (REVOKED | DENIED | COMPLETED)
```

| État | Signification | Couleur |
|------|---------------|---------|
| `REQUESTED` | Demande en attente | Orange |
| `GRANTED` | Accordé par le citoyen | Vert clair |
| `ACTIVE` | En cours d'utilisation | Vert |
| `REVOKED` | Retiré par le citoyen | Rouge |
| `DENIED` | Refusé par le citoyen | Rouge foncé |
| `COMPLETED` | Utilisation maximale atteinte | Gris |

---

# 6. Objets connectés (IoT)

## 6.1 Vue d'ensemble

L'écran IoT vous permet de gérer vos appareils connectés (capteurs environnementaux), de visualiser les données en temps réel, et de configurer des alertes.

## 6.2 Liste des appareils

Le haut de l'écran affiche la liste de tous vos appareils enregistrés.

### Affichage de chaque appareil

| Élément | Description |
|---------|-------------|
| **Nom** | Nom personnalisé de l'appareil (ou ID par défaut) |
| **Statut** | Badge coloré : EN_ATTENTE, APPAIRÉ, ACTIF, DÉSACTIVÉ |
| **Dernière activité** | Date/heure de la dernière donnée reçue |
| **Icône d'alerte** | Alerte non lue (notification rouge) |

### Statuts des appareils

| Statut | Couleur | Signification |
|--------|---------|---------------|
| `EN_ATTENTE` | Gris | Appareil enregistré mais pas encore appairé |
| `APPAIRÉ` | Orange | Appairage en cours de finalisation |
| `ACTIF` | Vert | Appareil opérationnel et transmettant des données |
| `DÉSACTIVÉ` | Rouge | Appareil déconnecté ou désactivé |

## 6.3 Appairage d'un nouvel appareil

### Méthode par QR Code

1. Appuyez sur le bouton `Scanner un QR Code` (icône `qr_code_scanner`)
2. L'écran de scan s'affiche avec :
   - Un viseur de scan (rectangle avec coins arrondis)
   - Un bouton pour activer/désactiver la lampe torche
   - Un bouton pour basculer entre caméra avant et arrière
3. Pointez la caméra vers le QR code de l'appareil
4. Le QR code contient un JSON signé avec :
   - L'ID de l'appareil
   - Une signature Ed25519
   - Un challenge cryptographique
5. L'appairage est automatiquement finalisé

### Méthode par challenge

1. Récupérez le challenge depuis l'appareil (`GET /iot/pair-challenge/:deviceId`)
2. L'appareil signe le message `pair:{deviceId}:{ownerId}:{challenge}`
3. La signature est envoyée au serveur pour vérification
4. L'appareil passe à l'état `APPAIRÉ`

### Scanner de QR Code — Détails

L'écran de scan (`qr_scanner_screen.dart`) contient :

| Élément | Description |
|---------|-------------|
| **Zone de scan** | Rectangle avec viseur au centre de l'écran |
| **Instructions** | `Alignez le QR code dans le cadre` |
| **Bouton torche** | `flash_on` / `flash_off` — allume/éteint la lampe torche |
| **Bouton caméra** | `camera_front` / `camera_rear` — bascule entre les caméras |
| **Bouton retour** | Flèche en haut à gauche pour revenir à l'écran IoT |

**Comportement :**
- Le scan est automatique dès que le QR code est détecté dans le viseur
- Un feedback visuel (animation ou vibration) indique la détection
- L'appareil est automatiquement appairé et la page se ferme

## 6.4 Détail d'un appareil

En appuyant sur un appareil dans la liste, l'écran de détail s'affiche :

### Section 1 : Informations de l'appareil

| Champ | Description |
|-------|-------------|
| **Nom** | Nom de l'appareil (modifiable via l'icône crayon) |
| **ID** | Identifiant unique de l'appareil |
| **Statut** | Statut actuel |
| **Clé publique** | Clé Ed25519 de l'appareil |
| **Attestation** | État des sécurité matérielles (Secure Boot, Flash Encryption, TPM) |

### Section 2 : Graphique de télémétrie

Un graphique en courbes (`fl_chart`) affiche les données de capteurs en temps réel :

| Métrique | Unité | Couleur | Description |
|----------|-------|---------|-------------|
| **Température** | °C | Rouge | Température ambiante |
| **Humidité** | % | Bleu | Taux d'humidité relative |
| **Pression** | hPa | Vert | Pression barométrique |

**Fonctionnalités du graphique :**
- Zoom et défilement horizontal
- Points de données avec tooltip (appui long)
- Légende colorée
- Données des 100 dernières mesures par défaut

### Section 3 : Configuration des seuils

La section seuils permet de définir des valeurs limites pour chaque métrique :

| Champ | Description |
|-------|-------------|
| **Métrique** | Sélectionnez : Température, Humidité, Pression |
| **Valeur minimale** | Seuil bas — en dessous duquel une alerte est déclenchée |
| **Valeur maximale** | Seuil haut — au-dessus duquel une alerte est déclenchée |
| **Activé** | Toggle pour activer/déséactiver ce seuil |

**Exemples :**
| Métrique | Min | Max | Effet |
|----------|-----|-----|-------|
| Température | 15 | 35 | Alertes si < 15°C ou > 35°C |
| Humidité | 30 | 70 | Alertes si < 30% ou > 70% |
| Pression | 980 | 1040 | Alertes si hors plage |

### Section 4 : Alertes

La liste des alertes de l'appareil s'affiche sous le graphique :

| Élément | Description |
|---------|-------------|
| **Type d'alerte** | `THRESHOLD_HIGH` (seuil dépassé) ou `THRESHOLD_LOW` (seuil non atteint) |
| **Sévérité** | `INFO`, `WARNING`, `CRITICAL` |
| **Message** | Description de l'alerte (ex. "Température: 38.5°C dépasse le seuil max de 35°C") |
| **Métrique** | Nom de la métrique concernée |
| **Valeur** | Valeur mesurée ayant déclenché l'alerte |
| **Statut** | `LU` (lecture confirmée) ou non lu (badge point rouge) |
| **Marquer comme lu** | Appuyez sur l'icône pour confirmer la lecture |

### Section 5 : Actions

| Action | Description |
|--------|-------------|
| **Renommer** | Change le nom affiché de l'appareil |
| **Désenregistrer** | Retire l'appareil de votre liste (statut → DÉSACTIVÉ) |

## 6.5 Alertes en temps réel

Les alertes peuvent aussi être reçues via :

- **Notifications push** (WebSocket) — une notification apparaît même si vous n'êtes pas sur l'écran IoT
- **Bandeau d'alerte** — si vous êtes sur l'écran IoT, un message s'affiche en haut

## 6.6 Données MQTT

L'application souscrit aux topics MQTT suivants :

| Topic | Description |
|-------|-------------|
| `midas/+/telemetry` | Données de télémétrie de tous les appareils |
| `midas/+/alerts` | Alertes en temps réel |

Le service MQTT maintient une connexion WebSocket avec :
- **Hôte primaire** : serveur MIDAS principal
- **Hôte de secours** : serveur de fallback

---

# 7. Piste d'audit

## 7.1 Vue d'ensemble

L'écran Audit affiche un journal immuable de toutes les actions effectuées sur vos données. Chaque événement est lié au précédent par une chaîne de hachage cryptographique, rendant toute modification détectable.

## 7.2 Liste des événements

### Affichage de chaque événement

| Élément | Description |
|---------|-------------|
| **Action** | Type d'événement (CONNEXION, CRÉATION, ACCÈS, PAIRAGE, etc.) |
| **Type d'entité** | Type d'objet concerné (Utilisateur, Consentement, IoTDevice, etc.) |
| **ID de l'entité** | Identifiant de l'objet |
| **Acteur** | DID de l'entité ayant effectué l'action |
| **Timestamp** | Date et heure précises |
| **Hash** | Hachage SHA-256 de l'événement (tronqué à l'affichage) |
| **Signature** | Si signé par l'utilisateur : badge `Signé par l'utilisateur` |
| **Statut** | Badge OK (vert) ou VIOLATION (rouge) |

### Codes d'action

| Action | Signification | Couleur |
|--------|---------------|---------|
| `LOGIN` | Connexion | Bleu |
| `CREATE` | Création d'une ressource | Vert |
| `REGISTER` | Enregistrement d'un appareil | Vert |
| `PAIR` | Appairage d'un appareil | Vert |
| `ACCESS` | Accès à des données | Bleu |
| `CONSENT` | Opération de consentement | Bleu |
| `DENIED` | Accès refusé | Rouge |
| `FAILED` | Échec d'opération | Rouge |
| `BREACH` | Violation détectée | Rouge |
| `DELETE` | Suppression | Orange |

## 7.3 Filtrage et recherche

Des filtres sont disponibles en haut de l'écran :

| Filtre | Options | Description |
|--------|---------|-------------|
| **Recherche texte** | Saisie libre | Recherche par ID d'entité |
| **Type d'entité** | Liste déroulante | Filtrer par type : User, Consent, IoTDevice, etc. |
| **Action** | Liste déroulante | Filtrer par type d'action |
| **Date de début** | Sélecteur de date | Événements après cette date |
| **Date de fin** | Sélecteur de date | Événements avant cette date |

## 7.4 Vérification de la chaîne d'intégrité

Un bouton `Vérifier la chaîne` permet de vérifier l'intégrité cryptographique de tous les événements :

**Fonctionnement :**
1. Appuyez sur `Vérifier la chaîne`
2. Le système recalcule le hash de chaque événement en partant du premier
3. Chaque hash contient le hash précédent (chaîne de hachage)
4. Si tous les hashes correspondent → `Chaîne intègre` (badge vert)
5. Si une altération est détectée → `Violation détectée` (badge rouge) avec détails

**Détails de la violation :**
| Champ | Description |
|-------|-------------|
| **Raison** | Pourquoi la violation a été détectée |
| **Événements concernés** | Les événements dont le hash ne correspond pas |
| **Position** | Position dans la chaîne où l'altération a eu lieu |

## 7.5 Export de preuve

Un bouton `Exporter la preuve` génère un document JSON-LD contenant :

- L'ensemble des événements d'audit
- Les preuves cryptographiques (hashes + signatures)
- Le statut de la chaîne d'intégrité
- Un timestamp de génération

Ce document peut servir de preuve juridique de l'historique des actions.

## 7.6 Signer un événement

Vous pouvez manuellement ajouter un événement d'audit signé :

1. Appuyez sur `Signer un événement`
2. L'événement est signé avec votre clé Ed25519
3. La signature est incluse dans l'événement
4. Le badge `Signé par l'utilisateur` apparaît

## 7.7 Statistiques

En haut de l'écran, des statistiques sont affichées :

| Statistique | Description |
|-------------|-------------|
| **Total événements** | Nombre total d'événements dans votre piste |
| **Dernières 24h** | Événements des dernières 24 heures |
| **Violations** | Nombre de violations détectées |
| **Chaîne OK** | Statut d'intégrité de la chaîne |

---

# 8. Profil et paramètres

## 8.1 Vue d'ensemble

L'écran Profil affiche les informations de votre compte et les paramètres de l'application.

## 8.2 Informations du compte

| Champ | Description | Exemple |
|-------|-------------|---------|
| **NPI** | Votre numéro d'identification | `NPIBENIN202400001` |
| **DID** | Votre identifiant décentralisé | `did:midas:benin:NPI...` |
| **ID utilisateur** | Identifiant interne | UUID |
| **Mode d'authentification** | Comment vous êtes connecté | NPI, Keycloak, Biométrie, Simple |
| **Rôles** | Vos rôles sur la plateforme | `citizen`, `admin`, etc. |

## 8.3 Paramètres de sécurité

| Paramètre | Description |
|-----------|-------------|
| **Statut biométrique** | Indique si la biométrie est activée et configurée |
| **Chiffrement du portefeuille** | Indique si le portefeuille est chiffré localement |
| **Dernière connexion** | Date et heure de la dernière authentification |

## 8.4 Actions disponibles

| Action | Description | Confirmation |
|--------|-------------|--------------|
| **Déconnexion** | Ferme la session et revient à l'écran d'authentification | Oui |
| **Réinitialiser les données locales** | Efface toutes les données stockées sur l'appareil (tokens, clés, credentials) | Oui (irréversible) |

### Procédure de déconnexion

1. Appuyez sur `Déconnexion`
2. Une confirmation apparaît
3. Tous les tokens sont supprimés du stockage sécurisé
4. Vous êtes redirigé vers l'écran d'authentification

### Procédure de réinitialisation

1. Appuyez sur `Réinitialiser les données locales`
2. Une double confirmation apparaît (action dangereuse)
3. Toutes les données locales sont effacées :
   - Token JWT
   - Paires de clés Ed25519
   - Identifiants de session
   - Données biométriques
4. L'application redémarre à l'écran d'authentification

---

# 9. Console d'administration web

## 9.1 Accès

La console d'administration est accessible via un navigateur web à l'adresse :

```
https://{serveur}/console/
```

> **Note :** L'acces est reserve aux administrateurs autorises (role `admin`).

## 9.2 Écran de connexion

### Layout

```
┌──────────────────────────────────────────────────┐
│  Gradient foncé → bordeaux                       │
│                                                  │
│  ┌────────────────────────────┐                  │
│  │      [M]                   │                  │
│  │   MIDAS-Bénin              │                  │
│  │ Console d'administration   │                  │
│  │         — APDP —           │                  │
│  │                            │                  │
│  │  Identifiant [admin    ]   │                  │
│  │  Mot de passe [••••••••]   │                  │
│  │                            │                  │
│  │  [    Connexion         ]  │                  │
│  │                            │                  │
│  │  Système Souverain...      │                  │
│  └────────────────────────────┘                  │
└──────────────────────────────────────────────────┘
```

### Champs de connexion

| Champ | Type | Placeholder | Description |
|-------|------|-------------|-------------|
| **Identifiant** | Texte | `admin` | Nom d'utilisateur administrateur |
| **Mot de passe** | Mot de passe | `••••••••` | Mot de passe administrateur |

### Comportement

1. Saisissez vos identifiants
2. Cliquez sur `Connexion`
3. Le bouton passe en mode `Connexion...` (désactivé)
4. Si succès : redirection vers le tableau de bord
5. Si erreur : message d'erreur en rouge sous le formulaire

### Session

- Le token admin est stocké dans `localStorage` du navigateur
- Durée de validité : 12 heures
- Si le token expire, déconnexion automatique

## 9.3 Structure de la console

La console est composée de :

| Zone | Position | Description |
|------|----------|-------------|
| **Barre latérale** | Gauche (240px) | Navigation + logo + statut de connexion |
| **Barre supérieure** | Haut du contenu | Titre de la page + badge Admin + bouton Actualiser |
| **Zone de contenu** | Centre | Contenu de la page active |

### Barre latérale

```
┌──────────────────┐
│ [M] MIDAS        │
│   Console Admin  │
├──────────────────┤
│ ▸ Tableau de bord│ ← actif (rouge)
│ ▸ Piste d'audit  │
│ ▸ Violations     │
│ ▸ Journal serveur│
│ ▸ Types d'entites│
│ ▸ Utilisateurs   │
│ ▸ Consentements  │
│ ▸ Donnees IoT    │
├──────────────────┤
│ [.] Connecte  [X] │
└──────────────────┘
```

- **Clic** sur un élément : navigue vers la page correspondante
- **Élément actif** : fond rouge clair, texte bordeaux, gras
- **En bas** : indicateur de connexion (point vert/rouge) + bouton déconnexion

## 9.4 Tableau de bord

### Statistiques principales (6 cartes colorées)

| Carte | Couleur | Donnée affichée |
|-------|---------|-----------------|
| **Événements d'audit** | Rouge | Nombre total d'événements |
| **Violations** | Orange | Nombre de violations détectées |
| **Utilisateurs** | Vert | Nombre d'utilisateurs enregistrés |
| **Consentements** | Bleu | Nombre total de consentements |
| **Appareils IoT** | Violet | Nombre d'appareils connectés |
| **Chaîne d'audit** | Turquoise | `Intègre` (vert) ou `Altérée` (rouge) |

### Activité récente (24h) — Colonne de gauche

| Stat | Description |
|------|-------------|
| **Total** | Nombre total de logs des dernières 24h |
| **Erreurs** | Nombre d'erreurs (affiché en rouge) |
| **Warnings** | Nombre d'avertissements (affiché en orange) |

**Répartition par catégorie :**

| Catégorie | Couleur | Description |
|-----------|---------|-------------|
| HTTP | Bleu | Requêtes HTTP |
| Auth | Vert | Authentifications |
| Audit | Orange | Événements d'audit |
| IoT | Violet | Données IoT |
| Système | Turquoise | Événements système |
| Admin | Gris | Actions administratives |

### Entités suivies — Colonne de droite

Pour chaque type d'entité, affiche le nombre d'événements associés :
```
┌──────────────────────────────────────────┐
│ User                    12 événements    │
│ Consent                   8 événements   │
│ IoTDevice                 5 événements   │
└──────────────────────────────────────────┘
```

### Derniers événements

La liste des 20 derniers événements d'audit s'affiche en bas du tableau de bord. Chaque événement est affiché sous forme de carte avec :

- **Badge d'action** : LOGIN (bleu), CREATE (vert), DENIED (rouge), etc.
- **Badge de statut** : OK (vert) ou VIOLATION (rouge)
- **Type et ID de l'entité**
- **Acteur DID**
- **Date/heure**
- **Hash** (tronqué)
- **Signature utilisateur** (si applicable)

## 9.5 Page Piste d'audit

### Filtres de recherche

| Filtre | Type | Options |
|--------|------|---------|
| **Recherche texte** | Champ texte | Recherche par ID d'entité |
| **Type d'entité** | Sélection | Tous les types (rempli dynamiquement) |
| **Action** | Sélection | Connexion, Accès, Création, Enregistrement, Suppression, Appairage, Accès refusé, Échec, Violation, Consentement |
| **Date de début** | Date picker | Filtrage par date |
| **Date de fin** | Date picker | Filtrage par date |
| **Bouton Rechercher** | — | Lance la recherche |

### Résultats

- Nombre total de résultats trouvé
- Liste des événements correspondant aux filtres
- Chaque événement est affiché sous la même carte que sur le tableau de bord

## 9.6 Page Violations

Affiche toutes les violations détectées dans la chaîne d'audit :

| Élément | Description |
|---------|-------------|
| **Action** | Type de violation (EN_COURS, ÉCHEC, VIOLATION) |
| **Raison** | Explication de la violation |
| **Entité** | Type et ID concernés |
| **Acteur** | DID de l'acteur (si disponible) |
| **Date/heure** | Timestamp de la violation |

**Style** : Carte avec fond rouge clair, bordure rouge, texte rouge.

## 9.7 Page Journal serveur

### Statistiques rapides (4 mini-cartes)

| Carte | Couleur | Description |
|-------|---------|-------------|
| **Total** | Rouge | Nombre total de logs en mémoire |
| **Erreurs (24h)** | Orange | Erreurs des dernières 24h |
| **Requêtes HTTP** | Bleu | Logs de catégorie HTTP |
| **Authentifications** | Vert | Logs de catégorie Auth |

### Filtres

| Filtre | Type | Options |
|--------|------|---------|
| **Niveau** | Sélection | Tous, Info, Warning, Erreur, Debug |
| **Catégorie** | Sélection | Toutes, HTTP, Auth, Audit, IoT, Système, Admin |
| **Recherche** | Champ texte | Recherche dans le message |
| **Auto-refresh** | Checkbox | Actualisation automatique toutes les 5 secondes |
| **Bouton Filtrer** | — | Applique les filtres |
| **Bouton Vider** | — | Supprime tous les logs (avec confirmation) |

### Format de chaque log

```
┌──────────────────────────────────────────────────────────────┐
│ 14:32:15  INFO  [auth]  Connexion réussie NPI: NPIBENIN...  │
│                                  [details]                   │
│  ┌─────────────────────────────────────┐                     │
│  │ { "userId": "...", "method": "ed25519" } │               │
│  └─────────────────────────────────────┘                     │
└──────────────────────────────────────────────────────────────┘
```

| Élément | Description |
|---------|-------------|
| **Heure** | Timestamp au format HH:MM:SS |
| **Niveau** | INFO (bleu), WARN (orange), ERROR (rouge), DEBUG (gris) |
| **Catégorie** | Badge coloré : HTTP, Auth, Audit, IoT, Système, Admin |
| **Message** | Description de l'événement |
| **Bouton details** | Affiche/masque les métadonnées JSON associées |

## 9.8 Page Types d'entités

Affiche la liste de tous les types d'entités suivis dans le système d'audit :

```
┌──────────────────────────────────────┐
│ User                12 événements    │
│ Consent               8 événements   │
│ IoTDevice             5 événements   │
│ VerifiableCredential  3 événements   │
└──────────────────────────────────────┘
```

Chaque entrée est une carte avec le type et le nombre d'événements associés.

## 9.9 Page Utilisateurs

Tableau de tous les utilisateurs enregistrés :

| Colonne | Description |
|---------|-------------|
| **NPI** | Numéro d'identification national (en gras) |
| **DID** | Identifiant décentralisé (tronqué) |
| **Clé publique** | Clé publique Ed25519 (tronquée à 30 caractères) |
| **Créé le** | Date de création au format français |

**Fonctionnalités :**
- Tri par colonnes
- Le bouton `Actualiser` recharge la liste

## 9.10 Page Consentements

Tableau de tous les consentements du système :

| Colonne | Description |
|---------|-------------|
| **ID** | Identifiant du consentement (tronqué à 8 caractères) |
| **Citoyen** | ID du citoyen concerné (tronqué) |
| **Finalité** | Objectif du consentement |
| **Domaine** | Domaine du fournisseur |
| **DID Fournisseur** | Identifiant du fournisseur (tronqué) |
| **Statut** | Badge : GRANTED (vert) ou autre (rouge) |
| **Date** | Date de création |

## 9.11 Page Données IoT

Tableau des 200 dernières données de télémétrie reçues :

| Colonne | Description |
|---------|-------------|
| **Appareil** | ID de l'appareil (tronqué à 16 caractères) |
| **Type** | Type de payload |
| **Métrique** | Nom de la métrique (température, humidité, etc.) |
| **Valeur** | Valeur mesurée (en gras) |
| **Unité** | Unité de mesure |
| **Date** | Date/heure de réception |

---

# 10. Annexes techniques

## 10.1 Glossaire

| Terme | Définition |
|-------|------------|
| **NPI** | Numéro de Pension d'Identité — numéro national d'identification du citoyen béninois |
| **DID** | Decentralized Identifier — identifiant unique et décentralisé (format : `did:method:identifier`) |
| **VC** | Verifiable Credential — credential numérique signé cryptographiquement |
| **VP** | Verifiable Presentation — présentation enveloppant un ou plusieurs VCs |
| **Ed25519** | Algorithme de signature numérique à courbe elliptique |
| **X25519** | Algorithme d'échange de clés |
| **JWT** | JSON Web Token — token d'authentification signé |
| **Keycloak** | Système de gestion d'identité et d'accès (IAM) |
| **MQTT** | Message Queuing Telemetry Transport — protocole de messagerie IoT |
| **APDP** | Autorité de Protection des Données Personnelles (Bénin) |
| **RGPD** | Règlement Général sur la Protection des Données (norme européenne applicable) |
| **PBKDF2** | Password-Based Key Derivation Function 2 — dérivation de clé à partir de mot de passe |
| **PKCE** | Proof Key for Code Exchange — sécurisation du flux OAuth 2.0 |

## 10.2 Endpoints API complets

### Authentification (8 endpoints)

| Méthode | Chemin | Auth requise | Corps de la requête |
|---------|--------|-------------|---------------------|
| GET | `/api/v1/auth/health` | Non | — |
| POST | `/api/v1/auth/register` | Non | `{ npi, publicKey }` |
| POST | `/api/v1/auth/login` | Non | `{ npi, signature }` |
| POST | `/api/v1/auth/login-simple` | Non | `{ npi }` |
| POST | `/api/v1/auth/keycloak` | Non | `{ token }` |
| GET | `/api/v1/auth/session` | JWT | — |
| POST | `/api/v1/auth/rotate-key` | JWT | `{ newPublicKey }` |
| GET | `/api/v1/auth/roles` | JWT | — |

### Portefeuille (9 endpoints)

| Méthode | Chemin | Auth requise | Corps de la requête |
|---------|--------|-------------|---------------------|
| POST | `/api/v1/wallet/create` | JWT | — |
| POST | `/api/v1/wallet/rotate-key` | JWT | `{ newPublicKey }` |
| POST | `/api/v1/wallet/add-keyx` | JWT | `{ x25519PublicKey }` |
| POST | `/api/v1/wallet/issue-vc` | JWT | `{ type, issuer, issuerPrivateKey? }` |
| POST | `/api/v1/wallet/revoke-vc` | JWT | `{ vcId }` |
| GET | `/api/v1/wallet/vcs` | JWT | — |
| GET | `/api/v1/wallet/resolve/:did` | Non | — |
| POST | `/api/v1/wallet/derive-key` | JWT | `{ secret }` |
| POST | `/api/v1/wallet/present-vc` | JWT | `{ vcId, challenge? }` |

### Consentements (9 endpoints)

| Méthode | Chemin | Auth requise | Corps de la requête |
|---------|--------|-------------|---------------------|
| POST | `/api/v1/consent/request` | JWT | `{ providerDID?, purpose, dataClasses?, consentType?, duration? }` |
| POST | `/api/v1/consent/grant` | JWT | `{ consentId, signature, publicKey }` |
| POST | `/api/v1/consent/revoke` | JWT | `{ consentId, signature, publicKey }` |
| POST | `/api/v1/consent/deny` | JWT | `{ consentId }` |
| GET | `/api/v1/consent/history` | JWT | — |
| GET | `/api/v1/consent/active` | JWT | — |
| GET | `/api/v1/consent/data-classes` | Non | `?purpose=` |
| GET | `/api/v1/consent/workflow/:id` | JWT | — |
| GET | `/api/v1/consent/export` | JWT | — |

### IoT (14 endpoints)

| Méthode | Chemin | Auth requise | Corps de la requête |
|---------|--------|-------------|---------------------|
| POST | `/api/v1/iot/register` | Non | `{ deviceId, name?, publicKey, attestation }` |
| GET | `/api/v1/iot/pair-challenge/:deviceId` | Non | — |
| POST | `/api/v1/iot/pair` | JWT | `{ deviceId, signature, challenge }` |
| POST | `/api/v1/iot/pair-qr` | JWT | `{ deviceId, challenge, signature }` |
| POST | `/api/v1/iot/data` | Non | `{ deviceId, encryptedPayload?, signature, metricName, metricValue, unit? }` |
| GET | `/api/v1/iot/devices` | JWT | — |
| GET | `/api/v1/iot/devices/:id` | JWT | — |
| GET | `/api/v1/iot/devices/:id/telemetry` | JWT | `?metric=&limit=` |
| GET | `/api/v1/iot/devices/:id/alerts` | JWT | `?unread=` |
| POST | `/api/v1/iot/alerts/:id/read` | JWT | — |
| POST | `/api/v1/iot/thresholds` | JWT | `{ deviceId, metric, minValue?, maxValue?, enabled? }` |
| PUT | `/api/v1/iot/devices/:id/name` | JWT | `{ name }` |
| POST | `/api/v1/iot/unregister` | JWT | `{ deviceId }` |
| GET | `/api/v1/iot/alerts` | JWT | `?unread=` |

### Audit (7 endpoints)

| Méthode | Chemin | Auth requise | Corps de la requête |
|---------|--------|-------------|---------------------|
| POST | `/api/v1/audit/event` | JWT | `{ entityType, entityId, action, actorDID?, payload?, userSignature? }` |
| GET | `/api/v1/audit/trail/:entityId` | Non | — |
| POST | `/api/v1/audit/verify` | Non | `{ entityId }` |
| GET | `/api/v1/audit/violations` | Non | — |
| GET | `/api/v1/audit/search` | Non | `?entityType=&action=&from=&to=&limit=` |
| GET | `/api/v1/audit/export/:entityId` | Non | — |
| GET | `/api/v1/audit/entity-types` | Non | — |

### Administration (16 endpoints)

| Méthode | Chemin | Auth requise | Corps de la requête |
|---------|--------|-------------|---------------------|
| POST | `/api/v1/admin/login` | Non | `{ username, password }` |
| GET | `/api/v1/admin/session` | Admin JWT | — |
| GET | `/api/v1/admin/dashboard` | Admin JWT | — |
| GET | `/api/v1/admin/logs` | Admin JWT | `?level=&category=&search=&limit=` |
| GET | `/api/v1/admin/logs/stats` | Admin JWT | — |
| DELETE | `/api/v1/admin/logs` | Admin JWT | — |
| GET | `/api/v1/admin/audit/search` | Admin JWT | `?entityType=&action=&entityId=&from=&to=&limit=` |
| GET | `/api/v1/admin/audit/trail/:entityId` | Admin JWT | — |
| GET | `/api/v1/admin/audit/violations` | Admin JWT | — |
| GET | `/api/v1/admin/audit/entity-types` | Admin JWT | — |
| POST | `/api/v1/admin/audit/verify` | Admin JWT | `{ entityId }` |
| GET | `/api/v1/admin/audit/export/:entityId` | Admin JWT | — |
| GET | `/api/v1/admin/users` | Admin JWT | — |
| GET | `/api/v1/admin/consents` | Admin JWT | — |
| GET | `/api/v1/admin/iot-data` | Admin JWT | — |
| GET | `/api/v1/admin/processing-registers` | Admin JWT | — |

### Registre de traitement (3 endpoints)

| Méthode | Chemin | Auth requise | Corps de la requête |
|---------|--------|-------------|---------------------|
| POST | `/api/v1/processing-register` | JWT | `{ controller, purpose, dataClasses[], retention, legalBasis }` |
| GET | `/api/v1/processing-register` | Non | — |
| GET | `/api/v1/processing-register/:id` | Non | — |

## 10.3 Formats de données

### Verifiable Credential (JSON)

```json
{
  "@context": ["https://www.w3.org/2018/credentials/v1"],
  "type": ["VerifiableCredential", "NpiCredential"],
  "issuer": "did:midas:benin:ANIP",
  "issuanceDate": "2026-07-16T10:00:00Z",
  "credentialSubject": {
    "id": "did:midas:benin:NPIBENIN202400001",
    "npi": "NPIBENIN202400001",
    "fullName": "Citoyen Béninois"
  },
  "proof": {
    "type": "Ed25519Signature2020",
    "created": "2026-07-16T10:00:00Z",
    "proofPurpose": "assertionMethod",
    "verificationMethod": "did:midas:benin:ANIP#keys-1",
    "proofValue": "z58DAdFfa9SkqZMVPxA..."
  }
}
```

### DID Document (JSON)

```json
{
  "@context": ["https://www.w3.org/ns/did/v1"],
  "id": "did:midas:benin:NPIBENIN202400001",
  "created": "2026-07-16T10:00:00Z",
  "updated": "2026-07-16T10:00:00Z",
  "verificationMethod": [{
    "id": "did:midas:benin:NPIBENIN202400001#keys-1",
    "type": "Ed25519VerificationKey2020",
    "controller": "did:midas:benin:NPIBENIN202400001",
    "publicKeyMultibase": "z6Mk..."
  }],
  "authentication": ["#keys-1"],
  "assertionMethod": ["#keys-1"]
}
```

### Consentement (JSON)

```json
{
  "id": "uuid-consent-001",
  "citizenId": "did:midas:benin:NPIBENIN202400001",
  "providerDID": "did:midas:benin:CNSS",
  "providerDomain": "cnss.bj",
  "purpose": "Traitement médical",
  "dataClasses": ["historique_médical", "ordonnances"],
  "consentType": "TEMPORARY",
  "status": "ACTIVE",
  "expiresAt": "2026-08-16T00:00:00Z",
  "createdAt": "2026-07-16T10:00:00Z"
}
```

## 10.4 Raccourcis et astuces

| Raccourci / Astuce | Description |
|--------------------|-------------|
| Appui long sur le DID | Copie le DID dans le presse-papier |
| Appui long sur un VC | Affiche les détails complets |
| Swipe vers la gauche sur un consentement | Révoquer rapidement |
| Tirer vers le bas | Rafraîchir la liste (pull-to-refresh) |
| Double-tap sur le graphique IoT | Réinitialiser le zoom |

## 10.5 Support et contact

| Canal | Contact |
|-------|---------|
| **Email support** | support@midas-benin.bj |
| **Urgence sécurité** | security@midas-benin.bj |
| **APDP** | apdp@midas-benin.bj |
| **Documentation** | https://docs.midas-benin.bj |
| **GitHub** | https://github.com/midas-benin |

---

*Manuel d'utilisateur MIDAS-Bénin v1.0 — Juillet 2026*
*Plateforme souveraine d'identité numérique — République du Bénin*
