import SwiftUI

/// Frage mit Countdown. Je knapper die Zeit, desto unruhiger der Screen.
struct QuestionView: View {
    let session: GameSession
    let turn: Turn
    let result: TurnResult?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var peeking = false
    /// Grün bzw. Rot geht bei der Auflösung als Kreis von der Mitte aus auf.
    @State private var burst: CGFloat = 0
    /// „Zurück“ und „Weiter“ werden erst kurz nach der Bewertung tippbar, damit ein Doppeltipp nichts auslöst.
    @State private var afterAnswerArmed = false
    /// Frage melden: lange auf die Karte drücken. Solange das Menü offen ist, steht die Zeit.
    @State private var showReport = false
    @State private var pausedForReport = false
    @State private var reported = false

    /// Wie lange die Auflösung im Multiple-Choice-Modus stehen bleibt, bevor es allein weitergeht.
    private let feedbackDuration = 1.9

    /// Mit Spielleiter geht es nicht von selbst weiter. Er wählt „Zurück“ oder „Weiter“.
    private var isHost: Bool { session.settings.answerMode == .host }

    private static let answerFills: [Color] = [Q.blue, Q.pink, Q.orange, Q.purple]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: result != nil || session.isPaused)) { context in
            let hasTimer = session.settings.hasAnswerTimer
            let total = Double(max(session.settings.answerTime, 1))
            let remaining = result == nil && hasTimer ? session.turnRemaining(at: context.date) : 0
            let fraction = hasTimer ? remaining / total : 1
            let secondsLeft = Int(remaining.rounded(.up))
            let t = context.date.timeIntervalSinceReferenceDate
            let panic = result == nil && hasTimer && !reduceMotion ? max(0, (0.2 - fraction) / 0.2) : 0

            ZStack {
                Q.categoryColor(turn.question.category).ignoresSafeArea()
                feedbackColor
                    .ignoresSafeArea()
                    .clipShape(RevealShape(progress: burst, origin: UnitPoint(x: 0.5, y: 0.45)))

                VStack(spacing: 0) {
                    header.padding(.top, 60)
                    if hasTimer {
                        timerRow(fraction: fraction, secondsLeft: secondsLeft, panic: panic).padding(.top, 18)
                    }
                    Spacer(minLength: 16)
                    questionCard(nervous: result == nil && hasTimer && fraction < 0.34)
                        .onLongPressGesture(minimumDuration: 0.6) { openReport() }
                        .sensoryFeedback(.impact(weight: .medium), trigger: showReport) { _, new in new }
                        .accessibilityAction(named: "Frage melden") { openReport() }
                        .rotationEffect(.degrees(-1 + sin(t * 31) * 1.6 * panic))
                        .offset(x: sin(t * 42) * 3 * panic)
                    Spacer(minLength: 16)
                    answerArea
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                if let result { stamp(for: result) }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: secondsLeft) { _, new in
                hasTimer && result == nil && new <= 5 && new > 0
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Tipp irgendwo auf den Screen wirkt wie „Weiter“. Mit Spielleiter erst, wenn die Knöpfe scharf sind.
            guard result != nil, !isHost || afterAnswerArmed else { return }
            session.continueAfterFeedback()
        }
        .sensoryFeedback(trigger: result) { _, new in
            guard let new else { return nil }
            return new.outcome.isCorrect ? .success : .error
        }
        .onChange(of: result) { _, new in
            afterAnswerArmed = false
            guard new != nil else {
                burst = 0
                return
            }
            if reduceMotion {
                burst = 1
            } else {
                withAnimation(.easeOut(duration: 0.45)) { burst = 1 }
            }
        }
        .task(id: result) {
            guard result != nil else { return }
            if isHost {
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.2)) { afterAnswerArmed = true }
                return
            }
            try? await Task.sleep(for: .seconds(feedbackDuration))
            // Während der Pause nicht weiterspringen.
            while session.isPaused, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
            }
            guard !Task.isCancelled else { return }
            session.continueAfterFeedback()
        }
        .confirmationDialog("Frage melden", isPresented: $showReport, titleVisibility: .visible) {
            ForEach(QuestionReport.Reason.allCases, id: \.self) { reason in
                Button(reason.label) {
                    session.report(turn.question, reason: reason)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { reported = true }
                }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die Meldung wird gespeichert. In den Regeln kannst du die Liste teilen.")
        }
        .onChange(of: showReport) { _, open in
            guard !open, pausedForReport else { return }
            pausedForReport = false
            session.resume()
        }
        .onAppear {
            appeared = true
            if result != nil { burst = 1 }
        }
    }

    // MARK: - Teile

    /// Grün oder Rot bei der Auflösung.
    private var feedbackColor: Color {
        switch result?.outcome {
        case .correct: Q.correct
        case .wrong: Q.wrong
        case .timeout, nil: Q.orange
        }
    }

    private var header: some View {
        let state = session.player(turn.playerID)
        return Group {
            if session.engine.isFinale {
                DuelBar(session: session)
            } else {
                playerHeader(state)
            }
        }
    }

    private func playerHeader(_ state: PlayerState?) -> some View {
        HStack(alignment: .center) {
            if let player = state?.player {
                PlayerChip(player: player, size: 17, tilt: -2)
            }
            Spacer()
            if let state, session.engine.wrongAnswersCostLives {
                HeartsRow(lives: state.lives,
                          maxLives: session.engine.isFinale ? session.settings.finaleLives : session.settings.lives,
                          size: 22)
            }
        }
    }


    private func timerRow(fraction: Double, secondsLeft: Int, panic: Double) -> some View {
        HStack(spacing: 12) {
            TimerBar(remainingFraction: result == nil ? fraction : 0)
            Text(result == nil ? "\(secondsLeft)" : "0")
                .font(.q(20))
                .monospacedDigit()
                .foregroundStyle(fraction > 0.25 ? Q.ink : Q.red)
                .frame(width: 46, height: 46)
                .background(Circle().fill(.white))
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                .scaleEffect(1 + 0.12 * panic)
                .accessibilityLabel("\(secondsLeft) Sekunden")
        }
        .opacity(result == nil ? 1 : 0.4)
    }

    private func questionCard(nervous: Bool) -> some View {
        let categoryColor = Q.categoryColor(turn.question.category)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(turn.question.category.uppercased())
                    .font(.qBody(12, .heavy))
                    .tracking(0.8)
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(categoryColor))
                if reported {
                    Label("GEMELDET", systemImage: "flag.fill")
                        .font(.qBody(12, .heavy))
                        .tracking(0.8)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(Q.ink))
                        .transition(.scale.combined(with: .opacity))
                } else if turn.question.isTrueFalse {
                    Text("WAHR ODER FALSCH?")
                        .font(.qBody(12, .heavy))
                        .tracking(0.8)
                        .foregroundStyle(Q.ink)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(Q.ink.opacity(0.08)))
                }
            }
            Text(turn.question.text)
                .font(.q(34))
                .foregroundStyle(Q.ink)
                .lineLimit(6)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 28)
        // Wabbel sitzt auf der Karte und guckt mit. Läuft die Zeit ab, wird er nervös.
        .overlay(alignment: .topTrailing) {
            if result == nil {
                WabbelView(mood: nervous ? .nervous : .idle, size: 78)
                    .offset(x: 2, y: -64)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .offset(y: appeared ? 0 : 60)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: appeared)
    }

    @ViewBuilder private var answerArea: some View {
        if isHost, turn.question.isTrueFalse {
            // Der Spielleiter tippt, was der Spieler sagt. Ob das stimmt, prüft das Spiel.
            if result != nil {
                afterAnswerControls(height: 110)
            } else {
                choiceGrid
            }
        } else if isHost {
            hostControls
        } else {
            choiceGrid
        }
    }

    private var choiceGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(Array(turn.options.enumerated()), id: \.offset) { index, option in
                Button { session.choose(option: index) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: symbol(forOption: index))
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(result == nil ? Self.answerFills[index % 4] : .white.opacity(0.25)))
                        Text(option)
                            .font(.qBody(18, .heavy))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                }
                .buttonStyle(QButtonStyle(fill: fill(forOption: index), foreground: textColor(forOption: index),
                                          height: turn.question.isTrueFalse ? 110 : 78, radius: 22))
                .opacity(dim(option: index) ? 0.5 : 1)
                .allowsHitTesting(result == nil)
                .scaleEffect(appeared ? 1 : 0.4)
                .animation(.spring(response: 0.45, dampingFraction: 0.55).delay(0.12 + Double(index) * 0.06), value: appeared)
            }
        }
    }

    private func symbol(forOption index: Int) -> String {
        if let result {
            if index == turn.correctOptionIndex { return "checkmark" }
            if index == result.chosenOption { return "xmark" }
        }
        if turn.question.isTrueFalse { return index == 0 ? "hand.thumbsup.fill" : "hand.thumbsdown.fill" }
        return ["a", "b", "c", "d"][index] + ".circle.fill"
    }

    private func fill(forOption index: Int) -> Color {
        guard let result else { return .white }
        if index == turn.correctOptionIndex { return Q.correct }
        if index == result.chosenOption { return Q.wrong }
        return .white
    }

    private func textColor(forOption index: Int) -> Color {
        fill(forOption: index) == .white ? Q.ink : .white
    }

    private func dim(option index: Int) -> Bool {
        guard let result else { return false }
        return index != turn.correctOptionIndex && index != result.chosenOption
    }

    private var hostControls: some View {
        let revealed = peeking || result != nil
        return VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: revealed ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(revealed ? Q.correct : Q.muted)
                Text(revealed ? solutionText : "Lösung: gedrückt halten")
                    .font(revealed ? .q(22) : .qBody(16, .bold))
                    .foregroundStyle(revealed ? Q.ink : Q.muted)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(height: 56)
            .card(radius: 18)
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(revealed ? Q.correct : .clear, lineWidth: 2.5))
            .onLongPressGesture(minimumDuration: 30, maximumDistance: 60, pressing: { peeking = $0 }, perform: {})
            .sensoryFeedback(.selection, trigger: peeking)
            .accessibilityLabel("Lösung anzeigen")
            .accessibilityAction { peeking.toggle() }

            if result != nil {
                // Gleiche Stelle und Größe wie „Richtig“/„Falsch“. Ein Doppeltipp verpufft, weil die Knöpfe kurz gesperrt sind.
                afterAnswerControls(height: 74)
            } else {
                HStack(spacing: 12) {
                    Button { session.answer(.wrong) } label: {
                        Label("Falsch", systemImage: "xmark").labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(QButtonStyle(fill: .white, foreground: Q.wrong, height: 74, radius: 22))
                    Button { session.answer(.correct) } label: {
                        Label("Richtig", systemImage: "checkmark").labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(QButtonStyle(fill: .white, foreground: Q.correct, height: 74, radius: 22))
                }
                .disabled(result != nil)
            }
        }
    }

    /// Bei Wahr-oder-falsch ganz ausgeschrieben, damit „Falsch“ nicht wie die Bewertung klingt.
    private var solutionText: String {
        guard turn.question.isTrueFalse else { return turn.question.answer }
        return turn.question.answer == Question.trueAnswer ? "Stimmt (wahr)" : "Stimmt nicht (falsch)"
    }

    private func openReport() {
        guard !showReport else { return }
        if !session.isPaused {
            session.pause()
            pausedForReport = true
        }
        showReport = true
    }

    /// Nach der Bewertung: „Zurück“ für Fehlklicks oder „Weiter“ zur nächsten Frage.
    /// Sieht aus wie die Antwortknöpfe, reagiert aber erst nach 0,6 Sekunden.
    private func afterAnswerControls(height: CGFloat) -> some View {
        HStack(spacing: 12) {
            if session.canUndoAnswer {
                Button { session.undoAnswer() } label: {
                    Label("Zurück", systemImage: "arrow.uturn.backward").labelStyle(.titleAndIcon)
                }
                .buttonStyle(QButtonStyle(fill: .white, foreground: Q.ink, height: height, radius: 22))
                .accessibilityHint("Nimmt die letzte Antwort zurück")
            }
            Button { session.continueAfterFeedback() } label: {
                Label("Weiter", systemImage: "arrow.right").labelStyle(.titleAndIcon)
            }
            .buttonStyle(QButtonStyle(fill: .white, foreground: Q.ink, height: height, radius: 22))
        }
        .allowsHitTesting(afterAnswerArmed)
    }

    /// Richtig: Jubel. Falsch: Platzen, Schmelzen, Luft ablassen oder Torkeln. Zeit um: eingeschlafen oder Schulterzucken.
    /// Die Wahl hängt am Ergebnis, damit sie beim Neuzeichnen gleich bleibt.
    private func wabbelMood(for result: TurnResult) -> WabbelView.Mood {
        let pick = abs(result.hashValue)
        return switch result.outcome {
        case .correct: .cheer
        case .wrong: [.explode, .explode, .melt, .deflate, .dizzy][pick % 5]
        case .timeout: [.sleep, .sleep, .shrug][pick % 3]
        }
    }

    private func stamp(for result: TurnResult) -> some View {
        let (text, fill): (String, Color) = switch result.outcome {
        case .correct: ("Richtig!", Q.correct)
        case .wrong: ("Falsch!", Q.wrong)
        case .timeout: ("Zeit um!", Q.orange)
        }
        return VStack(spacing: 14) {
            WabbelView(mood: wabbelMood(for: result), size: 130)
            StickerLabel(text: text, fill: .white, foreground: fill, size: 64, tilt: -6)
            if result.lostLife {
                HeartBreak(delay: result.outcome == .wrong ? 0.6 : 0.3)
            }
        }
        .transition(.scale(scale: 2.2).combined(with: .opacity))
        .allowsHitTesting(false)
    }
}
