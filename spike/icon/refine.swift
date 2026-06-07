import AppKit
let OUT = FileManager.default.currentDirectoryPath
let ink = NSColor.black, white = NSColor.white
func rr(_ r: NSRect, _ rad: CGFloat) -> NSBezierPath { NSBezierPath(roundedRect:r, xRadius:rad, yRadius:rad) }
func wisp(_ x: CGFloat,_ y0: CGFloat,_ h: CGFloat,_ lw: CGFloat,_ amp: CGFloat) {
    let p = NSBezierPath(); p.lineWidth = lw; p.lineCapStyle = .round
    p.move(to: NSPoint(x:x,y:y0))
    p.curve(to: NSPoint(x:x,y:y0+h), controlPoint1: NSPoint(x:x-amp,y:y0+h*0.33), controlPoint2: NSPoint(x:x+amp,y:y0+h*0.66))
    p.stroke()
}
// shared: bean on the body face, centered at (cx,cy), height bh
func bean(_ cx: CGFloat,_ cy: CGFloat,_ bh: CGFloat) {
    let bw = bh*0.66
    white.setFill(); NSBezierPath(ovalIn: NSRect(x:cx-bw/2,y:cy-bh/2,width:bw,height:bh)).fill()
    ink.setStroke(); let seam = NSBezierPath(); seam.lineWidth = bh*0.12; seam.lineCapStyle = .round
    seam.move(to: NSPoint(x:cx, y:cy-bh*0.34)); seam.line(to: NSPoint(x:cx, y:cy+bh*0.34)); seam.stroke()
}

func draw(_ v: Int, _ s: CGFloat) {
    ink.setFill(); ink.setStroke()
    switch v {
    // R1: literal edit — drive body, bean LEFT + bigger LED RIGHT, 3 thin wisps raised higher
    case 0:
        let w=s*0.66, h=s*0.34, x=(s-w)/2, y=s*0.14
        rr(NSRect(x:x,y:y,width:w,height:h), s*0.06).fill()
        bean(x+w*0.34, y+h*0.5, h*0.62)
        white.setFill(); NSBezierPath(ovalIn:NSRect(x:x+w*0.66,y:y+h*0.5-s*0.045,width:s*0.09,height:s*0.09)).fill(); ink.setFill()
        let gap = s*0.12
        for i in 0..<3 { wisp(x+w*0.5+CGFloat(i-1)*w*0.24, y+h+gap, s*0.30, s*0.035, s*0.06) }

    // R2: "more like a coffee cup" — body taller + handle, bean centered, bigger LED, 3 thin high wisps
    case 1:
        let w=s*0.50, h=s*0.42, x=s*0.20, y=s*0.14
        rr(NSRect(x:x,y:y,width:w,height:h), s*0.07).fill()
        let handle=NSBezierPath(); handle.lineWidth=s*0.06
        handle.appendArc(withCenter:NSPoint(x:x+w+s*0.005,y:y+h*0.5), radius:s*0.12, startAngle:-78, endAngle:78); handle.stroke()
        bean(x+w*0.42, y+h*0.52, h*0.5)
        white.setFill(); NSBezierPath(ovalIn:NSRect(x:x+w*0.74,y:y+h*0.5-s*0.045,width:s*0.09,height:s*0.09)).fill(); ink.setFill()
        let gap=s*0.13
        for i in 0..<3 { wisp(x+w*0.5+CGFloat(i-1)*w*0.28, y+h+gap, s*0.28, s*0.035, s*0.055) }

    // R3: cleaner — cup body + handle, ONLY a big LED (no bean), 3 thin high wisps
    case 2:
        let w=s*0.50, h=s*0.42, x=s*0.20, y=s*0.14
        rr(NSRect(x:x,y:y,width:w,height:h), s*0.07).fill()
        let handle=NSBezierPath(); handle.lineWidth=s*0.06
        handle.appendArc(withCenter:NSPoint(x:x+w+s*0.005,y:y+h*0.5), radius:s*0.12, startAngle:-78, endAngle:78); handle.stroke()
        white.setFill(); NSBezierPath(ovalIn:NSRect(x:x+w*0.5-s*0.06,y:y+h*0.5-s*0.06,width:s*0.12,height:s*0.12)).fill(); ink.setFill()
        let gap=s*0.13
        for i in 0..<3 { wisp(x+w*0.5+CGFloat(i-1)*w*0.28, y+h+gap, s*0.28, s*0.035, s*0.055) }

    // R4: cleaner alt — wide drive body + ONLY a big LED + bean removed, 3 thin high wisps (most drive-like)
    case 3:
        let w=s*0.66, h=s*0.34, x=(s-w)/2, y=s*0.14
        rr(NSRect(x:x,y:y,width:w,height:h), s*0.06).fill()
        white.setFill(); NSBezierPath(ovalIn:NSRect(x:x+w*0.78,y:y+h*0.5-s*0.06,width:s*0.12,height:s*0.12)).fill(); ink.setFill()
        let gap=s*0.13
        for i in 0..<3 { wisp(x+w*0.5+CGFloat(i-1)*w*0.24, y+h+gap, s*0.30, s*0.035, s*0.06) }
    default: break
    }
}
func render(_ v:Int,_ size:CGFloat,_ bg:NSColor,_ name:String){
    let img=NSImage(size:NSSize(width:size,height:size)); img.lockFocus()
    bg.setFill(); NSBezierPath(rect:NSRect(x:0,y:0,width:size,height:size)).fill()
    draw(v,size); img.unlockFocus()
    if let t=img.tiffRepresentation,let r=NSBitmapImageRep(data:t),let p=r.representation(using:.png,properties:[:]){
        try? p.write(to:URL(fileURLWithPath:"\(OUT)/\(name).png")) }
}
for v in 0..<4 { render(v,512,.white,"r\(v+1)-big"); render(v,36,NSColor(white:0.90,alpha:1),"r\(v+1)-bar") }
print("rendered refined r1-r4")
