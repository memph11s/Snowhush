import AppKit
import SwiftUI

/// A change made in the settings window, carried out by the app as the menu would.
enum SettingChange {
    case intensity(Double), opacity(Double)
    case mode(Mode), mixed(Bool), halloween(Bool), flakeStyle(Int)
    case surface(Surfaces, Bool), melt(Bool), deep(Bool), clear
    case newYear(Bool), garland(Bool), garlandBlinks(Bool), garlandStyle(Int), icicles(Bool), snowmen(Bool), storm(Bool)
    case behind(Bool), fullScreen(Bool), screenshots(Bool), performance(Bool)
    case login(Bool), updates
}

/// What the settings window shows, read back from the preferences each time it opens or the menu changes something.
final class SettingsModel: ObservableObject {
    var apply: (SettingChange) -> Void = { _ in }
    var loginEnabled: () -> Bool = { false }

    @Published var intensity = 0.0
    @Published var opacity = 1.0
    @Published var modes: [Mode] = [.snow]
    @Published var mixed = false
    @Published var halloween = false
    @Published var flakeStyle = 0
    @Published var surfaces: Surfaces = []
    @Published var melt = true
    @Published var deep = false
    @Published var newYear = false
    @Published var garland = false
    @Published var garlandBlinks = true
    @Published var garlandStyle = 0
    @Published var icicles = false
    @Published var snowmen = true
    @Published var storm = false
    @Published var behind = false
    @Published var fullScreen = true
    @Published var screenshots = false
    @Published var performance = false
    @Published var login = false

    func reload() {
        intensity = Preferences.intensity
        opacity = Preferences.fallingOpacity
        modes = Preferences.modes
        mixed = Preferences.mixed
        halloween = Halloween.isWanted
        flakeStyle = Preferences.flakeStyle
        surfaces = Preferences.surfaces
        melt = Preferences.meltSnow
        deep = Preferences.deepInteraction
        newYear = Preferences.newYear
        garland = Preferences.garland
        garlandBlinks = Preferences.garlandBlinks
        garlandStyle = Preferences.garlandStyle
        icicles = Preferences.icicles
        snowmen = Preferences.snowmen
        storm = Preferences.storm
        behind = Preferences.behindWindows
        fullScreen = Preferences.showOverFullScreen
        screenshots = Preferences.showInScreenshots
        performance = Preferences.maxPerformance
        login = loginEnabled()
    }

    /// A binding that sends its changes on to the app, then reads everything back, as one change can move others.
    func binding<T>(_ path: ReferenceWritableKeyPath<SettingsModel, T>, _ change: @escaping (T) -> SettingChange) -> Binding<T> {
        Binding(get: { self[keyPath: path] }, set: { value in
            self[keyPath: path] = value
            self.apply(change(value))
            self.reload()
        })
    }

    func surface(_ surface: Surfaces) -> Binding<Bool> {
        Binding(get: { self.surfaces.contains(surface) }, set: { on in
            self.apply(.surface(surface, on))
            self.reload()
        })
    }
}

/// Opened with a double click on the menu bar icon or from the menu: every setting, with pictures to pick from.
final class SettingsWindowController: NSWindowController {
    let model = SettingsModel()

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 560), styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: true)
        window.title = tr("settings.window")
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.contentViewController = NSHostingController(rootView: SettingsView(model: model))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func present() {
        model.reload()
        guard let window else { return }
        if !window.isVisible { window.center() }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}

// MARK: - The window

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        TabView {
            SnowfallTab(model: model).tabItem { Label(tr("tab.snowfall"), systemImage: "snowflake") }
            DriftsTab(model: model).tabItem { Label(tr("tab.drifts"), systemImage: "mountain.2") }
            NewYearTab(model: model).tabItem { Label(tr("newyear"), systemImage: "gift") }
            DisplayTab(model: model).tabItem { Label(tr("display"), systemImage: "display") }
            GeneralTab(model: model).tabItem { Label(tr("general"), systemImage: "gearshape") }
        }
        .padding(16)
        .frame(width: 620, height: 560)
    }
}

