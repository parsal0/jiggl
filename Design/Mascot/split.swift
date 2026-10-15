// split.swift <in> <outprefix> : exportiert jede größere Zusammenhangskomponente zugeschnitten als PNG
import CoreImage
import AppKit
let src = CIImage(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))!
let prefix = CommandLine.arguments[2]
let w = Int(src.extent.width), h = Int(src.extent.height)
var px = [UInt8](repeating: 0, count: w*h*4)
CIContext().render(src, toBitmap: &px, rowBytes: w*4, bounds: src.extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
var label = [Int](repeating: -1, count: w*h)
var comps: [(minX:Int,minY:Int,maxX:Int,maxY:Int,n:Int)] = []
for s in 0..<(w*h) where label[s] < 0 && px[s*4+3] > 8 {
  let id = comps.count; var c = (minX:w,minY:h,maxX:0,maxY:0,n:0)
  var st = [s]; label[s] = id
  while let i = st.popLast() {
    let x=i%w,y=i/w; c.n+=1; c.minX=min(c.minX,x);c.maxX=max(c.maxX,x);c.minY=min(c.minY,y);c.maxY=max(c.maxY,y)
    for j in [x>0 ? i-1 : -1, x<w-1 ? i+1 : -1, y>0 ? i-w : -1, y<h-1 ? i+w : -1] where j >= 0 && label[j] < 0 && px[j*4+3] > 8 { label[j]=id; st.append(j) }
  }
  comps.append(c)
}
let big = comps.enumerated().filter { $0.element.n > 2000 }.sorted { $0.element.minX < $1.element.minX }
for (k, e) in big.enumerated() {
  let c = e.element, pad = 4
  let x0=max(0,c.minX-pad), y0=max(0,c.minY-pad), x1=min(w-1,c.maxX+pad), y1=min(h-1,c.maxY+pad)
  let cw=x1-x0+1, ch=y1-y0+1
  var out = [UInt8](repeating: 0, count: cw*ch*4)
  for y in 0..<ch { for x in 0..<cw { let i=(y+y0)*w+x+x0
    // Nur Pixel dieser Komponente (plus weicher Rand ohne Label)
    if label[i] == e.offset || (label[i] < 0) { for k in 0..<4 { out[(y*cw+x)*4+k] = px[i*4+k] } } } }
  // vormultiplizieren
  for i in 0..<(cw*ch) { let a = Double(out[i*4+3])/255; for k in 0..<3 { out[i*4+k] = UInt8(Double(out[i*4+k])*a) } }
  let cg = CGImage(width: cw, height: ch, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: cw*4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: CGDataProvider(data: Data(out) as CFData)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
  let name = big.count == 1 ? "\(prefix).png" : "\(prefix)-\(k == 0 ? "left" : "right").png"
  try! NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: name))
  print(name, "bbox", c.minX, c.minY, c.maxX, c.maxY, "size", cw, ch)
}
