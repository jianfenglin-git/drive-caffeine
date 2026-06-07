import AppKit
let O=FileManager.default.currentDirectoryPath
let img=NSImage(size:NSSize(width:680,height:360)); img.lockFocus()
NSColor.white.setFill(); NSBezierPath(rect:NSRect(x:0,y:0,width:680,height:360)).fill()
for (i,t) in [("steam-a","A: small gap"),("steam-b","B: bigger gap, floatier")].enumerated(){
    let x=CGFloat(40+i*340)
    if let v=NSImage(contentsOfFile:"\(O)/\(t.0)-big.png"){ v.draw(in:NSRect(x:x,y:120,width:200,height:200)) }
    NSColor(white:0.90,alpha:1).setFill(); NSBezierPath(rect:NSRect(x:x+210,y:200,width:48,height:48)).fill()
    if let v=NSImage(contentsOfFile:"\(O)/\(t.0)-bar.png"){ v.draw(in:NSRect(x:x+225,y:215,width:18,height:18)) }
    (t.1 as NSString).draw(at:NSPoint(x:x,y:90),withAttributes:[.font:NSFont.boldSystemFont(ofSize:15),.foregroundColor:NSColor.black])
}
img.unlockFocus()
if let t=img.tiffRepresentation,let r=NSBitmapImageRep(data:t),let p=r.representation(using:.png,properties:[:]){ try? p.write(to:URL(fileURLWithPath:"\(O)/steam-contact.png")); print("ok") }
