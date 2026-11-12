import AppKit

/// What snow and leaves settle on.
struct Surfaces: OptionSet {
    let rawValue: Int
    static let ground = Surfaces(rawValue: 1)
    static let dock = Surfaces(rawValue: 2)
    static let windows = Surfaces(rawValue: 4)
    static let widgets = Surfaces(rawValue: 8)
    /// What the window list is read for.
    static let tracked: Surfaces = [.dock, .windows, .widgets]
}

enum Preferences {
    private static let defaults = UserDefaults.standard
    static let opacityRange = 0.1...1.0
    private static let intensityKey = "intensity"
    /// Before the slider, the intensity was one of Off, Light, Steady, Heavy and Variable.
    private static let snowfallKey = "snowfall"
    private static let behindWindowsKey = "behindWindows"
    private static let showOverFullScreenKey = "showOverFullScreen"
    private static let meltSnowKey = "meltSnow"
    /// Before Accumulate picked where snow settles, it turned settling off everywhere at once.
    private static let accumulateKey = "accumulate"
    private static let groundKey = "settleGround"
    private static let dockKey = "settleDock"
    private static let widgetsKey = "settleWidgets"
    private static let snowOnWindowsKey = "snowOnWindows"
    private static let welcomedKey = "welcomed"
    private static let installedAtKey = "installedAt"
    private static let showInScreenshotsKey = "showInScreenshots"
    private static let deepInteractionKey = "deepInteraction"
    private static let halloweenKey = "halloweenOn"
    private static let halloweenSkippedKey = "halloweenSkipped"
    private static let modeKey = "mode"
    private static let mixedKey = "mixed"
    private static let mixKey = "mix"
    /// Before rain, the mode was only whether leaves fell.
    private static let autumnKey = "autumn"
    private static let performanceKey = "performance"
    private static let fallingOpacityKey = "fallingOpacity"
    private static let newYearKey = "newYear"
    private static let stormKey = "storm"
    private static let garlandKey = "garland"
    private static let garlandBlinksKey = "garlandBlinks"
    private static let iciclesKey = "icicles"
    private static let snowmenKey = "snowmen"
    private static let garlandStyleKey = "garlandStyle"
    private static let flakeStyleKey = "flakeStyle"
    private static let garlandColorKey = "garlandColor"
    private static let snowColorKey = "snowColor"

    static func registerDefaults() {
        let calm = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        defaults.register(defaults: [
            intensityKey: calm ? 0.25 : 0.35,
            behindWindowsKey: false,
            showOverFullScreenKey: true,
            meltSnowKey: true,
            groundKey: true,
            dockKey: true,
            widgetsKey: true,
            snowOnWindowsKey: true,
            showInScreenshotsKey: false,
            deepInteractionKey: false,
            halloweenKey: false,
            halloweenSkippedKey: 0,
            autumnKey: false,
            mixedKey: false,
            fallingOpacityKey: 1.0,
            newYearKey: false,
            stormKey: false,
            garlandKey: false,
            garlandBlinksKey: true,
            iciclesKey: false,
            snowmenKey: true,
            garlandStyleKey: 0,
            flakeStyleKey: 0,
            garlandColorKey: 0,
            snowColorKey: 0,
        ])
        if defaults.object(forKey: intensityKey) == nil, let stop = defaults.object(forKey: snowfallKey) as? Int {
            defaults.set([0, 0.25, 0.5, 0.75, 0.5][min(max(stop, 0), 4)], forKey: intensityKey)
        }
        if defaults.object(forKey: accumulateKey) != nil {
            if !defaults.bool(forKey: accumulateKey) {
                for key in [groundKey, dockKey, widgetsKey, snowOnWindowsKey] { defaults.set(false, forKey: key) }
            }
            defaults.removeObject(forKey: accumulateKey)
        }
        if defaults.object(forKey: installedAtKey) == nil {
            defaults.set(defaults.bool(forKey: welcomedKey) ? 0 : Date().timeIntervalSince1970, forKey: installedAtKey)
        }
    }

    /// When this install was first run, or nil for an install older than the stamp.
    static var installedAt: Date? {
        let stamp = defaults.double(forKey: installedAtKey)
        return stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
    }

    /// How much falls, from 0 to 1.
    static var intensity: Double {
        get { min(max(defaults.double(forKey: intensityKey), 0), 1) }
        set { defaults.set(newValue, forKey: intensityKey) }
    }

    /// Where snow settles; Windows is `snowOnWindows`.
    static var surfaces: Surfaces {
        get {
            var surfaces: Surfaces = []
            for (surface, key) in [(Surfaces.ground, groundKey), (.dock, dockKey), (.widgets, widgetsKey), (.windows, snowOnWindowsKey)]
            where defaults.bool(forKey: key) {
                surfaces.insert(surface)
            }
            return surfaces
        }
        set {
            for (surface, key) in [(Surfaces.ground, groundKey), (.dock, dockKey), (.widgets, widgetsKey), (.windows, snowOnWindowsKey)] {
                defaults.set(newValue.contains(surface), forKey: key)
            }
        }
    }

    static var meltSnow: Bool {
        get { defaults.bool(forKey: meltSnowKey) }
        set { defaults.set(newValue, forKey: meltSnowKey) }
    }

    /// Puts every setting back as it was on the first run, keeping only that the welcome was seen and when the app was
    /// installed.
    static func reset() {
        let installedAt = defaults.object(forKey: installedAtKey)
        if let domain = Bundle.main.bundleIdentifier { defaults.removePersistentDomain(forName: domain) }
        defaults.set(true, forKey: welcomedKey)
        if let installedAt { defaults.set(installedAt, forKey: installedAtKey) }
        defaults.synchronize()
    }

