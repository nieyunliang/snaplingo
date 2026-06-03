import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("Usage: generate-menu-bar-icon.swift <source-logo> <output-png>\n".utf8))
    exit(64)
}

let sourceURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])
let colorSpace = CGColorSpaceCreateDeviceRGB()

guard
    let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
    let sourceImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    FileHandle.standardError.write(Data("Unable to read source image: \(sourceURL.path)\n".utf8))
    exit(65)
}

guard let workingContext = CGContext(
    data: nil,
    width: sourceImage.width,
    height: sourceImage.height,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    FileHandle.standardError.write(Data("Unable to create working bitmap context\n".utf8))
    exit(66)
}

let sourceRect = CGRect(x: 0, y: 0, width: sourceImage.width, height: sourceImage.height)
workingContext.draw(sourceImage, in: sourceRect)

guard let data = workingContext.data else {
    FileHandle.standardError.write(Data("Unable to access working bitmap data\n".utf8))
    exit(67)
}

let pixels = data.assumingMemoryBound(to: UInt8.self)
let edgeInset = Int(Double(min(sourceImage.width, sourceImage.height)) * 0.06)
var minX = sourceImage.width
var minY = sourceImage.height
var maxX = 0
var maxY = 0
var alphaSum = 0.0
var weightedX = 0.0
var weightedY = 0.0

for y in 0 ..< sourceImage.height {
    for x in 0 ..< sourceImage.width {
        let offset = y * workingContext.bytesPerRow + x * 4
        let alpha = Double(pixels[offset + 3])
        let isNearEdge = x < edgeInset
            || x >= sourceImage.width - edgeInset
            || y < edgeInset
            || y >= sourceImage.height - edgeInset

        if alpha == 0 || isNearEdge {
            pixels[offset] = 0
            pixels[offset + 1] = 0
            pixels[offset + 2] = 0
            pixels[offset + 3] = 0
            continue
        }

        let redDistance = 255 - Double(pixels[offset])
        let greenDistance = 255 - Double(pixels[offset + 1])
        let blueDistance = 255 - Double(pixels[offset + 2])
        let distanceFromWhite = sqrt(
            redDistance * redDistance
                + greenDistance * greenDistance
                + blueDistance * blueDistance
        )
        let matte = max(0, min(1, (distanceFromWhite - 105) / 45))

        pixels[offset] = 0
        pixels[offset + 1] = 0
        pixels[offset + 2] = 0
        pixels[offset + 3] = UInt8(alpha * matte)

        if pixels[offset + 3] > 8 {
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }

        let outputAlpha = Double(pixels[offset + 3])
        alphaSum += outputAlpha
        weightedX += (Double(x) + 0.5) * outputAlpha
        weightedY += (Double(y) + 0.5) * outputAlpha
    }
}

guard
    minX <= maxX,
    minY <= maxY,
    alphaSum > 0,
    let recoloredImage = workingContext.makeImage(),
    let croppedImage = recoloredImage.cropping(
        to: CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )
    )
else {
    FileHandle.standardError.write(Data("Unable to recolor source image\n".utf8))
    exit(68)
}

let outputPixels = 34
let outputRect = CGRect(x: 0, y: 0, width: outputPixels, height: outputPixels)
let cropWidth = CGFloat(maxX - minX + 1)
let cropHeight = CGFloat(maxY - minY + 1)
let maximumIconPixels = CGFloat(outputPixels)
let iconScale = min(maximumIconPixels / cropWidth, maximumIconPixels / cropHeight)
let iconWidth = cropWidth * iconScale
let iconHeight = cropHeight * iconScale
let centroidX = CGFloat(weightedX / alphaSum - Double(minX)) * iconScale
let centroidY = CGFloat(weightedY / alphaSum - Double(minY)) * iconScale
let canvasCenter = CGFloat(outputPixels) / 2
let originX = max(0, min(CGFloat(outputPixels) - iconWidth, canvasCenter - centroidX))
let originY = max(0, min(CGFloat(outputPixels) - iconHeight, canvasCenter - (iconHeight - centroidY)))
let iconRect = CGRect(x: originX, y: originY, width: iconWidth, height: iconHeight)

guard let outputContext = CGContext(
    data: nil,
    width: outputPixels,
    height: outputPixels,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    FileHandle.standardError.write(Data("Unable to create output bitmap context\n".utf8))
    exit(69)
}

outputContext.clear(outputRect)
outputContext.interpolationQuality = .high
outputContext.draw(croppedImage, in: iconRect)

guard
    let outputImage = outputContext.makeImage(),
    let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    )
else {
    FileHandle.standardError.write(Data("Unable to create output image\n".utf8))
    exit(70)
}

CGImageDestinationAddImage(destination, outputImage, nil)
guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write(Data("Unable to write output image\n".utf8))
    exit(71)
}
