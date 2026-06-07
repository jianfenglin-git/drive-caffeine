import AppKit
let OUT = FileManager.default.currentDirectoryPath
// Show each 36px bar-render at 2 sizes: actual 18pt (tiny, the real test) and a
// 4x zoom so detail is visible. Lay out 10 rows: [zoom]  [actual]  label.
let rowH: CGFloat = 80, zoom: CGFloat = 72, actual: CGFloat = 18
let W: CGFloat = 520, H = rowH*10 + 40
let img = NSImage(size: NSSize(width:W,height:H)); img.lockFocus()
// menu-bar-ish light gray background
NSColor(white:0.90, alpha:1).setFill(); NSBezierPath(rect:NSRect(x:0,y:0,width:W,height:H)).fill()
let attrs: [NSAttributedString.Key:Any] = [.font:NSFont.boldSystemFont(ofSize:15), .foregroundColor:NSColor.black]
for i in 0..<10 {
    let y = H - 30 - CGFloat(i)*rowH
    guard let v = NSImage(contentsOfFile:"\(OUT)/v\(i+1)-bar.png") else { continue }
    // zoomed (to see detail)
    v.draw(in: NSRect(x:40, y:y-zoom+10, width:zoom, height:zoom))
    // actual menu-bar size
    v.draw(in: NSRect(x:200, y:y-actual-10, width:actual, height:actual))
    ("v\(i+1)" as NSString).draw(at: NSPoint(x:300, y:y-zoom*0.5), withAttributes: attrs)
}
("← 4x zoom            ↑ actual 18px size" as NSString).draw(at: NSPoint(x:40, y:H-26),
    withAttributes:[.font:NSFont.systemFont(ofSize:13), .foregroundColor:NSColor.darkGray])
img.unlockFocus()
if let t=img.tiffRepresentation, let r=NSBitmapImageRep(data:t), let p=r.representation(using:.png,properties:[:]) {
    try? p.write(to:URL(fileURLWithPath:"\(OUT)/contact-bar.png")); print("wrote contact-bar.png")
}
