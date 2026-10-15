// export.swift <in.png> <outdir.imageset> <width>
import AppKit
let a = CommandLine.arguments
let src = NSImage(contentsOfFile: a[1])!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let w = Int(a[3])!
let ratio = Double(src.height) / Double(src.width)
let h = Int((Double(w) * ratio).rounded())
let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.interpolationQuality = .high
ctx.draw(src, in: CGRect(x: 0, y: 0, width: w, height: h))
let dir = URL(fileURLWithPath: a[2]); try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
let name = dir.deletingPathExtension().lastPathComponent.lowercased() + ".png"
try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent(name))
try! """
{
  "images" : [
    { "filename" : "\(name)", "idiom" : "universal" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
""".write(to: dir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print(name, w, h)
