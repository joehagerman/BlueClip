import AppKit
import CoreGraphics

func createIconImage(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        img.unlockFocus()
        return img
    }
    
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    
    // Draw Squircle Background
    let cornerRadius = size * 0.224
    let squircleRect = rect.insetBy(dx: size * 0.05, dy: size * 0.05)
    let squirclePath = NSBezierPath(roundedRect: squircleRect, xRadius: cornerRadius, yRadius: cornerRadius)
    
    ctx.saveGState()
    squirclePath.addClip()
    
    // Vibrant Blue Gradient
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let startColor = CGColor(red: 0.08, green: 0.50, blue: 0.98, alpha: 1.0) // Bright Azure Blue
    let midColor = CGColor(red: 0.02, green: 0.35, blue: 0.88, alpha: 1.0)   // Deep Cobalt Blue
    let endColor = CGColor(red: 0.01, green: 0.22, blue: 0.65, alpha: 1.0)   // Rich Sapphire
    let locations: [CGFloat] = [0.0, 0.55, 1.0]
    
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: [startColor, midColor, endColor] as CFArray, locations: locations) {
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
    }
    
    // Subtle top inner gloss
    let glossPath = NSBezierPath(ovalIn: CGRect(x: size * 0.1, y: size * 0.5, width: size * 0.8, height: size * 0.45))
    ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.12))
    ctx.addPath(glossPath.cgPath)
    ctx.fillPath()
    
    ctx.restoreGState()
    
    // Squircle border
    ctx.saveGState()
    let borderPath = NSBezierPath(roundedRect: squircleRect, xRadius: cornerRadius, yRadius: cornerRadius)
    borderPath.lineWidth = size * 0.015
    NSColor(white: 1.0, alpha: 0.25).setStroke()
    borderPath.stroke()
    ctx.restoreGState()
    
    // Draw Silver/Chrome Paperclip
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.03), blur: size * 0.04, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.4))
    
    let scale = size / 512.0
    ctx.translateBy(x: size * 0.5, y: size * 0.5)
    ctx.rotate(by: -CGFloat.pi / 4.0) // 45 degree tilt
    
    let wireWidth: CGFloat = 36.0 * scale
    let outerW: CGFloat = 130.0 * scale
    let outerH: CGFloat = 260.0 * scale
    
    let clipPath = CGMutablePath()
    // Paperclip outer loop
    let r1 = outerW / 2.0
    let r2 = (outerW - wireWidth * 1.5) / 2.0
    let r3 = (outerW - wireWidth * 3.0) / 2.0
    
    // Start at bottom right loop
    let xRight = r1
    let xLeft = -r1
    let yTop = outerH / 2.0
    let yBottom = -outerH / 2.0
    
    clipPath.move(to: CGPoint(x: xRight, y: yBottom + r1))
    clipPath.addLine(to: CGPoint(x: xRight, y: yTop - r1))
    clipPath.addArc(center: CGPoint(x: 0, y: yTop - r1), radius: r1, startAngle: 0, endAngle: CGFloat.pi, clockwise: false)
    clipPath.addLine(to: CGPoint(x: xLeft, y: yBottom + r1))
    clipPath.addArc(center: CGPoint(x: xLeft + r2, y: yBottom + r1), radius: r2, startAngle: CGFloat.pi, endAngle: 0, clockwise: true)
    clipPath.addLine(to: CGPoint(x: xLeft + r2 * 2, y: yTop - r1 - 20 * scale))
    clipPath.addArc(center: CGPoint(x: xLeft + r2 * 2 + r3, y: yTop - r1 - 20 * scale), radius: r3, startAngle: CGFloat.pi, endAngle: 0, clockwise: true)
    clipPath.addLine(to: CGPoint(x: xLeft + r2 * 2 + r3 * 2, y: yBottom + r1 + 30 * scale))
    
    ctx.addPath(clipPath)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.setLineWidth(wireWidth)
    
    // Metallic chrome gradient stroke simulation
    ctx.setStrokeColor(CGColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 0.95))
    ctx.strokePath()
    
    // Highlight inner stroke
    ctx.addPath(clipPath)
    ctx.setLineWidth(wireWidth * 0.35)
    ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.8))
    ctx.strokePath()
    
    ctx.restoreGState()
    
    img.unlockFocus()
    return img
}

