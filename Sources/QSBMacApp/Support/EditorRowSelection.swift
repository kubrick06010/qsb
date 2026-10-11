import Foundation

/// Keeps a surviving selection, or uses its former position in the remaining rows.
/// An absent selection stays absent so model changes do not steal keyboard focus.
func repairedEditorRowSelection(_ selection: UUID?, previous: [UUID], current: [UUID]) -> UUID? {
    guard let selection else { return nil }
    if current.contains(selection) { return selection }
    guard !current.isEmpty else { return nil }
    let index = previous.firstIndex(of: selection) ?? 0
    return current[min(index, current.count - 1)]
}
