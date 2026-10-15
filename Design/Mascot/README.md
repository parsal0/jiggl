# Wabbel

Wabbel besteht aus Einzelteilen. Körper, Arme und Füße sind Bilder, das Gesicht (Augen, Brauen, Mund)
wird in `DDF/Design/Components/Wabbel.swift` gezeichnet.

- `source/v2/`: Originale von ChatGPT (Körper, Arme, Füße, Komplettbild ohne Gesicht, Referenz mit Gesicht)
- `split.swift <bild> <präfix>`: schneidet jedes Teil eines Bildes einzeln aus (links/rechts)
- `export.swift <teil.png> <Name.imageset> <breite>`: verkleinert ein Teil und legt es im Asset-Katalog ab

Alle Ausdrücke ansehen: App mit dem Startargument `-demo wabbel` starten.
