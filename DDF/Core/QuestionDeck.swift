import Foundation

/// Deterministischer Zufallsgenerator, damit Spiele in Tests reproduzierbar sind.
struct SplitMix64: RandomNumberGenerator, Hashable {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Zieht Fragen ohne Wiederholung. Je weiter das Spiel ist, desto schwerer werden sie.
struct QuestionDeck {
    /// Anteil der Wahr-oder-falsch-Aussagen unter den gezogenen Fragen.
    static let trueFalseShare = 0.1

    private var unused: [Int: [Question]]
    private var used: [Question] = []

    /// - Parameter seen: Fragen, die an früheren Abenden schon dran waren. Sie kommen erst, wenn die neuen aufgebraucht sind.
    init(questions: [Question], answerMode: AnswerMode, seen: Set<String> = [], rng: inout SplitMix64) {
        let pool = answerMode == .multipleChoice ? questions.filter(\.supportsMultipleChoice) : questions
        let grouped = Dictionary(grouping: pool.shuffled(using: &rng), by: { min(max($0.difficulty, 1), 3) })
        // Gezogen wird von hinten. Darum stehen die schon gesehenen vorne.
        unused = grouped.mapValues { list in
            list.filter { seen.contains($0.id) } + list.filter { !seen.contains($0.id) }
        }
    }

    var remaining: Int { unused.values.reduce(0) { $0 + $1.count } }
    var isEmpty: Bool { remaining == 0 && used.isEmpty }

    /// - Parameters:
    ///   - progress: 0 = Spielbeginn, 1 = Finale.
    ///   - handicap: verschiebt die Schwierigkeit für diesen Spieler um eine Stufe (−1 leichter, +1 schwerer).
    mutating func draw(progress: Double, handicap: Int = 0, rng: inout SplitMix64) -> Question? {
        if remaining == 0 {
            guard !used.isEmpty else { return nil }
            unused = Dictionary(grouping: used.shuffled(using: &rng), by: { min(max($0.difficulty, 1), 3) })
            used.removeAll()
        }
        let base = progress < 0.34 ? 1 : (progress < 0.75 ? 2 : 3)
        let target = min(max(base + handicap, 1), 3)
        // Zielstufe zuerst, dann die nächstgelegenen Stufen.
        let order = [target, target + 1, target - 1, target + 2, target - 2].filter { (1...3).contains($0) }
        // Nur jede zehnte Frage soll eine Wahr-oder-falsch-Aussage sein. Gibt es die gewünschte Art nicht mehr, kommt die andere.
        let wantsTrueFalse = Double.random(in: 0..<1, using: &rng) < Self.trueFalseShare
        for kind in [wantsTrueFalse, !wantsTrueFalse] {
            for tier in order {
                if var list = unused[tier], let index = list.lastIndex(where: { $0.isTrueFalse == kind }) {
                    let question = list.remove(at: index)
                    unused[tier] = list
                    used.append(question)
                    return question
                }
            }
        }
        return nil
    }
}
