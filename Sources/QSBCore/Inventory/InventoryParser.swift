import Foundation
public enum WinQSBInventoryParser {
    public static func parseModelEnvelope(from data: Data) throws -> InventoryModelEnvelope {
        guard let text = data.legacyLatin1String,
              let firstLine = text
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
                .split(separator: "\n", omittingEmptySubsequences: true)
                .first
        else {
            throw InventoryModelError.unsupportedFormat
        }
        let metadata = firstLine
            .split(separator: "\t", omittingEmptySubsequences: false)
            .map(clean)
        guard metadata.count >= 5, metadata[0] == "ITS" else {
            throw InventoryModelError.unsupportedFormat
        }
        switch (metadata[3], metadata[4]) {
        case ("0", "0"):
            return .eoq(try parseEOQ(from: data))
        case ("1", "1"):
            return .quantityDiscountEOQ(try parseQuantityDiscountEOQ(from: data))
        case ("2", "2"):
            return .newsboy(try parseNewsboy(from: data))
        case ("3", _):
            return .lotSizing(try parseLotSizing(from: data))
        case ("4", _), ("5", _), ("6", _), ("7", _):
            return .stochasticReview(try parseStochasticInventory(from: data))
        default:
            throw InventoryModelError.unsupportedModel(
                "recognized ITS variant \(metadata[3]) \(metadata[4]) has no normalized model yet"
            )
        }
    }

    public static func parseEOQ(from data: Data) throws -> EOQModel {
        guard let text = data.legacyLatin1String else {
            throw InventoryModelError.unsupportedFormat
        }

        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(clean) }

        guard let metadata = lines.first,
              metadata.count >= 5,
              metadata[0] == "ITS",
              metadata[3] == "0",
              metadata[4] == "0"
        else {
            throw InventoryModelError.unsupportedFormat
        }

        var entries: [String: String] = [:]
        for row in lines.dropFirst(2) where row.count >= 2 {
            entries[row[0].lowercased()] = row[1]
        }

