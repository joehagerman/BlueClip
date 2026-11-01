import AppKit
import CoreGraphics

func createBluePushpinImage(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        img.unlockFocus()
        return img
    }
    
    let scale = size / 512.0
    
    // Background Squircle for macOS App Icon
    if size >= 64 {
        let cornerRadius = size * 0.224
        let squircleRect = CGRect(x: size * 0.05, y: size * 0.05, width: size * 0.9, height: size * 0.9)
        let squirclePath = NSBezierPath(roundedRect: squircleRect, xRadius: cornerRadius, yRadius: cornerRadius)
        
        ctx.saveGState()
        squirclePath.addClip()
        
        // Soft Slate / Dark Gradient Background so the Blue Pushpin pops brilliantly
        let bgSpace = CGColorSpaceCreateDeviceRGB()
        let bgColors = [
            CGColor(red: 0.12, green: 0.15, blue: 0.22, alpha: 1.0),
            CGColor(red: 0.06, green: 0.08, blue: 0.13, alpha: 1.0)
        ] as CFArray
        if let bgGrad = CGGradient(colorsSpace: bgSpace, colors: bgColors, locations: [0.0, 1.0]) {
            ctx.drawLinearGradient(bgGrad, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
        }
        ctx.restoreGState()
        
        // Subtle border
        ctx.saveGState()
        let borderPath = NSBezierPath(roundedRect: squircleRect, xRadius: cornerRadius, yRadius: cornerRadius)
        borderPath.lineWidth = size * 0.015
        NSColor(white: 1.0, alpha: 0.15).setStroke()
        borderPath.stroke()
        ctx.restoreGState()
    }
    
    // Draw Blue Pushpin at Center
    ctx.saveGState()
    ctx.translateBy(x: size * 0.5, y: size * 0.5)
    ctx.rotate(by: -CGFloat.pi / 4.0) // 45 degree tilt
    
    // Drop Shadow
    ctx.setShadow(offset: CGSize(width: -size * 0.04, height: -size * 0.04), blur: size * 0.06, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.5))
    
    // 1. Metal Needle (Point at bottom)
    let needlePath = CGMutablePath()
    let needleW: CGFloat = 16.0 * scale
    let needleH: CGFloat = 140.0 * scale
    let needleBottomY: CGFloat = -180.0 * scale
    
    needlePath.move(to: CGPoint(x: -needleW / 2.0, y: needleBottomY + needleH))
    needlePath.addLine(to: CGPoint(x: needleW / 2.0, y: needleBottomY + needleH))
    needlePath.addLine(to: CGPoint(x: 0, y: needleBottomY))
    needlePath.closeSubpath()
    
    ctx.saveGState()
    ctx.addPath(needlePath)
    ctx.setFillColor(CGColor(red: 0.82, green: 0.85, blue: 0.90, alpha: 1.0))
    ctx.fillPath()
    
    // Needle highlight
    let needleHighlight = CGMutablePath()
    needleHighlight.move(to: CGPoint(x: 0, y: needleBottomY + needleH))
    needleHighlight.addLine(to: CGPoint(x: needleW / 2.0, y: needleBottomY + needleH))
    needleHighlight.addLine(to: CGPoint(x: 0, y: needleBottomY))
    needleHighlight.closeSubpath()
    ctx.addPath(needleHighlight)
    ctx.setFillColor(CGColor(red: 0.96, green: 0.98, blue: 1.0, alpha: 0.8))
    ctx.fillPath()
    ctx.restoreGState()
    
    // 2. Metallic Collar / Rim
    let collarRect = CGRect(x: -30.0 * scale, y: needleBottomY + needleH - 5.0 * scale, width: 60.0 * scale, height: 18.0 * scale)
    let collarPath = NSBezierPath(roundedRect: collarRect, xRadius: 4.0 * scale, yRadius: 4.0 * scale)
    ctx.saveGState()
    ctx.setFillColor(CGColor(red: 0.70, green: 0.74, blue: 0.80, alpha: 1.0))
    collarPath.fill()
    ctx.restoreGState()
    
    // 3. Blue Pushpin Plastic Body (Conical grip + bulbous top head)
    let bodyY = needleBottomY + needleH + 10.0 * scale
    
    // Lower waist (narrower cylinder/cone)
    let waistPath = CGMutablePath()
    let waistBottomW: CGFloat = 55.0 * scale
    let waistTopW: CGFloat = 40.0 * scale
    let waistH: CGFloat = 70.0 * scale
    
    waistPath.move(to: CGPoint(x: -waistBottomW / 2.0, y: bodyY))
    waistPath.addLine(to: CGPoint(x: -waistTopW / 2.0, y: bodyY + waistH))
    waistPath.addLine(to: CGPoint(x: waistTopW / 2.0, y: bodyY + waistH))
    waistPath.addLine(to: CGPoint(x: waistBottomW / 2.0, y: bodyY))
    waistPath.closeSubpath()
    
    ctx.saveGState()
    ctx.addPath(waistPath)
    ctx.clip()
    let waistSpace = CGColorSpaceCreateDeviceRGB()
    let blueColors = [
        CGColor(red: 0.12, green: 0.60, blue: 1.0, alpha: 1.0), // Bright Azure
        CGColor(red: 0.02, green: 0.38, blue: 0.92, alpha: 1.0), // Deep Royal Blue
        CGColor(red: 0.01, green: 0.22, blue: 0.65, alpha: 1.0)  // Rich Sapphire
    ] as CFArray
    if let blueGrad = CGGradient(colorsSpace: waistSpace, colors: blueColors, locations: [0.0, 0.5, 1.0]) {
        ctx.drawLinearGradient(blueGrad, start: CGPoint(x: -waistBottomW / 2.0, y: bodyY), end: CGPoint(x: waistBottomW / 2.0, y: bodyY), options: [])
    }
    ctx.restoreGState()
    
    // Top Bulbous Head Cap
    let capY = bodyY + waistH
    let capW: CGFloat = 110.0 * scale
    let capH: CGFloat = 90.0 * scale
    let capRect = CGRect(x: -capW / 2.0, y: capY - 10.0 * scale, width: capW, height: capH)
    let capPath = NSBezierPath(ovalIn: capRect)
    
    ctx.saveGState()
    capPath.addClip()
    let capSpace = CGColorSpaceCreateDeviceRGB()
    let capColors = [
        CGColor(red: 0.25, green: 0.70, blue: 1.0, alpha: 1.0), // Highlight Blue
        CGColor(red: 0.04, green: 0.45, blue: 0.95, alpha: 1.0), // Azure
        CGColor(red: 0.01, green: 0.25, blue: 0.70, alpha: 1.0)  // Deep Blue
    ] as CFArray
    if let capGrad = CGGradient(colorsSpace: capSpace, colors: capColors, locations: [0.0, 0.45, 1.0]) {
        ctx.drawRadialGradient(capGrad, startCenter: CGPoint(x: -capW * 0.15, y: capY + capH * 0.65), startRadius: 0, endCenter: CGPoint(x: 0, y: capY + capH * 0.4), endRadius: capW * 0.6, options: [.drawsAfterEndLocation])
    }
    
    // Gloss Highlight Spot on Cap
    let glossRect = CGRect(x: -capW * 0.25, y: capY + capH * 0.5, width: capW * 0.35, height: capH * 0.3)
    let glossPath = NSBezierPath(ovalIn: glossRect)
    ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.55))
    glossPath.fill()
    ctx.restoreGState()
    
    ctx.restoreGState()
    
    img.unlockFocus()
    return img
}