private struct SnowfallTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section {
                LabeledContent(tr("intensity")) {
                    Slider(value: model.binding(\.intensity) { .intensity($0) }, in: 0...1)
                    Text(percent(model.intensity)).monospacedDigit().frame(width: 44, alignment: .trailing)
                }
                LabeledContent(tr("opacity")) {
                    Slider(value: model.binding(\.opacity) { .opacity($0) }, in: Preferences.opacityRange)
                    Text(percent(model.opacity)).monospacedDigit().frame(width: 44, alignment: .trailing)
                }
            }
            Section(tr("mode")) {
                HStack(spacing: 10) {
                    ForEach(Mode.allCases, id: \.self) { mode in
                        PictureCard(image: StylePreviews.mode(mode), title: tr(mode.key), selected: model.modes.contains(mode)) {
                            model.apply(.mode(mode))
                            model.reload()
                        }
                    }
                }
                Toggle(tr("mixed"), isOn: model.binding(\.mixed) { .mixed($0) })
                Text(tr("mixed.about")).font(.caption).foregroundStyle(.secondary)
                Toggle(tr("halloween"), isOn: model.binding(\.halloween) { .halloween($0) }).disabled(model.modes != [.snow])
            }
            Section(tr("flakes.style")) {
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { k in
                        PictureCard(image: StylePreviews.flakes(k), title: tr(["flakes.style.soft", "flakes.style.crystals", "flakes.style.big"][k]),
                                    selected: model.flakeStyle == k) {
                            model.binding(\.flakeStyle) { .flakeStyle($0) }.wrappedValue = k
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct DriftsTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section(tr("accumulate")) {
                Toggle(tr("surface.ground"), isOn: model.surface(.ground))
                Toggle(tr("surface.windows"), isOn: model.surface(.windows))
                Toggle(tr("surface.dock"), isOn: model.surface(.dock))
                Toggle(tr("surface.widgets"), isOn: model.surface(.widgets))
            }
            Section(tr("behavior")) {
                Toggle(tr("melt.snow"), isOn: model.binding(\.melt) { .melt($0) }).disabled(model.surfaces.isEmpty)
                Toggle(tr("deep"), isOn: model.binding(\.deep) { .deep($0) }).disabled(!model.surfaces.contains(.windows))
                Text(tr("deep.about")).font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Button(tr("clear.snow")) { model.apply(.clear) }
            }
        }
        .formStyle(.grouped)
    }
}

private struct NewYearTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section {
                FeatureRow(image: StylePreviews.picture(.snowman, height: 44), title: tr("newyear.decor"), about: tr("newyear.decor.about"),
                           isOn: model.binding(\.newYear) { .newYear($0) })
                FeatureRow(image: StylePreviews.picture(.icicle, height: 44), title: tr("icicles"), about: tr("icicles.about"),
                           isOn: model.binding(\.icicles) { .icicles($0) })
                FeatureRow(image: StylePreviews.storm, title: tr("storm"), about: tr("storm.about"),
                           isOn: model.binding(\.storm) { .storm($0) })
            }
            Section(tr("garland")) {
                Toggle(tr("garland"), isOn: model.binding(\.garland) { .garland($0) })
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { k in
                        PictureCard(image: StylePreviews.garland(k),
                                    title: tr(["garland.style.bulbs", "garland.style.fairy", "garland.style.stars"][k]),
                                    selected: model.garlandStyle == k) {
                            model.binding(\.garlandStyle) { .garlandStyle($0) }.wrappedValue = k
                            if !model.garland { model.binding(\.garland) { .garland($0) }.wrappedValue = true }
                        }
                    }
                }
                Toggle(tr("garland.blinks"), isOn: model.binding(\.garlandBlinks) { .garlandBlinks($0) }).disabled(!model.garland)
            }
            Section(tr("snowmen")) {
                FeatureRow(image: StylePreviews.snowman, title: tr("snowmen"), about: tr("snowmen.howto"),
                           isOn: model.binding(\.snowmen) { .snowmen($0) })
            }
        }
        .formStyle(.grouped)
    }
}