    static var welcomed: Bool {
        get { defaults.bool(forKey: welcomedKey) }
        set { defaults.set(newValue, forKey: welcomedKey) }
    }

    static var behindWindows: Bool {
        get { defaults.bool(forKey: behindWindowsKey) }
        set { defaults.set(newValue, forKey: behindWindowsKey) }
    }

    static var showOverFullScreen: Bool {
        get { defaults.bool(forKey: showOverFullScreenKey) }
        set { defaults.set(newValue, forKey: showOverFullScreenKey) }
    }

    static var showInScreenshots: Bool {
        get { defaults.bool(forKey: showInScreenshotsKey) }
        set { defaults.set(newValue, forKey: showInScreenshotsKey) }
    }

    /// The snow also settles on what the desktop draws without a window of its own: a selection dragged across it.
    static var deepInteraction: Bool {
        get { defaults.bool(forKey: deepInteractionKey) }
        set { defaults.set(newValue, forKey: deepInteractionKey) }
    }

    /// Ornaments, gifts and a snowman in the drift.
    static var newYear: Bool {
        get { defaults.bool(forKey: newYearKey) }
        set { defaults.set(newValue, forKey: newYearKey) }
    }

    /// A strong wind with gusts: the snow flies slanted and the drifts are blown.
    static var storm: Bool {
        get { defaults.bool(forKey: stormKey) }
        set { defaults.set(newValue, forKey: stormKey) }
    }

    /// Blinking lights under the menu bar.
    static var garland: Bool {
        get { defaults.bool(forKey: garlandKey) }
        set { defaults.set(newValue, forKey: garlandKey) }
    }

    /// Whether the garland's bulbs blink in turn or all stay lit.
    static var garlandBlinks: Bool {
        get { defaults.bool(forKey: garlandBlinksKey) }
        set { defaults.set(newValue, forKey: garlandBlinksKey) }
    }

    /// Icicles growing under the windows' bottom edges.
    static var icicles: Bool {
        get { defaults.bool(forKey: iciclesKey) }
        set { defaults.set(newValue, forKey: iciclesKey) }
    }

    /// Snowballs rolled with Option held and stacked into snowmen.
    static var snowmen: Bool {
        get { defaults.bool(forKey: snowmenKey) }
        set { defaults.set(newValue, forKey: snowmenKey) }
    }

    /// What the garland is strung with: 0 coloured bulbs, 1 warm fairy lights, 2 stars.
    static var garlandStyle: Int {
        get { min(max(defaults.integer(forKey: garlandStyleKey), 0), 2) }
        set { defaults.set(newValue, forKey: garlandStyleKey) }
    }

    /// The colour of the garland's lights: 0 their own, then red, gold, green, blue and cold white.
    static var garlandColor: Int {
        get { min(max(defaults.integer(forKey: garlandColorKey), 0), 5) }
        set { defaults.set(newValue, forKey: garlandColorKey) }
    }

    /// What colour the snow is: white, blue, warm, pink, lilac or mint.
    static var snowColor: Int {
        get { min(max(defaults.integer(forKey: snowColorKey), 0), 5) }
        set { defaults.set(newValue, forKey: snowColorKey) }
    }

    /// How the flakes look: 0 soft round, 1 crystals, 2 big flakes.
    static var flakeStyle: Int {
        get { min(max(defaults.integer(forKey: flakeStyleKey), 0), 2) }
        set { defaults.set(newValue, forKey: flakeStyleKey) }
    }

    /// Halloween turned on from the menu, for every day.
    static var halloween: Bool {
        get { defaults.bool(forKey: halloweenKey) }
        set { defaults.set(newValue, forKey: halloweenKey) }
    }

    /// The year whose Halloween was turned off from the menu, zero for none.
    static var halloweenSkipped: Int {
        get { defaults.integer(forKey: halloweenSkippedKey) }
        set { defaults.set(newValue, forKey: halloweenSkippedKey) }
    }

    static var mode: Mode {
        get {
            if let raw = defaults.object(forKey: modeKey) as? Int, let mode = Mode(rawValue: raw) { return mode }
            return defaults.bool(forKey: autumnKey) ? .autumn : .snow
        }
        set { defaults.set(newValue.rawValue, forKey: modeKey) }
    }

    /// Two modes falling together.
    static var mixed: Bool {
        get { defaults.bool(forKey: mixedKey) }
        set { defaults.set(newValue, forKey: mixedKey) }
    }

    /// The two modes Mixed lets fall together, the one picked last at the end.
    static var mix: [Mode] {
        get {
            let picked = (defaults.array(forKey: mixKey) as? [Int] ?? []).compactMap(Mode.init(rawValue:))
            return picked.count == 2 && picked[0] != picked[1] ? picked : [mode == .snow ? .autumn : .snow, mode]
        }
        set { defaults.set(newValue.map(\.rawValue), forKey: mixKey) }
    }

    /// What falls.
    static var modes: [Mode] { mixed ? mix : [mode] }

    /// How opaque snow, leaves and rain are while they fall.
    static var fallingOpacity: Double {
        get { min(max(defaults.double(forKey: fallingOpacityKey), opacityRange.lowerBound), opacityRange.upperBound) }
        set { defaults.set(newValue, forKey: fallingOpacityKey) }
    }

    /// Drawn at the display's highest rate all the time, instead of only while something is pushed around.
    static var maxPerformance: Bool {
        get { defaults.integer(forKey: performanceKey) == 1 }
        set { defaults.set(newValue ? 1 : 0, forKey: performanceKey) }
    }
}
