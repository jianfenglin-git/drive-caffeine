import AppKit
let ink=NSColor.black
func wisp(_ x:CGFloat,_ y0:CGFloat,_ h:CGFloat,_ lw:CGFloat,_ amp:CGFloat){
    let p=NSBezierPath(); p.lineWidth=lw; p.lineCapStyle = .round
    p.move(to:NSPoint(x:x,y:y0))
    p.curve(to:NSPoint(x:x,y:y0+h),controlPoint1:NSPoint(x:x-amp,y:y0+h*0.28),controlPoint2:NSPoint(x:x+amp,y:y0+h*0.72))
    p.stroke()
}
// classic tapered MUG (wider at top), filled, with handle. cx=center x, baseY bottom.
func mug(_ cx:CGFloat,_ baseY:CGFloat,_ topW:CGFloat,_ botW:CGFloat,_ h:CGFloat){
    let p=NSBezierPath()
    p.move(to:NSPoint(x:cx-botW/2,y:baseY))
    p.line(to:NSPoint(x:cx-topW/2,y:baseY+h))
    p.line(to:NSPoint(x:cx+topW/2,y:baseY+h))
    p.line(to:NSPoint(x:cx+botW/2,y:baseY))
    p.close(); p.fill()
    // round the bottom a touch
    NSBezierPath(ovalIn:NSRect(x:cx-botW/2,y:baseY-botW*0.12,width:botW,height:botW*0.24)).fill()
}
func driveBase(_ s:CGFloat,_ cx:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat){
    NSBezierPath(roundedRect:NSRect(x:cx-w/2,y:y,width:w,height:h), xRadius:h*0.42, yRadius:h*0.42).fill()
    let led=s*0.12
    let ctx=NSGraphicsContext.current!; ctx.saveGraphicsState(); ctx.compositingOperation = .destinationOut
    NSBezierPath(ovalIn:NSRect(x:cx+w*0.30-led/2,y:y+h*0.5-led/2,width:led,height:led)).fill()
    ctx.restoreGraphicsState()
}
// swirling activity arc (open ring) around center
func arc(_ cx:CGFloat,_ cy:CGFloat,_ r:CGFloat,_ lw:CGFloat,_ start:CGFloat,_ end:CGFloat){
    let p=NSBezierPath(); p.lineWidth=lw; p.lineCapStyle = .round
    p.appendArc(withCenter:NSPoint(x:cx,y:cy), radius:r, startAngle:start, endAngle:end)
    p.stroke()
}

func draw(_ v:Int,_ s:CGFloat){
    ink.setFill(); ink.setStroke()
    switch v {
    // V1: mug on drive + 2 side activity arcs (closest to reference)
    case 0:
        let cx=s*0.46
        driveBase(s,cx,s*0.10,s*0.78,s*0.26)
        mug(cx, s*0.40, s*0.34, s*0.30, s*0.30)
        // handle
        let hd=NSBezierPath(); hd.lineWidth=s*0.055
        hd.appendArc(withCenter:NSPoint(x:cx+s*0.20,y:s*0.55), radius:s*0.085, startAngle:-80, endAngle:80); hd.stroke()
        // 2 steam wisps
        for i in 0..<2 { wisp(cx+CGFloat(i)*s*0.14 - s*0.07, s*0.72, s*0.20, s*0.038, s*0.06) }
        // activity arcs left & right around the cup
        arc(cx, s*0.55, s*0.40, s*0.05, 130, 210)
        arc(cx, s*0.55, s*0.40, s*0.05, -30, 50)

    // V2: same but NO arcs (cleaner) — taller mug, curlier steam
    case 1:
        let cx=s*0.46
        driveBase(s,cx,s*0.10,s*0.80,s*0.27)
        mug(cx, s*0.42, s*0.36, s*0.30, s*0.32)
        let hd=NSBezierPath(); hd.lineWidth=s*0.06
        hd.appendArc(withCenter:NSPoint(x:cx+s*0.21,y:s*0.58), radius:s*0.09, startAngle:-80, endAngle:80); hd.stroke()
        for i in 0..<3 { wisp(cx+CGFloat(i-1)*s*0.13, s*0.76, s*0.20, s*0.04, s*0.07) }

    // V3: mug + ONE wrapping arc underneath (single activity sweep, less busy)
    case 2:
        let cx=s*0.46
        driveBase(s,cx,s*0.10,s*0.80,s*0.27)
        mug(cx, s*0.42, s*0.36, s*0.30, s*0.30)
        let hd=NSBezierPath(); hd.lineWidth=s*0.06
        hd.appendArc(withCenter:NSPoint(x:cx+s*0.21,y:s*0.57), radius:s*0.09, startAngle:-80, endAngle:80); hd.stroke()
        for i in 0..<2 { wisp(cx+CGFloat(i)*s*0.13 - s*0.065, s*0.74, s*0.18, s*0.04, s*0.06) }
        // one wide activity arc hugging the cup bottom
        arc(cx, s*0.50, s*0.46, s*0.055, 200, 340)
    default: break
    }
}
func render(_ v:Int,_ px:Int,_ bg:NSColor?,_ name:String){
    let s=CGFloat(px); let img=NSImage(size:NSSize(width:s,height:s)); img.lockFocus()
    if let bg=bg { bg.setFill(); NSBezierPath(rect:NSRect(x:0,y:0,width:s,height:s)).fill() }
    draw(v,s); img.unlockFocus()
    if let t=img.tiffRepresentation,let r=NSBitmapImageRep(data:t),let p=r.representation(using:.png,properties:[:]){
        try? p.write(to:URL(fileURLWithPath:name)) }
}
for v in 0..<3 { render(v,512,.white,"ref\(v+1)-big.png"); render(v,36,NSColor(white:0.90,alpha:1),"ref\(v+1)-bar.png") }
print("rendered ref1-3")
