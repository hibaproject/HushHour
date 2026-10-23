import Foundation
import SwiftUI

enum SoundKind: String, Codable, CaseIterable, Identifiable {
    case white, pink, brown, file

    var id: String { rawValue }

    var name: String {
        switch self {
        case .white: return "Bruit blanc"
        case .pink: return "Bruit rose"
        case .brown: return "Bruit marron"
        case .file: return "Mon son"
        }
    }

    var hint: String {
        switch self {
        case .white: return "Aigu, comme une radio entre deux stations"
        case .pink: return "Plus doux, comme la pluie"
        case .brown: return "Grave, couvre bien les bruits sourds"
        case .file: return "Un fichier audio de ton téléphone"
        }
    }
}

struct Schedule: Codable, Identifiable, Equatable {
    var id = UUID()
    /// Minutes depuis minuit.
    var start: Int = 4 * 60
    var end: Int = 8 * 60
    /// Jours de la semaine au format Calendar : 1 = dimanche … 7 = samedi.
    var days: Set<Int> = Set(1...7)
    var sound: SoundKind = .brown
    var volume: Double = 0.6
    var fadeMinutes: Int = 10
    var isOn: Bool = true

    /// Durée de la plage en minutes (gère le passage de minuit).
    var duration: Int { (end - start + 1440) % 1440 }

    /// Minutes écoulées depuis le début si la plage est en cours à `date`, sinon nil.
    func elapsed(at date: Date, calendar: Calendar = .current) -> Double? {
        guard isOn, start != end else { return nil }
        let c = calendar.dateComponents([.hour, .minute, .second, .weekday], from: date)
        let m = Double((c.hour ?? 0) * 60 + (c.minute ?? 0)) + Double(c.second ?? 0) / 60
        let today = c.weekday ?? 1
        let yesterday = today == 1 ? 7 : today - 1
        let a = Double(start), b = Double(end)
        if start < end {
            return days.contains(today) && m >= a && m < b ? m - a : nil
        }
        // La plage passe minuit, par exemple 23:00 → 07:00.
        if m >= a && days.contains(today) { return m - a }
        if m < b && days.contains(yesterday) { return m + 1440 - a }
        return nil
    }

    func nextStart(after date: Date, calendar: Calendar = .current) -> Date? {
        guard isOn, !days.isEmpty, start != end else { return nil }
        let day0 = calendar.startOfDay(for: date)
        for k in 0..<8 {
            guard let day = calendar.date(byAdding: .day, value: k, to: day0),
                  let at = calendar.date(bySettingHour: start / 60, minute: start % 60, second: 0, of: day)
            else { continue }
            if at > date && days.contains(calendar.component(.weekday, from: at)) { return at }
        }
        return nil
    }
}

struct CustomSound: Codable, Equatable {
    var fileName: String
    var displayName: String
}

final class ScheduleStore: ObservableObject {
    @Published var schedules: [Schedule] { didSet { save() } }
    @Published var customSound: CustomSound? { didSet { save() } }

    private static let schedulesKey = "schedules.v1"
    private static let soundKey = "customSound.v1"

    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.schedulesKey),
           let list = try? JSONDecoder().decode([Schedule].self, from: data) {
            schedules = list
        } else {
            schedules = [Schedule()] // exemple : 04:00 → 08:00, bruit marron, tous les jours
        }
        if let data = defaults.data(forKey: Self.soundKey) {
            customSound = try? JSONDecoder().decode(CustomSound.self, from: data)
        }
    }

    private func save() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(schedules) { defaults.set(data, forKey: Self.schedulesKey) }
        if let sound = customSound, let data = try? JSONEncoder().encode(sound) {
            defaults.set(data, forKey: Self.soundKey)
        } else {
            defaults.removeObject(forKey: Self.soundKey)
        }
    }

    var customSoundURL: URL? {
        guard let sound = customSound else { return nil }
        let url = Self.documents.appendingPathComponent(sound.fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Copie le fichier choisi dans les documents de l'app pour qu'il reste disponible.
    func importSound(from url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.isEmpty ? "m4a" : url.pathExtension
        let name = "custom-\(UUID().uuidString.prefix(8)).\(ext)"
        let dest = Self.documents.appendingPathComponent(name)
        try FileManager.default.copyItem(at: url, to: dest)
        if let old = customSoundURL { try? FileManager.default.removeItem(at: old) }
        customSound = CustomSound(fileName: name, displayName: url.lastPathComponent)
    }

    func upsert(_ schedule: Schedule) {
        if let i = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[i] = schedule
        } else {
            schedules.append(schedule)
        }
    }

    func active(at date: Date) -> (schedule: Schedule, elapsed: Double)? {
        for s in schedules {
            if let e = s.elapsed(at: date) { return (schedule: s, elapsed: e) }
        }
        return nil
    }

    func next(after date: Date) -> (schedule: Schedule, at: Date)? {
        schedules
            .compactMap { s in s.nextStart(after: date).map { (schedule: s, at: $0) } }
            .min { $0.at < $1.at }
    }
}

enum Theme {
    static let night = Color(red: 0.05, green: 0.063, blue: 0.125)
    static let panel = Color(red: 0.086, green: 0.10, blue: 0.18)
    static let moon = Color(red: 0.94, green: 0.79, blue: 0.48)
    static let live = Color(red: 0.50, green: 0.84, blue: 0.69)
}

enum Fmt {
    static let weekOrder = [2, 3, 4, 5, 6, 7, 1]
    static let weekdayNames: [Int: String] = [1: "Dim", 2: "Lun", 3: "Mar", 4: "Mer", 5: "Jeu", 6: "Ven", 7: "Sam"]

    static func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    static func clock(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return clock((c.hour ?? 0) * 60 + (c.minute ?? 0))
    }

    static func until(_ interval: TimeInterval) -> String {
        let total = Int((interval / 60).rounded()), h = total / 60, m = total % 60
        if h >= 24 { return "dans \(h / 24) j" }
        return h > 0 ? "dans \(h) h \(String(format: "%02d", m))" : "dans \(m) min"
    }

    static func day(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "aujourd'hui" }
        if cal.isDateInTomorrow(date) { return "demain" }
        return (weekdayNames[cal.component(.weekday, from: date)] ?? "").lowercased() + "."
    }

    static func days(_ d: Set<Int>) -> String {
        if d.count == 7 { return "Tous les jours" }
        if d == [2, 3, 4, 5, 6] { return "En semaine" }
        if d == [7, 1] { return "Week-end" }
        return weekOrder.filter(d.contains).compactMap { weekdayNames[$0] }.joined(separator: " ")
    }
}
