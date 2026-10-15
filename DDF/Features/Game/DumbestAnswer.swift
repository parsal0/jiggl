import SwiftUI

/// „Dümmste Antwort des Abends“: eine falsche Antwort auswählen, eintippen, was gesagt wurde, und als Story-Karte teilen.
struct DumbestAnswerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let session: GameSession

    @State private var selected: TurnResult?
    @State private var said = ""
    @State private var rendered: Image?

    private var wrongAnswers: [TurnResult] {
        session.engine.history.filter { !$0.outcome.isCorrect }.reversed()
    }

    var body: some View {
        NavigationStack {
            Group {
                if let selected { cardStep(selected) } else { pickStep }
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Q.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selected != nil {
                        Button { withAnimation { selected = nil } } label: { Label("Zurück", systemImage: "chevron.left") }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }.font(.qBody(17, .heavy))
                }
            }
        }
        .tint(Q.ink)
        .presentationCornerRadius(32)
        #if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-showDumbestCard"), let first = wrongAnswers.first { choose(first) }
        }
        #endif
    }

    // MARK: - Schritt 1: auswählen

    private var pickStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Dümmste Antwort des Abends").font(.q(30)).foregroundStyle(Q.ink)
            Text("Welche falsche Antwort war die beste?")
                .font(.qBody(16, .medium)).foregroundStyle(Q.muted)
            if wrongAnswers.isEmpty {
                Text("Heute lag niemand falsch. Respekt.")
                    .font(.qBody(17, .bold))
                    .foregroundStyle(Q.ink)
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .card()
            }
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(wrongAnswers.enumerated()), id: \.offset) { _, result in
                        Button { choose(result) } label: { row(result) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
        }
        .padding(.top, 8)
    }

    private func row(_ result: TurnResult) -> some View {
        let player = session.player(result.turn.playerID)?.player ?? Player(name: "?", colorIndex: 0)
        return HStack(alignment: .top, spacing: 12) {
            PlayerAvatar(player: player, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(player.name).font(.qBody(15, .heavy)).foregroundStyle(Q.ink)
                Text(result.turn.question.text)
                    .font(.qBody(15, .semibold))
                    .foregroundStyle(Q.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Text(givenAnswer(result).map { "Gesagt: \($0) · Richtig: \(result.turn.question.answer)" }
                     ?? "Richtig: \(result.turn.question.answer)")
                    .font(.qBody(13, .semibold))
                    .foregroundStyle(Q.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "star")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Q.yellow)
        }
        .padding(14)
        .card(radius: 18)
    }

    // MARK: - Schritt 2: Karte

    private func cardStep(_ result: TurnResult) -> some View {
        let player = session.player(result.turn.playerID)?.player ?? Player(name: "?", colorIndex: 0)
        return ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Was hat \(player.name) gesagt?").font(.q(20)).foregroundStyle(Q.ink)
                    TextField("", text: $said, prompt: Text("z. B. Sydney").foregroundStyle(Q.ink.opacity(0.3)))
                        .font(.qBody(20, .heavy))
                        .foregroundStyle(Q.ink)
                        .submitLabel(.done)
                        .padding(.horizontal, 16)
                        .frame(height: 54)
                        .card(radius: 16)
                }

                ShareCard(player: player, said: said, question: result.turn.question)
                    .frame(width: ShareCard.size.width, height: ShareCard.size.height)
                    .scaleEffect(0.78)
                    .frame(width: ShareCard.size.width * 0.78, height: ShareCard.size.height * 0.78)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 14, y: 6)

                if let rendered {
                    ShareLink(item: rendered, preview: SharePreview("Dümmste Antwort des Abends", image: rendered)) {
                        Label("Teilen", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(QButtonStyle())
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { render(player: player, question: result.turn.question) }
        .onChange(of: said) { _, _ in render(player: player, question: result.turn.question) }
    }

    private func choose(_ result: TurnResult) {
        said = givenAnswer(result) ?? ""
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { selected = result }
    }

    /// Bei Multiple Choice ist bekannt, was gewählt wurde.
    private func givenAnswer(_ result: TurnResult) -> String? {
        if let i = result.chosenOption, result.turn.options.indices.contains(i) { return result.turn.options[i] }
        if result.outcome == .timeout { return "…" }
        return nil
    }

    private func render(player: Player, question: Question) {
        let renderer = ImageRenderer(content: ShareCard(player: player, said: said, question: question)
            .frame(width: ShareCard.size.width, height: ShareCard.size.height))
        renderer.scale = 3
        rendered = renderer.uiImage.map { Image(uiImage: $0) }
    }
}

/// Story-Karte im Format 9:16 (wird mit Faktor 3 als 1080 × 1920 gerendert).
struct ShareCard: View {
    static let size = CGSize(width: 360, height: 640)

    let player: Player
    let said: String
    let question: Question

    var body: some View {
        let color = Q.playerColor(player.colorIndex)
        let fg = Q.onPlayerColor(player.colorIndex)
        let quote = said.trimmingCharacters(in: .whitespaces)
        VStack(spacing: 0) {
            StickerLabel(text: "Dümmste Antwort des Abends", fill: .white, foreground: color, size: 20, tilt: -3)
                .padding(.top, 44)

            WabbelView(mood: .laugh, size: 130, animated: false)
                .padding(.top, 26)

            HStack(spacing: 10) {
                PlayerAvatar(player: player, size: 44, inverted: true)
                Text(player.name).font(.q(40)).foregroundStyle(fg).lineLimit(1).minimumScaleFactor(0.5)
            }
            .padding(.top, 14)

            VStack(spacing: 12) {
                Text(quote.isEmpty ? "…" : "„\(quote)“")
                    .font(.q(40))
                    .foregroundStyle(Q.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.5)
                Text(question.text)
                    .font(.qBodyFixed(15, .bold))
                    .foregroundStyle(Q.muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Richtig: \(question.answer)").lineLimit(1).minimumScaleFactor(0.6)
                }
                .font(.qBodyFixed(15, .heavy))
                .foregroundStyle(Q.green)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(.white))
            .rotationEffect(.degrees(1.5))
            .padding(.horizontal, 22)
            .padding(.top, 18)

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                JigglBadge(size: 26, fill: color == Q.brand ? Q.ink : Q.brand, animated: false)
                Text("Der Dümmste fliegt")
                    .font(.q(15))
                    .foregroundStyle(fg.opacity(0.85))
            }
            .padding(.bottom, 28)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(color)
    }
}
