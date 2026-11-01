import Foundation
import NaturalLanguage

public final class AFMKeywordService {
    public static let shared = AFMKeywordService()

    private let afmEndpoints = [
        "http://127.0.0.1:11434/v1/chat/completions",
        "http://127.0.0.1:11435/v1/chat/completions"
    ]

    private init() {}

    /// Extracts 5 salient keywords using on-device Apple NLP,
    /// then asynchronously attempts enrichment via local AFM if available.
    public func generateKeywords(
        for text: String,
        completion: (([String]) -> Void)? = nil
    ) -> [String] {
        let initialKeywords = extractOnDeviceKeywords(from: text)
        completion?(initialKeywords)

        // Asynchronously query local AFM engine (11434 / 11435) to refine keywords if online
        queryAFMEngine(text: text) { refinedKeywords in
            if let refined = refinedKeywords, !refined.isEmpty {
                DispatchQueue.main.async {
                    completion?(refined)
                }
            }
        }

        return initialKeywords
    }

    /// Pure on-device Apple NaturalLanguage & domain tagger.
    public func extractOnDeviceKeywords(from text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var results = detectDomainKeywords(trimmed: trimmed)

        let nlpWords = extractNLPKeywords(trimmed: trimmed)
        for word in nlpWords where !results.contains(word) {
            results.append(word)
            if results.count >= 5 { break }
        }

        if results.isEmpty {
            results.append("Snippet")
        }

        return Array(results.prefix(5))
    }

    private func detectDomainKeywords(trimmed: String) -> [String] {
        var tags: [String] = []

        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            tags.append("URL")
            extractHostParts(from: trimmed, into: &tags)
        }

        let isCLI = trimmed.hasPrefix("ssh ") || trimmed.hasPrefix("sudo ") || trimmed.hasPrefix("curl ") ||
                    trimmed.hasPrefix("cd ") || trimmed.hasPrefix("brew ") || trimmed.hasPrefix("git ")
        if isCLI && !tags.contains("Terminal") {
            tags.append("Terminal")
        }

        let isCode = trimmed.contains("func ") || trimmed.contains("import ") || trimmed.contains("class ") ||
                     trimmed.contains("def ") || trimmed.contains("const ") || trimmed.contains("return ")
        if isCode && !tags.contains("Code") {
            tags.append("Code")
        }

        if (trimmed.hasPrefix("/") || trimmed.hasPrefix("~/")) && !tags.contains("FilePath") {
            tags.append("FilePath")
        }

        let lower = trimmed.lowercased()
        if (lower.contains("ec2") || lower.contains("aws") || lower.contains("cloud")) && !tags.contains("AWS") {
            tags.append("AWS")
        }

        return tags
    }

    private func extractHostParts(from urlStr: String, into tags: inout [String]) {
        guard let url = URL(string: urlStr), let host = url.host else { return }
        let ignored: Set<String> = ["com", "org", "net", "io", "nip", "local", "www"]
        let parts = host.split(separator: ".").filter { !ignored.contains(String($0)) }
        for part in parts.prefix(2) {
            let cleaned = String(part).capitalized
            if !tags.contains(cleaned) {
                tags.append(cleaned)
            }
        }
    }

    private func extractNLPKeywords(trimmed: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass, .lemma])
        tagger.string = trimmed
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]

        let stopwords: Set<String> = [
            "the", "and", "for", "with", "this", "that", "from", "you", "your", "are", "have", "can",
            "will", "was", "were", "about", "all", "also", "into", "some", "what", "which", "when",
            "there", "then", "them", "these", "other", "more", "like", "just", "been", "only", "would"
        ]

        var words: [String] = []
        let range = trimmed.startIndex..<trimmed.endIndex
        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            let rawWord = String(trimmed[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = rawWord.lowercased()
            if rawWord.count >= 3 && !stopwords.contains(lower) {
                if tag == .noun || tag == .otherWord || tag == .adjective {
                    let cleaned = rawWord.capitalized
                    if !words.contains(cleaned) {
                        words.append(cleaned)
                    }
                }
            }
            return true
        }
        return words
    }

    /// Queries local AFM engine (OpenAI compatible endpoint on port 11434 / 11435)
    private func queryAFMEngine(text: String, completion: @escaping ([String]?) -> Void) {
        let snippet = String(text.prefix(300))
        guard let url = URL(string: afmEndpoints[0]) else {
            completion(nil)
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 2.0
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = "Extract exactly 5 concise keywords or category tags for this clipboard snippet. " +
                     "Respond ONLY with 5 comma-separated keywords, nothing else.\n\nText:\n\(snippet)"

        let payload: [String: Any] = [
            "model": "afm",
            "messages": [
                ["role": "system", "content": "You are a concise keyword extraction engine."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 40,
            "temperature": 0.1
        ]

        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let task = URLSession.shared.dataTask(with: req) { data, response, _ in
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                completion(nil)
                return
            }

            let rawKeywords = content
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).capitalized }
                .filter { !$0.isEmpty }

            completion(rawKeywords.isEmpty ? nil : Array(rawKeywords.prefix(5)))
        }
        task.resume()
    }
}
