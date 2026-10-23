import SwiftUI

@main
struct HushHourApp: App {
    @StateObject private var store: ScheduleStore
    @StateObject private var night: NightController

    init() {
        let store = ScheduleStore()
        _store = StateObject(wrappedValue: store)
        _night = StateObject(wrappedValue: NightController(store: store))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(night)
                .preferredColorScheme(.dark)
                .tint(Theme.moon)
        }
    }
}