        return EOQModel(
            title: metadata[1],
            timeUnit: metadata[2],
            demand: try requiredDouble(entries, "demand per year"),
            setupCost: try requiredDouble(entries, "order or setup cost per order"),
            holdingCost: try requiredDouble(entries, "unit holding cost per year"),
            shortageCost: try optionalDouble(entries["unit shortage cost per year"]),
            replenishmentRate: try optionalDouble(entries["replenishment or production rate per year"]),
            leadTime: try optionalDouble(entries["lead time for a new order in year"]),
            acquisitionCost: try optionalDouble(entries["unit acquisition cost without discount"]),
            knownOrderQuantity: try optionalDouble(entries["order quantity if you known"])
        )
    }

    public static func parseNewsboy(from data: Data) throws -> NewsboyModel {
        let (metadata, entries) = try parseEntryTable(from: data)
        guard metadata.count >= 5,
              metadata[0] == "ITS",
              metadata[3] == "2",
              metadata[4] == "2"
        else {
            throw InventoryModelError.unsupportedFormat
        }

        let distribution = entries["demand distribution (in year)"] ?? ""
        guard distribution.lowercased() == "normal" else {
            throw InventoryModelError.unsupportedModel("only normal newsboy demand is currently supported")
        }

        return NewsboyModel(
            title: metadata[1],
            timeUnit: metadata[2],
            demandDistribution: distribution,
            meanDemand: try requiredDouble(entries, "mean (u)"),
            standardDeviation: try requiredDouble(entries, "standard deviation (s>0)"),
            setupCost: try requiredDouble(entries, "order or setup cost"),
            acquisitionCost: try requiredDouble(entries, "unit acquisition cost"),
            sellingPrice: try requiredDouble(entries, "unit selling price"),
            shortageCost: try requiredDouble(entries, "unit shortage (opportunity) cost"),
            salvageValue: try requiredDouble(entries, "unit salvage value"),
            initialInventory: try optionalDouble(entries["initial inventory"]),
            knownOrderQuantity: try optionalDouble(entries["order quantity if you know"]),
            desiredServiceLevelPercent: try optionalDouble(entries["desired service level (%) if you know"])
        )
    }

    public static func parseQuantityDiscountEOQ(from data: Data) throws -> QuantityDiscountEOQModel {
        let (metadata, entries, lines) = try parseEntryTableWithLines(from: data)
        guard metadata.count >= 5,
              metadata[0] == "ITS",
              metadata[3] == "1",
              metadata[4] == "1"
        else {
            throw InventoryModelError.unsupportedFormat
        }

        let breakCount = Int(try requiredDouble(entries, "number of discount breaks (quantities)"))
        guard breakCount >= 0 else {
            throw InventoryModelError.invalidModel("discount break count must be nonnegative")
        }

        guard let breakCountRowIndex = lines.firstIndex(where: { row in
            row.first?.lowercased() == "number of discount breaks (quantities)"
        }) else {
            throw InventoryModelError.unsupportedFormat
        }

        let discountRowsStart = breakCountRowIndex + 4
        guard lines.count >= discountRowsStart + breakCount else {
            throw InventoryModelError.unsupportedFormat
        }

        let discountBreaks = try (0..<breakCount).map { offset in
            let row = lines[discountRowsStart + offset]
            guard row.count >= 3 else {
                throw InventoryModelError.unsupportedFormat
            }
            return QuantityDiscountBreak(
                minimumQuantity: try requiredDouble(row[1]),
                discountPercent: try requiredDouble(row[2])
            )
        }

        return QuantityDiscountEOQModel(
            title: metadata[1],
            timeUnit: metadata[2],
            demand: try requiredDouble(entries, "demand per year"),
            setupCost: try requiredDouble(entries, "order or setup cost per order"),
            holdingCost: try requiredDouble(entries, "unit holding cost per year"),
            acquisitionCost: try requiredDouble(entries, "unit acquisition cost without discount"),
            discountBreaks: discountBreaks,
            knownOrderQuantity: try optionalDouble(entries["order quantity if you known"])
        )
    }

    public static func parseLotSizing(from data: Data) throws -> LotSizingModel {
        let (metadata, _, lines) = try parseEntryTableWithLines(from: data)
        guard metadata.count >= 5,
              metadata[0] == "ITS",
              metadata[3] == "3",
              let periodCount = Int(metadata[4]),
              periodCount > 0,
              lines.count >= periodCount + 2
        else {
            throw InventoryModelError.unsupportedFormat
        }

        let periods = try lines[2..<(2 + periodCount)].map { row in
            guard row.count >= 6 else {
                throw InventoryModelError.unsupportedFormat
            }
            return LotSizingPeriod(
                name: row[0],
                demand: try requiredInt(row[1]),
                setupCost: try requiredDouble(row[2]),
                unitVariableCost: try requiredDouble(row[3]),
                unitHoldingCost: try requiredDouble(row[4]),
                unitBackorderCost: try requiredDouble(row[5])
            )
        }

        return LotSizingModel(
            title: metadata[1],
            timeUnit: metadata[2],
            periods: periods
        )
    }

    private static func parseEntryTable(from data: Data) throws -> ([String], [String: String]) {
        let (metadata, entries, _) = try parseEntryTableWithLines(from: data)
        return (metadata, entries)
    }

    private static func parseEntryTableWithLines(from data: Data) throws -> ([String], [String: String], [[String]]) {
        guard let text = data.legacyLatin1String else {
            throw InventoryModelError.unsupportedFormat
        }

        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(clean) }

        guard let metadata = lines.first, metadata.count >= 5 else {
            throw InventoryModelError.unsupportedFormat
        }

        var entries: [String: String] = [:]
        for row in lines.dropFirst(2) where row.count >= 2 {
            entries[row[0].lowercased()] = row[1]
        }
        return (metadata, entries, lines)
    }

    private static func requiredDouble(_ entries: [String: String], _ key: String) throws -> Double {
        guard let value = entries[key] else {
            throw InventoryModelError.unsupportedFormat
        }
        guard let number = try optionalDouble(value) else {
            throw InventoryModelError.invalidNumericValue(value)
        }
        return number
    }

    private static func requiredDouble(_ value: String) throws -> Double {
        guard let number = try optionalDouble(value) else {
            throw InventoryModelError.invalidNumericValue(value)
        }
        return number
    }

    private static func requiredInt(_ value: String) throws -> Int {
        let number = try requiredDouble(value)
        let rounded = number.rounded()
        guard abs(number - rounded) < 1e-8 else {
            throw InventoryModelError.unsupportedModel("lot sizing currently requires integer demand")
        }
        return Int(rounded)
    }

    private static func optionalDouble(_ value: String?) throws -> Double? {
        guard let value else {
            return nil
        }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.uppercased() != "M" else {
            return nil
        }
        guard let number = Double(normalized), number.isFinite else {
            throw InventoryModelError.invalidNumericValue(value)
        }
        return number
    }

    private static func clean(_ value: Substring) -> String {
        String(value).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

