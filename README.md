# Bruit de Nuit (iPhone)

App iPhone qui lance un bruit blanc, rose, marron ou ton propre son à l'heure que tu choisis (par exemple de 4 h à 8 h), même quand le téléphone est verrouillé.

## Comment ça marche

iOS n'autorise pas une app endormie à se réveiller toute seule pour jouer du son. L'app fait donc comme les apps de sommeil : quand tu appuies sur **Lancer le mode nuit**, elle démarre son moteur audio en silence. Grâce au mode d'arrière-plan « Audio », iOS la laisse tourner toute la nuit, puis à l'heure prévue le volume monte doucement.

À savoir :
- Tu peux verrouiller le téléphone. Par contre, **ne ferme pas l'app** en la balayant dans le sélecteur d'apps : ça l'arrête.
- Le son joue même en mode silencieux. Règle le volume média avant de dormir.
- Après un appel ou une alarme, l'app essaie de reprendre le son toute seule.

## Installer sur ton iPhone (avec ton Mac)

Il te faut Xcode (gratuit sur l'App Store du Mac) et un câble pour brancher l'iPhone.

### Méthode A : avec XcodeGen (la plus rapide)

1. Dans le Terminal :
   ```
   brew install xcodegen
   cd chemin/vers/BruitDeNuit
   xcodegen
   open BruitDeNuit.xcodeproj
   ```
2. Passe ensuite à « Signer et lancer » plus bas.

### Méthode B : à la main dans Xcode

1. Xcode → File → New → Project → **iOS → App**.
   Product Name : `BruitDeNuit`, Interface : **SwiftUI**, Language : **Swift**.
2. Supprime les fichiers `ContentView.swift` et `BruitDeNuitApp.swift` créés par Xcode (Move to Trash).
3. Glisse les 7 fichiers `.swift` du dossier `BruitDeNuit/` dans le projet (coche « Copy items if needed »).
4. Clique sur le projet → cible **BruitDeNuit** → onglet **Signing & Capabilities** → **+ Capability** → **Background Modes** → coche **Audio, AirPlay, and Picture in Picture**.
   Sans cette case, le son ne démarrera pas téléphone verrouillé.

### Signer et lancer

1. Projet → cible BruitDeNuit → **Signing & Capabilities** → **Team** : choisis ton identifiant Apple (Add Account si besoin).
   Si Xcode affiche une erreur de « bundle identifier », remplace-le par quelque chose d'unique, par exemple `com.tonprenom.bruitdenuit`.
2. Branche l'iPhone, déverrouille-le et accepte « Faire confiance à cet ordinateur ».
3. Sur l'iPhone : Réglages → Confidentialité et sécurité → **Mode développeur** → activer (l'iPhone redémarre).
4. Dans Xcode, choisis ton iPhone en haut de la fenêtre, puis appuie sur ▶︎.
5. La première fois, iOS bloque l'app : Réglages → Général → **VPN et gestion de l'appareil** → ton identifiant → Faire confiance.

Avec un compte Apple gratuit, l'app expire après **7 jours**. Il suffit de rebrancher le téléphone et d'appuyer à nouveau sur ▶︎ dans Xcode (tes programmations sont conservées). Avec le programme développeur Apple (99 €/an), elle reste installée un an.

## Tester avant la première nuit

1. Crée une programmation qui commence dans 2 minutes, avec une montée progressive « Aucune ».
2. Lance le mode nuit, puis verrouille le téléphone.
3. Vérifie que le son démarre à l'heure prévue.

## Fichiers

| Fichier | Rôle |
|---|---|
| `BruitDeNuitApp.swift` | Point d'entrée de l'app |
| `Models.swift` | Programmations, sauvegarde, calcul des horaires (y compris les plages qui passent minuit) |
| `NoiseEngine.swift` | Génération des bruits blanc, rose et marron, lecture en boucle du fichier perso |
| `NightController.swift` | Vérifie chaque seconde quelle programmation est active et règle le volume |
| `ContentView.swift` | Écran principal : horloge, mode nuit, liste |
| `ScheduleEditor.swift` | Création et modification d'une programmation |
| `NightView.swift` | Écran noir du mode nuit |
