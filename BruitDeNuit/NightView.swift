import SwiftUI

/// Écran noir affiché pendant le mode nuit.
struct NightView: View {
    @EnvironmentObject private var store: ScheduleStore
    @EnvironmentObject private var night: NightController

    private let dimAmber = Color(red: 0.54, green: 0.48, blue: 0.33)
    private let dimText = Color(red: 0.42, green: 0.42, blue: 0.50)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 16) {
                Spacer()
                Text(Fmt.clock(context.date))
                    .font(.system(size: 96, weight: .light, design: .monospaced))
                    .foregroundStyle(dimAmber)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(status(context.date))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(night.playing != nil ? Theme.live.opacity(0.7) : dimText)
                if let error = night.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.red.opacity(0.7))
                }
                Spacer()
                Text("Tu peux verrouiller le téléphone.\nNe ferme pas l'app depuis le sélecteur d'apps.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(dimText)
                Button("Quitter le mode nuit") { night.disarm() }
                    .buttonStyle(.bordered)
                    .tint(dimText)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
        .statusBarHidden()
    }

    private func status(_ now: Date) -> String {
        if let s = night.playing {
            var text = "\(s.sound.name) en cours · jusqu'à \(Fmt.clock(s.end))"
            if night.fadeProgress < 1 { text += " · montée \(Int(night.fadeProgress * 100)) %" }
            return text
        }
        if let n = store.next(after: now) {
            return "\(n.schedule.sound.name) à \(Fmt.clock(n.schedule.start)) \(Fmt.day(n.at))\n\(Fmt.until(n.at.timeIntervalSince(now)))"
        }
        return "Aucune programmation active."
    }
}
