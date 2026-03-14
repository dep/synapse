import Foundation

struct SlashCommandContext: Equatable {
    let range: NSRange
    let query: String
}

enum SlashCommand: String, CaseIterable {
    case time
    case date
    case datetime
    case todo
    case note
    case filename

}

struct SlashCommandResolverContext {
    let now: Date
    let currentFileURL: URL?
    let locale: Locale
    let timeZone: TimeZone

    init(now: Date, currentFileURL: URL?, locale: Locale = .current, timeZone: TimeZone = .current) {
        self.now = now
        self.currentFileURL = currentFileURL
        self.locale = locale
        self.timeZone = timeZone
    }
}

func slashCommandContext(in text: String, cursor: Int) -> SlashCommandContext? {
    let nsText = text as NSString
    let clampedCursor = min(max(0, cursor), nsText.length)
    let prefix = String(text.prefix(clampedCursor))
    let lineStart = prefix.lastIndex(of: "\n").map { prefix.distance(from: prefix.startIndex, to: prefix.index(after: $0)) } ?? 0
    let tokenRange = NSRange(location: lineStart, length: clampedCursor - lineStart)

    guard tokenRange.length > 0 else { return nil }

    let token = nsText.substring(with: tokenRange)
    guard token.hasPrefix("/") else { return nil }
    guard !token.contains(" "), !token.contains("\t") else { return nil }
    guard token.range(of: #"^/[A-Za-z]*$"#, options: .regularExpression) != nil else { return nil }

    return SlashCommandContext(range: tokenRange, query: String(token.dropFirst()).lowercased())
}

func resolveSlashCommandOutput(_ command: SlashCommand, context: SlashCommandResolverContext) -> String {
    switch command {
    case .time:
        return formattedSlashCommandDate(context.now, format: "h:mm a", locale: context.locale, timeZone: context.timeZone).lowercased()
    case .date:
        return formattedSlashCommandDate(context.now, format: "yyyy-MM-dd", locale: context.locale, timeZone: context.timeZone)
    case .datetime:
        return formattedSlashCommandDate(context.now, format: "yyyy-MM-dd h:mm a", locale: context.locale, timeZone: context.timeZone)
    case .todo:
        return "- [ ] "
    case .note:
        return "> **Note:** "
    case .filename:
        return context.currentFileURL?.deletingPathExtension().lastPathComponent ?? ""
    }
}

private func formattedSlashCommandDate(_ date: Date, format: String, locale: Locale, timeZone: TimeZone) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.timeZone = timeZone
    formatter.dateFormat = format
    return formatter.string(from: date)
}
