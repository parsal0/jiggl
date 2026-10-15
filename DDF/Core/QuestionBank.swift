import Foundation

/// Lädt die Fragen aus den JSON-Dateien im App-Bundle (`questions_*.json`).
/// Weitere Fragenpakete einfach als zusätzliche Datei mit demselben Format ablegen.
enum QuestionBank {
    static func loadAll(bundle: Bundle = .main) -> [Question] {
        let urls = (bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("questions_") }
        var seen = Set<String>()
        var result: [Question] = []
        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let questions = try? JSONDecoder().decode([Question].self, from: data) else { continue }
            for q in questions where seen.insert(q.id).inserted {
                result.append(q)
            }
        }
        return result
    }
}
