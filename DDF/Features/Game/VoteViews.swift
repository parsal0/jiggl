import SwiftUI

/// Rundenende im Abstimmungs-Modus: Statistik der Runde, dann Abstimmung.
struct RoundOverView: View {
    let session: GameSession
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StickerLabel(text: "Zeit ist um!", fill: .white, foreground: Q.orange, size: 48, tilt: -4)
                .scaleEffect(appeared ? 1 : 0.3)
                .animation(.spring(response: 0.45, dampingFraction: 0.55), value: appeared)
                .padding(.top, 90)

            Text("Wer war in dieser Runde der Dümmste?")
                .font(.q(24))
                .foregroundStyle(.white)
                .padding(.top, 22)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(session.engine.activePlayers.enumerated()), id: \.element.id) { i, state in
                        HStack(spacing: 12) {
                            PlayerAvatar(player: state.player, size: 38)
                            Text(state.player.name).font(.qBody(18, .heavy)).foregroundStyle(Q.ink).lineLimit(1)
                            Spacer()
                            stat(state.roundCorrect, "richtig", Q.correct)
                            stat(state.roundWrong, "falsch", Q.wrong)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .card(radius: 20)
                        .offset(x: appeared ? 0 : 400)
                        .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(Double(i) * 0.06), value: appeared)
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 2)
            }

            Button("Abstimmen") { session.beginVoting() }
                .buttonStyle(QButtonStyle(fill: .white, foreground: Q.ink, height: 64, fontSize: 24))
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Q.orange.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            WabbelView(mood: .shock, size: 84)
                .padding(.top, 82)
                .padding(.trailing, 22)
        }
        .onAppear { appeared = true }
    }

    private func stat(_ value: Int, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(value)").font(.q(17)).monospacedDigit()
            Text(label).font(.qBody(12, .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(color))
    }
}

/// Geheime Abstimmung: Handy weitergeben, dann wählen.
struct VotingView: View {
    let session: GameSession
    let voterIndex: Int
    @State private var handedOver = false
    @State private var selected: UUID?

    var body: some View {
        let voter = session.engine.voters[voterIndex].player
        ZStack {
            (handedOver ? Q.blue : Q.playerColor(voter.colorIndex)).ignoresSafeArea()
            if handedOver {
                ballot(voter: voter).transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                handOver(voter: voter).transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: handedOver)
    }

    private func handOver(voter: Player) -> some View {
        let fg = Q.onPlayerColor(voter.colorIndex)
        return VStack(spacing: 0) {
            Spacer()
            Text("Stimme \(voterIndex + 1) von \(session.engine.voters.count)")
                .font(.qBody(15, .heavy))
                .foregroundStyle(Q.ink)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Capsule().fill(Q.surface))
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            Text("Handy an").font(.q(30)).foregroundStyle(fg.opacity(0.8)).padding(.top, 30)
            PlayerAvatar(player: voter, size: 130, inverted: true).padding(.top, 18)
            Text(voter.name).font(.q(60)).foregroundStyle(fg).lineLimit(1).minimumScaleFactor(0.4)
                .padding(.top, 12)
            Text("Niemand sonst guckt!").font(.qBody(17, .bold)).foregroundStyle(fg.opacity(0.8)).padding(.top, 4)
            Spacer()
            WabbelView(mood: .coverEyes, size: 92)
                .padding(.bottom, 10)
            Button("Ich bin \(voter.name)") { handedOver = true }
                .buttonStyle(QButtonStyle(fill: .white, foreground: Q.ink, height: 64, fontSize: 22))
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
    }

    private func ballot(voter: Player) -> some View {
        let candidates = session.engine.candidates(forVoterAt: voterIndex)
        return VStack(alignment: .leading, spacing: 0) {
            Text("\(voter.name), wer ist der Dümmste?")
                .font(.q(34))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 76)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(Array(candidates.enumerated()), id: \.element.id) { i, state in
                        let isSelected = selected == state.id
                        let color = Q.playerColor(state.player.colorIndex)
                        Button { selected = state.id } label: {
                            VStack(spacing: 8) {
                                PlayerAvatar(player: state.player, size: 56)
                                Text(state.player.name)
                                    .font(.qBody(19, .heavy))
                                    .foregroundStyle(isSelected ? Q.onPlayerColor(state.player.colorIndex) : Q.ink)
                                    .lineLimit(1).minimumScaleFactor(0.6)
                            }
                            .frame(maxWidth: .infinity, minHeight: 128)
                            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(isSelected ? color : Q.surface))
                            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white, lineWidth: isSelected ? 5 : 0))
                            .shadow(color: .black.opacity(isSelected ? 0.16 : 0.06), radius: 10, y: 4)
                        }
                        .buttonStyle(.plain)
                        .rotationEffect(.degrees(isSelected ? -3 : stickerTilt(i) * 0.3))
                        .scaleEffect(isSelected ? 1.05 : 1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isSelected)
                        .sensoryFeedback(.selection, trigger: isSelected)
                        .accessibilityLabel(state.player.name)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.vertical, 22)
                .padding(.horizontal, 4)
            }
            Button("Stimme abgeben") {
                if let selected { session.castVote(for: selected) }
            }
            .buttonStyle(QButtonStyle(fill: .white, foreground: Q.ink, height: 64, fontSize: 22))
            .disabled(selected == nil)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
    }
}

