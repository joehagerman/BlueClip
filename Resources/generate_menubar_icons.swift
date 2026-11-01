import AppKit
import CoreGraphics

func createBadgeMenuBarIcon(size: CGFloat = 18) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        img.unlockFocus()
        return img
    }
    
    // Draw Mini Blue Squircle
    let rect = CGRect(x: 1, y: 1, width: size - 2, height: size - 2)
    let corner = size * 0.24
    let path = NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner)
    
    let colors = [
        CGColor(red: 0.12, green: 0.58, blue: 1.0, alpha: 1.0),
        CGColor(red: 0.02, green: 0.38, blue: 0.92, alpha: 1.0)
    ] as CFArray
    let space = CGColorSpaceCreateDeviceRGB()
    if let grad = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0]) {
        ctx.saveGState()
        path.addClip()
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
        ctx.restoreGState()
    }
    
    // White paperclip inside
    ctx.saveGState()
    let scale = size / 24.0
    ctx.translateBy(x: size * 0.5, y: size * 0.5)
    ctx.rotate(by: -CGFloat.pi / 4.0)
    
    let wireWidth: CGFloat = 1.8 * scale
    let outerW: CGFloat = 6.5 * scale
    let outerH: CGFloat = 13.0 * scale
    
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
    clipPath.addLine(to: CGPoint(x: -r1 + r2 * 2, y: yTop - r1 - 1.2 * scale))
    clipPath.addArc(center: CGPoint(x: -r1 + r2 * 2 + r3, y: yTop - r1 - 1.2 * scale), radius: r3, startAngle: CGFloat.pi, endAngle: 0, clockwise: true)
    clipPath.addLine(to: CGPoint(x: -r1 + r2 * 2 + r3 * 2, y: yBottom + r1 + 1.5 * scale))
    
    ctx.addPath(clipPath)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.setLineWidth(wireWidth)
    ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95))
    ctx.strokePath()
    ctx.restoreGState()
    
    img.unlockFocus()
    img.isTemplate = false
    return img
}

func createVibrantBluePaperclip(size: CGFloat = 18) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        img.unlockFocus()
        return img
    }
    
    let scale = size / 20.0
    ctx.translateBy(x: size * 0.5, y: size * 0.5)
    ctx.rotate(by: -CGFloat.pi / 4.0)
    
    let wireWidth: CGFloat = 2.4 * scale
    let outerW: CGFloat = 8.5 * scale
    let outerH: CGFloat = 16.5 * scale
    
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
    clipPath.addLine(to: CGPoint(x: -r1 + r2 * 2 + r3 * 2, y: yBottom + r1 + 1.8 * scale))
    
    ctx.addPath(clipPath)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.setLineWidth(wireWidth)
    // Azure vibrant blue
    ctx.setStrokeColor(CGColor(red: 0.05, green: 0.52, blue: 1.0, alpha: 1.0))
    ctx.strokePath()
    
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
let badge1x = createBadgeMenuBarIcon(size: 18)
savePNG(image: badge1x, path: "\(resDir)/MenuBarIconBadge.png")
let badge2x = createBadgeMenuBarIcon(size: 36)
savePNG(image: badge2x, path: "\(resDir)/MenuBarIconBadge@2x.png")

let blue1x = createVibrantBluePaperclip(size: 18)
savePNG(image: blue1x, path: "\(resDir)/MenuBarIconBlue.png")
let blue2x = createVibrantBluePaperclip(size: 36)
savePNG(image: blue2x, path: "\(resDir)/MenuBarIconBlue@2x.png")
print("Menu bar blue icons generated successfully.")
