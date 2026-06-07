import AppKit
let O=FileManager.default.currentDirectoryPath
let img=NSImage(size:NSSize(width:520,height:340)); img.lockFocus()
NSColor.white.setFill(); NSBezierPath(rect:NSRect(x:0,y:0,width:520,height:340)).fill()
if let v=NSImage(contentsOfFile:"\(O)/bigger-big.png"){ v.draw(in:NSRect(x:30,y:60,width:240,height:240)) }
// 18px and 22px actual sizes on gray
for (i,px) in [18,22,28].enumerated(){
    let x=CGFloat(310+i*70)
    NSColor(white:0.90,alpha:1).setFill(); NSBezierPath(rect:NSRect(x:x-6,y:180,width:CGFloat(px)+12,height:CGFloat(px)+12)).fill()
    if let v=NSImage(contentsOfFile:"\(O)/bigger-bar.png"){ v.draw(in:NSRect(x:x,y:186,width:CGFloat(px),height:CGFloat(px))) }
    ("\(px)px" as NSString).draw(at:NSPoint(x:x,y:150),withAttributes:[.font:NSFont.systemFont(ofSize:11),.foregroundColor:NSColor.gray])
}
("filled-frame, bigger cup, thicker drive, curvier wisps" as NSString).draw(at:NSPoint(x:30,y:20),withAttributes:[.font:NSFont.boldSystemFont(ofSize:15),.foregroundColor:NSColor.black])
img.unlockFocus()
if let t=img.tiffRepresentation,let r=NSBitmapImageRep(data:t),let p=r.representation(using:.png,properties:[:]){ try? p.write(to:URL(fileURLWithPath:"\(O)/bigger-contact.png")); print("ok") }