/// Auflösung wie ein Glücksrad: Die Markierung springt immer langsamer und bleibt beim Verlierer stehen.
struct VoteResultView: View {
    let session: GameSession
    let result: VoteResult
    @State private var start = Date()
    @State private var landed = false
    /// Alle Stimmen sind hochgezählt, die Uhr darf anhalten.
    @State private var counted = false

    /// Abstand zwischen zwei Stimmen beim Hochzählen.
    private static let countStep = 0.2

    var body: some View {
        let players = session.engine.activePlayers
        let loserIndex = players.firstIndex { $0.id == result.playerID } ?? 0
        let schedule = Self.schedule(count: players.count, landingOn: loserIndex)
        let loser = session.player(result.playerID)
        let flies = (loser?.lives ?? 1) <= 1

        let landTime = (schedule.last ?? 0) + 0.35
        let maxVotes = result.tally.values.max() ?? 0

        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: counted)) { context in
            let t = context.date.timeIntervalSince(start)
            let step = schedule.lastIndex { $0 <= t } ?? 0
            let highlight = landed ? loserIndex : step % players.count
            let done = landed || t > landTime
            // Nach dem Landen zählen alle Stimmen gleichzeitig Stück für Stück hoch.
            let shownVotes = counted ? maxVotes : max(0, min(maxVotes, Int((t - landTime - 0.25) / Self.countStep) + 1))

            ZStack {
                (done ? Q.pink : Q.blue).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    Group {
                        if done {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(loser?.player.name ?? "")
                                    .font(.q(60))
                                    .foregroundStyle(.white)
                                    .lineLimit(1).minimumScaleFactor(0.5)
                                StickerLabel(text: flies ? "fliegt!" : "verliert ein Leben!",
                                             fill: .white, foreground: flies ? Q.pink : Q.orange, size: flies ? 44 : 28, tilt: -4)
                            }
                            .transition(.scale(scale: 1.4).combined(with: .opacity))
                        } else {
                            Text("Und der Dümmste ist …")
                                .font(.q(38))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 80)

                    VStack(spacing: 10) {
                        ForEach(Array(players.enumerated()), id: \.element.id) { i, state in
                            let on = i == highlight
                            HStack {
                                PlayerChip(player: state.player, size: 18, tilt: on ? -3 : 0, dimmed: done && !on, highlighted: on)
                                    .scaleEffect(on ? 1.1 : 1, anchor: .leading)
                                Spacer()
                                if done {
                                    let votes = min(result.tally[state.id] ?? 0, shownVotes)
                                    Text("\(votes)")
                                        .font(.q(20))
                                        .contentTransition(.numericText(value: Double(votes)))
                                        .foregroundStyle(on ? .white : Q.ink)
                                        .frame(width: 44, height: 44)
                                        .background(Circle().fill(on ? Q.ink : Q.surface))
                                        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                                        .scaleEffect(votes > 0 && votes == result.tally[state.id] && shownVotes == votes ? 1.18 : 1)
                                        .animation(.spring(response: 0.25, dampingFraction: 0.45), value: votes)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: on)
                        }
                    }
                    .padding(.top, 40)

                    if done && result.wasTieBreak {
                        Text("Gleichstand! Entschieden hat, wer in der Runde mehr falsch hatte.")
                            .font(.qBody(15, .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.top, 16)
                    }

                    Spacer()
                    // Wabbel als Richter. Bei vielen Spielern ist kein Platz für ihn.
                    if players.count <= 8 {
                        WabbelView(mood: done ? .verdict : .judge, size: 96)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.bottom, 8)
                    }
                    if done {
                        Button("Weiter") { session.continueAfterVoteResult() }
                            .buttonStyle(QButtonStyle(fill: .white, foreground: Q.ink, height: 64, fontSize: 24))
                            .padding(.bottom, 12)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 20)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: done)
            .sensoryFeedback(.selection, trigger: highlight)
            .onChange(of: done) { _, isDone in
                guard isDone else { return }
                landed = true
                if maxVotes == 0 { counted = true }
            }
            .onChange(of: shownVotes) { _, new in
                guard new > 0 else { return }
                if new >= maxVotes { counted = true }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: shownVotes)
        }
        .contentShape(Rectangle())
        // Tipp irgendwo auf den Screen wirkt wie „Weiter“, sobald das Ergebnis steht.
        .onTapGesture { if landed { session.continueAfterVoteResult() } }
        .sensoryFeedback(.error, trigger: landed)
        .onAppear { start = Date() }
    }

    /// Zeitpunkte der einzelnen Sprünge, immer langsamer, letzter Sprung auf `landingOn`.
    static func schedule(count: Int, landingOn target: Int) -> [Double] {
        guard count > 0 else { return [0] }
        var steps = max(14, count * 3)
        while steps % count != target { steps += 1 }
        var times: [Double] = [0]
        for k in 1...steps {
            times.append(times[k - 1] + 0.05 + 0.0012 * Double(k * k))
        }
        return times
    }
}
