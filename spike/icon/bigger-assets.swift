import AppKit
let ink=NSColor.black
func rr(_ r:NSRect,_ rad:CGFloat)->NSBezierPath{ NSBezierPath(roundedRect:r,xRadius:rad,yRadius:rad) }
func wisp(_ x:CGFloat,_ y0:CGFloat,_ h:CGFloat,_ lw:CGFloat,_ amp:CGFloat){
    let p=NSBezierPath(); p.lineWidth=lw; p.lineCapStyle = .round
    p.move(to:NSPoint(x:x,y:y0))
    p.curve(to:NSPoint(x:x,y:y0+h),controlPoint1:NSPoint(x:x-amp,y:y0+h*0.30),controlPoint2:NSPoint(x:x+amp,y:y0+h*0.70))
    p.stroke()
}
func draw(_ s:CGFloat){
    ink.setFill(); ink.setStroke()
    let m=s*0.06
    let dw=s-2*m, dh=s*0.30, dx=m, dy=s*0.08
    rr(NSRect(x:dx,y:dy,width:dw,height:dh), dh*0.40).fill()
    let led=s*0.13
    let ctx=NSGraphicsContext.current!; ctx.saveGraphicsState()
    ctx.compositingOperation = .destinationOut
    NSBezierPath(ovalIn:NSRect(x:dx+dw*0.82-led/2,y:dy+dh*0.5-led/2,width:led,height:led)).fill()
    ctx.restoreGraphicsState()
    let cw=s*0.52, ch=s*0.34, cx=(s-cw)/2 - s*0.04, cy=dy+dh+s*0.05
    rr(NSRect(x:cx,y:cy,width:cw,height:ch), ch*0.28).fill()
    let handle=NSBezierPath(); handle.lineWidth=s*0.07
    handle.appendArc(withCenter:NSPoint(x:cx+cw+s*0.005,y:cy+ch*0.5), radius:s*0.11, startAngle:-80, endAngle:80); handle.stroke()
    let gap=s*0.04
    for i in 0..<3 { wisp(cx+cw*0.5+CGFloat(i-1)*cw*0.30, cy+ch+gap, s*0.22, s*0.045, s*0.075) }
}
func tmpl(_ px:Int,_ path:String){
    let s=CGFloat(px); let img=NSImage(size:NSSize(width:s,height:s)); img.lockFocus()
    draw(s); img.unlockFocus()   // transparent bg
    if let t=img.tiffRepresentation,let r=NSBitmapImageRep(data:t),let p=r.representation(using:.png,properties:[:]){
        try? p.write(to:URL(fileURLWithPath:path)) }
}
let dir="../../Sources/DriveCaffeineApp/Resources"
tmpl(18,"\(dir)/MenuIcon.png"); tmpl(36,"\(dir)/MenuIcon@2x.png"); tmpl(54,"\(dir)/MenuIcon@3x.png")
print("regenerated MenuIcon assets (bigger)")
