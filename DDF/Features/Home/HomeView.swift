import SwiftUI

/// Vergleich der Startseiten-Varianten per Startargument `-homeStyle a` oder `-homeStyle b`.
/// Ohne Argument: der heutige Stand. Fliegt raus, sobald eine Variante gewählt ist.
private enum HomeStyle {
    case current, refined, cards

    static let active: HomeStyle = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-homeStyle"), i + 1 < args.count else { return .current }
        return switch args[i + 1] { case "a": .refined; case "b": .cards; default: .current }
    }()
}

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showSettings = false
    @State private var showAddPlayer = false
    @State private var editing: Player?
    @State private var appeared = false
    @State private var wabbelMood: WabbelView.Mood = .land
    @State private var reaction = 0
    @State private var confirmClear = false
    /// Kurzer Moment zwischen Tippen auf „Los geht’s“ und Spielstart.
    @State private var launching = false
    private let style = HomeStyle.active

    var body: some View {
        ZStack {
            Q.blue.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    topBar
                    gameCard
                    if style == .cards {
                        playersCard
                        rulesCard
                    } else {
                        playersSection
                        rulesSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) { startBar }
        .sheet(isPresented: $showSettings) { SettingsSheet() }
        .sheet(isPresented: $showAddPlayer) { PlayerSheet() }
        .sheet(item: $editing) { PlayerSheet(editing: $0) }
        .onChange(of: model.players) { old, new in react(from: old, to: new) }
        .confirmationDialog("Alle Spieler entfernen?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Alle entfernen", role: .destructive) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { model.removeAllPlayers() }
            }
        } message: {
            Text("Nach dem nächsten Spiel könnt ihr diese Runde mit „Gleiche Runde wie letztes Mal“ zurückholen.")
        }
        .task(id: reaction) {
            // Nach dem Plumpsen bzw. nach einer Reaktion wieder in Grundstimmung.
            try? await Task.sleep(for: .seconds(reaction == 0 ? 2.0 : 2.8))
            guard !Task.isCancelled else { return }
            wabbelMood = model.players.isEmpty ? .sad : .idle
        }
        .onAppear {
            appeared = true
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-showSettings") { showSettings = true }
            #endif
        }
    }

    private var topBar: some View {
        HStack {
            JigglLogo(size: 40)
            Spacer()
            Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                .buttonStyle(QIconButtonStyle())
                .accessibilityLabel("Regeln")
        }
    }

    private var gameCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Der Dümmste\nfliegt")
                .font(.q(style == .current ? 46 : 50))
                .lineSpacing(-4)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
            Text(cardSubtitle)
                .font(.qBody(16, .semibold))
                .foregroundStyle(Q.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Q.ink)
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 30)
        .overlay(alignment: .topTrailing) {
            WabbelView(mood: wabbelMood, size: 124).offset(x: 0, y: -72)
        }
        .padding(.top, 48)
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.55, dampingFraction: 0.7), value: appeared)
    }

    /// Wabbel jubelt und der Knopf federt, dann fährt das Spiel herein.
    private func launch() {
        guard model.canStart, !launching else { return }
        launching = true
        wabbelMood = .cheer
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            model.startGame()
            launching = false
            wabbelMood = .idle
        }
    }

    /// Wabbel winkt neuen Spielern und ist traurig, wenn jemand geht.
    private func react(from old: [Player], to new: [Player]) {
        if new.count > old.count {
            wabbelMood = wabbelMood == .wave ? .present : .wave
        } else if new.count < old.count {
            wabbelMood = .sad
        } else {
            return
        }
        reaction += 1
    }

    private var cardSubtitle: String {
        model.settings.eliminationMode == .lives
            ? "Wer falsch antwortet, verliert ein Leben. Die letzten zwei spielen das Finale."
            : "Ihr spielt auf Zeit, danach stimmt ihr ab, wer der Dümmste war."
    }

    private var playersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Wer spielt mit?", trailing: "\(model.players.count) / \(AppModel.maxPlayers)")

            FlowLayout(spacing: 10, lineSpacing: 12) {
                ForEach(Array(model.players.enumerated()), id: \.element.id) { index, player in
                    Button { editing = player } label: {
                        PlayerChip(player: player, tilt: style == .current ? stickerTilt(index) : 0)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Bearbeiten oder entfernen")
                    .scaleEffect(appeared ? 1 : 0.3)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.45, dampingFraction: 0.55).delay(0.1 + Double(index) * 0.05), value: appeared)
                        .transition(.scale.combined(with: .opacity))
                }
                if model.players.count < AppModel.maxPlayers {
                    Button { showAddPlayer = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 46, height: 46)
                            .overlay(Circle().strokeBorder(.white.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
                    }
                    .accessibilityLabel("Spieler hinzufügen")
                }
            }

            Text(model.startHint ?? "Tippt auf einen Spieler, um ihn zu bearbeiten oder zu entfernen.")
                .font(.qBody(13, .semibold))
                .foregroundStyle(.white.opacity(0.75))

            if model.canRestoreLastGroup || !model.players.isEmpty {
                HStack(spacing: 10) {
                    if model.canRestoreLastGroup {
                        Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { model.restoreLastGroup() } } label: {
                            Label("Gleiche Runde wie letztes Mal", systemImage: "arrow.counterclockwise")
                                .lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .font(.qBody(14, .heavy))
                        .foregroundStyle(Q.ink)
                        .padding(.horizontal, 14).frame(height: 40)
                        .background(Capsule().fill(Q.surface))
                        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                        .accessibilityHint(model.lastGroup.map(\.name).joined(separator: ", "))
                    }
                    if !model.players.isEmpty {
                        Button("Neue Runde") { confirmClear = true }
                            .font(.qBody(14, .heavy))
                            .foregroundStyle(.white)
                            .underline()
                            .accessibilityHint("Entfernt alle Spieler")
                    }
                }
            }
        }
    }

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionHeader("Regeln")
                Spacer()
                Button("Ändern") { showSettings = true }
                    .font(.qBody(15, .heavy))
                    .foregroundStyle(.white)
                    .underline()
            }
            if style == .refined {
                ruleGrid
            } else {
                ruleFlow
            }
        }
    }

    /// Regeln als eine weiße Karte mit vier ruhigen Feldern.
    private var ruleGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], alignment: .leading, spacing: 14) {
            ForEach(ruleChips, id: \.text) { chip in
                HStack(spacing: 10) {
                    Image(systemName: chip.icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(chip.color)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(chip.color.opacity(0.14)))
                    Text(chip.text)
                        .font(.qBody(14, .heavy))
                        .foregroundStyle(Q.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .padding(16)
        .card(radius: 22)
        .contentShape(Rectangle())
        .onTapGesture { showSettings = true }
    }

    private var ruleFlow: some View {
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(ruleChips, id: \.text) { chip in
                    HStack(spacing: 7) {
                        Image(systemName: chip.icon).foregroundStyle(chip.color)
                        Text(chip.text).foregroundStyle(Q.ink)
                    }
                    .font(.qBody(14, .bold))
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Capsule().fill(Q.surface))
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                }
            }
            .onTapGesture { showSettings = true }
    }

    // MARK: - Variante „Karten“

    private var playersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Wer spielt mit?").font(.q(22))
                Spacer()
                Text("\(model.players.count) / \(AppModel.maxPlayers)").font(.qBody(14, .bold)).foregroundStyle(Q.muted).monospacedDigit()
            }
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(model.players) { player in
                    Button { editing = player } label: {
                        HStack(spacing: 8) {
                            PlayerAvatar(player: player, size: 30)
                            Text(player.name).font(.qBody(16, .heavy)).foregroundStyle(Q.ink).lineLimit(1)
                        }
                        .padding(.leading, 5).padding(.trailing, 14).padding(.vertical, 5)
                        .background(Capsule().fill(Q.bg))
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
                if model.players.count < AppModel.maxPlayers {
                    Button { showAddPlayer = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(Q.ink)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Q.bg))
                    }
                    .accessibilityLabel("Spieler hinzufügen")
                }
            }
            if let hint = model.startHint {
                Text(hint).font(.qBody(13, .semibold)).foregroundStyle(Q.muted)
            }
            if model.canRestoreLastGroup || !model.players.isEmpty {
                HStack {
                    if model.canRestoreLastGroup {
                        Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { model.restoreLastGroup() } } label: {
                            Label("Gleiche Runde wie letztes Mal", systemImage: "arrow.counterclockwise")
                        }
                        .foregroundStyle(Q.blue)
                    }
                    Spacer()
                    if !model.players.isEmpty {
                        Button("Neue Runde") { confirmClear = true }.foregroundStyle(Q.muted)
                    }
                }
                .font(.qBody(14, .heavy))
            }
        }
        .foregroundStyle(Q.ink)
        .padding(18)
        .card(radius: 26)
    }

    private var rulesCard: some View {
        Button { showSettings = true } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Regeln").font(.q(22))
                    Spacer()
                    Text("Ändern").font(.qBody(14, .heavy)).foregroundStyle(Q.blue)
                }
                .padding(.bottom, 8)
                ForEach(Array(ruleChips.enumerated()), id: \.element.text) { index, chip in
                    if index > 0 { Divider().overlay(Q.line) }
                    HStack(spacing: 12) {
                        Image(systemName: chip.icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(chip.color)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(chip.color.opacity(0.14)))
                        Text(chip.text).font(.qBody(16, .bold))
                        Spacer()
                    }
                    .padding(.vertical, 9)
                }
            }
            .foregroundStyle(Q.ink)
            .padding(18)
            .card(radius: 26)
        }
        .buttonStyle(.plain)
    }

    private struct RuleChip { let icon: String; let text: String; let color: Color }

    private var ruleChips: [RuleChip] {
        let s = model.settings
        return [
            s.eliminationMode == .lives
                ? RuleChip(icon: "heart.fill", text: "\(s.lives) Leben", color: Q.red)
                : RuleChip(icon: "hand.raised.fill",
                           text: s.hasRoundTimer ? "Abstimmung alle \(s.roundDuration / 60) Min." : "Abstimmung, Runde ohne Limit",
                           color: Q.pink),
            RuleChip(icon: "timer", text: s.hasAnswerTimer ? "\(s.answerTime) Sek. pro Frage" : "Ohne Zeitlimit", color: Q.orange),
            s.answerMode == .host
                ? RuleChip(icon: "person.fill.questionmark", text: "Spielleiter", color: Q.purple)
                : RuleChip(icon: "square.grid.2x2.fill", text: "Multiple Choice", color: Q.purple),
            RuleChip(icon: "trophy.fill", text: "Finale mit \(s.finaleLives) Leben", color: Q.yellow)
        ]
    }

    private func sectionHeader(_ title: String, trailing: String? = nil) -> some View {
        HStack {
            Text(title).font(.q(22)).foregroundStyle(.white)
            if let trailing {
                Spacer()
                Text(trailing).font(.qBody(14, .bold)).foregroundStyle(.white.opacity(0.75)).monospacedDigit()
            }
        }
    }

    private var startBar: some View {
        Button("Los geht’s") { launch() }
            .buttonStyle(QButtonStyle(fill: .white, foreground: Q.ink, height: 64, fontSize: 24))
            .disabled(!model.canStart)
            .scaleEffect(launching ? 1.06 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.4), value: launching)
            .sensoryFeedback(.impact(weight: .heavy), trigger: launching) { _, new in new }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .background {
                if style == .current {
                    Q.blue.opacity(0.94).ignoresSafeArea()
                } else {
                    // Weicher Übergang statt harter Kante.
                    LinearGradient(colors: [Q.blue.opacity(0), Q.blue], startPoint: .top, endPoint: .init(x: 0.5, y: 0.35))
                        .ignoresSafeArea()
                }
            }
    }
}
