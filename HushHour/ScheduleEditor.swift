import SwiftUI
import UniformTypeIdentifiers

struct ScheduleEditor: View {
    @EnvironmentObject private var store: ScheduleStore
    @EnvironmentObject private var night: NightController
    @Environment(\.dismiss) private var dismiss

    @State var draft: Schedule
    let isNew: Bool
    @State private var importing = false
    @State private var importError: String?

    init(draft: Schedule, isNew: Bool) {
        _draft = State(initialValue: draft)
        self.isNew = isNew
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Horaires") {
                    DatePicker("Début", selection: time(\.start), displayedComponents: .hourAndMinute)
                    DatePicker("Fin", selection: time(\.end), displayedComponents: .hourAndMinute)
                    if draft.start == draft.end {
                        Text("Le début et la fin doivent être différents.").font(.footnote).foregroundStyle(.red)
                    } else if draft.start > draft.end {
                        Text("Passe minuit : se termine le lendemain à \(Fmt.clock(draft.end)).")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section("Jours") {
                    DayPicker(days: $draft.days)
                    if draft.days.isEmpty {
                        Text("Choisis au moins un jour.").font(.footnote).foregroundStyle(.red)
                    }
                }

                Section("Son") {
                    Picker("Son", selection: $draft.sound) {
                        ForEach(SoundKind.allCases) { kind in
                            VStack(alignment: .leading) {
                                Text(kind.name)
                                Text(kind.hint).font(.footnote).foregroundStyle(.secondary)
                            }
                            .tag(kind)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()

                    if draft.sound == .file {
                        Button(store.customSound.map { "Remplacer « \($0.displayName) »" } ?? "Choisir un fichier audio") {
                            importing = true
                        }
                        if let importError {
                            Text(importError).font(.footnote).foregroundStyle(.red)
                        }
                    }
                }

                Section("Réglages") {
                    HStack {
                        Text("Volume")
                        Slider(value: $draft.volume, in: 0.05...1, step: 0.05)
                        Text("\(Int((draft.volume * 100).rounded())) %")
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                    }
                    Picker("Montée progressive", selection: $draft.fadeMinutes) {
                        Text("Aucune").tag(0)
                        ForEach([1, 5, 10, 20, 30], id: \.self) { Text("\($0) min").tag($0) }
                    }
                    Button(night.previewing ? "Arrêter l'écoute" : "Écouter 10 s") {
                        night.togglePreview(sound: draft.sound, volume: draft.volume)
                    }
                    .disabled(draft.sound == .file && store.customSoundURL == nil)
                }

                if !isNew {
                    Section {
                        Button("Supprimer cette programmation", role: .destructive) {
                            store.schedules.removeAll { $0.id == draft.id }
                            dismiss()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.night)
            .navigationTitle(isNew ? "Nouvelle programmation" : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Ajouter" : "Enregistrer") {
                        store.upsert(draft)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in
                switch result {
                case .success(let url):
                    do {
                        try store.importSound(from: url)
                        importError = nil
                    } catch {
                        importError = "Ce fichier n'a pas pu être copié. Essaie un mp3 ou un m4a enregistré sur l'iPhone."
                    }
                case .failure:
                    importError = "Aucun fichier choisi."
                }
            }
            .onChange(of: draft.volume) { _ in night.updatePreview(sound: draft.sound, volume: draft.volume) }
            .onChange(of: draft.sound) { _ in night.updatePreview(sound: draft.sound, volume: draft.volume) }
            .onDisappear { night.stopPreview() }
        }
        .preferredColorScheme(.dark)
    }

    private var isValid: Bool {
        !draft.days.isEmpty && draft.start != draft.end && (draft.sound != .file || store.customSoundURL != nil)
    }

    /// Relie un DatePicker heure/minute à un nombre de minutes depuis minuit.
    private func time(_ keyPath: WritableKeyPath<Schedule, Int>) -> Binding<Date> {
        Binding(
            get: {
                let m = draft[keyPath: keyPath]
                return Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                draft[keyPath: keyPath] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }
}

private struct DayPicker: View {
    @Binding var days: Set<Int>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Fmt.weekOrder, id: \.self) { day in
                let on = days.contains(day)
                Button {
                    if on { days.remove(day) } else { days.insert(day) }
                } label: {
                    Text(String((Fmt.weekdayNames[day] ?? "").prefix(2)))
                        .font(.footnote.weight(.medium))
                        .frame(width: 38, height: 38)
                        .background(on ? Color.white : Color.clear, in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.25)))
                        .foregroundStyle(on ? Color.black : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Fmt.weekdayNames[day] ?? "")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }
}
