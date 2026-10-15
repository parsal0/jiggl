import SwiftUI

struct SettingsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    /// Welcher Wert gerade frei eingegeben wird.
    private enum CustomField: String, Identifiable {
        case lives, roundMinutes, answerTime, finaleLives
        var id: String { rawValue }

        var title: String {
            switch self {
            case .lives: "Eigene Anzahl Leben"
            case .roundMinutes: "Eigene Rundenlänge"
            case .answerTime: "Eigene Zeit pro Antwort"
            case .finaleLives: "Eigene Leben im Finale"
            }
        }

        var range: ClosedRange<Int> {
            switch self {
            case .lives, .finaleLives: GameSettings.customLivesRange
            case .roundMinutes: GameSettings.customRoundMinutesRange
            case .answerTime: GameSettings.customAnswerTimeRange
            }
        }

        var unit: String {
            switch self {
            case .lives, .finaleLives: "Leben"
            case .roundMinutes: "Minuten"
            case .answerTime: "Sekunden"
            }
        }
    }

    @State private var editing: CustomField?
    @State private var draft = ""

    private static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

    var body: some View {
        @Bindable var model = model
        let s = model.settings
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .center) {
                    Text("Regeln").font(.q(40))
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .buttonStyle(QIconButtonStyle(size: 44))
                        .accessibilityLabel("Schließen")
                }

                section("Wer fliegt?", hint: s.eliminationMode == .lives
                        ? "Jede falsche Antwort kostet ein Leben."
                        : "Gespielt wird in Runden. Danach stimmen alle ab, wer der Dümmste war.") {
                    pill("Leben", selected: s.eliminationMode == .lives) { model.settings.eliminationMode = .lives }
                    pill("Abstimmung", selected: s.eliminationMode == .vote) { model.settings.eliminationMode = .vote }
                }

                section("Leben", hint: s.eliminationMode == .vote ? "Wer abgewählt wird, verliert ein Leben." : nil) {
                    ForEach(GameSettings.livesRange, id: \.self) { n in
                        pill("\(n)", tint: Q.red, selected: s.lives == n) { model.settings.lives = n }
                    }
                    customPill(value: GameSettings.livesRange.contains(s.lives) ? nil : "\(s.lives)", tint: Q.red, field: .lives)
                }

                if s.eliminationMode == .vote {
                    section("Rundenlänge", hint: s.hasRoundTimer ? nil
                            : "Die Runde läuft, bis ihr oben auf „Runde beenden“ tippt.") {
                        ForEach(GameSettings.roundDurationOptions, id: \.self) { sec in
                            pill("\(sec / 60) Min.", tint: Q.pink, selected: s.roundDuration == sec) { model.settings.roundDuration = sec }
                        }
                        customPill(value: s.hasRoundTimer && !GameSettings.roundDurationOptions.contains(s.roundDuration)
                                   ? "\(s.roundDuration / 60) Min." : nil, tint: Q.pink, field: .roundMinutes)
                        pill("∞ Ohne Limit", tint: Q.pink, selected: !s.hasRoundTimer) { model.settings.roundDuration = 0 }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                section("Zeit pro Antwort", hint: s.hasAnswerTimer ? nil : "Kein Countdown. Der Spielleiter entscheidet, wann Schluss ist.") {
                    ForEach(GameSettings.answerTimeOptions, id: \.self) { sec in
                        pill("\(sec) s", tint: Q.orange, selected: s.answerTime == sec) { model.settings.answerTime = sec }
                    }
                    customPill(value: s.hasAnswerTimer && !GameSettings.answerTimeOptions.contains(s.answerTime)
                               ? "\(s.answerTime) s" : nil, tint: Q.orange, field: .answerTime)
                    pill("∞ Ohne Limit", tint: Q.orange, selected: !s.hasAnswerTimer) { model.settings.answerTime = 0 }
                }

                section("Wer entscheidet?", hint: s.answerMode == .host
                        ? "Ein Spielleiter liest vor, sieht die Lösung und drückt „Richtig“ oder „Falsch“."
                        : "Vier Antworten zur Auswahl, die App prüft.") {
                    pill("Spielleiter", tint: Q.purple, selected: s.answerMode == .host) { model.settings.answerMode = .host }
                    pill("Multiple Choice", tint: Q.purple, selected: s.answerMode == .multipleChoice) { model.settings.answerMode = .multipleChoice }
                }

                categorySection

                section("Leben im Finale", hint: "Die letzten zwei spielen ein Duell mit frischen Leben.") {
                    ForEach(1...5, id: \.self) { n in
                        pill("\(n)", tint: Q.green, selected: s.finaleLives == n) { model.settings.finaleLives = n }
                    }
                    customPill(value: (1...5).contains(s.finaleLives) ? nil : "\(s.finaleLives)", tint: Q.green, field: .finaleLives)
                }

                reportSection

                VStack(spacing: 4) {
                    JigglBadge(size: 22)
                    Text("Version \(Self.version)")
                        .font(.qBody(12, .semibold))
                        .foregroundStyle(Q.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
            }
            .padding(22)
            .padding(.bottom, 20)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.settings)
        }
        .foregroundStyle(Q.ink)
        .background(Q.bg.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .alert(editing?.title ?? "", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } }), presenting: editing) { field in
            TextField(field.unit, text: $draft)
                .keyboardType(.numberPad)
            Button("Übernehmen") { apply(field) }
            Button("Abbrechen", role: .cancel) {}
        } message: { field in
            Text("\(field.range.lowerBound) bis \(field.range.upperBound) \(field.unit)")
        }
    }

    /// Kategorien an- und abwählen. Neue Fragen kommen zuerst, gesehene erst danach.
    private var categorySection: some View {
        let excluded = model.settings.excludedCategories
        let active = model.categories.filter { !excluded.contains($0.name) }
        let poolCount = model.questionPool.count
        return section("Kategorien", hint: active.isEmpty
                       ? "Keine Kategorie an. Wähle mindestens eine."
                       : "\(poolCount) Fragen im Spiel. Neue Fragen kommen zuerst, schon gespielte erst, wenn alle durch sind.") {
            pill("Alle", tint: Q.orange, selected: excluded.isEmpty) { model.setAllCategories(enabled: true) }
            pill("Keine", tint: Q.orange, selected: active.isEmpty) { model.setAllCategories(enabled: false) }
            ForEach(model.categories, id: \.name) { category in
                let on = !excluded.contains(category.name)
                pill(category.name, tint: Q.categoryColor(category.name), selected: on) {
                    model.setCategory(category.name, enabled: !on)
                }
                .accessibilityValue(on ? "an" : "aus")
            }
        }
    }

    /// Beim Spielen gemeldete Fragen. Lange auf die Frage drücken, um sie zu melden.
    @ViewBuilder private var reportSection: some View {
        let count = model.reports.count
        section("Gemeldete Fragen", hint: count == 0
                ? "Ist eine Frage falsch oder unklar? Im Spiel lange auf die Frage drücken und melden."
                : "\(count) gemeldet. Teile die Liste, damit die Fragen korrigiert werden können.") {
            if count > 0 {
                ShareLink(item: model.reportsText) {
                    Label("Liste teilen", systemImage: "square.and.arrow.up").labelStyle(.titleAndIcon)
                }
                .buttonStyle(QPillStyle(selected: true, tint: Q.blue))
                pill("Liste leeren", tint: Q.red, selected: false) { model.clearReports() }
            }
        }
    }

    private func section<Content: View>(_ title: String, hint: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.q(20))
            FlowLayout(spacing: 10, lineSpacing: 10) { content() }
            if let hint {
                Text(hint)
                    .font(.qBody(15, .medium))
                    .foregroundStyle(Q.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func pill(_ label: String, tint: Color = Q.blue, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .buttonStyle(QPillStyle(selected: selected, tint: tint))
            .sensoryFeedback(.selection, trigger: selected)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// „Eigene“-Pille. Ist ein eigener Wert gesetzt, zeigt sie ihn an und ist ausgewählt.
    private func customPill(value: String?, tint: Color, field: CustomField) -> some View {
        pill(value.map { "✎ \($0)" } ?? "✎ Eigene", tint: tint, selected: value != nil) {
            draft = ""
            editing = field
        }
        .accessibilityLabel(value.map { "Eigener Wert \($0), ändern" } ?? "Eigenen Wert eingeben")
    }

    private func apply(_ field: CustomField) {
        guard let n = Int(draft.trimmingCharacters(in: .whitespaces)) else { return }
        let v = min(max(n, field.range.lowerBound), field.range.upperBound)
        switch field {
        case .lives: model.settings.lives = v
        case .roundMinutes: model.settings.roundDuration = v * 60
        case .answerTime: model.settings.answerTime = v
        case .finaleLives: model.settings.finaleLives = v
        }
    }
}

/// Spieler anlegen oder bearbeiten: Name, Farbe, beim Bearbeiten auch entfernen.
struct PlayerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var editing: Player?

    @State private var name = ""
    @State private var colorIndex = 0
    @State private var handicap = 0
    @FocusState private var focused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                // Der eigene Wabbel. Er hüpft kurz, wenn man eine neue Farbe wählt.
                WabbelView(mood: .idle, size: 64, playerColor: colorIndex)
                    .id(colorIndex)
                    .transition(.scale.combined(with: .opacity))
                Text(editing == nil ? "Neuer Spieler" : "Spieler bearbeiten").font(.q(28))
            }

            TextField("", text: $name, prompt: Text("Name").foregroundStyle(Q.ink.opacity(0.3)))
                .font(.qBody(24, .heavy))
                .foregroundStyle(Q.ink)
                .tint(Q.blue)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focused)
                .onSubmit(save)
                .padding(.horizontal, 20)
                .frame(height: 60)
                .card(radius: 20)

            HStack(spacing: 0) {
                ForEach(Q.playerColors.indices, id: \.self) { i in
                    // Jeder Spieler wählt einen Wabbel in seiner Farbe.
                    Button { colorIndex = i } label: {
                        WabbelView(mood: .idle, size: 36, playerColor: i, animated: false)
                            .allowsHitTesting(false)
                            .padding(.bottom, 6)
                            .overlay(alignment: .bottom) {
                                Capsule().fill(Q.ink).frame(width: 18, height: 4)
                                    .opacity(colorIndex == i ? 1 : 0)
                            }
                            .scaleEffect(colorIndex == i ? 1.22 : 0.92)
                            .opacity(colorIndex == i ? 1 : 0.75)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Wabbel \(i + 1)")
                    .accessibilityAddTraits(colorIndex == i ? .isSelected : [])
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: colorIndex)
            .sensoryFeedback(.selection, trigger: colorIndex)

            VStack(alignment: .leading, spacing: 8) {
                Text("Fragen").font(.q(18))
                HStack(spacing: 8) {
                    ForEach(Handicap.allCases) { h in
                        Button { handicap = h.rawValue } label: {
                            Label(h.label, systemImage: h.symbol).labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(QPillStyle(selected: handicap == h.rawValue, tint: h.color))
                        .sensoryFeedback(.selection, trigger: handicap)
                    }
                }
                Text(Handicap(rawValue: handicap)?.hint ?? "")
                    .font(.qBody(13, .medium))
                    .foregroundStyle(Q.muted)
            }

            Button(editing == nil ? "Hinzufügen" : "Speichern", action: save)
                .buttonStyle(QButtonStyle())
                .disabled(trimmed.isEmpty)

            if let editing {
                Button(role: .destructive) {
                    withAnimation(.spring) { model.removePlayer(editing.id) }
                    dismiss()
                } label: {
                    Label("Entfernen", systemImage: "trash")
                        .font(.qBody(17, .heavy))
                        .foregroundStyle(Q.red)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
        }
        .padding(22)
        .frame(maxHeight: .infinity, alignment: .top)
        .foregroundStyle(Q.ink)
        .background(Q.bg.ignoresSafeArea())
        .presentationDetents([.height(editing == nil ? 470 : 530)])
        .presentationCornerRadius(32)
        .onAppear {
            if let editing {
                name = editing.name
                colorIndex = editing.colorIndex
                handicap = editing.handicap
            } else {
                let used = Set(model.players.map(\.colorIndex))
                colorIndex = Q.playerColors.indices.first { !used.contains($0) } ?? model.players.count % Q.playerColors.count
                focused = true
            }
        }
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            if let editing {
                model.updatePlayer(editing.id, name: trimmed, colorIndex: colorIndex, handicap: handicap)
            } else {
                model.addPlayer(named: trimmed, colorIndex: colorIndex, handicap: handicap)
            }
        }
        dismiss()
    }
}

/// Handicap pro Spieler: verschiebt die Schwierigkeit der Fragen um eine Stufe.
enum Handicap: Int, CaseIterable, Identifiable {
    case easier = -1, normal = 0, harder = 1
    var id: Int { rawValue }

    var label: String {
        switch self {
        case .easier: "Leichter"
        case .normal: "Normal"
        case .harder: "Schwerer"
        }
    }

    var symbol: String {
        switch self {
        case .easier: "tortoise.fill"
        case .normal: "equal"
        case .harder: "flame.fill"
        }
    }

    var color: Color {
        switch self {
        case .easier: Q.green
        case .normal: Q.blue
        case .harder: Q.red
        }
    }

    var hint: String {
        switch self {
        case .easier: "Bekommt leichtere Fragen als alle anderen, z. B. für Jüngere."
        case .normal: "Bekommt dieselben Fragen wie alle."
        case .harder: "Bekommt schwerere Fragen, z. B. für Klugscheißer."
        }
    }
}
