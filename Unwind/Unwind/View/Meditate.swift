//
//  Meditate.swift
//  Unwind
//
//  Guided breathing session: a countdown timer inside a soft breathing circle
//  whose expand/contract is synced to gentle Core Haptics swells. The circle is
//  the whole interface — tap it to begin; once running, the pause/restart
//  controls live inside it, under the countdown.
//
//  Created by Leah Cluff on 4/10/23.
//

import SwiftUI
import CoreHaptics
import os

struct Meditate: View {

    /// Where the session is in its lifecycle. Drives what shows inside the circle.
    private enum SessionState { case idle, running, paused, done }

    // MARK: Session configuration
    /// Selectable session lengths, in minutes.
    private let lengthOptions = [1, 3, 5, 10]
    /// How long to breathe in / out, in seconds. One full cycle = 12.5s,
    /// i.e. ~4.8 breaths per minute — an unhurried, meditative pace.
    private let inhale: Double = 6.25
    private let exhale: Double = 6.25

    // MARK: Layout — breathing circle sizing
    /// Resting diameter of the breathing circle (its starting size).
    private let restDiameter: CGFloat = 240
    /// Full-inhale scale: the circle expands out to restDiameter * maxScale
    /// (the "outer ring" extent — nothing is drawn there, it's just the bound).
    private let maxScale: CGFloat = 1.5

    // MARK: State
    @State private var session: SessionState = .idle
    @State private var sessionMinutes = 3
    @State private var remaining = 3 * 60          // seconds left in the session

    @State private var pendingMinutes = 3          // length awaiting confirmation
    @State private var showSwitchConfirm = false

    @State private var breathScale: CGFloat = 1.0  // 1 = resting, maxScale = full inhale
    /// Drives the inhale/exhale phases on their own clock, independent of the
    /// 1-second countdown tick (the phases aren't whole seconds long).
    @State private var breathTask: Task<Void, Never>?

    /// Used to pause a running session when the app backgrounds / screen locks.
    @Environment(\.scenePhase) private var scenePhase

    private let haptics = BreathingHaptics()

    /// Fires once a second for the countdown. Ignored unless running.
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Gradient.blueGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                NavHeader("Meditation")

                Spacer()

                breathingCircle

                Spacer()

                // Length picker. Switch freely while idle or paused; a running
                // session confirms first (handled in requestLength).
                Picker("Length", selection: Binding(
                    get: { sessionMinutes },
                    set: { requestLength($0) }
                )) {
                    ForEach(lengthOptions, id: \.self) { mins in
                        Text("\(mins) min").tag(mins)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 40)

                Spacer()
            }
            .foregroundStyle(.white)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onReceive(ticker) { _ in tick() }
        .onDisappear { leave() }
        .onChange(of: scenePhase) { _, phase in handleScenePhase(phase) }
        .confirmationDialog("Switch to \(pendingMinutes) min?",
                            isPresented: $showSwitchConfirm,
                            titleVisibility: .visible) {
            Button("Switch Timer") { commitLength(pendingMinutes) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This ends your current session.")
        }
    }

    // MARK: Breathing circle

    private var breathingCircle: some View {
        ZStack {
            // Soft blurred disc + ring that breathe from restDiameter out to
            // restDiameter * maxScale.
            Circle()
                .fill(Color.vividTangerine)
                .opacity(0.55)
                .frame(width: restDiameter, height: restDiameter)
                .scaleEffect(breathScale)
                .blur(radius: 16)
                .shadow(radius: 25)

            Circle()
                .stroke(Color.desertSand, lineWidth: 10)
                .frame(width: restDiameter, height: restDiameter)
                .scaleEffect(breathScale)
                .opacity(0.7)
                .blur(radius: 9)

            // Countdown + (depending on state) the prompt or the controls. This
            // layer is crisp and still — it does not scale or blur with the circle.
            VStack(spacing: 12) {
                Text(timeString)
                    .font(.custom("Montserrat-Medium", size: 44))
                    .monospacedDigit()

                centerContent
            }
            .frame(maxWidth: restDiameter * 0.72)
            .multilineTextAlignment(.center)

            // Idle-only transparent tap target: tapping the circle begins. It only
            // exists while idle, so it can never intercept the control buttons.
            if session == .idle {
                Circle()
                    .fill(.clear)
                    .contentShape(Circle())
                    .frame(width: restDiameter, height: restDiameter)
                    .onTapGesture { start() }
            }
        }
        .frame(height: restDiameter * maxScale + 24)   // reserve room for full inhale
    }

