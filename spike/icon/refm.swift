import AppKit
let O=FileManager.default.currentDirectoryPath
let img=NSImage(size:NSSize(width:900,height:420)); img.lockFocus()
NSColor.white.setFill(); NSBezierPath(rect:NSRect(x:0,y:0,width:900,height:420)).fill()
let names=["V1: mug+drive+2 arcs (closest to ref)","V2: mug+drive, no arcs (clean)","V3: mug+drive+1 sweep arc"]
for i in 0..<3 {
    let x=CGFloat(30+i*300)
    if let v=NSImage(contentsOfFile:"\(O)/ref\(i+1)-big.png"){ v.draw(in:NSRect(x:x,y:170,width:170,height:170)) }
    NSColor(white:0.90,alpha:1).setFill(); NSBezierPath(rect:NSRect(x:x+185,y:240,width:48,height:48)).fill()
    if let v=NSImage(contentsOfFile:"\(O)/ref\(i+1)-bar.png"){ v.draw(in:NSRect(x:x+200,y:255,width:18,height:18)) }
    (names[i] as NSString).draw(at:NSPoint(x:x,y:140),withAttributes:[.font:NSFont.boldSystemFont(ofSize:12),.foregroundColor:NSColor.black])
    ("18px" as NSString).draw(at:NSPoint(x:x+190,y:215),withAttributes:[.font:NSFont.systemFont(ofSize:10),.foregroundColor:NSColor.gray])
}
img.unlockFocus()
if let t=img.tiffRepresentation,let r=NSBitmapImageRep(data:t),let p=r.representation(using:.png,properties:[:]){ try? p.write(to:URL(fileURLWithPath:"\(O)/ref-contact.png")); print("ok") }
