import AppKit
let ink=NSColor.black, white=NSColor.white
func rr(_ r:NSRect,_ rad:CGFloat)->NSBezierPath{ NSBezierPath(roundedRect:r,xRadius:rad,yRadius:rad) }
func wisp(_ x:CGFloat,_ y0:CGFloat,_ h:CGFloat,_ lw:CGFloat,_ amp:CGFloat){
    let p=NSBezierPath(); p.lineWidth=lw; p.lineCapStyle = .round
    p.move(to:NSPoint(x:x,y:y0))
    p.curve(to:NSPoint(x:x,y:y0+h),controlPoint1:NSPoint(x:x-amp,y:y0+h*0.33),controlPoint2:NSPoint(x:x+amp,y:y0+h*0.66))
    p.stroke()
}
// Final icon: cup(no dot)+handle on a drive base with 1.4x LED. Template image:
// black shapes on TRANSPARENT bg (macOS tints for light/dark menu bars).
func draw(_ s:CGFloat){
    ink.setFill(); ink.setStroke()
    let dw=s*0.74, dh=s*0.22, dx=(s-dw)/2, dy=s*0.12
    rr(NSRect(x:dx,y:dy,width:dw,height:dh), s*0.05).fill()
    // LED knocked out — but on transparent template we must DRAW the hole as
    // clear. Simplest: draw base, then clear the LED via destinationOut.
    let led=s*0.07*1.4
    let ctx=NSGraphicsContext.current!; ctx.saveGraphicsState()
    ctx.compositingOperation = .destinationOut
    NSBezierPath(ovalIn:NSRect(x:dx+dw*0.84-led/2,y:dy+dh*0.5-led/2,width:led,height:led)).fill()
    ctx.restoreGraphicsState()
    // cup
    let cw=s*0.40, ch=s*0.28, cx=(s-cw)/2, cy=dy+dh+s*0.06
    rr(NSRect(x:cx,y:cy,width:cw,height:ch), s*0.04).fill()
    let handle=NSBezierPath(); handle.lineWidth=s*0.05
    handle.appendArc(withCenter:NSPoint(x:cx+cw+s*0.005,y:cy+ch*0.5), radius:s*0.085, startAngle:-78, endAngle:78); handle.stroke()
    let gap=s*0.06
    for i in 0..<3 { wisp(cx+cw*0.5+CGFloat(i-1)*cw*0.30, cy+ch+gap, s*0.20, s*0.03, s*0.045) }
}
func renderTemplate(_ px:Int,_ path:String){
    let s=CGFloat(px)
    let img=NSImage(size:NSSize(width:s,height:s)); img.lockFocus()
    // transparent background — do NOT fill
    draw(s); img.unlockFocus()
    if let t=img.tiffRepresentation,let r=NSBitmapImageRep(data:t),let p=r.representation(using:.png,properties:[:]){
        try? p.write(to:URL(fileURLWithPath:path)) }
}
let dir="../../Sources/DriveCaffeineApp/Resources"
renderTemplate(18,"\(dir)/MenuIcon.png")     // @1x
renderTemplate(36,"\(dir)/MenuIcon@2x.png")  // @2x
renderTemplate(54,"\(dir)/MenuIcon@3x.png")  // @3x
print("wrote MenuIcon template PNGs")
