import AppKit
let ink=NSColor.black
func wisp(_ x:CGFloat,_ y0:CGFloat,_ h:CGFloat,_ lw:CGFloat,_ amp:CGFloat){
    let p=NSBezierPath(); p.lineWidth=lw; p.lineCapStyle = .round
    p.move(to:NSPoint(x:x,y:y0))
    p.curve(to:NSPoint(x:x,y:y0+h),controlPoint1:NSPoint(x:x-amp,y:y0+h*0.28),controlPoint2:NSPoint(x:x+amp,y:y0+h*0.72))
    p.stroke()
}
func mug(_ cx:CGFloat,_ baseY:CGFloat,_ topW:CGFloat,_ botW:CGFloat,_ h:CGFloat){
    let p=NSBezierPath()
    p.move(to:NSPoint(x:cx-botW/2,y:baseY)); p.line(to:NSPoint(x:cx-topW/2,y:baseY+h))
    p.line(to:NSPoint(x:cx+topW/2,y:baseY+h)); p.line(to:NSPoint(x:cx+botW/2,y:baseY)); p.close(); p.fill()
    NSBezierPath(ovalIn:NSRect(x:cx-botW/2,y:baseY-botW*0.12,width:botW,height:botW*0.24)).fill()
}
// gapMul controls how far above the rim the steam starts; steamH its length.
func draw(_ s:CGFloat,_ gapMul:CGFloat,_ steamH:CGFloat){
    ink.setFill(); ink.setStroke()
    let cx=s*0.46
    let w=s*0.80, h=s*0.27, y=s*0.10
    NSBezierPath(roundedRect:NSRect(x:cx-w/2,y:y,width:w,height:h), xRadius:h*0.45, yRadius:h*0.45).fill()
    let led=s*0.12
    let ctx=NSGraphicsContext.current!; ctx.saveGraphicsState(); ctx.compositingOperation = .destinationOut
    NSBezierPath(ovalIn:NSRect(x:cx+w*0.30-led/2,y:y+h*0.5-led/2,width:led,height:led)).fill()
    ctx.restoreGraphicsState()
    let mugTop = s*0.42 + s*0.32
    mug(cx, s*0.42, s*0.36, s*0.30, s*0.32)
    let hd=NSBezierPath(); hd.lineWidth=s*0.06
    hd.appendArc(withCenter:NSPoint(x:cx+s*0.21,y:s*0.58), radius:s*0.09, startAngle:-80, endAngle:80); hd.stroke()
    // steam starts ABOVE the rim by gapMul, shorter, so it floats (not rooted)
    for i in 0..<3 { wisp(cx+CGFloat(i-1)*s*0.13, mugTop + s*gapMul, s*steamH, s*0.04, s*0.06) }
}
func render(_ px:Int,_ bg:NSColor?,_ gap:CGFloat,_ sh:CGFloat,_ name:String){
    let s=CGFloat(px); let img=NSImage(size:NSSize(width:s,height:s)); img.lockFocus()
    if let bg=bg { bg.setFill(); NSBezierPath(rect:NSRect(x:0,y:0,width:s,height:s)).fill() }
    draw(s,gap,sh); img.unlockFocus()
    if let t=img.tiffRepresentation,let r=NSBitmapImageRep(data:t),let p=r.representation(using:.png,properties:[:]){
        try? p.write(to:URL(fileURLWithPath:name)) }
}
// A: small gap, B: bigger gap + shorter (floatier)
render(512,.white,0.06,0.16,"steam-a-big.png"); render(36,NSColor(white:0.90,alpha:1),0.06,0.16,"steam-a-bar.png")
render(512,.white,0.10,0.14,"steam-b-big.png"); render(36,NSColor(white:0.90,alpha:1),0.10,0.14,"steam-b-bar.png")
print("rendered steam a/b")
