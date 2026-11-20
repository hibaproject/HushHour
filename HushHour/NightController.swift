import Foundation

/// Vérifie chaque seconde quelle programmation est en cours et règle le son.
final class NightController: ObservableObject {
    @Published private(set) var isArmed = false
    @Published private(set) var playing: Schedule?
    @Published private(set) var fadeProgress: Double = 1
    @Published private(set) var errorMessage: String?
    @Published private(set) var previewing = false

    private let engine = NoiseEngine()
    private let store: ScheduleStore
    private var timer: Timer?
    private var previewEnd: Date?
    private var previewSound: (kind: SoundKind, volume: Double)?

    init(store: ScheduleStore) {
        self.store = store
    }

    // MARK: - Mode nuit

    func arm() {
        do {
            try engine.start()
            errorMessage = nil
        } catch {
            errorMessage = "Impossible de démarrer le son : \(error.localizedDescription)"
        }
        isArmed = true
        ensureTimer()
        tick()
    }

    func disarm() {
        guard isArmed else { return }
        isArmed = false
        playing = nil
        engine.apply(sound: nil, volume: 0, fileURL: nil)
        stopEngineSoon()
    }

    // MARK: - Écoute rapide dans l'éditeur

    func togglePreview(sound: SoundKind, volume: Double) {
        if previewing { stopPreview(); return }
        do { try engine.start() } catch { return }
        previewSound = (kind: sound, volume: volume)
        previewEnd = Date().addingTimeInterval(10)
        previewing = true
        ensureTimer()
        tick()
    }

    func updatePreview(sound: SoundKind, volume: Double) {
        guard previewing else { return }
        previewSound = (kind: sound, volume: volume)
        tick()
    }

    func stopPreview() {
        guard previewing else { return }
        previewEnd = nil
        previewSound = nil
        previewing = false
        if isArmed {
            tick()
        } else {
            engine.apply(sound: nil, volume: 0, fileURL: nil)
            stopEngineSoon()
        }
    }

    // MARK: - Boucle

    private func ensureTimer() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick(now: Date = Date()) {
        if previewing {
            if let end = previewEnd, now < end, let p = previewSound {
                if !engine.apply(sound: p.kind, volume: Float(p.volume), fileURL: store.customSoundURL) {
                    stopPreview()
                }
                return
            }
            stopPreview()
            return
        }

        guard isArmed else {
            timer?.invalidate()
            timer = nil
            return
        }

        if let active = store.active(at: now) {
            let s = active.schedule, elapsed = active.elapsed
            let fadeIn = s.fadeMinutes > 0 ? min(1, elapsed / Double(s.fadeMinutes)) : 1
            let fadeOut = min(1, (Double(s.duration) - elapsed) / 0.5) // 30 s de fondu à la fin
            let gain = s.volume * Self.loudnessCurve(fadeIn) * fadeOut
            let ok = engine.apply(sound: s.sound, volume: Float(gain), fileURL: store.customSoundURL)
            errorMessage = ok ? nil : "Ton fichier audio est introuvable. Choisis-le à nouveau dans la programmation."
            playing = ok ? s : nil
            fadeProgress = fadeIn
        } else {
            engine.apply(sound: nil, volume: 0, fileURL: nil)
            playing = nil
        }
    }

    /// L'oreille perçoit le volume en décibels : une montée linéaire paraît brutale au début puis plate.
    /// On monte donc de -50 dB à 0 dB à vitesse constante, ce qui s'entend comme une montée douce et régulière.
    private static func loudnessCurve(_ progress: Double) -> Double {
        guard progress > 0 else { return 0 }
        guard progress < 1 else { return 1 }
        return pow(10, 2.5 * (progress - 1))
    }

    private func stopEngineSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, !self.isArmed, !self.previewing else { return }
            self.engine.stop()
        }
    }
}
