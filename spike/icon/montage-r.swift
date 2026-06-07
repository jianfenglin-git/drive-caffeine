import AppKit
let OUT=FileManager.default.currentDirectoryPath
let W:CGFloat=900, H:CGFloat=560
let img=NSImage(size:NSSize(width:W,height:H)); img.lockFocus()
NSColor.white.setFill(); NSBezierPath(rect:NSRect(x:0,y:0,width:W,height:H)).fill()
let names=["r1: bean+big LED (your edit)","r2: cup+handle, bean+LED","r3: cup+handle, LED only","r4: wide drive, big LED only"]
for i in 0..<4 {
    let c=i%2, r=i/2
    let x=40+CGFloat(c)*440, yTop=H-40-CGFloat(r)*270
    // big
    if let v=NSImage(contentsOfFile:"\(OUT)/r\(i+1)-big.png"){ v.draw(in:NSRect(x:x,y:yTop-200,width:200,height:200)) }
    // actual 18px next to it on gray
    NSColor(white:0.90,alpha:1).setFill(); NSBezierPath(rect:NSRect(x:x+220,y:yTop-120,width:60,height:60)).fill()
    if let v=NSImage(contentsOfFile:"\(OUT)/r\(i+1)-bar.png"){ v.draw(in:NSRect(x:x+241,y:yTop-99,width:18,height:18)) }
    (names[i] as NSString).draw(at:NSPoint(x:x,y:yTop-230), withAttributes:[.font:NSFont.boldSystemFont(ofSize:16),.foregroundColor:NSColor.black])
    ("18px" as NSString).draw(at:NSPoint(x:x+232,y:yTop-145), withAttributes:[.font:NSFont.systemFont(ofSize:11),.foregroundColor:NSColor.gray])
}
img.unlockFocus()
if let t=img.tiffRepresentation,let rr=NSBitmapImageRep(data:t),let p=rr.representation(using:.png,properties:[:]){
    try? p.write(to:URL(fileURLWithPath:"\(OUT)/contact-refine.png")); print("wrote contact-refine.png") }
