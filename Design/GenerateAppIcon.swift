import AppKit
import ImageIO
import UniformTypeIdentifiers

// Run from the repository root: swift Design/GenerateAppIcon.swift
let source = URL(fileURLWithPath: "Design/Bird.png")
let destination = URL(fileURLWithPath: "JustAlarm/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let image = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(source as CFURL, nil)!, 0, nil)!
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
context.interpolationQuality = .high
context.draw(image, in: CGRect(x: -188, y: -188, width: 1400, height: 1400))
let output = CGImageDestinationCreateWithURL(destination as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(output, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(output), "Could not write app icon")
