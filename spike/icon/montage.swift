import AppKit
let OUT = FileManager.default.currentDirectoryPath
let cols = 5, rows = 2, cell: CGFloat = 220, pad: CGFloat = 12, label: CGFloat = 26
let W = CGFloat(cols)*cell + CGFloat(cols+1)*pad
let H = CGFloat(rows)*(cell+label) + CGFloat(rows+1)*pad
let img = NSImage(size: NSSize(width: W, height: H)); img.lockFocus()
NSColor.white.setFill(); NSBezierPath(rect: NSRect(x:0,y:0,width:W,height:H)).fill()
for i in 0..<10 {
    let r = i / cols, c = i % cols
    let x = pad + CGFloat(c)*(cell+pad)
    let y = H - (pad + CGFloat(r)*(cell+label+pad) + cell)
    if let v = NSImage(contentsOfFile: "\(OUT)/v\(i+1)-big.png") {
        v.draw(in: NSRect(x:x, y:y, width:cell, height:cell))
    }
    let s = "v\(i+1)" as NSString
    s.draw(at: NSPoint(x:x+cell/2-10, y:y-20),
           withAttributes:[.font:NSFont.boldSystemFont(ofSize:18), .foregroundColor:NSColor.black])
}
img.unlockFocus()
if let tiff=img.tiffRepresentation, let rep=NSBitmapImageRep(data:tiff),
   let png=rep.representation(using:.png, properties:[:]) {
    try? png.write(to: URL(fileURLWithPath: "\(OUT)/contact.png")); print("wrote contact.png")
}