func createMenuBluePushpin(size: CGFloat = 18) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        img.unlockFocus()
        return img
    }
    
    let scale = size / 20.0
    ctx.translateBy(x: size * 0.5, y: size * 0.5)
    ctx.rotate(by: -CGFloat.pi / 4.0)
    
    // Needle
    let needle = CGMutablePath()
    needle.move(to: CGPoint(x: -1.0 * scale, y: -2.0 * scale))
    needle.addLine(to: CGPoint(x: 1.0 * scale, y: -2.0 * scale))
    needle.addLine(to: CGPoint(x: 0, y: -8.0 * scale))
    needle.closeSubpath()
    ctx.addPath(needle)
    ctx.setFillColor(CGColor(red: 0.75, green: 0.80, blue: 0.88, alpha: 1.0))
    ctx.fillPath()
    
    // Blue Head
    let head = NSBezierPath(ovalIn: CGRect(x: -4.5 * scale, y: -2.0 * scale, width: 9.0 * scale, height: 9.5 * scale))
    ctx.setFillColor(CGColor(red: 0.08, green: 0.54, blue: 1.0, alpha: 1.0))
    head.fill()
    
    // Highlight
    let hi = NSBezierPath(ovalIn: CGRect(x: -2.5 * scale, y: 2.5 * scale, width: 3.5 * scale, height: 3.5 * scale))
    ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.7))
    hi.fill()
    
    img.unlockFocus()
    img.isTemplate = false
    return img
}

func savePNG(image: NSImage, path: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: path))
}

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0])
let resDir = scriptURL.deletingLastPathComponent().path
let iconSetDir = "\(resDir)/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconSetDir, withIntermediateDirectories: true)

let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, sz) in sizes {
    let img = createBluePushpinImage(size: sz)
    savePNG(image: img, path: "\(iconSetDir)/\(name)")
}

let master = createBluePushpinImage(size: 1024)
savePNG(image: master, path: "\(resDir)/AppIcon.png")

let menuPin1x = createMenuBluePushpin(size: 18)
savePNG(image: menuPin1x, path: "\(resDir)/MenuBarIconBlue.png")
let menuPin2x = createMenuBluePushpin(size: 36)
savePNG(image: menuPin2x, path: "\(resDir)/MenuBarIconBlue@2x.png")

print("Blue Pushpin icons generated successfully.")
