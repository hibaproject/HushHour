import AVFoundation

/// Génère les bruits en temps réel et lit le fichier perso en boucle.
/// Tant que le moteur tourne (même en silence), iOS garde l'app active en arrière-plan
/// grâce au mode « Audio » : c'est ce qui permet de démarrer le son à 4 h téléphone verrouillé.
final class NoiseEngine {
    /// État partagé avec le thread audio.
    private final class State {
        var kind: SoundKind = .brown
        var target: Float = 0
        var gain: Float = 0
        var seed: UInt32 = 0x9E37_79B9
        var b0: Float = 0, b1: Float = 0, b2: Float = 0, b3: Float = 0, b4: Float = 0, b5: Float = 0, b6: Float = 0
        var brown: Float = 0
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let state: State
    private let source: AVAudioSourceNode
    private var audioFile: AVAudioFile?
    private var fileLooping = false
    private var wantsRunning = false

    init() {
        let sampleRate = 48_000.0
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let st = State()
        let smoothing = Float(1 / (0.3 * sampleRate)) // lissage du volume sur ~0,3 s, sans clic
        state = st
        source = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                st.gain += (st.target - st.gain) * smoothing
                st.seed ^= st.seed << 13
                st.seed ^= st.seed >> 17
                st.seed ^= st.seed << 5
                let w = Float(st.seed) / Float(UInt32.max) * 2 - 1
                var v: Float
                switch st.kind {
                case .white:
                    v = w * 0.3
                case .pink:
                    // Filtre de Paul Kellet
                    st.b0 = 0.99886 * st.b0 + w * 0.0555179
                    st.b1 = 0.99332 * st.b1 + w * 0.0750759
                    st.b2 = 0.96900 * st.b2 + w * 0.1538520
                    st.b3 = 0.86650 * st.b3 + w * 0.3104856
                    st.b4 = 0.55000 * st.b4 + w * 0.5329522
                    st.b5 = -0.7616 * st.b5 - w * 0.0168980
                    v = (st.b0 + st.b1 + st.b2 + st.b3 + st.b4 + st.b5 + st.b6 + w * 0.5362) * 0.1
                    st.b6 = w * 0.115926
                case .brown:
                    st.brown = (st.brown + 0.02 * w) / 1.02
                    v = st.brown * 3.2
                case .file:
                    v = 0
                }
                v *= st.gain
                for buffer in buffers {
                    buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = v
                }
            }
            return noErr
        }

        engine.attach(source)
        engine.attach(player)
        engine.connect(source, to: engine.mainMixerNode, format: format)

        let nc = NotificationCenter.default
        nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
            self?.recover()
        }
        nc.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            self?.recover()
        }
    }

    func start() throws {
        wantsRunning = true
        let session = AVAudioSession.sharedInstance()
        // .playback joue même si l'iPhone est en mode silencieux ; .mixWithOthers évite d'être coupé par d'autres apps.
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
        if !engine.isRunning {
            engine.prepare()
            try engine.start()
        }
    }

    func stop() {
        wantsRunning = false
        stopFile()
        state.target = 0
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// `sound == nil` : silence (le moteur continue de tourner pour garder l'app éveillée).
    @discardableResult
    func apply(sound: SoundKind?, volume: Float, fileURL: URL?) -> Bool {
        switch sound {
        case .file?:
            state.target = 0
            guard let fileURL, startFile(fileURL) else { return false }
            player.volume = volume
        case let kind?:
            if fileLooping { stopFile() }
            state.kind = kind
            state.target = volume
        case nil:
            state.target = 0
            if fileLooping { stopFile() }
        }
        return true
    }

    // MARK: - Fichier perso

    private func startFile(_ url: URL) -> Bool {
        if fileLooping, audioFile?.url == url { return true }
        stopFile()
        guard let file = try? AVAudioFile(forReading: url) else { return false }
        audioFile = file
        engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)
        fileLooping = true
        scheduleLoop(file)
        player.volume = 0
        player.play()
        return true
    }

    private func scheduleLoop(_ file: AVAudioFile) {
        player.scheduleFile(file, at: nil, completionCallbackType: .dataConsumed) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.fileLooping, self.audioFile === file else { return }
                self.scheduleLoop(file)
            }
        }
    }

    private func stopFile() {
        fileLooping = false
        player.stop()
        player.volume = 0
    }

    // MARK: - Reprise après un appel, une alarme ou un changement de sortie audio

    private func recover() {
        guard wantsRunning else { return }
        let fileURL = fileLooping ? audioFile?.url : nil
        let volume = player.volume
        try? start()
        if let fileURL {
            fileLooping = false
            if startFile(fileURL) { player.volume = volume }
        }
    }
}
