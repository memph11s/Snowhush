import AppKit
import MetalKit
import ServiceManagement
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, SPUStandardUserDriverDelegate {
    private var device: MTLDevice!
    private var screens: [ScreenSnow] = []
    private let displays = Displays()
    private var surfaces: Surfaces = []
    private var thaws = true
    private var behindWindows = false
    private var snowfallHeld = false
    private var halloween = false
    private var statusItem: NSStatusItem!
    private let intensitySlider = MenuSlider(range: 0...1)
    private var clearItem: NSMenuItem!
    private var halloweenItem: NSMenuItem!
    private var newYearItem: NSMenuItem!
    private var stormItem: NSMenuItem!
    private var garlandItem: NSMenuItem!
    private var iciclesItem: NSMenuItem!
    private var snowmenItem: NSMenuItem!
    private var mixedItem: NSMenuItem!
    private var modeItems: [(item: NSMenuItem, mode: Mode)] = []
    private var observers: [NSObjectProtocol] = []
    private var screensAsleep = false
    private let screenshots = ScreenshotWatch()
    private var screenLocked = false
    private var sessionInactive = false
    private var updater: SPUStandardUpdaterController!
    private var welcome: WelcomeController?
    private let power = PowerMonitor()
    private var halloweenTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppMover.moveIfNeeded() {
            NSApp.terminate(nil)
            return
        }
        Preferences.registerDefaults()
        guard let device = Self.lowPowerDevice() ?? MTLCreateSystemDefaultDevice() else {
            NSApp.terminate(nil)
            return
        }
        self.device = device
        surfaces = Preferences.surfaces
        thaws = Preferences.meltSnow
        behindWindows = Preferences.behindWindows
        snowfallHeld = !Preferences.welcomed
        syncScreens()
        guard !screens.isEmpty else {
            NSApp.terminate(nil)
            return
        }

        updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)
        statusItem = makeStatusItem()
        updateStatusIcon()
        refreshHalloween()
        halloweenTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.refreshHalloween() }
        observeSystem()
        // `open Snowhush.app --args --settings 2` opens the settings window on its third tab.
        let arguments = CommandLine.arguments
        if let at = arguments.firstIndex(of: "--settings") {
            showSettings()
            if at + 1 < arguments.count, let tab = Int(arguments[at + 1]) { settings?.model.tab = tab }
        }
        Marquee.enabled = Preferences.deepInteraction
        screenshots.stepAside = { [weak self] aside in self?.screens.forEach { $0.stepAside(aside) } }
        screenshots.start()
        if snowfallHeld {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.showWelcome() }
        }
    }

    // A menu bar app has no Dock icon to badge, so update reminders are left to Sparkle's own gentle alerts.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    // MARK: - Displays

    /// One overlay per display: new displays get snow, removed ones lose theirs, the rest follow resolution changes.
    private func syncScreens() {
        let current = NSScreen.screens
        displays.update(screens: current)
        let ids = Set(current.compactMap(\.displayID))
        for gone in screens where !ids.contains(gone.displayID) { gone.close() }
        screens.removeAll { !ids.contains($0.displayID) }

        for screen in current {
            if let existing = screens.first(where: { $0.displayID == screen.displayID }) {
                existing.fit(to: screen)
            } else if let snow = ScreenSnow(screen: screen, device: device, displays: displays, surfaces: { [unowned self] in surfaces }) {
                snow.simulation.snowfallHeld = snowfallHeld
                snow.simulation.snowfallReleased = { [weak self] in self?.releaseSnowfall() }
                snow.halloween = halloween
                snow.newYear = Preferences.newYear
                snow.storm = Preferences.storm
                snow.garland = Preferences.garland
                snow.garlandBlinks = Preferences.garlandBlinks
                snow.icicles = Preferences.icicles
                snow.snowmen = Preferences.snowmen
                snow.garlandStyle = Preferences.garlandStyle
                snow.flakeStyle = Preferences.flakeStyle
                snow.garlandColor = Preferences.garlandColor
                snow.snowColor = Preferences.snowColor
                snow.modes = Preferences.modes
                snow.maxFrameRate = Preferences.maxPerformance
                snow.activityChanged = { [weak self] in self?.updateActivity() }
                snow.apply(power.budget)
                screens.append(snow)
            }
        }
        displays.snows = screens
        updateActivity()
    }

    private func releaseSnowfall() {
        snowfallHeld = false
        for snow in screens { snow.simulation.snowfallHeld = false }
    }

    private func showWelcome() {
        let welcome = WelcomeController()
        welcome.scatter = { [weak self] pieces in
            guard let self, let first = pieces.first else { return }
            let point = CGPoint(x: CGFloat(first.position.x), y: CGFloat(first.position.y))
            guard let snow = screens.first(where: { $0.window.frame.contains(point) }) ?? screens.first else { return }
            let origin = SIMD2(Float(snow.window.frame.minX), Float(snow.window.frame.minY))
            snow.simulation.scatter(pieces.map { piece in
                var local = piece
                local.position -= origin
                return local
            })
        }
        welcome.skipped = { [weak self] in self?.releaseSnowfall() }
        welcome.finished = { [weak self] in
            Preferences.welcomed = true
            self?.welcome = nil
        }
        self.welcome = welcome
        welcome.show()
    }

    // MARK: - Menu

    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        menu.addItem(.sectionHeader(title: tr("intensity")))
        intensitySlider.changed = { [unowned self] in select(intensity: $0) }
        let intensityItem = NSMenuItem()
        intensityItem.view = intensitySlider
        menu.addItem(intensityItem)
        let modes = NSMenu()
        modes.autoenablesItems = false
        mixedItem = toggle(tr("mixed"), #selector(toggleMixed), to: modes)
        modes.addItem(.separator())
        modeItems = Mode.allCases.map { mode in
            let item = toggle(tr(mode.key), #selector(chooseMode), to: modes)
            (item.view as? MenuToggle)?.staysOpen = { Preferences.mixed }
            return (item, mode)
        }
        modes.addItem(.separator())
        halloweenItem = add(tr("halloween"), #selector(toggleHalloween), to: modes)
        menu.addItem(withTitle: tr("mode"), action: nil, keyEquivalent: "").submenu = modes
        // Any day of the year: each piece is switched on and off by itself.
        let newYear = NSMenu()
        newYear.autoenablesItems = false
        newYearItem = toggle(tr("newyear.decor"), #selector(toggleNewYear), to: newYear)
        garlandItem = toggle(tr("garland"), #selector(toggleGarland), to: newYear)
        iciclesItem = toggle(tr("icicles"), #selector(toggleIcicles), to: newYear)
        snowmenItem = toggle(tr("snowmen"), #selector(toggleSnowmen), to: newYear)
        stormItem = toggle(tr("storm"), #selector(toggleStorm), to: newYear)
        newYear.addItem(.separator())
        let hint = newYear.addItem(withTitle: tr("snowmen.hint"), action: nil, keyEquivalent: "")
        hint.isEnabled = false
        add(tr("newyear.more"), #selector(showSettings), to: newYear)
        // Several are wanted at once, so the menu stays open between them.
        for item in [newYearItem, garlandItem, iciclesItem, snowmenItem, stormItem] { (item?.view as? MenuToggle)?.staysOpen = { true } }
        menu.addItem(withTitle: tr("newyear"), action: nil, keyEquivalent: "").submenu = newYear
        clearItem = add(tr("clear.snow"), #selector(clearSnow), to: menu)
        menu.addItem(.separator())
        // Everything else is in the settings window, which a double click on the icon opens too.
        let settings = add(tr("settings.open"), #selector(showSettings), to: menu)
        settings.keyEquivalent = ","
        let updates = menu.addItem(withTitle: tr("updates"), action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        updates.target = updater
        menu.addItem(withTitle: tr("quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        item.menu = menu
        return item
    }

    @discardableResult
    private func add(_ title: String, _ action: Selector, to menu: NSMenu) -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func toggle(_ title: String, _ action: Selector, to menu: NSMenu) -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: nil, keyEquivalent: "")
        let toggle = MenuToggle(action: action, target: self)
        toggle.fit(title)
        item.view = toggle
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        intensitySlider.value = Preferences.intensity
        let modes = Mode.allCases.filter(Preferences.modes.contains)
        mixedItem.state = Preferences.mixed ? .on : .off
        for (item, mode) in modeItems { item.state = modes.contains(mode) ? .on : .off }
        // Rain neither heaps up nor lies about to clear away.
        let heaps = modes.filter { $0 != .rain }
        clearItem.isHidden = heaps.isEmpty
        clearItem.title = tr("clear", heaps)
        clearItem.isEnabled = screens.contains { $0.simulation.hasSnow || $0.simulation.spriteCount > 0 }
        halloweenItem.state = Halloween.isWanted ? .on : .off
        halloweenItem.isEnabled = modes == [.snow]
        newYearItem.state = Preferences.newYear ? .on : .off
        stormItem.state = Preferences.storm ? .on : .off
        garlandItem.state = Preferences.garland ? .on : .off
        iciclesItem.state = Preferences.icicles ? .on : .off
        snowmenItem.state = Preferences.snowmen ? .on : .off
    }

    /// When the menu last opened: a second click on the icon soon after closes it and opens the settings window.
    private var menuOpenedAt: TimeInterval = 0

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === statusItem.menu else { return }
        menuOpenedAt = ProcessInfo.processInfo.systemUptime
    }

    func menuDidClose(_ menu: NSMenu) {
        guard menu === statusItem.menu else { return }
        settings?.model.reload()
        guard let event = NSApp.currentEvent, event.type == .leftMouseDown || event.type == .leftMouseUp,
              ProcessInfo.processInfo.systemUptime - menuOpenedAt < max(NSEvent.doubleClickInterval, 0.5),
              let button = statusItem.button, let window = button.window, event.window === window || button.window?.frame.contains(NSEvent.mouseLocation) == true
        else { return }
        DispatchQueue.main.async { [weak self] in self?.showSettings() }
    }

    private var settings: SettingsWindowController?

    /// Opening the app again, from the Finder, Launchpad or Spotlight, while it already runs opens its settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    @objc func showSettings() {
        if settings == nil {
            let controller = SettingsWindowController()
            controller.model.apply = { [unowned self] change in apply(change) }
            controller.model.loginEnabled = { SMAppService.mainApp.status == .enabled }
            settings = controller
        }
        settings?.present()
    }

    /// Carries out a change from the settings window, as its menu item would.
    private func apply(_ change: SettingChange) {
        switch change {
        case .intensity(let value):
            select(intensity: value)
        case .opacity(let value):
            Preferences.fallingOpacity = value
            for snow in screens { snow.simulation.fallingOpacity = Float(value) }
        case .mode(let mode):
            choose(mode)
        case .mixed(let on):
            if on != Preferences.mixed { toggleMixed() }
        case .halloween(let on):
            if on != Halloween.isWanted { toggleHalloween() }
        case .flakeStyle(let style):
            Preferences.flakeStyle = style
            for snow in screens { snow.flakeStyle = style }
        case .surface(let surface, let on):
            if on != surfaces.contains(surface) { toggle(surface) }
        case .melt(let on):
            if on != thaws { toggleMeltSnow() }
        case .deep(let on):
            if on != Preferences.deepInteraction { toggleDeepInteraction() }
        case .clear:
            clearSnow()
        case .newYear(let on):
            if on != Preferences.newYear { toggleNewYear() }
        case .garland(let on):
            if on != Preferences.garland { toggleGarland() }
        case .garlandBlinks(let on):
            if on != Preferences.garlandBlinks { toggleGarlandBlinks() }
        case .garlandStyle(let style):
            Preferences.garlandStyle = style
            for snow in screens { snow.garlandStyle = style }
        case .garlandColor(let color):
            Preferences.garlandColor = color
            for snow in screens { snow.garlandColor = color }
        case .snowColor(let color):
            Preferences.snowColor = color
            for snow in screens { snow.snowColor = color }
        case .reset:
            resetSettings()
        case .icicles(let on):
            if on != Preferences.icicles { toggleIcicles() }
        case .snowmen(let on):
            if on != Preferences.snowmen { toggleSnowmen() }
        case .storm(let on):
            if on != Preferences.storm { toggleStorm() }
        case .behind(let on):
            if on != behindWindows { toggleBehindWindows() }
        case .fullScreen(let on):
            if on != Preferences.showOverFullScreen { toggleFullScreen() }
        case .screenshots(let on):
            if on != Preferences.showInScreenshots { toggleScreenshots() }
        case .performance(let on):
            if on != Preferences.maxPerformance { toggleMaxPerformance() }
        case .login(let on):
            if on != (SMAppService.mainApp.status == .enabled) { toggleOpenAtLogin() }
        case .updates:
            updater.checkForUpdates(nil)
        }
    }

    /// Asks, then puts every setting back as it was on the first run and starts the app again with them.
    private func resetSettings() {
        let alert = NSAlert()
        alert.messageText = tr("reset.confirm")
        alert.informativeText = tr("reset.confirm.text")
        alert.alertStyle = .warning
        alert.addButton(withTitle: tr("reset.do"))
        alert.addButton(withTitle: tr("cancel"))
        NSApp.activate(ignoringOtherApps: true)
        let answer = alert.runModal()
        guard answer == .alertFirstButtonReturn else { return }
        Preferences.reset()
        // A new copy is opened once this one has quit, from the shell, which outlives it.
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        try? relaunch.run()
        NSApp.terminate(nil)
    }

    private func select(intensity: Double) {
        Preferences.intensity = intensity
        for snow in screens { snow.simulation.intensity = Float(intensity) }
        updateStatusIcon()
    }

    private func toggle(_ surface: Surfaces) {
        surfaces.formSymmetricDifference(surface)
        Preferences.surfaces = surfaces
        for snow in screens {
            snow.simulation.accumulates = !surfaces.isEmpty
            snow.simulation.groundSettles = surfaces.contains(.ground)
        }
        if surfaces.isDisjoint(with: .tracked) { screens.forEach { $0.dropWindowSnow() } }
        if let menu = statusItem.menu { menuNeedsUpdate(menu) }
    }

    @objc private func toggleMeltSnow() {
        thaws.toggle()
        Preferences.meltSnow = thaws
        for snow in screens { snow.simulation.thaws = thaws }
    }

    @objc private func toggleDeepInteraction() {
        Preferences.deepInteraction.toggle()
        Marquee.enabled = Preferences.deepInteraction
    }

    @objc private func clearSnow() {
        let direction = screens.first?.simulation.breezeDirection ?? -1
        let calm = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        for snow in screens { snow.simulation.blowAway(direction: direction, calm: calm) }
    }

    @objc private func toggleBehindWindows() {
        behindWindows.toggle()
        Preferences.behindWindows = behindWindows
        for snow in screens { snow.window.behindWindows = behindWindows }
    }

    @objc private func toggleFullScreen() {
        Preferences.showOverFullScreen.toggle()
        for snow in screens { snow.overFullScreen = Preferences.showOverFullScreen }
    }

    @objc private func toggleScreenshots() {
        Preferences.showInScreenshots.toggle()
        for snow in screens {
            snow.window.showsInScreenshots = Preferences.showInScreenshots
            snow.dock.window.showsInScreenshots = Preferences.showInScreenshots
        }
    }

    @objc private func toggleOpenAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSLog("Snowhush: login item change failed: \(error)")
        }
    }

    /// Mixed, a third mode picked takes the place of the one picked before the other.
    @objc private func chooseMode(_ sender: NSMenuItem) {
        guard let mode = modeItems.first(where: { $0.item === sender })?.mode else { return }
        choose(mode)
    }

    private func choose(_ mode: Mode) {
        if Preferences.mixed {
            let mix = Preferences.mix
            guard !mix.contains(mode) else { return }
            Preferences.mix = [mix[1], mode]
        } else {
            guard mode != Preferences.mode else { return }
        }
        Preferences.mode = mode
        switchModes()
    }

    /// Mixed, the mode picked last falls along with the one picked before it; unmixed, it falls alone.
    @objc private func toggleMixed() {
        Preferences.mixed.toggle()
        let mode = Preferences.mode
        if Preferences.mixed, !Preferences.mix.contains(mode) {
            Preferences.mix = [Preferences.mix[1], mode]
        } else if Preferences.mixed {
            Preferences.mix = [Preferences.mix.first { $0 != mode } ?? .snow, mode]
        }
        switchModes()
    }

    private func switchModes() {
        refreshHalloween()
        updateStatusIcon()
        let direction = screens.first?.simulation.breezeDirection ?? -1
        let calm = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        for snow in screens { snow.simulation.switchMode(to: Preferences.modes, direction: direction, calm: calm) }
    }

    @objc private func toggleMaxPerformance() {
        Preferences.maxPerformance.toggle()
        for snow in screens { snow.maxFrameRate = Preferences.maxPerformance }
    }

    @objc private func toggleNewYear() {
        Preferences.newYear.toggle()
        for snow in screens { snow.newYear = Preferences.newYear }
    }

    @objc private func toggleStorm() {
        Preferences.storm.toggle()
        for snow in screens { snow.storm = Preferences.storm }
    }

    @objc private func toggleGarland() {
        Preferences.garland.toggle()
        for snow in screens { snow.garland = Preferences.garland }
    }

    @objc private func toggleGarlandBlinks() {
        Preferences.garlandBlinks.toggle()
        for snow in screens { snow.garlandBlinks = Preferences.garlandBlinks }
    }

    @objc private func toggleIcicles() {
        Preferences.icicles.toggle()
        for snow in screens { snow.icicles = Preferences.icicles }
    }

    @objc private func toggleSnowmen() {
        Preferences.snowmen.toggle()
        for snow in screens { snow.snowmen = Preferences.snowmen }
    }

    @objc private func toggleHalloween() {
        Halloween.toggle()
        refreshHalloween()
    }

    private func updateStatusIcon() {
        statusItem.button?.image = Self.icon(halloween: halloween, dimmed: Preferences.intensity <= 0)
    }

    private static let symbol: [Mode: String] = [.snow: "snowflake", .autumn: "leaf", .rain: "cloud.rain"]

    /// The integrated GPU on a Mac with two: asking for the default device would wake the discrete one and hold it
    /// awake for as long as the snow falls. The devices left unused are let go before the discrete GPU powers up.
    private static func lowPowerDevice() -> MTLDevice? {
        autoreleasepool { MTLCopyAllDevices().first { $0.isLowPower } }
    }

    private static func icon(halloween: Bool, dimmed: Bool) -> NSImage? {
        let image = halloween ? Halloween.icon : Preferences.mode == .blossom ? Blossom.icon
            : NSImage(systemSymbolName: Self.symbol[Preferences.mode] ?? "snowflake", accessibilityDescription: "Snowhush")
        guard dimmed, let image else { return image }
        // Dimmed by hand: the button's appearsDisabled also disables the slider in its menu, so Off could not be left.
        let faded = NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 0.4)
            return true
        }
        faded.isTemplate = image.isTemplate
        faded.accessibilityDescription = image.accessibilityDescription
        return faded
    }

    private func refreshHalloween() {
        guard Halloween.isOn != halloween else { return }
        halloween.toggle()
        updateStatusIcon()
        for snow in screens { snow.halloween = halloween }
    }

    // MARK: - System

    private func observeSystem() {
        power.changed = { [unowned self] in screens.forEach { $0.apply(power.budget) } }
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()

        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.screensAsleep = true }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { $0.screensAsleep = false }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { $0.sessionInactive = true }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { $0.sessionInactive = false }
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.screenLocked = true }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.screenLocked = false }
        observe(.default, NSWindow.didChangeOcclusionStateNotification) { _ in }
        observe(.default, NSApplication.didChangeScreenParametersNotification) { $0.syncScreens() }
        observe(workspace, NSWorkspace.activeSpaceDidChangeNotification) { $0.screens.forEach { $0.spaceChanged() } }
        observe(workspace, NSWorkspace.didActivateApplicationNotification) { $0.screens.forEach { $0.watchWindows() } }
    }

    private func observe(
        _ center: NotificationCenter,
        _ name: Notification.Name,
        object: AnyObject? = nil,
        _ change: @escaping (AppDelegate) -> Void
    ) {
        observers.append(center.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
            guard let self else { return }
            change(self)
            self.updateActivity()
        })
    }

    private func updateActivity() {
        let awake = !screensAsleep && !screenLocked && !sessionInactive
        for snow in screens {
            snow.occlusionChanged()
            snow.setActive(awake && !snow.givesWay && (snow.window.occlusionState.contains(.visible) || snow.fading), asleep: !awake)
        }
    }
}