private struct DisplayTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section {
                Toggle(tr("behind"), isOn: model.binding(\.behind) { .behind($0) })
                Toggle(tr("full_screen"), isOn: model.binding(\.fullScreen) { .fullScreen($0) }).disabled(model.behind)
                Toggle(tr("screenshots"), isOn: model.binding(\.screenshots) { .screenshots($0) })
                Toggle(tr("performance"), isOn: model.binding(\.performance) { .performance($0) })
                Text(tr("performance.about")).font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct GeneralTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section {
                Toggle(tr("login"), isOn: model.binding(\.login) { .login($0) })
                Button(tr("updates")) { model.apply(.updates) }
            }
            Section {
                Text(tr("settings.doubleclick")).foregroundStyle(.secondary)
                let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
                LabeledContent("Snowhush", value: version)
                Link("github.com/memph11s/Snowhush", destination: URL(string: "https://github.com/memph11s/Snowhush")!)
            }
        }
        .formStyle(.grouped)
    }
}

/// A picture to pick, outlined in the accent colour once picked.
private struct PictureCard: View {
    let image: NSImage
    let title: String
    let selected: Bool
    let pick: () -> Void

    var body: some View {
        Button(action: pick) {
            VStack(spacing: 6) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 64)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.12, green: 0.17, blue: 0.3)))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 3))
                Text(title).font(.callout).lineLimit(1).minimumScaleFactor(0.8)
                    .foregroundStyle(selected ? Color.accentColor : Color.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

/// A feature with a picture beside it, what it does and its switch.
private struct FeatureRow: View {
    let image: NSImage
    let title: String
    let about: String
    let isOn: Binding<Bool>

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.12, green: 0.17, blue: 0.3)))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Toggle(title, isOn: isOn).font(.headline)
                Text(about).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
}

private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }

// MARK: - Pictures

/// Small pictures of the choices: drawn once, the way the snow and decorations look on screen.
enum StylePreviews {
    private static var cache: [String: NSImage] = [:]

    private static func cached(_ key: String, size: NSSize, draw: @escaping (CGContext) -> Void) -> NSImage {
        if let image = cache[key] { return image }
        let image = NSImage(size: size, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            draw(context)
            return true
        }
        cache[key] = image
        return image
    }

    private static func cgImage(_ picture: NewYear.Picture) -> CGImage? { NewYear.draw(picture)?.makeImage() }

    /// `picture` tinted `color`, its shading kept, drawn into `rect`.
    private static func draw(_ picture: NewYear.Picture, in rect: CGRect, tint color: NSColor? = nil, angle: CGFloat = 0, into context: CGContext) {
        guard let image = cgImage(picture) else { return }
        context.saveGState()
        context.translateBy(x: rect.midX, y: rect.midY)
        context.rotate(by: angle)
        let local = CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        context.draw(image, in: local)
        if let color {
            context.setBlendMode(.sourceAtop)
            context.setFillColor(color.cgColor)
            context.fill(local)
            context.setBlendMode(.multiply)
            context.draw(image, in: local)
        }
        context.endTransparencyLayer()
        context.restoreGState()
    }

    static func picture(_ picture: NewYear.Picture, height: CGFloat) -> NSImage {
        let size = NewYear.size(of: picture)
        let scale = height / size.height
        let box = NSSize(width: max(size.width * scale, height) + 8, height: height + 8)
        return cached("picture-\(picture)", size: box) { context in
            draw(picture, in: CGRect(x: (box.width - size.width * scale) / 2, y: 4, width: size.width * scale, height: height), into: context)
        }
    }

