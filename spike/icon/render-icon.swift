// Renders DriveCaffeine menu-bar icon candidates to PNGs for visual review.
// Each variant is drawn as a monochrome glyph (what a template image becomes).
// We render BIG (512) on white so we can see it, plus a small 18px on a gray
// bar to preview how it reads at real menu-bar size.
//
// Run:  swift render-icon.swift
import AppKit

let OUT = FileManager.default.currentDirectoryPath

// Draw a variant into the current NSGraphicsContext at the given size.
// All shapes are black; this is what the template (system-tinted) icon uses.
func draw(_ variant: Int, _ s: CGFloat) {
    let ink = NSColor.black
    ink.setStroke(); ink.setFill()

    switch variant {

    // A — External drive + 3 steam wisps rising. The drive is "hot/awake."
    case 0:
        let driveH = s * 0.34, driveW = s * 0.68
        let dx = (s - driveW)/2, dy = s * 0.16
        let drive = NSBezierPath(roundedRect: NSRect(x: dx, y: dy, width: driveW, height: driveH),
                                 xRadius: s*0.05, yRadius: s*0.05)
        drive.fill()
        // little activity dot on the drive (knock it out in white)
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: dx+driveW*0.78, y: dy+driveH*0.38, width: s*0.05, height: s*0.05)).fill()
        ink.setFill(); ink.setStroke()
        // 3 steam wisps above the drive
        let topY = dy + driveH + s*0.04
        for i in 0..<3 {
            let x = dx + driveW*0.5 + CGFloat(i-1)*driveW*0.26
            let p = NSBezierPath(); p.lineWidth = s*0.045; p.lineCapStyle = .round
            p.move(to: NSPoint(x: x, y: topY))
            p.curve(to: NSPoint(x: x, y: topY + s*0.30),
                    controlPoint1: NSPoint(x: x - s*0.07, y: topY + s*0.10),
                    controlPoint2: NSPoint(x: x + s*0.07, y: topY + s*0.20))
            p.stroke()
        }

    // B — Coffee mug whose body carries drive "slats" + steam. Cuter, busier.
    case 1:
        let bodyW = s*0.46, bodyH = s*0.40
        let bx = s*0.20, by = s*0.18
        let body = NSBezierPath(roundedRect: NSRect(x: bx, y: by, width: bodyW, height: bodyH),
                                xRadius: s*0.05, yRadius: s*0.05)
        body.fill()
        // handle
        let handle = NSBezierPath(); handle.lineWidth = s*0.06
        handle.appendArc(withCenter: NSPoint(x: bx+bodyW+s*0.02, y: by+bodyH*0.5),
                         radius: s*0.13, startAngle: -80, endAngle: 80)
        handle.stroke()
        // drive slats (white knockouts) across the mug body
        NSColor.white.setFill()
        for i in 0..<2 {
            NSBezierPath(rect: NSRect(x: bx+bodyW*0.18, y: by+bodyH*0.30+CGFloat(i)*bodyH*0.26,
                                      width: bodyW*0.64, height: s*0.03)).fill()
        }
        ink.setFill(); ink.setStroke()
        // 2 steam wisps
        let topY = by + bodyH + s*0.04
        for i in 0..<2 {
            let x = bx + bodyW*0.5 + CGFloat(i)*bodyW*0.34 - bodyW*0.17
            let p = NSBezierPath(); p.lineWidth = s*0.045; p.lineCapStyle = .round
            p.move(to: NSPoint(x: x, y: topY))
            p.curve(to: NSPoint(x: x, y: topY + s*0.26),
                    controlPoint1: NSPoint(x: x - s*0.06, y: topY + s*0.09),
                    controlPoint2: NSPoint(x: x + s*0.06, y: topY + s*0.17))
            p.stroke()
        }

    // C — Drive body with a single bold steam swirl + a coffee bean seam.
    case 2:
        let driveH = s*0.36, driveW = s*0.64
        let dx = (s - driveW)/2, dy = s*0.14
        NSBezierPath(roundedRect: NSRect(x: dx, y: dy, width: driveW, height: driveH),
                     xRadius: s*0.06, yRadius: s*0.06).fill()
        // bean seam: a white S-curve on the drive face
        NSColor.white.setStroke()
        let seam = NSBezierPath(); seam.lineWidth = s*0.04; seam.lineCapStyle = .round
        seam.move(to: NSPoint(x: dx+driveW*0.30, y: dy+driveH*0.30))
        seam.curve(to: NSPoint(x: dx+driveW*0.70, y: dy+driveH*0.70),
                   controlPoint1: NSPoint(x: dx+driveW*0.62, y: dy+driveH*0.28),
                   controlPoint2: NSPoint(x: dx+driveW*0.38, y: dy+driveH*0.72))
        seam.stroke()
        ink.setStroke()
        // one bold steam swirl
        let topY = dy + driveH + s*0.05
        let p = NSBezierPath(); p.lineWidth = s*0.06; p.lineCapStyle = .round
        p.move(to: NSPoint(x: s*0.5, y: topY))
        p.curve(to: NSPoint(x: s*0.5, y: topY + s*0.34),
                controlPoint1: NSPoint(x: s*0.5 - s*0.12, y: topY + s*0.12),
                controlPoint2: NSPoint(x: s*0.5 + s*0.12, y: topY + s*0.22))
        p.stroke()

    default: break
    }
}

func render(variant: Int, size: CGFloat, bg: NSColor, name: String) {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    bg.setFill(); NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
    draw(variant, size)
    img.unlockFocus()
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: "\(OUT)/\(name).png"))
    print("wrote \(name).png")
}

let bigBG = NSColor.white
let barBG = NSColor(white: 0.92, alpha: 1)   // approximate light menu bar
for v in 0..<3 {
    let letter = ["A","B","C"][v]
    render(variant: v, size: 512, bg: bigBG, name: "variant-\(letter)-big")
    render(variant: v, size: 36,  bg: barBG, name: "variant-\(letter)-bar")  // ~18pt @2x
}
