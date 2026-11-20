import AppKit
let size: CGFloat = 1024
let image = NSImage(size: NSSize(width:size,height:size))
image.lockFocus()
let bg=NSBezierPath(roundedRect:NSRect(x:32,y:32,width:960,height:960),xRadius:220,yRadius:220)
NSColor(calibratedRed:0.09,green:0.12,blue:0.19,alpha:1).setFill(); bg.fill()
let body=NSBezierPath(roundedRect:NSRect(x:175,y:230,width:674,height:465),xRadius:45,yRadius:45)
NSColor(calibratedRed:0.96,green:0.97,blue:1,alpha:1).setFill(); body.fill()
let panel=NSBezierPath(roundedRect:NSRect(x:209,y:266,width:606,height:300),xRadius:20,yRadius:20)
NSColor(calibratedRed:0.17,green:0.22,blue:0.32,alpha:1).setFill(); panel.fill()
NSColor(calibratedRed:0.43,green:0.66,blue:1,alpha:1).setFill()
NSBezierPath(roundedRect:NSRect(x:263,y:463,width:390,height:18),xRadius:9,yRadius:9).fill()
NSBezierPath(roundedRect:NSRect(x:263,y:390,width:320,height:18),xRadius:9,yRadius:9).fill()
NSBezierPath(roundedRect:NSRect(x:263,y:317,width:365,height:18),xRadius:9,yRadius:9).fill()
let bar=NSBezierPath(roundedRect:NSRect(x:175,y:608,width:674,height:87),xRadius:10,yRadius:10)
NSColor(calibratedRed:0.08,green:0.11,blue:0.17,alpha:1).setFill();bar.fill()
NSGraphicsContext.saveGraphicsState(); bar.addClip(); NSColor.white.setFill()
for x in stride(from:150,through:850,by:175) { let p=NSBezierPath();p.move(to:NSPoint(x:x,y:608));p.line(to:NSPoint(x:x+67,y:608));p.line(to:NSPoint(x:x+127,y:695));p.line(to:NSPoint(x:x+60,y:695));p.close();p.fill() }
NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.saveGraphicsState()
let t=NSAffineTransform(); t.translateX(by:185,yBy:705); t.rotate(byDegrees:12); t.concat()
let lid=NSBezierPath(roundedRect:NSRect(x:0,y:0,width:680,height:92),xRadius:12,yRadius:12)
NSColor(calibratedRed:0.96,green:0.97,blue:1,alpha:1).setFill();lid.fill();lid.addClip()
NSColor(calibratedRed:0.08,green:0.11,blue:0.17,alpha:1).setFill()
for x in stride(from:-50,through:700,by:175) { let p=NSBezierPath();p.move(to:NSPoint(x:x,y:0));p.line(to:NSPoint(x:x+70,y:0));p.line(to:NSPoint(x:x+135,y:92));p.line(to:NSPoint(x:x+65,y:92));p.close();p.fill() }
NSGraphicsContext.restoreGraphicsState()
image.unlockFocus()
let bitmap=NSBitmapImageRep(data:image.tiffRepresentation!)!
let png=bitmap.representation(using:.png,properties:[:])!
try png.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
