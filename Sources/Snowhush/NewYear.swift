import AppKit

/// A decoration drawn as a picture on a quad: an ornament in the drift, a garland's bulb or wire, an icicle, a drop.
struct DecorSprite {
    var picture: NewYear.Picture
    /// The point the picture is pinned at, in the overlay's points.
    var anchor: SIMD2<Float>
    var size: SIMD2<Float>
    /// Where on the picture `anchor` is, as a share of its size from the bottom-left: (0.5, 0) is the middle of the
    /// bottom edge, (0.5, 1) the middle of the top one.
    var pivot = SIMD2<Float>(0.5, 0)
    /// Counter-clockwise, in radians, about the pivot.
    var angle: Float = 0
    /// Multiplies the premultiplied picture: a colour, a brightness or a fade.
    var tint = SIMD4<Float>(1, 1, 1, 1)
    /// One for a light that shines by itself and is not dimmed at night.
    var glow: Float = 0
}

/// What the decoration shader reads per instance; laid out as `DecorUniforms` in the shader.
struct DecorUniforms {
    var tint: SIMD4<Float>
    var anchor: SIMD2<Float>
    var size: SIMD2<Float>
    var pivot: SIMD2<Float>
    var angle: Float
    var glow: Float

    init(_ sprite: DecorSprite) {
        tint = sprite.tint
        anchor = sprite.anchor
        size = sprite.size
        pivot = sprite.pivot
        angle = sprite.angle
        glow = sprite.glow
    }
}

/// New Year: ornaments, gifts and a snowman in the drift, a garland under the menu bar, icicles under the windows
/// and a snowstorm. Each is switched on and off from the menu, on any day.
enum NewYear {
    enum Picture: Hashable {
        case wire, ball(Int), gift(Int), snowman, sign, bulb, halo, icicle, drop
        /// A rolled snowball, its lumps of snow turning with it, and what makes three of them a snowman.
        case lump, lumpTexture(Int), twig, buttons, scarf, face, hat
        /// The garland's other lights: a small round fairy light and a star.
        case fairy, star
    }

    /// An ornament sitting in the drift at the bottom of the screen: how far it is from the right edge, or from the
    /// left one when negative, how wide it is and how deep it sinks into the snow, as a share of its height.
    struct Ornament {
        let inset: Float
        let picture: Picture
        let width: Float
        let sink: Float
    }

    static let ornaments: [Ornament] = [
        Ornament(inset: -60, picture: .ball(0), width: 24, sink: 0.3),
        Ornament(inset: -100, picture: .gift(1), width: 36, sink: 0.2),
        Ornament(inset: -230, picture: .ball(2), width: 20, sink: 0.3),
        Ornament(inset: -266, picture: .gift(2), width: 28, sink: 0.2),
        Ornament(inset: 60, picture: .ball(1), width: 22, sink: 0.3),
        Ornament(inset: 250, picture: .gift(0), width: 38, sink: 0.2),
        Ornament(inset: 284, picture: .ball(3), width: 18, sink: 0.3),
        Ornament(inset: 340, picture: .snowman, width: 48, sink: 0.08),
    ]

    /// The garland's bulbs, in turn along the wire.
    static let bulbColors: [SIMD3<Float>] = [
        SIMD3(1.0, 0.22, 0.2), SIMD3(1.0, 0.78, 0.25), SIMD3(0.25, 0.9, 0.4), SIMD3(0.3, 0.6, 1.0), SIMD3(0.95, 0.35, 0.9),
    ]

    /// Pixels per point the pictures are drawn at.
    static let scale: CGFloat = 3

    static func size(of picture: Picture) -> CGSize {
        switch picture {
        case .wire: return CGSize(width: 4, height: 4)
        case .ball: return CGSize(width: 30, height: 36)
        case .gift: return CGSize(width: 40, height: 40)
        case .snowman: return CGSize(width: 56, height: 84)
        case .sign: return sign.size
        case .bulb: return CGSize(width: 10, height: 16)
        case .halo: return CGSize(width: 40, height: 40)
        case .icicle: return CGSize(width: 12, height: 48)
        case .drop: return CGSize(width: 6, height: 8)
        case .lump, .lumpTexture, .face: return CGSize(width: 64, height: 64)
        case .twig: return CGSize(width: 50, height: 30)
        case .buttons: return CGSize(width: 12, height: 44)
        case .scarf: return CGSize(width: 64, height: 38)
        case .hat: return CGSize(width: 48, height: 38)
        case .fairy: return CGSize(width: 8, height: 8)
        case .star: return CGSize(width: 20, height: 20)
        }
    }