    static func garland(_ style: Int) -> NSImage {
        let size = NSSize(width: 150, height: 64)
        return cached("garland-\(style)", size: size) { context in
            let wire = CGMutablePath()
            wire.move(to: CGPoint(x: 0, y: 52))
            wire.addQuadCurve(to: CGPoint(x: 75, y: 52), control: CGPoint(x: 37, y: 30))
            wire.addQuadCurve(to: CGPoint(x: 150, y: 52), control: CGPoint(x: 112, y: 30))
            context.addPath(wire)
            context.setStrokeColor(NSColor(srgbRed: 0.1, green: 0.3, blue: 0.13, alpha: 1).cgColor)
            context.setLineWidth(1.6)
            context.strokePath()
            let colors = NewYear.bulbColors.map { NSColor(srgbRed: CGFloat($0.x), green: CGFloat($0.y), blue: CGFloat($0.z), alpha: 1) }
            let gold = NSColor(srgbRed: 1, green: 0.78, blue: 0.25, alpha: 1)
            let warm = NSColor(srgbRed: 1, green: 0.8, blue: 0.48, alpha: 1)
            let count = style == 1 ? 15 : style == 2 ? 5 : 7
            for k in 0..<count {
                let x = (CGFloat(k) + 0.5) / CGFloat(count) * 150
                let u = x.truncatingRemainder(dividingBy: 75) / 75
                let y = 52 - 22 * 2 * u * (1 - u)
                let color = style == 1 ? warm : style == 2 ? (k % 2 == 0 ? gold : colors[(k / 2) % colors.count]) : colors[k % colors.count]
                let halo = style == 1 ? 9.0 : 16.0
                context.saveGState()
                let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                      colors: [color.withAlphaComponent(0.55).cgColor, color.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])!
                let center = CGPoint(x: x, y: y - (style == 1 ? 2 : 9))
                context.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: halo, options: [])
                context.restoreGState()
                switch style {
                case 1: draw(.fairy, in: CGRect(x: x - 2.5, y: y - 4.5, width: 5, height: 5), tint: color, into: context)
                case 2: draw(.star, in: CGRect(x: x - 9, y: y - 18, width: 18, height: 18), tint: color, into: context)
                default: draw(.bulb, in: CGRect(x: x - 5, y: y - 16, width: 10, height: 16), tint: color, angle: CGFloat(k % 2 == 0 ? 0.15 : -0.15), into: context)
                }
            }
        }
    }

    static func flakes(_ style: Int) -> NSImage {
        let size = NSSize(width: 150, height: 64)
        return cached("flakes-\(style)", size: size) { context in
            var seed: UInt32 = 7
            func next() -> CGFloat {
                seed = seed &* 1_664_525 &+ 1_013_904_223
                return CGFloat(seed >> 8) / CGFloat(1 << 24)
            }
            for _ in 0..<(style == 0 ? 18 : 11) {
                let center = CGPoint(x: 8 + next() * 134, y: 8 + next() * 48)
                let radius = (style == 0 ? 2 : style == 1 ? 6 : 5) + next() * (style == 0 ? 3 : 4)
                switch style {
                case 1: crystal(at: center, radius: radius, angle: next() * .pi, into: context)
                case 2: clump(at: center, radius: radius, seed: next() * 10, into: context)
                default: soft(at: center, radius: radius, into: context)
                }
            }
        }
    }

    private static func soft(at center: CGPoint, radius: CGFloat, into context: CGContext) {
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [NSColor.white.cgColor, NSColor.white.withAlphaComponent(0.85).cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
                                  locations: [0, 0.55, 1])!
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }

    private static func crystal(at center: CGPoint, radius: CGFloat, angle: CGFloat, into context: CGContext) {
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: angle)
        context.setStrokeColor(NSColor(srgbRed: 0.95, green: 0.97, blue: 1, alpha: 1).cgColor)
        context.setLineCap(.round)
        for k in 0..<6 {
            context.saveGState()
            context.rotate(by: CGFloat(k) * .pi / 3)
            context.setLineWidth(max(radius * 0.17, 1))
            context.move(to: .zero)
            context.addLine(to: CGPoint(x: radius, y: 0))
            context.strokePath()
            context.setLineWidth(max(radius * 0.11, 0.8))
            for side: CGFloat in [-1, 1] {
                context.move(to: CGPoint(x: radius * 0.55, y: 0))
                context.addLine(to: CGPoint(x: radius * 0.55 + radius * 0.3 * 0.5, y: side * radius * 0.3 * 0.866))
            }
            context.strokePath()
            context.restoreGState()
        }
        context.restoreGState()
    }

    private static func clump(at center: CGPoint, radius: CGFloat, seed: CGFloat, into context: CGContext) {
        let path = CGMutablePath()
        for k in 0...40 {
            let a = CGFloat(k) / 40 * 2 * .pi
            let r = radius * (1 + 0.16 * sin(5 * a) + 0.1 * sin(3 * a + seed * 17))
            let point = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
            if k == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        context.saveGState()
        context.addPath(path)
        context.clip()
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [NSColor.white.cgColor, NSColor(srgbRed: 0.8, green: 0.85, blue: 0.93, alpha: 0.95).cgColor] as CFArray,
                                  locations: [0, 1])!
        context.drawRadialGradient(gradient, startCenter: CGPoint(x: center.x - radius * 0.3, y: center.y + radius * 0.3), startRadius: 0,
                                   endCenter: center, endRadius: radius * 1.3, options: [])
        context.restoreGState()
    }

    static func mode(_ mode: Mode) -> NSImage {
        let size = NSSize(width: 110, height: 64)
        return cached("mode-\(mode.rawValue)", size: size) { context in
            let name = [Mode.snow: "snowflake", .autumn: "leaf.fill", .rain: "cloud.rain.fill", .blossom: "camera.macro"][mode] ?? "snowflake"
            let color: NSColor = [Mode.snow: NSColor.white, .autumn: .orange, .rain: NSColor(srgbRed: 0.6, green: 0.8, blue: 1, alpha: 1),
                                  .blossom: NSColor(srgbRed: 1, green: 0.7, blue: 0.85, alpha: 1)][mode] ?? .white
            let configuration = NSImage.SymbolConfiguration(pointSize: 30, weight: .regular).applying(.init(paletteColors: [color]))
            guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(configuration),
                  let image = symbol.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
            let box = symbol.size
            context.draw(image, in: CGRect(x: (size.width - box.width) / 2, y: (size.height - box.height) / 2, width: box.width, height: box.height))
        }
    }

    static let storm: NSImage = cached("storm", size: NSSize(width: 64, height: 64)) { context in
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        context.setLineCap(.round)
        for (y, length) in [(CGFloat(46), CGFloat(40)), (32, 48), (18, 34)] {
            context.setLineWidth(2.4)
            context.move(to: CGPoint(x: 8, y: y))
            context.addCurve(to: CGPoint(x: 8 + length, y: y), control1: CGPoint(x: 8 + length * 0.4, y: y + 5), control2: CGPoint(x: 8 + length * 0.7, y: y - 5))
            context.strokePath()
        }
        for (x, y) in [(CGFloat(52), CGFloat(52)), (56, 26), (44, 12), (30, 40)] {
            soft(at: CGPoint(x: x, y: y), radius: 3.5, into: context)
        }
    }

    /// Three balls stacked, dressed as the snowman they make.
    static let snowman: NSImage = cached("snowman", size: NSSize(width: 64, height: 64)) { context in
        let balls: [(CGFloat, CGFloat)] = [(15, 13), (34, 10), (49, 7.5)]
        draw(.twig, in: CGRect(x: 32, y: 30, width: 18, height: 11), angle: 0.35, into: context)
        context.saveGState()
        context.translateBy(x: 32, y: 0)
        context.scaleBy(x: -1, y: 1)
        draw(.twig, in: CGRect(x: 0, y: 30, width: 18, height: 11), angle: 0.35, into: context)
        context.restoreGState()
        for (y, r) in balls {
            draw(.lump, in: CGRect(x: 32 - r, y: y - r, width: r * 2, height: r * 2), into: context)
        }
        draw(.buttons, in: CGRect(x: 30.5, y: 28.5, width: 3, height: 11), into: context)
        draw(.scarf, in: CGRect(x: 24.5, y: 37, width: 15, height: 9), into: context)
        draw(.face, in: CGRect(x: 24.5, y: 41.5, width: 15, height: 15), into: context)
        draw(.hat, in: CGRect(x: 26.5, y: 53, width: 11, height: 9), angle: -0.12, into: context)
    }
}
