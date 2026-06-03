import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("Usage: round-app-icon.swift <source-png> <output-png>\n".utf8))
    exit(64)
}

let sourceURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])

guard
    let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
    let sourceImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    FileHandle.standardError.write(Data("Unable to read source image: \(sourceURL.path)\n".utf8))
    exit(65)
}

let width = sourceImage.width
let height = sourceImage.height
let rect = CGRect(x: 0, y: 0, width: width, height: height)
let radius = CGFloat(min(width, height)) * 0.205
let colorSpace = CGColorSpaceCreateDeviceRGB()

guard let context = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    FileHandle.standardError.write(Data("Unable to create bitmap context\n".utf8))
    exit(66)
}

context.clear(rect)
context.addPath(CGPath(
    roundedRect: rect,
    cornerWidth: radius,
    cornerHeight: radius,
    transform: nil
))
context.clip()
context.draw(sourceImage, in: rect)

guard
    let roundedImage = context.makeImage(),
    let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    )
else {
    FileHandle.standardError.write(Data("Unable to create output image\n".utf8))
    exit(67)
}

CGImageDestinationAddImage(destination, roundedImage, nil)
guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write(Data("Unable to write output image\n".utf8))
    exit(68)
}
