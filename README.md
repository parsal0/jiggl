# Jiggl

Partyspiele fürs iPhone (SwiftUI, iOS 17+). Das erste Spiel ist **Der Dümmste fliegt**. Alle spielen an einem Gerät. Wer falsch antwortet, verliert ein Leben, und die letzten zwei spielen ein Finale.

## Projekt öffnen

Das Xcode-Projekt wird aus `project.yml` erzeugt ([XcodeGen](https://github.com/yonaskolb/XcodeGen)):

```bash
xcodegen generate && open DDF.xcodeproj
```

## Aufbau

```
DDF/
  Core/        Spiel-Logik ohne UI und ohne Uhr: Models, GameEngine (Zustandsautomat), QuestionDeck, QuestionBank
  Session/     GameSession (Timer, Pause), AppModel (Spieler, Einstellungen, gespeichert), DemoLauncher (nur Debug)
  Design/      „Quatsch“-Design-System: Theme (Farben `Q`, Schrift `QFont`), Components (Sticker, Knöpfe, Spieler-Avatare, Timer, Konfetti)
  Features/    Screens: Home (Start, Regeln, Spieler) und Game (Frage, Rauswurf, Abstimmung, Finale, Sieger)
  Resources/   Fragen als JSON (`questions_*.json`), optional Schriften (`Fonts/`)
DDFTests/      Tests der Spiel-Logik (Swift Testing)
```

- **GameEngine** entscheidet nur, was als Nächstes passiert (`Phase`). Sie ist deterministisch (Seed) und vollständig getestet.
- **GameSession** ergänzt die Zeit: Antwort-Timer, Rundenuhr im Abstimmungs-Modus, Pause.
- **GameView** zeigt je Phase einen Screen. Frage und Auflösung teilen sich einen Screen, damit die Animation durchläuft.

## Fragen hinzufügen

Weitere Dateien `DDF/Resources/questions_<name>.json` werden automatisch geladen:

```json
{"id":"x001","c":"Kategorie","d":2,"q":"Frage?","a":"Richtige Antwort","w":["Falsch 1","Falsch 2","Falsch 3"]}
```

- `d` ist die Schwierigkeit: 1 = leicht, 2 = mittel, 3 = schwer. Je weiter das Spiel ist, desto schwerer werden die Fragen.
- `w` enthält die falschen Antworten. Fragen ohne mindestens drei falsche Antworten erscheinen nur im Spielleiter-Modus.
- Jede `id` muss eindeutig sein.
- **Wahr oder falsch:** Die Frage ist eine Aussage, `a` ist `"Wahr"` oder `"Falsch"` und `w` enthält nur das Gegenteil. Im Multiple-Choice-Modus erscheinen dann zwei große Knöpfe.

```json
{"id":"geo029","c":"Geografie","d":1,"q":"Deutschland liegt in Asien.","a":"Falsch","w":["Wahr"]}
```

Aktuell gibt es gut 7.500 Fragen in 14 Kategorien (rund 500 je Kategorie, davon etwa 2.300 Wahr-oder-falsch-Aussagen). Außer `questions_de_basis.json` enthält jede Datei genau eine Kategorie.

## Design

Jeder Screen hat eine kräftige Vollfarbe ohne Muster. Darauf weiße Karten, bunte Sticker mit weißem Rand und weichem Schatten, runde fette Schrift. Die Farben stehen in `Q` (`DDF/Design/Theme.swift`), die Bausteine in `DDF/Design/Components/Stickers.swift`:

- `.sticker(farbe)` für bunte Flächen, `.card()` für weiße Karten
- `QButtonStyle` (schwarze Pille als Standard), `QIconButtonStyle`, `QPillStyle`
- `PlayerAvatar`, `PlayerChip`, `StickerLabel`, `HeartsRow`, `TimerBar`, `Confetti`

## Marke

Die Marke besteht aus dem Namen **Jiggl** und dem Maskottchen **Wabbel**. Sie ist spielneutral: Jedes Spiel bringt nur eine Farbe und einen Titel mit.

- `JigglLogo` (`DDF/Design/Components/JigglLogo.swift`): Schriftzug als pinker Sticker mit weißem Rand, der i-Punkt ist ein hüpfender Wackelpudding-Würfel. Antippen schickt eine Welle durchs Wort.
- `JigglBadge`: kleiner Wabbel plus Schriftzug für Fußzeilen (Regeln, Teilen-Karte).
- `SplashView`: Wabbel plumpst herein, „Jiggl“ ploppt auf, dann geht es nahtlos in die blaue Startseite über.
- Markenfarbe `Q.brand` (Pink), Startbildschirm-Farbe `Q.launch` (Blau, auch als Asset `LaunchBackground`).
- App-Icon: `AppIconArt`. Mit `-demo brand` zeigt die App alle Markenteile und legt das Icon als `Documents/AppIcon.png` im Simulator ab, das dann nach `Assets.xcassets/AppIcon.appiconset/` kopiert wird.

## Maskottchen Wabbel

`WabbelView` (`DDF/Design/Components/Wabbel.swift`) zeigt das Bild `Wabbel` aus den Assets und lässt es wie Wackelpudding wabbeln: `.idle`, `.cheer` (wird grün und hüpft), `.explode` (bläst sich auf und zerplatzt). Antippen lässt ihn wackeln.

- Original von ChatGPT: `Design/Mascot/source/`
- Freistellen auf dem Mac (Vision, füllt Löcher in der Figur auf):
  `swiftc -O Design/Mascot/cutout.swift -o /tmp/cutout && /tmp/cutout eingabe.webp ausgabe.png`
- Die flachen SVG-Entwürfe in `Design/Mascot/svg/` sind nur für kleine Sticker gedacht.

## Schrift

Titel sind für **Lilita One** gebaut (kostenlos, OFL, von Google Fonts). Liegt `LilitaOne-Regular.ttf` in `DDF/Resources/Fonts/`, wird sie automatisch genutzt. Sonst greift SF Pro Rounded in Black. Fließtext ist immer SF Pro Rounded.

## Demo-Starts (Debug)

Mit dem Startargument `-demo <szene>` springt die App direkt in eine Spielphase. Das ist praktisch für Design-Reviews:

- **Fragen:** `question`, `mc`, `tf` (Wahr oder falsch), `hosttf` (Wahr oder falsch mit Spielleiter, beantwortet), `feedback` (falsch), `correct` (richtig)
- **Ablauf:** `turn`, `elimination`, `finale`, `duel` (Finalfrage), `winner`
- **Abstimmung:** `vote`, `ballot`, `voteresult`

`-showSettings` öffnet direkt die Regeln.
