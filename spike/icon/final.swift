import AppKit
let OUT=FileManager.default.currentDirectoryPath
let ink=NSColor.black, white=NSColor.white
func rr(_ r:NSRect,_ rad:CGFloat)->NSBezierPath{ NSBezierPath(roundedRect:r,xRadius:rad,yRadius:rad) }
func wisp(_ x:CGFloat,_ y0:CGFloat,_ h:CGFloat,_ lw:CGFloat,_ amp:CGFloat){
    let p=NSBezierPath(); p.lineWidth=lw; p.lineCapStyle = .round
    p.move(to:NSPoint(x:x,y:y0))
    p.curve(to:NSPoint(x:x,y:y0+h),controlPoint1:NSPoint(x:x-amp,y:y0+h*0.33),controlPoint2:NSPoint(x:x+amp,y:y0+h*0.66))
    p.stroke()
}
// v5 + r3 combined: clean coffee cup (handle, NO dot inside) stacked on a drive
// base that has a bigger LED. `ledScale` lets us compare LED sizes.
func draw(_ ledScale:CGFloat,_ s:CGFloat){
    ink.setFill(); ink.setStroke()
    // drive base (bottom)
    let dw=s*0.74, dh=s*0.22, dx=(s-dw)/2, dy=s*0.12
    rr(NSRect(x:dx,y:dy,width:dw,height:dh), s*0.05).fill()
    // bigger LED on the base (right side), knocked out white
    let led=s*0.07*ledScale
    white.setFill(); NSBezierPath(ovalIn:NSRect(x:dx+dw*0.84-led/2,y:dy+dh*0.5-led/2,width:led,height:led)).fill()
    ink.setFill()
    // coffee cup on top (clean: body + handle, NO dot inside)
    let cw=s*0.40, ch=s*0.28, cx=(s-cw)/2, cy=dy+dh+s*0.06
    rr(NSRect(x:cx,y:cy,width:cw,height:ch), s*0.04).fill()
    let handle=NSBezierPath(); handle.lineWidth=s*0.05
    handle.appendArc(withCenter:NSPoint(x:cx+cw+s*0.005,y:cy+ch*0.5), radius:s*0.085, startAngle:-78, endAngle:78); handle.stroke()
    // 3 thin steam wisps, raised a bit above the cup
    let gap=s*0.06
    for i in 0..<3 { wisp(cx+cw*0.5+CGFloat(i-1)*cw*0.30, cy+ch+gap, s*0.20, s*0.03, s*0.045) }
}
func render(_ led:CGFloat,_ size:CGFloat,_ bg:NSColor,_ name:String){
    let img=NSImage(size:NSSize(width:size,height:size)); img.lockFocus()
    bg.setFill(); NSBezierPath(rect:NSRect(x:0,y:0,width:size,height:size)).fill()
    draw(led,size); img.unlockFocus()
    if let t=img.tiffRepresentation,let r=NSBitmapImageRep(data:t),let p=r.representation(using:.png,properties:[:]){
        try? p.write(to:URL(fileURLWithPath:"\(OUT)/\(name).png")) }
}
// two LED sizes to compare
render(1.4,512,.white,"final-a-big"); render(1.4,36,NSColor(white:0.90,alpha:1),"final-a-bar")
render(1.9,512,.white,"final-b-big"); render(1.9,36,NSColor(white:0.90,alpha:1),"final-b-bar")
print("rendered final a (LED 1.4x) and b (LED 1.9x)")
