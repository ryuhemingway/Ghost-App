import Foundation

struct DirectWebSearchResult: Sendable {
    let title: String
    let url: String
    let snippet: String
    let pageText: String?
}

struct DirectWebSearchService: Sendable {
    func search(query: String, maxResults: Int = 6) async throws -> [DirectWebSearchResult] {
        var components = URLComponents(string: "https://lite.duckduckgo.com/lite/")!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components.url else {
            return []
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12

        let (data, response) = try await URLSession.shared.data(for: request)
        guard
            let http = response as? HTTPURLResponse,
            (200..<300).contains(http.statusCode),
            let html = String(data: data, encoding: .utf8)
        else {
            return []
        }

        let results = parseResults(from: html, maxResults: maxResults)
        return await enrich(results)
    }

    private func parseResults(from html: String, maxResults: Int) -> [DirectWebSearchResult] {
        let pattern = #"<a rel="nofollow" href="([^"]+)" class='result-link'>(.*?)</a>[\s\S]*?<td class='result-snippet'>\s*([\s\S]*?)\s*</td>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, range: range).prefix(maxResults).compactMap { match in
            guard
                let hrefRange = Range(match.range(at: 1), in: html),
                let titleRange = Range(match.range(at: 2), in: html),
                let snippetRange = Range(match.range(at: 3), in: html)
            else {
                return nil
            }

            let title = cleanHTML(String(html[titleRange]))
            let url = cleanSearchURL(String(html[hrefRange]))
            let snippet = cleanHTML(String(html[snippetRange]))
            guard !title.isEmpty, !url.isEmpty else {
                return nil
            }

            return DirectWebSearchResult(title: title, url: url, snippet: snippet, pageText: nil)
        }
    }

    private func enrich(_ results: [DirectWebSearchResult]) async -> [DirectWebSearchResult] {
        var enriched: [DirectWebSearchResult] = []
        for result in results {
            guard enriched.count < 4 else {
                enriched.append(result)
                continue
            }

            let pageText = await fetchReadableText(from: result.url)
            enriched.append(
                DirectWebSearchResult(
                    title: result.title,
                    url: result.url,
                    snippet: result.snippet,
                    pageText: pageText
                )
            )
        }
        return enriched
    }

    private func fetchReadableText(from urlString: String) async -> String? {
        guard let url = URL(string: urlString), ["http", "https"].contains(url.scheme?.lowercased()) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard
                let http = response as? HTTPURLResponse,
                (200..<300).contains(http.statusCode),
                let contentType = http.value(forHTTPHeaderField: "Content-Type")?.lowercased(),
                contentType.contains("text/html"),
                let html = String(data: data, encoding: .utf8)
            else {
                return nil
            }
            let text = readableText(from: html)
            return text.isEmpty ? nil : String(text.prefix(1_800))
        } catch {
            return nil
        }
    }

    private func readableText(from html: String) -> String {
        var text = html
        let removalPatterns = [
            #"<script[\s\S]*?</script>"#,
            #"<style[\s\S]*?</style>"#,
            #"<noscript[\s\S]*?</noscript>"#,
            #"<svg[\s\S]*?</svg>"#
        ]
        for pattern in removalPatterns {
            text = text.replacingOccurrences(of: pattern, with: " ", options: [.regularExpression, .caseInsensitive])
        }
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        return decodeEntities(text)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanSearchURL(_ rawURL: String) -> String {
        var value = decodeEntities(rawURL)
        if value.hasPrefix("//") {
            value = "https:" + value
        }
        guard
            let components = URLComponents(string: value),
            let wrapped = components.queryItems?.first(where: { $0.name == "uddg" })?.value,
            !wrapped.isEmpty
        else {
            return value
        }
        return wrapped
    }

    private func cleanHTML(_ rawHTML: String) -> String {
        let withoutTags = rawHTML.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: "",
            options: .regularExpression
        )
        return decodeEntities(withoutTags)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodeEntities(_ text: String) -> String {
        var decoded = text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")

        let numericPattern = #"&#(\d+);"#
        if let regex = try? NSRegularExpression(pattern: numericPattern) {
            let nsText = decoded as NSString
            let matches = regex.matches(in: decoded, range: NSRange(location: 0, length: nsText.length)).reversed()
            for match in matches {
                let numberText = nsText.substring(with: match.range(at: 1))
                if let scalarValue = UInt32(numberText), let scalar = UnicodeScalar(scalarValue) {
                    decoded = (decoded as NSString).replacingCharacters(in: match.range, with: String(Character(scalar)))
                }
            }
        }

        return decoded
    }
}