    @ViewBuilder
    private var centerContent: some View {
        switch session {
        case .idle:
            Text("tap to begin")
                .font(.custom("Montserrat-Light", size: 17))
                .opacity(0.85)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        case .done:
            Text("Done")
                .font(.custom("Montserrat-Light", size: 17))
                .opacity(0.85)
        case .running, .paused:
            HStack(spacing: 36) {
                Button(action: restart) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 22))
                }
                Button(action: togglePause) {
                    Image(systemName: session == .running ? "pause.fill" : "play.fill")
                        .font(.system(size: 26))
                }
            }
            .padding(.top, 2)
        }
    }

    // MARK: Derived values
    private var timeString: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    // MARK: Controls

    /// Picker tapped. Switch freely while idle or paused; a running session
    /// asks to confirm first so an active meditation isn't lost by accident.
    private func requestLength(_ minutes: Int) {
        guard minutes != sessionMinutes else { return }
        if session == .running {
            pendingMinutes = minutes
            showSwitchConfirm = true
        } else {
            commitLength(minutes)
        }
    }

    /// Apply a new length and reset to a fresh "tap to begin" at that length.
    private func commitLength(_ minutes: Int) {
        sessionMinutes = minutes
        remaining = minutes * 60
        guard session != .idle else { return }
        session = .idle
        breathTask?.cancel()
        haptics.stopBreath()
        withAnimation(.easeInOut(duration: 0.4)) { breathScale = 1.0 }
    }

    /// Begin (from idle) or resume (from paused).
    private func start() {
        if remaining == 0 { remaining = sessionMinutes * 60 }
        session = .running
        haptics.start()
        startBreathing()
    }

    /// The breath loop. The haptic measure loops sample-accurately on the
    /// haptic engine's own clock (no per-cycle re-trigger, so no gap or jitter
    /// at the loop seam), while the animation phases are scheduled against
    /// absolute clock deadlines so they can't drift apart from the haptics
    /// over a long session.
    private func startBreathing() {
        breathTask?.cancel()
        haptics.startBreathLoop(inhale: inhale, exhale: exhale)
        breathTask = Task { @MainActor in
            let clock = ContinuousClock()
            let t0 = clock.now
            var cycle = 0
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: inhale)) { breathScale = maxScale }
                try? await clock.sleep(
                    until: t0 + .seconds(Double(cycle) * (inhale + exhale) + inhale))
                if Task.isCancelled { break }
                withAnimation(.easeInOut(duration: exhale)) { breathScale = 1.0 }
                cycle += 1
                try? await clock.sleep(
                    until: t0 + .seconds(Double(cycle) * (inhale + exhale)))
            }
        }
    }

    /// Leaving the app or locking the screen mid-session pauses it. iOS stops
    /// the haptic engine and suspends the countdown the moment we background, so
    /// pausing keeps the UI honest — and tapping play on return cleanly rebuilds
    /// the engine and breath loop. Only a true background pauses; a brief banner
    /// or Control Center peek is merely .inactive and is left alone.
    private func handleScenePhase(_ phase: ScenePhase) {
        if phase == .background, session == .running {
            togglePause()
        }
    }

    private func togglePause() {
        switch session {
        case .running:
            session = .paused
            breathTask?.cancel()
            haptics.stopBreath()
            // Settle to rest so the next inhale starts from the bottom, in sync.
            withAnimation(.easeInOut(duration: 0.8)) { breathScale = 1.0 }
        case .paused:
            start()
        default:
            break
        }
    }

    /// Back to the idle "tap to begin" state with the time reset.
    private func restart() {
        session = .idle
        remaining = sessionMinutes * 60
        breathTask?.cancel()
        haptics.stopBreath()
        withAnimation(.easeInOut(duration: 0.5)) { breathScale = 1.0 }
    }

    /// Leaving the screen — stop the loop and shut the haptic engine down.
    private func leave() {
        session = .idle
        breathTask?.cancel()
        haptics.shutdown()
    }

    // MARK: Per-second countdown tick
    private func tick() {
        guard session == .running else { return }
        if remaining > 0 {
            remaining -= 1
        }
        if remaining == 0 {
            finish()
        }
    }

    private func finish() {
        session = .done
        breathTask?.cancel()
        haptics.stopBreath()
        haptics.completion()
        withAnimation(.easeInOut(duration: 0.6)) { breathScale = 1.0 }

        // Hold "Done" through the closing three-knock cadence (~2.5s) plus a
        // beat of silence, then settle back to the idle prompt.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.4))
            if session == .done {
                remaining = sessionMinutes * 60
                session = .idle
            }
        }
    }
}