func createMenuBarIcon(size: CGFloat = 22, isTemplate: Bool = true, isBlue: Bool = false) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        img.unlockFocus()
        return img
    }
    
    let scale = size / 22.0
    ctx.translateBy(x: size * 0.5, y: size * 0.5)
    ctx.rotate(by: -CGFloat.pi / 4.0)
    
    let wireWidth: CGFloat = 2.2 * scale
    let outerW: CGFloat = 8.0 * scale
    let outerH: CGFloat = 16.0 * scale
    
    let r1 = outerW / 2.0
    let r2 = (outerW - wireWidth * 1.3) / 2.0
    let r3 = (outerW - wireWidth * 2.6) / 2.0
    
    let yTop = outerH / 2.0
    let yBottom = -outerH / 2.0
    
    let clipPath = CGMutablePath()
    clipPath.move(to: CGPoint(x: r1, y: yBottom + r1))
    clipPath.addLine(to: CGPoint(x: r1, y: yTop - r1))
    clipPath.addArc(center: CGPoint(x: 0, y: yTop - r1), radius: r1, startAngle: 0, endAngle: CGFloat.pi, clockwise: false)
    clipPath.addLine(to: CGPoint(x: -r1, y: yBottom + r1))
    clipPath.addArc(center: CGPoint(x: -r1 + r2, y: yBottom + r1), radius: r2, startAngle: CGFloat.pi, endAngle: 0, clockwise: true)
    clipPath.addLine(to: CGPoint(x: -r1 + r2 * 2, y: yTop - r1 - 1.5 * scale))
    clipPath.addArc(center: CGPoint(x: -r1 + r2 * 2 + r3, y: yTop - r1 - 1.5 * scale), radius: r3, startAngle: CGFloat.pi, endAngle: 0, clockwise: true)
    clipPath.addLine(to: CGPoint(x: -r1 + r2 * 2 + r3 * 2, y: yBottom + r1 + 2.0 * scale))
    
    ctx.addPath(clipPath)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.setLineWidth(wireWidth)
    
    if isBlue {
        ctx.setStrokeColor(CGColor(red: 0.08, green: 0.50, blue: 0.98, alpha: 1.0))
    } else {
        ctx.setStrokeColor(CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0))
    }
    ctx.strokePath()
    
    img.unlockFocus()
    img.isTemplate = isTemplate && !isBlue
    return img
}

func savePNG(image: NSImage, path: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        print("Failed to encode PNG for \(path)")
        return
    }
    try? png.write(to: URL(fileURLWithPath: path))
    print("Saved \(path)")
}

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0])
let resDir = scriptURL.deletingLastPathComponent().path
let iconSetDir = "\(resDir)/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconSetDir, withIntermediateDirectories: true)

// Generate Iconset sizes
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
    let img = createIconImage(size: sz)
    savePNG(image: img, path: "\(iconSetDir)/\(name)")
}

// Save main 1024x1024 AppIcon.png
let fullImg = createIconImage(size: 1024)
savePNG(image: fullImg, path: "\(resDir)/AppIcon.png")

// Menu Bar Icons
let menu1x = createMenuBarIcon(size: 18, isTemplate: true)
savePNG(image: menu1x, path: "\(resDir)/MenuBarIcon.png")
let menu2x = createMenuBarIcon(size: 36, isTemplate: true)
savePNG(image: menu2x, path: "\(resDir)/MenuBarIcon@2x.png")

let menuBlue1x = createMenuBarIcon(size: 18, isTemplate: false, isBlue: true)
savePNG(image: menuBlue1x, path: "\(resDir)/MenuBarIconBlue.png")
let menuBlue2x = createMenuBarIcon(size: 36, isTemplate: false, isBlue: true)
savePNG(image: menuBlue2x, path: "\(resDir)/MenuBarIconBlue@2x.png")

print("Icon asset generation complete.")
