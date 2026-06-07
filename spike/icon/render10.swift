// Render 10 menu-bar icon concepts for Drive Caffeine. Monochrome template
// glyphs (what macOS tints). Each rendered big (512, on white) + small (36 ≈
// 18pt @2x, on a gray bar) to test menu-bar legibility.
// Run: swift render10.swift
import AppKit

let OUT = FileManager.default.currentDirectoryPath
let ink = NSColor.black
let white = NSColor.white

func roundRect(_ r: NSRect, _ rad: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: r, xRadius: rad, yRadius: rad)
}
// A steam wisp from (x, y0) rising height h, with given line width.
func wisp(x: CGFloat, y0: CGFloat, h: CGFloat, lw: CGFloat, amp: CGFloat) {
    let p = NSBezierPath(); p.lineWidth = lw; p.lineCapStyle = .round
    p.move(to: NSPoint(x: x, y: y0))
    p.curve(to: NSPoint(x: x, y: y0 + h),
            controlPoint1: NSPoint(x: x - amp, y: y0 + h*0.33),
            controlPoint2: NSPoint(x: x + amp, y: y0 + h*0.66))
    p.stroke()
}

func draw(_ v: Int, _ s: CGFloat) {
    ink.setFill(); ink.setStroke()

    switch v {
    // 1: drive + 3 steam wisps + LED (original A)
    case 0:
        let w = s*0.68, h = s*0.34, x=(s-w)/2, y=s*0.16
        roundRect(NSRect(x:x,y:y,width:w,height:h), s*0.05).fill()
        white.setFill(); NSBezierPath(ovalIn: NSRect(x:x+w*0.80,y:y+h*0.38,width:s*0.05,height:s*0.05)).fill(); ink.setFill()
        for i in 0..<3 { wisp(x:x+w*0.5+CGFloat(i-1)*w*0.26, y0:y+h+s*0.04, h:s*0.30, lw:s*0.045, amp:s*0.07) }

    // 2: drive + 2 thicker wisps (calmer)
    case 1:
        let w = s*0.66, h = s*0.36, x=(s-w)/2, y=s*0.16
        roundRect(NSRect(x:x,y:y,width:w,height:h), s*0.06).fill()
        for i in 0..<2 { wisp(x:x+w*0.5+CGFloat(i)*w*0.30 - w*0.15, y0:y+h+s*0.05, h:s*0.30, lw:s*0.06, amp:s*0.08) }

    // 3: mug-shaped drive (rounded body + handle) + 2 wisps
    case 2:
        let w=s*0.50, h=s*0.42, x=s*0.18, y=s*0.18
        roundRect(NSRect(x:x,y:y,width:w,height:h), s*0.06).fill()
        let handle=NSBezierPath(); handle.lineWidth=s*0.06
        handle.appendArc(withCenter:NSPoint(x:x+w+s*0.01,y:y+h*0.5), radius:s*0.12, startAngle:-80, endAngle:80); handle.stroke()
        for i in 0..<2 { wisp(x:x+w*0.5+CGFloat(i)*w*0.32 - w*0.16, y0:y+h+s*0.04, h:s*0.26, lw:s*0.05, amp:s*0.06) }

    // 4: drive with a single coffee BEAN on its face + 2 wisps
    case 3:
        let w=s*0.64, h=s*0.34, x=(s-w)/2, y=s*0.16
        roundRect(NSRect(x:x,y:y,width:w,height:h), s*0.06).fill()
        // bean: white oval with a center seam
        let bx=x+w*0.5-s*0.07, by=y+h*0.5-s*0.10
        white.setFill(); NSBezierPath(ovalIn:NSRect(x:bx,y:by,width:s*0.14,height:s*0.20)).fill()
        ink.setStroke(); let seam=NSBezierPath(); seam.lineWidth=s*0.025
        seam.move(to:NSPoint(x:bx+s*0.07,y:by+s*0.02)); seam.line(to:NSPoint(x:bx+s*0.07,y:by+s*0.18)); seam.stroke()
        ink.setFill()
        for i in 0..<2 { wisp(x:x+w*0.5+CGFloat(i)*w*0.30 - w*0.15, y0:y+h+s*0.05, h:s*0.26, lw:s*0.05, amp:s*0.06) }

    // 5: coffee cup ON TOP of a drive (stacked)
    case 4:
        let dw=s*0.70, dh=s*0.22, dx=(s-dw)/2, dy=s*0.16
        roundRect(NSRect(x:dx,y:dy,width:dw,height:dh), s*0.05).fill()  // drive base
        white.setFill(); NSBezierPath(ovalIn:NSRect(x:dx+dw*0.82,y:dy+dh*0.34,width:s*0.05,height:s*0.05)).fill(); ink.setFill()
        let cw=s*0.34, ch=s*0.26, cx=(s-cw)/2, cy=dy+dh+s*0.05
        roundRect(NSRect(x:cx,y:cy,width:cw,height:ch), s*0.04).fill() // cup
        let handle=NSBezierPath(); handle.lineWidth=s*0.045
        handle.appendArc(withCenter:NSPoint(x:cx+cw+s*0.005,y:cy+ch*0.5), radius:s*0.08, startAngle:-80, endAngle:80); handle.stroke()
        wisp(x:s*0.5, y0:cy+ch+s*0.03, h:s*0.18, lw:s*0.05, amp:s*0.05)

    // 6: power "Z" (sleep) crossed out feel — drive + Zzz turning to steam. Use small z + wisps.
    case 5:
        let w=s*0.64, h=s*0.34, x=(s-w)/2, y=s*0.16
        roundRect(NSRect(x:x,y:y,width:w,height:h), s*0.06).fill()
        // a "Z" knocked out of the drive
        white.setStroke(); let z=NSBezierPath(); z.lineWidth=s*0.04; z.lineCapStyle = .round
        let zx=x+w*0.40, zy=y+h*0.30, zw=s*0.18, zh=s*0.16
        z.move(to:NSPoint(x:zx,y:zy+zh)); z.line(to:NSPoint(x:zx+zw,y:zy+zh)); z.line(to:NSPoint(x:zx,y:zy)); z.line(to:NSPoint(x:zx+zw,y:zy)); z.stroke()
        ink.setStroke()
        for i in 0..<2 { wisp(x:x+w*0.5+CGFloat(i)*w*0.30 - w*0.15, y0:y+h+s*0.05, h:s*0.24, lw:s*0.05, amp:s*0.06) }

    // 7: drive with a lightning bolt (energized) on its face
    case 6:
        let w=s*0.64, h=s*0.36, x=(s-w)/2, y=s*0.16
        roundRect(NSRect(x:x,y:y,width:w,height:h), s*0.06).fill()
        white.setFill()
        let b=NSBezierPath(); let cx=x+w*0.5, cy=y+h*0.5
        b.move(to:NSPoint(x:cx+s*0.02,y:cy+h*0.30))
        b.line(to:NSPoint(x:cx-s*0.06,y:cy)); b.line(to:NSPoint(x:cx,y:cy))
        b.line(to:NSPoint(x:cx-s*0.02,y:cy-h*0.30)); b.line(to:NSPoint(x:cx+s*0.07,y:cy+s*0.02))
        b.line(to:NSPoint(x:cx+s*0.01,y:cy+s*0.02)); b.close(); b.fill(); ink.setFill()
        for i in 0..<2 { wisp(x:x+w*0.5+CGFloat(i)*w*0.34 - w*0.17, y0:y+h+s*0.05, h:s*0.22, lw:s*0.05, amp:s*0.05) }

    // 8: tall stacked drive (vertical) + steam — like a thermos/drive tower
    case 7:
        let w=s*0.40, h=s*0.52, x=(s-w)/2, y=s*0.12
        roundRect(NSRect(x:x,y:y,width:w,height:h), s*0.06).fill()
        white.setFill()
        for i in 0..<3 { NSBezierPath(rect:NSRect(x:x+w*0.2,y:y+h*0.18+CGFloat(i)*h*0.16,width:w*0.6,height:s*0.025)).fill() }
        ink.setFill()
        for i in 0..<2 { wisp(x:s*0.5+CGFloat(i)*w*0.5 - w*0.25, y0:y+h+s*0.04, h:s*0.22, lw:s*0.05, amp:s*0.05) }

    // 9: coffee bean WITH drive activity dot (bean is the hero, dot = drive)
    case 8:
        let bw=s*0.40, bh=s*0.56, bx=(s-bw)/2, by=s*0.20
        NSBezierPath(ovalIn:NSRect(x:bx,y:by,width:bw,height:bh)).fill()
        // S-seam in white
        white.setStroke(); let seam=NSBezierPath(); seam.lineWidth=s*0.05; seam.lineCapStyle = .round
        seam.move(to:NSPoint(x:bx+bw*0.5,y:by+bh*0.10))
        seam.curve(to:NSPoint(x:bx+bw*0.5,y:by+bh*0.90),
                   controlPoint1:NSPoint(x:bx+bw*0.95,y:by+bh*0.35),
                   controlPoint2:NSPoint(x:bx+bw*0.05,y:by+bh*0.65)); seam.stroke()
        ink.setStroke()
        for i in 0..<2 { wisp(x:s*0.5+CGFloat(i)*bw*0.5 - bw*0.25, y0:by+bh+s*0.03, h:s*0.16, lw:s*0.045, amp:s*0.04) }

    // 10: drive face = a smiling/awake "eye" open (anti-sleep) + steam. Eye = open=awake.
    case 9:
        let w=s*0.66, h=s*0.40, x=(s-w)/2, y=s*0.16
        roundRect(NSRect(x:x,y:y,width:w,height:h), s*0.08).fill()
        white.setFill()
        NSBezierPath(ovalIn:NSRect(x:x+w*0.5-s*0.09,y:y+h*0.5-s*0.09,width:s*0.18,height:s*0.18)).fill() // open eye (awake)
        ink.setFill(); NSBezierPath(ovalIn:NSRect(x:x+w*0.5-s*0.035,y:y+h*0.5-s*0.035,width:s*0.07,height:s*0.07)).fill() // pupil
        for i in 0..<2 { wisp(x:x+w*0.5+CGFloat(i)*w*0.34 - w*0.17, y0:y+h+s*0.04, h:s*0.20, lw:s*0.05, amp:s*0.05) }

    default: break
    }
}

func render(_ v: Int, _ size: CGFloat, _ bg: NSColor, _ name: String) {
    let img = NSImage(size: NSSize(width:size,height:size)); img.lockFocus()
    bg.setFill(); NSBezierPath(rect:NSRect(x:0,y:0,width:size,height:size)).fill()
    draw(v, size); img.unlockFocus()
    guard let tiff=img.tiffRepresentation, let rep=NSBitmapImageRep(data:tiff),
          let png=rep.representation(using:.png, properties:[:]) else { return }
    try? png.write(to:URL(fileURLWithPath:"\(OUT)/\(name).png"))
}

let bar = NSColor(white:0.92, alpha:1)
for v in 0..<10 {
    let n = v+1
    render(v, 512, .white, "v\(n)-big")
    render(v, 36, bar, "v\(n)-bar")
}
print("rendered 10 variants (big + bar)")