// MARK: - Breathing haptics

/// The breathing "percussion section": each breath cycle is one measure of
/// soft, low wooden thumps — like a bamboo wind chime knocking quietly — whose
/// volume swells to a crescendo at full inhale and dies away through the exhale.
///
/// In the musician's terms this code is tuned with:
///   - PACE   = the crescendo envelope — locked to the circle's ease-in-out
///              animation, peaking exactly at full inhale.
///   - SPEED  = `thumpsPerSecond` — the subdivision. ~2.5/s reads as separate
///              "thump… thump…" knocks; raise it toward 10/s and it blurs
///              into a tremolo roll.
///   - TIMBRE = `thumpSharpness` (0 = deepest, most muffled strike) plus a
///              short quiet decay tail after each thump — the hollow
///              resonance that makes it bamboo instead of plastic.
///
/// A full cycle (rise + fall) is ONE seamless pattern, so there is no player
/// hand-off at the peak (that splice was felt as a "skip"). The only pattern
/// boundaries are at near-silence, where they're imperceptible.
/// No-ops safely on devices without a haptic engine (e.g. the Simulator).
final class BreathingHaptics {

    /// "Speed": thumps per second — unhurried knocking, well below heartbeat
    /// pace. (The actual interval is nudged so thumps divide the measure
    /// exactly evenly, keeping the spacing metronomic across cycle loops.)
    private let thumpsPerSecond: Double = 1.0
    /// Dynamics: the crescendo swells from a feelable pianissimo floor to the
    /// peak — never from silence, so the start of each breath still registers.
    private let peakIntensity: Float = 0.8
    private let floorIntensity: Float = 0.3
    /// The closing cadence's knock interval, relative to the breathing tempo —
    /// a touch of allargando: the last three knocks ritard into the ending.
    private let cadenceStretch: Double = 1.25
    /// "Timbre": softness of each thump (0 = deepest, roundest knock).
    private let thumpSharpness: Float = 0.0
    /// Hollow after-ring: each thump's decay tail, as a fraction of the
    /// thump's strength, and how long it rings.
    private let resonance: Float = 0.35
    private let resonanceDuration: TimeInterval = 0.09

    private var engine: CHHapticEngine?
    private var activePlayer: CHHapticAdvancedPatternPlayer?
    /// Built once — the cycle durations are fixed for the session — so starting
    /// a cycle never pays pattern-construction latency.
    private var cyclePattern: CHHapticPattern?

    private var supportsHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    /// Spin up the haptic engine for a session. Safe to call repeatedly. The
    /// engine then stays alive across pauses so resuming has no startup lag.
    func start() {
        guard supportsHaptics else {
            Log.haptics.info("Haptics unsupported on this device; running silent.")
            return
        }
        do {
            if engine == nil {
                let engine = try CHHapticEngine()
                // The system can shut the engine down (interruption, background);
                // these handlers let us see and recover from it.
                engine.resetHandler = { [weak self] in
                    Log.haptics.notice("Haptic engine reset; restarting.")
                    do { try self?.engine?.start() }
                    catch { Log.haptics.error("Engine restart after reset failed: \(error.localizedDescription)") }
                }
                engine.stoppedHandler = { reason in
                    Log.haptics.notice("Haptic engine stopped (reason \(reason.rawValue)).")
                }
                self.engine = engine
            }
            try engine?.start()
        } catch {
            Log.haptics.error("Failed to start haptic engine: \(error.localizedDescription)")
        }
    }

