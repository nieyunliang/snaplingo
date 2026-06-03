import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 4 else {
    FileHandle.standardError.write(Data("Usage: generate-app-icon.swift <source-png> <output-iconset> <output-icns>\n".utf8))
    exit(64)
}

let sourceURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2], isDirectory: true)
let icnsURL = URL(fileURLWithPath: arguments[3])
let fileManager = FileManager.default

guard
    let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
    let sourceImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    FileHandle.standardError.write(Data("Unable to read source image: \(sourceURL.path)\n".utf8))
    exit(65)
}

if fileManager.fileExists(atPath: outputURL.path) {
    try fileManager.removeItem(at: outputURL)
}
try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)

let iconFiles: [(name: String, pixels: Int, icnsType: String?)] = [
    ("icon_16x16.png", 16, "icp4"),
    ("icon_16x16@2x.png", 32, nil),
    ("icon_32x32.png", 32, "icp5"),
    ("icon_32x32@2x.png", 64, "icp6"),
    ("icon_128x128.png", 128, "ic07"),
    ("icon_128x128@2x.png", 256, nil),
    ("icon_256x256.png", 256, "ic08"),
    ("icon_256x256@2x.png", 512, nil),
    ("icon_512x512.png", 512, "ic09"),
    ("icon_512x512@2x.png", 1024, "ic10"),
]

let colorSpace = CGColorSpaceCreateDeviceRGB()
let iconScale = 0.8
var icnsChunks: [(type: String, data: Data)] = []

for iconFile in iconFiles {
    guard let context = CGContext(
        data: nil,
        width: iconFile.pixels,
        height: iconFile.pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        FileHandle.standardError.write(Data("Unable to create bitmap context for \(iconFile.name)\n".utf8))
        exit(66)
    }

    let canvasSize = CGFloat(iconFile.pixels)
    let iconSize = canvasSize * iconScale
    let inset = (canvasSize - iconSize) / 2
    let rect = CGRect(x: inset, y: inset, width: iconSize, height: iconSize)
    context.interpolationQuality = .high
    context.clear(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))
    context.draw(sourceImage, in: rect)

    guard
        let scaledImage = context.makeImage(),
        let destination = CGImageDestinationCreateWithURL(
            outputURL.appendingPathComponent(iconFile.name) as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        FileHandle.standardError.write(Data("Unable to write \(iconFile.name)\n".utf8))
        exit(67)
    }

    CGImageDestinationAddImage(destination, scaledImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        FileHandle.standardError.write(Data("Unable to finalize \(iconFile.name)\n".utf8))
        exit(68)
    }

    if let icnsType = iconFile.icnsType {
        let data = try Data(contentsOf: outputURL.appendingPathComponent(iconFile.name))
        icnsChunks.append((icnsType, data))
    }
}

func bigEndianUInt32(_ value: Int) -> Data {
    var value = UInt32(value).bigEndian
    return Data(bytes: &value, count: MemoryLayout<UInt32>.size)
}

var icnsData = Data("icns".utf8)
let totalLength = 8 + icnsChunks.reduce(0) { $0 + 8 + $1.data.count }
icnsData.append(bigEndianUInt32(totalLength))

for chunk in icnsChunks {
    icnsData.append(Data(chunk.type.utf8))
    icnsData.append(bigEndianUInt32(8 + chunk.data.count))
    icnsData.append(chunk.data)
}

try icnsData.write(to: icnsURL)
