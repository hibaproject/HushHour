import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ScheduleStore
    @EnvironmentObject private var night: NightController
    @State private var editing: Schedule?
    @State private var isNew = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(Fmt.clock(context.date))
                                .font(.system(size: 72, weight: .light, design: .monospaced))
                            nextLine(context.date)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listRowBackground(Color.clear)

                Section {
                    Button { night.arm() } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Lancer le mode nuit").font(.title3.bold())
                                Text("Le son démarrera tout seul à l'heure prévue, même téléphone verrouillé")
                                    .font(.footnote)
                                    .opacity(0.8)
                            }
                            Spacer()
                            Image(systemName: "moon.fill").font(.title)
                        }
                        .foregroundStyle(Color.black)
                        .padding(18)
                        .frame(maxWidth: .infinity)
                        .background(Theme.moon, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                Section("Programmations") {
                    if store.schedules.isEmpty {
                        Text("Aucune programmation. Appuie sur + pour en ajouter une.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach($store.schedules) { $schedule in
                        ScheduleRow(schedule: $schedule, fileMissing: schedule.sound == .file && store.customSoundURL == nil)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isNew = false
                                editing = schedule
                            }
                    }
                    .onDelete { store.schedules.remove(atOffsets: $0) }
                }
                .listRowBackground(Theme.panel)

                Section("Pour que ça marche la nuit") {
                    Tip(title: "Lance le mode nuit avant de dormir.", text: "Tu peux ensuite verrouiller le téléphone. Ne ferme pas l'app en la balayant vers le haut dans le sélecteur d'apps.")
                    Tip(title: "Branche le chargeur.", text: "L'app reste active toute la nuit en arrière-plan.")
                    Tip(title: "Monte le volume média.", text: "Le son joue même si l'iPhone est en mode silencieux.")
                }
                .listRowBackground(Theme.panel)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.night)
            .navigationTitle("Hush Hour")
            .toolbar {
                Button {
                    isNew = true
                    editing = Schedule()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Ajouter une programmation")
            }
            .sheet(item: $editing) { schedule in
                ScheduleEditor(draft: schedule, isNew: isNew)
            }
            .fullScreenCover(isPresented: Binding(get: { night.isArmed }, set: { if !$0 { night.disarm() } })) {
                NightView()
            }
        }
    }

    @ViewBuilder
    private func nextLine(_ now: Date) -> some View {
        if let s = store.active(at: now)?.schedule {
            Text("\(s.sound.name) programmé en ce moment, jusqu'à \(Fmt.clock(s.end))")
        } else if let n = store.next(after: now) {
            Text("Prochain son : ") + Text(Fmt.clock(n.schedule.start)).foregroundColor(Theme.moon) + Text(" \(Fmt.day(n.at)), \(Fmt.until(n.at.timeIntervalSince(now)))")
        } else {
            Text("Aucune programmation active")
        }
    }
}

private struct ScheduleRow: View {
    @Binding var schedule: Schedule
    let fileMissing: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Fmt.clock(schedule.start)) → \(Fmt.clock(schedule.end))")
                    .font(.system(.title2, design: .monospaced))
                Text(details)
                    .font(.footnote)
                    .foregroundStyle(fileMissing ? Color.red : Color.secondary)
            }
            Spacer()
            Toggle("Activer", isOn: $schedule.isOn).labelsHidden()
        }
        .padding(.vertical, 4)
        .opacity(schedule.isOn ? 1 : 0.5)
    }

    private var details: String {
        var parts = [schedule.sound.name + (fileMissing ? " (fichier manquant)" : ""), Fmt.days(schedule.days), "\(Int(schedule.volume * 100)) %"]
        if schedule.fadeMinutes > 0 { parts.append("montée \(schedule.fadeMinutes) min") }
        return parts.joined(separator: " · ")
    }
}

private struct Tip: View {
    let title: String
    let text: String

    var body: some View {
        (Text(title).bold() + Text(" ") + Text(text).foregroundColor(.secondary))
            .font(.footnote)
    }
}
