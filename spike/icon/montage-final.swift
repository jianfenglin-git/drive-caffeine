import AppKit
let OUT=FileManager.default.currentDirectoryPath
let W:CGFloat=760, H:CGFloat=420
let img=NSImage(size:NSSize(width:W,height:H)); img.lockFocus()
NSColor.white.setFill(); NSBezierPath(rect:NSRect(x:0,y:0,width:W,height:H)).fill()
let items=[("final-a","LED bigger (1.4x)"),("final-b","LED biggest (1.9x)")]
for (i,it) in items.enumerated(){
    let x=40+CGFloat(i)*380
    if let v=NSImage(contentsOfFile:"\(OUT)/\(it.0)-big.png"){ v.draw(in:NSRect(x:x,y:H-300,width:240,height:240)) }
    NSColor(white:0.90,alpha:1).setFill(); NSBezierPath(rect:NSRect(x:x+250,y:H-180,width:64,height:64)).fill()
    if let v=NSImage(contentsOfFile:"\(OUT)/\(it.0)-bar.png"){ v.draw(in:NSRect(x:x+273,y:H-157,width:18,height:18)) }
    (it.1 as NSString).draw(at:NSPoint(x:x,y:H-330),withAttributes:[.font:NSFont.boldSystemFont(ofSize:17),.foregroundColor:NSColor.black])
    ("18px" as NSString).draw(at:NSPoint(x:x+262,y:H-205),withAttributes:[.font:NSFont.systemFont(ofSize:11),.foregroundColor:NSColor.gray])
}
img.unlockFocus()
if let t=img.tiffRepresentation,let r=NSBitmapImageRep(data:t),let p=r.representation(using:.png,properties:[:]){
    try? p.write(to:URL(fileURLWithPath:"\(OUT)/contact-final.png")); print("ok") }