    /// Start the breathing measure as a LOOPING pattern: crescendo over the
    /// inhale, decrescendo over the exhale, repeated sample-accurately on the
    /// haptic engine's own clock. No per-cycle re-trigger means no gap or
    /// jitter at the seam between measures.
    func startBreathLoop(inhale: Double, exhale: Double) {
        guard supportsHaptics, let engine else { return }
        do {
            // iOS stops the engine on background / screen lock, so make sure
            // it's running before we (re)arm the loop. Idempotent if already up.
            try engine.start()

            let pattern: CHHapticPattern
            if let cached = cyclePattern {
                pattern = cached
            } else {
                pattern = try makeCyclePattern(inhale: inhale, exhale: exhale)
                cyclePattern = pattern
            }
            let player = try engine.makeAdvancedPlayer(with: pattern)
            player.loopEnabled = true
            // Loop on the full measure, not the last event's end — this keeps
            // the knock spacing exact across the loop point.
            player.loopEnd = inhale + exhale
            activePlayer = player
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // A failed haptic must never interrupt the session — log and move on.
            Log.haptics.error("Failed to start breath loop: \(error.localizedDescription)")
        }
    }

    private func makeCyclePattern(inhale: Double, exhale: Double) throws -> CHHapticPattern {
        let total = inhale + exhale
        // Fit a whole number of thumps into the measure so the gap between the
        // last thump of one cycle and the first of the next is exactly one
        // interval — the knocking stays metronomic across the loop.
        let count = max(1, Int((total * thumpsPerSecond).rounded()))
        let interval = total / Double(count)
        var events: [CHHapticEvent] = []

        for i in 0..<count {
            let t = Double(i) * interval
            // Where this thump sits in the breath: 0→1 across the inhale,
            // back 1→0 across the exhale.
            let phase = t <= inhale ? t / inhale : 1 - (t - inhale) / exhale
            // Same sine ease-in-out as the circle's animation, so the felt
            // crescendo tracks the visual growth; dynamics ride from the
            // pianissimo floor up to the peak and back.
            let eased = Float(0.5 - 0.5 * cos(.pi * phase))
            let intensity = floorIntensity + (peakIntensity - floorIntensity) * eased

            appendThump(at: t, intensity: intensity, into: &events)
        }

        return try CHHapticPattern(events: events, parameters: [])
    }

    /// One bamboo knock: the strike plus its short hollow after-ring.
    private func appendThump(at t: TimeInterval, intensity: Float,
                             into events: inout [CHHapticEvent]) {
        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: thumpSharpness)
            ],
            relativeTime: t
        ))
        events.append(CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * resonance),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.0)
            ],
            relativeTime: t + 0.01,
            duration: resonanceDuration
        ))
    }

    /// The final cadence: three knocks in the same bamboo voice, swelling to
    /// full strength at a slightly stretched interval (allargando) — a slow
    /// countdown that lulls the session to a close instead of jolting out.
    func completion() {
        guard supportsHaptics, let engine else { return }
        let interval = (1.0 / thumpsPerSecond) * cadenceStretch
        let intensities: [Float] = [peakIntensity, (peakIntensity + 1.0) / 2, 1.0]
        var events: [CHHapticEvent] = []
        for (i, intensity) in intensities.enumerated() {
            appendThump(at: Double(i) * interval, intensity: intensity, into: &events)
        }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            try engine.makePlayer(with: pattern).start(atTime: 0)
        } catch {
            Log.haptics.error("Failed to play completion cadence: \(error.localizedDescription)")
        }
    }

    /// Stop the in-flight breath swell (pause / restart). The engine itself
    /// keeps running so the next breath starts instantly.
    func stopBreath() {
        try? activePlayer?.stop(atTime: CHHapticTimeImmediate)
        activePlayer = nil
    }

    /// Full shutdown when leaving the screen.
    func shutdown() {
        stopBreath()
        engine?.stop()
    }
}

#Preview {
    NavigationStack { Meditate() }
}
