import AppKit
import Foundation

struct MarkdownTableCell: Equatable {
    let rowIndex: Int
    let columnIndex: Int
    let range: NSRange
    let contentRange: NSRange
}

struct MarkdownTableLayout: Equatable {
    let blockRange: NSRange
    let columnCount: Int
    let cells: [MarkdownTableCell]
    let rowRanges: [NSRange]
    let alignments: [ColumnAlignment]

    enum ColumnAlignment: Equatable {
        case left
        case center
        case right

        var textAlignment: NSTextAlignment {
            switch self {
            case .left: return .left
            case .center: return .center
            case .right: return .right
            }
        }
    }

    func cell(at location: Int) -> MarkdownTableCell? {
        cells.first { NSLocationInRange(location, $0.contentRange) || NSLocationInRange(location, $0.range) }
    }

    func nextCell(after location: Int) -> MarkdownTableCell? {
        guard let current = cell(at: location) else { return nil }
        return cells.first {
            ($0.rowIndex > current.rowIndex) || ($0.rowIndex == current.rowIndex && $0.columnIndex > current.columnIndex)
        }
    }

    func previousCell(before location: Int) -> MarkdownTableCell? {
        guard let current = cell(at: location) else { return nil }
        return cells.reversed().first {
            ($0.rowIndex < current.rowIndex) || ($0.rowIndex == current.rowIndex && $0.columnIndex < current.columnIndex)
        }
    }
}

enum MarkdownTableEditing {
    static func tableLayouts(in source: String, parser: MarkdownDocumentParser = MarkdownDocumentParser()) -> [MarkdownTableLayout] {
        let document = parser.parse(source)
        return document.blocks.compactMap { block in
            guard case let .table(columnCount) = block.kind else { return nil }
            return makeLayout(for: block, columnCount: columnCount, source: source)
        }
    }

    static func tableLayout(in source: String, at location: Int, parser: MarkdownDocumentParser = MarkdownDocumentParser()) -> MarkdownTableLayout? {
        let document = parser.parse(source)
        guard let tableBlock = document.blocks.first(where: {
            guard case .table = $0.kind else { return false }
            return NSLocationInRange(location, $0.range)
        }) else { return nil }
        guard case let .table(columnCount) = tableBlock.kind else { return nil }

        return makeLayout(for: tableBlock, columnCount: columnCount, source: source)
    }

    private static func makeLayout(for tableBlock: MarkdownBlock, columnCount: Int, source: String) -> MarkdownTableLayout? {
        let nsSource = source as NSString
        let blockText = nsSource.substring(with: tableBlock.range)
        let lines = blockText.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard lines.count >= 2 else { return nil }

        let alignments = alignmentsForSeparatorLine(lines[1])

        var cells: [MarkdownTableCell] = []
        var rowRanges: [NSRange] = []
        var absoluteLocation = tableBlock.range.location

        for (rowIndex, line) in lines.enumerated() {
            let lineLength = (line as NSString).length
            let lineRange = NSRange(location: absoluteLocation, length: lineLength)
            if rowIndex != 1 {
                rowRanges.append(lineRange)
                cells.append(contentsOf: cellsForLine(line, lineRange: lineRange, rowIndex: rowRanges.count - 1))
            }
            absoluteLocation += lineLength + 1
        }

        return MarkdownTableLayout(blockRange: tableBlock.range, columnCount: columnCount, cells: cells, rowRanges: rowRanges, alignments: alignments)
    }

    static func insertionForNewRow(in source: String, at location: Int, parser: MarkdownDocumentParser = MarkdownDocumentParser()) -> (range: NSRange, replacement: String, selection: NSRange)? {
        guard let layout = tableLayout(in: source, at: location, parser: parser), let currentCell = layout.cell(at: location) else { return nil }
        let currentRowRange = layout.rowRanges[currentCell.rowIndex]
        let insertionLocation = currentRowRange.location + currentRowRange.length
        let emptyRow = "\n|" + Array(repeating: "   |", count: layout.columnCount).joined()
        let firstCellStart = insertionLocation + 3
        return (
            range: NSRange(location: insertionLocation, length: 0),
            replacement: emptyRow,
            selection: NSRange(location: firstCellStart, length: 0)
        )
    }

    private static func cellsForLine(_ line: String, lineRange: NSRange, rowIndex: Int) -> [MarkdownTableCell] {
        let nsLine = line as NSString
        var boundaries: [Int] = []
        for index in 0..<nsLine.length where nsLine.substring(with: NSRange(location: index, length: 1)) == "|" {
            boundaries.append(index)
        }
        guard boundaries.count >= 2 else { return [] }

        var result: [MarkdownTableCell] = []
        for columnIndex in 0..<(boundaries.count - 1) {
            let start = boundaries[columnIndex] + 1
            let end = boundaries[columnIndex + 1]
            let cellRange = NSRange(location: lineRange.location + start, length: max(0, end - start))
            let rawCell = nsLine.substring(with: NSRange(location: start, length: max(0, end - start))) as NSString
            let trimmed = rawCell.trimmingCharacters(in: .whitespaces)
            let contentLocation: Int
            if trimmed.isEmpty {
                contentLocation = cellRange.location + min(1, cellRange.length)
            } else {
                let local = rawCell.range(of: trimmed)
                contentLocation = cellRange.location + local.location
            }
            let contentRange = NSRange(location: contentLocation, length: max(0, trimmed.count))
            result.append(MarkdownTableCell(rowIndex: rowIndex, columnIndex: columnIndex, range: cellRange, contentRange: contentRange))
        }
        return result
    }

    private static func alignmentsForSeparatorLine(_ line: String) -> [MarkdownTableLayout.ColumnAlignment] {
        let nsLine = line as NSString
        var boundaries: [Int] = []
        for index in 0..<nsLine.length where nsLine.substring(with: NSRange(location: index, length: 1)) == "|" {
            boundaries.append(index)
        }
        guard boundaries.count >= 2 else { return [] }

        var result: [MarkdownTableLayout.ColumnAlignment] = []
        for columnIndex in 0..<(boundaries.count - 1) {
            let start = boundaries[columnIndex] + 1
            let end = boundaries[columnIndex + 1]
            let raw = nsLine.substring(with: NSRange(location: start, length: max(0, end - start))).trimmingCharacters(in: .whitespaces)
            if raw.hasPrefix(":") && raw.hasSuffix(":") {
                result.append(.center)
            } else if raw.hasSuffix(":") {
                result.append(.right)
            } else {
                result.append(.left)
            }
        }
        return result
    }
}