    static func aspect(of picture: Picture) -> Float {
        let size = size(of: picture)
        return Float(size.height / size.width)
    }

    /// A number from 0 to 1 that is always the same for the same pair.
    static func noise(_ a: UInt32, _ b: UInt32) -> Float {
        var n = a &* 374_761_393 &+ b &* 668_265_263
        n = (n ^ (n >> 13)) &* 1_274_126_177
        n ^= n >> 16
        return Float(n & 0xFFFF) / 65535
    }

    // MARK: - Pictures

    /// `picture` drawn into premultiplied BGRA, its rows from the top down.
    static func draw(_ picture: Picture) -> CGContext? {
        let size = size(of: picture)
        let width = Int(ceil(size.width * scale)), height = Int(ceil(size.height * scale))
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }
        context.scaleBy(x: scale, y: scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        defer { NSGraphicsContext.restoreGraphicsState() }
        switch picture {
        case .wire:
            NSColor.white.setFill()
            NSRect(origin: .zero, size: size).fill()
        case .ball(let k): drawBall(ballColors[k % ballColors.count])
        case .gift(let k): drawGift(giftColors[k % giftColors.count])
        case .snowman: drawSnowman()
        case .sign: drawSign()
        case .bulb: drawBulb()
        case .halo: drawHalo()
        case .icicle: drawIcicle()
        case .drop: drawDrop()
        case .lump: drawLump()
        case .lumpTexture(let k): drawLumpTexture(seed: k)
        case .twig: drawTwig()
        case .buttons: drawButtons()
        case .scarf: drawScarf()
        case .face: drawFace()
        case .hat: drawHat()
        case .fairy: drawFairy()
        case .star: drawStar()
        }
        return context
    }

    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }

    private static let ballColors: [NSColor] = [
        rgb(0.86, 0.1, 0.14), rgb(0.95, 0.7, 0.18), rgb(0.14, 0.38, 0.86), rgb(0.08, 0.58, 0.34),
    ]

    private static let giftColors: [(box: NSColor, ribbon: NSColor)] = [
        (rgb(0.82, 0.1, 0.14), rgb(1.0, 0.82, 0.3)),
        (rgb(0.1, 0.52, 0.3), rgb(0.9, 0.15, 0.18)),
        (rgb(0.18, 0.36, 0.8), rgb(0.9, 0.92, 0.96)),
    ]

    private static func lighter(_ color: NSColor, _ amount: CGFloat) -> NSColor {
        color.blended(withFraction: amount, of: .white) ?? color
    }

    private static func darker(_ color: NSColor, _ amount: CGFloat) -> NSColor {
        color.blended(withFraction: amount, of: .black) ?? color
    }

    private static func drawBall(_ color: NSColor) {
        // The cap and its loop.
        let cap = NSBezierPath(roundedRect: NSRect(x: 10.5, y: 27, width: 9, height: 5), xRadius: 1.2, yRadius: 1.2)
        NSGradient(colors: [rgb(0.98, 0.86, 0.5), rgb(0.72, 0.55, 0.2)])?.draw(in: cap, angle: 0)
        let loop = NSBezierPath(ovalIn: NSRect(x: 12.6, y: 31, width: 4.8, height: 4.4))
        loop.lineWidth = 1.2
        rgb(0.75, 0.6, 0.25).setStroke()
        loop.stroke()

        let sphere = NSBezierPath(ovalIn: NSRect(x: 1, y: 1, width: 28, height: 28))
        NSGradient(colors: [lighter(color, 0.55), color, darker(color, 0.45)], atLocations: [0, 0.45, 1], colorSpace: .sRGB)?
            .draw(in: sphere, relativeCenterPosition: NSPoint(x: -0.35, y: 0.4))
        NSGraphicsContext.saveGraphicsState()
        sphere.addClip()
        // A frosted band with dots round its middle.
        lighter(color, 0.6).withAlphaComponent(0.45).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 12.5, width: 30, height: 4)).fill()
        rgb(1, 1, 1, 0.75).setFill()
        for x in stride(from: CGFloat(4), through: 26, by: 4.4) {
            NSBezierPath(ovalIn: NSRect(x: x - 0.9, y: 13.6, width: 1.8, height: 1.8)).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        // The window's reflection.
        rgb(1, 1, 1, 0.7).setFill()
        NSBezierPath(ovalIn: NSRect(x: 7, y: 18.5, width: 6, height: 4.2)).fill()
        rgb(1, 1, 1, 0.35).setFill()
        NSBezierPath(ovalIn: NSRect(x: 14.5, y: 21, width: 2.4, height: 1.8)).fill()
    }

    private static func drawGift(_ colors: (box: NSColor, ribbon: NSColor)) {
        let box = NSBezierPath(rect: NSRect(x: 3, y: 0, width: 34, height: 25))
        NSGradient(colors: [darker(colors.box, 0.25), colors.box])?.draw(in: box, angle: 90)
        let lid = NSBezierPath(roundedRect: NSRect(x: 1, y: 23, width: 38, height: 7), xRadius: 1, yRadius: 1)
        NSGradient(colors: [colors.box, lighter(colors.box, 0.18)])?.draw(in: lid, angle: 90)
        darker(colors.box, 0.35).setStroke()
        lid.lineWidth = 0.6
        lid.stroke()
        let ribbon = NSGradient(colors: [darker(colors.ribbon, 0.15), lighter(colors.ribbon, 0.3), darker(colors.ribbon, 0.15)])
        ribbon?.draw(in: NSRect(x: 17, y: 0, width: 6, height: 30), angle: 0)
        ribbon?.draw(in: NSRect(x: 3, y: 10, width: 34, height: 5), angle: 90)
        // The bow: two loops and a knot.
        colors.ribbon.setStroke()
        for (x, tilt) in [(CGFloat(8), CGFloat(18)), (21, -18)] {
            let loop = NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: 11, height: 7))
            var transform = AffineTransform(translationByX: x + 5.5, byY: 33.5)
            transform.rotate(byDegrees: tilt)
            transform.translate(x: -5.5, y: -3.5)
            loop.transform(using: transform)
            loop.lineWidth = 2.4
            loop.stroke()
        }
        colors.ribbon.setFill()
        NSBezierPath(ovalIn: NSRect(x: 17, y: 29.5, width: 6, height: 5)).fill()
    }

    private static func drawSnowman() {
        let snow = NSGradient(colors: [rgb(1, 1, 1), rgb(0.93, 0.95, 0.99), rgb(0.78, 0.84, 0.93)], atLocations: [0, 0.5, 1], colorSpace: .sRGB)
        let edge = rgb(0.68, 0.76, 0.88)
        // Stick arms behind the body.
        rgb(0.42, 0.27, 0.14).setStroke()
        for (from, to, twig) in [(NSPoint(x: 15, y: 47), NSPoint(x: 2, y: 60), NSPoint(x: 6, y: 61)),
                                 (NSPoint(x: 41, y: 47), NSPoint(x: 54, y: 58), NSPoint(x: 51, y: 61))] {
            let arm = NSBezierPath()
            arm.move(to: from)
            arm.line(to: to)
            let mid = NSPoint(x: from.x + (to.x - from.x) * 0.75, y: from.y + (to.y - from.y) * 0.75)
            arm.move(to: mid)
            arm.line(to: twig)
            arm.lineWidth = 1.8
            arm.lineCapStyle = .round
            arm.stroke()
        }
        for rect in [NSRect(x: 6, y: 0, width: 44, height: 38), NSRect(x: 12, y: 31, width: 32, height: 29), NSRect(x: 16, y: 55, width: 24, height: 22)] {
            let ball = NSBezierPath(ovalIn: rect)
            snow?.draw(in: ball, relativeCenterPosition: NSPoint(x: -0.3, y: 0.35))
            edge.setStroke()
            ball.lineWidth = 0.6
            ball.stroke()
        }
        // Hat.
        rgb(0.12, 0.12, 0.14).setFill()
        NSBezierPath(roundedRect: NSRect(x: 14, y: 73, width: 28, height: 3.5), xRadius: 1.5, yRadius: 1.5).fill()
        NSBezierPath(roundedRect: NSRect(x: 19, y: 75, width: 18, height: 9), xRadius: 1.5, yRadius: 1.5).fill()
        rgb(0.8, 0.1, 0.14).setFill()
        NSBezierPath(rect: NSRect(x: 19, y: 76.5, width: 18, height: 2.2)).fill()
        // Face.
        rgb(0.1, 0.1, 0.12).setFill()
        for x in [CGFloat(23.5), 32.5] { NSBezierPath(ovalIn: NSRect(x: x - 1.6, y: 67.5, width: 3.2, height: 3.2)).fill() }
        for (x, y) in [(CGFloat(22.5), CGFloat(62.4)), (25, 61.2), (28, 60.8), (31, 61.2), (33.5, 62.4)] {
            NSBezierPath(ovalIn: NSRect(x: x - 0.8, y: y - 0.8, width: 1.6, height: 1.6)).fill()
        }
        let nose = NSBezierPath()
        nose.move(to: NSPoint(x: 28, y: 66.5))
        nose.line(to: NSPoint(x: 38, y: 64.5))
        nose.line(to: NSPoint(x: 28, y: 63.5))
        nose.close()
        rgb(0.98, 0.5, 0.1).setFill()
        nose.fill()
        // Scarf.
        let scarf = rgb(0.85, 0.12, 0.16)
        scarf.setFill()
        NSBezierPath(roundedRect: NSRect(x: 16.5, y: 53, width: 23, height: 5), xRadius: 2.5, yRadius: 2.5).fill()
        let tail = NSBezierPath(roundedRect: NSRect(x: 31, y: 42, width: 6, height: 13), xRadius: 2, yRadius: 2)
        tail.fill()
        rgb(1, 1, 1, 0.55).setFill()
        for y in [CGFloat(45), 49] { NSBezierPath(rect: NSRect(x: 31, y: y, width: 6, height: 1.2)).fill() }
        // Buttons.
        rgb(0.1, 0.1, 0.12).setFill()
        for y in [CGFloat(49), 42, 35] { NSBezierPath(ovalIn: NSRect(x: 26.4, y: y, width: 3.2, height: 3.2)).fill() }
    }

    /// The snowman's sign: a red board on a stick with the greeting, a cap of snow on top.
    private static let sign: (size: CGSize, text: NSAttributedString, textSize: CGSize, board: CGSize) = {
        let font = NSFont.systemFont(ofSize: 11, weight: .heavy)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let text = NSAttributedString(string: tr("newyear.sign"), attributes: [
            .font: font, .foregroundColor: NSColor.white, .paragraphStyle: style,
        ])
        let measured = text.boundingRect(with: NSSize(width: 160, height: 100), options: [.usesLineFragmentOrigin]).size
        let textSize = CGSize(width: ceil(measured.width), height: ceil(measured.height))
        let board = CGSize(width: textSize.width + 16, height: textSize.height + 10)
        return (CGSize(width: board.width + 6, height: board.height + 6 + signStick), text, textSize, board)
    }()

    static let signStick: CGFloat = 22

    private static func drawSign() {
        let size = sign.size
        let stick = NSBezierPath(roundedRect: NSRect(x: size.width / 2 - 2, y: 0, width: 4, height: signStick + 6), xRadius: 1.2, yRadius: 1.2)
        rgb(0.55, 0.36, 0.18).setFill()
        stick.fill()
        let rect = NSRect(x: 3, y: signStick + 2, width: sign.board.width, height: sign.board.height)
        let board = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
        NSGradient(colors: [rgb(0.7, 0.06, 0.1), rgb(0.88, 0.16, 0.18)])?.draw(in: board, angle: 90)
        rgb(1, 0.85, 0.4).setStroke()
        board.lineWidth = 1.4
        board.stroke()
        // Snow lying on the board.
        let cap = NSBezierPath()
        cap.move(to: NSPoint(x: rect.minX - 1, y: rect.maxY - 1))
        var x = rect.minX - 1
        var up = true
        while x < rect.maxX + 1 {
            let next = min(x + 6, rect.maxX + 1)
            cap.curve(to: NSPoint(x: next, y: rect.maxY - 1), controlPoint1: NSPoint(x: x + 1.5, y: rect.maxY + (up ? 4.5 : 3)),
                      controlPoint2: NSPoint(x: next - 1.5, y: rect.maxY + (up ? 4.5 : 3)))
            x = next
            up.toggle()
        }
        cap.line(to: NSPoint(x: rect.maxX + 1, y: rect.maxY - 2.5))
        cap.line(to: NSPoint(x: rect.minX - 1, y: rect.maxY - 2.5))
        cap.close()
        rgb(0.97, 0.98, 1).setFill()
        cap.fill()
        let textRect = NSRect(x: rect.midX - sign.textSize.width / 2, y: rect.midY - sign.textSize.height / 2 - 0.5,
                              width: sign.textSize.width, height: sign.textSize.height)
        sign.text.draw(with: textRect, options: [.usesLineFragmentOrigin])
    }

    /// A white bulb, tinted its colour as it is drawn; its cap at the top.
    private static func drawBulb() {
        let glass = NSBezierPath(ovalIn: NSRect(x: 0.5, y: 0, width: 9, height: 13))
        NSGradient(colors: [rgb(1, 1, 1), rgb(0.92, 0.92, 0.92), rgb(0.7, 0.7, 0.7)], atLocations: [0, 0.55, 1], colorSpace: .sRGB)?
            .draw(in: glass, relativeCenterPosition: NSPoint(x: -0.2, y: 0.1))
        let cap = NSBezierPath(roundedRect: NSRect(x: 2.8, y: 11, width: 4.4, height: 5), xRadius: 0.8, yRadius: 0.8)
        NSGradient(colors: [rgb(0.35, 0.38, 0.36), rgb(0.6, 0.64, 0.6), rgb(0.35, 0.38, 0.36)])?.draw(in: cap, angle: 0)
    }

    private static func drawHalo() {
        NSGradient(colors: [rgb(1, 1, 1, 0.85), rgb(1, 1, 1, 0.25), rgb(1, 1, 1, 0)], atLocations: [0, 0.22, 0.7], colorSpace: .sRGB)?
            .draw(in: NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: 40, height: 40)), relativeCenterPosition: .zero)
    }

    /// Hanging from its top edge, tapering to a point at the bottom.
    private static func drawIcicle() {
        let shape = NSBezierPath()
        shape.move(to: NSPoint(x: 0.5, y: 48))
        shape.line(to: NSPoint(x: 11.5, y: 48))
        shape.curve(to: NSPoint(x: 6.4, y: 0.5), controlPoint1: NSPoint(x: 10.5, y: 30), controlPoint2: NSPoint(x: 7.6, y: 10))
        shape.line(to: NSPoint(x: 5.6, y: 0.5))
        shape.curve(to: NSPoint(x: 0.5, y: 48), controlPoint1: NSPoint(x: 4.4, y: 10), controlPoint2: NSPoint(x: 1.5, y: 30))
        shape.close()
        NSGradient(colors: [rgb(0.72, 0.86, 1, 0.7), rgb(0.97, 0.99, 1, 0.95), rgb(0.66, 0.82, 1, 0.65)])?.draw(in: shape, angle: 0)
        NSGraphicsContext.saveGraphicsState()
        shape.addClip()
        let shine = NSBezierPath()
        shine.move(to: NSPoint(x: 4.2, y: 46))
        shine.curve(to: NSPoint(x: 5.8, y: 6), controlPoint1: NSPoint(x: 3.6, y: 30), controlPoint2: NSPoint(x: 5, y: 14))
        shine.lineWidth = 1.1
        rgb(1, 1, 1, 0.8).setStroke()
        shine.stroke()
        rgb(1, 1, 1, 0.5).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 45.5, width: 12, height: 2.5)).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawDrop() {
        let drop = NSBezierPath(ovalIn: NSRect(x: 1, y: 0.5, width: 4, height: 6))
        NSGradient(colors: [rgb(1, 1, 1, 0.95), rgb(0.7, 0.85, 1, 0.75)])?.draw(in: drop, relativeCenterPosition: NSPoint(x: -0.3, y: 0.3))
    }

    // MARK: - Snowballs and snowmen

    /// A ball of packed snow, lit from the upper left, darker toward its foot.
    private static func drawLump() {
        let ball = NSBezierPath(ovalIn: NSRect(x: 1.2, y: 1.2, width: 61.6, height: 61.6))
        NSGradient(colors: [rgb(1, 1, 1), rgb(0.95, 0.96, 0.99), rgb(0.8, 0.85, 0.93), rgb(0.66, 0.73, 0.85)],
                   atLocations: [0, 0.35, 0.8, 1], colorSpace: .sRGB)?
            .draw(in: ball, relativeCenterPosition: NSPoint(x: -0.35, y: 0.4))
        rgb(0.62, 0.7, 0.84, 0.8).setStroke()
        ball.lineWidth = 0.8
        ball.stroke()
    }

    /// The lumps and hollows on a ball, faint, turned with it as it rolls.
    private static func drawLumpTexture(seed: Int) {
        let clip = NSBezierPath(ovalIn: NSRect(x: 1.5, y: 1.5, width: 61, height: 61))
        NSGraphicsContext.saveGraphicsState()
        clip.addClip()
        for k in 0..<26 {
            let a = CGFloat(noise(UInt32(k), UInt32(seed + 11))) * 2 * .pi
            let d = CGFloat(noise(UInt32(k), UInt32(seed + 23))).squareRoot() * 28
            let size = 3 + CGFloat(noise(UInt32(k), UInt32(seed + 37))) * 7
            let center = NSPoint(x: 32 + cos(a) * d, y: 32 + sin(a) * d)
            let dark = k % 3 != 0
            (dark ? rgb(0.55, 0.62, 0.76, 0.16) : rgb(1, 1, 1, 0.5)).setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x - size / 2, y: center.y - size / 3, width: size, height: size * 0.66)).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    /// A twig arm from the shoulder at the left to its forked tip at the right.
    private static func drawTwig() {
        rgb(0.4, 0.25, 0.13).setStroke()
        let arm = NSBezierPath()
        arm.move(to: NSPoint(x: 1, y: 6))
        arm.curve(to: NSPoint(x: 48, y: 20), controlPoint1: NSPoint(x: 16, y: 8), controlPoint2: NSPoint(x: 32, y: 16))
        arm.lineWidth = 2.6
        arm.lineCapStyle = .round
        arm.stroke()
        for (from, to) in [(NSPoint(x: 34, y: 15.5), NSPoint(x: 41, y: 28)), (NSPoint(x: 42, y: 18.5), NSPoint(x: 49, y: 13))] {
            let twig = NSBezierPath()
            twig.move(to: from)
            twig.line(to: to)
            twig.lineWidth = 1.7
            twig.lineCapStyle = .round
            twig.stroke()
        }
    }

    private static func drawButtons() {
        for y in [CGFloat(4), 18, 32] {
            let coal = NSBezierPath(ovalIn: NSRect(x: 1, y: y, width: 9, height: 8.5))
            NSGradient(colors: [rgb(0.32, 0.32, 0.34), rgb(0.06, 0.06, 0.07)])?.draw(in: coal, relativeCenterPosition: NSPoint(x: -0.4, y: 0.4))
        }
    }

    /// Coal eyes and smile, a carrot for a nose.
    private static func drawFace() {
        for x in [CGFloat(22), 40] {
            let eye = NSBezierPath(ovalIn: NSRect(x: x - 3.6, y: 37, width: 7.2, height: 7.6))
            NSGradient(colors: [rgb(0.3, 0.3, 0.33), rgb(0.05, 0.05, 0.06)])?.draw(in: eye, relativeCenterPosition: NSPoint(x: -0.4, y: 0.4))
        }
        rgb(0.08, 0.08, 0.09).setFill()
        for k in 0..<6 {
            let u = CGFloat(k) / 5
            let x = 19 + u * 24, y = 20 - sin(u * .pi) * 5
            NSBezierPath(ovalIn: NSRect(x: x - 1.9, y: y - 1.9, width: 3.8, height: 3.8)).fill()
        }
        let nose = NSBezierPath()
        nose.move(to: NSPoint(x: 31, y: 34.5))
        nose.line(to: NSPoint(x: 56, y: 28))
        nose.line(to: NSPoint(x: 31, y: 27))
        nose.close()
        NSGradient(colors: [rgb(1, 0.6, 0.18), rgb(0.9, 0.38, 0.06)])?.draw(in: nose, angle: -90)
        rgb(0.7, 0.3, 0.05, 0.6).setStroke()
        for x in [CGFloat(38), 45] {
            let line = NSBezierPath()
            line.move(to: NSPoint(x: x, y: 33.5 - (x - 31) * 0.26))
            line.line(to: NSPoint(x: x + 1, y: 27.5 + (x - 31) * 0.02))
            line.lineWidth = 0.7
            line.stroke()
        }
    }

    /// A red knitted scarf round the neck, its end hanging down one side.
    private static func drawScarf() {
        let red = rgb(0.84, 0.12, 0.16), dark = rgb(0.6, 0.06, 0.1)
        let tail = NSBezierPath(roundedRect: NSRect(x: 38, y: 1, width: 11, height: 26), xRadius: 3, yRadius: 3)
        NSGradient(colors: [red, dark])?.draw(in: tail, angle: 0)
        rgb(1, 1, 1, 0.6).setFill()
        for y in [CGFloat(6), 12] { NSBezierPath(rect: NSRect(x: 38, y: y, width: 11, height: 2.4)).fill() }
        let band = NSBezierPath(roundedRect: NSRect(x: 4, y: 22, width: 56, height: 13), xRadius: 6.5, yRadius: 6.5)
        NSGradient(colors: [rgb(0.95, 0.25, 0.25), red, dark], atLocations: [0, 0.5, 1], colorSpace: .sRGB)?.draw(in: band, angle: -90)
        rgb(1, 1, 1, 0.55).setFill()
        for x in stride(from: CGFloat(10), to: 58, by: 9) { NSBezierPath(rect: NSRect(x: x, y: 22.5, width: 2.4, height: 12)).fill() }
    }

    /// A black top hat with a red band.
    private static func drawHat() {
        let brim = NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: 46, height: 7), xRadius: 3.5, yRadius: 3.5)
        let crown = NSBezierPath(roundedRect: NSRect(x: 9, y: 5, width: 30, height: 32), xRadius: 3, yRadius: 3)
        NSGradient(colors: [rgb(0.25, 0.25, 0.28), rgb(0.08, 0.08, 0.1)])?.draw(in: crown, angle: 0)
        NSGradient(colors: [rgb(0.22, 0.22, 0.25), rgb(0.06, 0.06, 0.08)])?.draw(in: brim, angle: -90)
        rgb(0.78, 0.1, 0.14).setFill()
        NSBezierPath(rect: NSRect(x: 9, y: 9, width: 30, height: 5.5)).fill()
        rgb(0.97, 0.98, 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 12, y: 33.5, width: 24, height: 4.5)).fill()
    }

    /// A small round light, white to be tinted as it is drawn.
    private static func drawFairy() {
        NSGradient(colors: [rgb(1, 1, 1), rgb(1, 1, 1), rgb(0.75, 0.75, 0.75)], atLocations: [0, 0.4, 1], colorSpace: .sRGB)?
            .draw(in: NSBezierPath(ovalIn: NSRect(x: 0.5, y: 0.5, width: 7, height: 7)), relativeCenterPosition: NSPoint(x: -0.2, y: 0.2))
    }

    /// A five-pointed star, white to be tinted as it is drawn, hung from its top point.
    private static func drawStar() {
        let star = NSBezierPath()
        for k in 0..<10 {
            let a = CGFloat.pi / 2 + CGFloat(k) * .pi / 5
            let r: CGFloat = k % 2 == 0 ? 9.5 : 4
            let point = NSPoint(x: 10 + cos(a) * r, y: 9.6 + sin(a) * r)
            if k == 0 { star.move(to: point) } else { star.line(to: point) }
        }
        star.close()
        NSGradient(colors: [rgb(1, 1, 1), rgb(0.82, 0.82, 0.82)])?.draw(in: star, relativeCenterPosition: NSPoint(x: -0.3, y: 0.3))
        rgb(0.6, 0.6, 0.6).setStroke()
        star.lineWidth = 0.5
        star.stroke()
    }
}
