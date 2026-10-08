import Foundation
import ImageIO
import UIKit
import CoreText

struct StoredImage {
  let source: URL
  let raw: URL
  let width: Int
  let height: Int
  let colorSpace: CGColorSpace
}

func imageError(_ message: String) -> NSError {
  NSError(domain: "LongImage", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
}

final class ImageStore {
  static let lock = NSLock()

  static func open(_ uri: String) throws -> StoredImage {
    lock.lock(); defer { lock.unlock() }
    guard let source = URL(string: uri), source.isFileURL,
      let imageSource = CGImageSourceCreateWithURL(source as CFURL,
        [kCGImageSourceShouldCache: false] as CFDictionary),
      let props = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
      let width = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
      let height = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
      width > 0, height > 0, width <= 32768, height <= 1000000
    else { throw imageError("صيغة أو أبعاد الصورة غير مدعومة") }
    let raw = URL(fileURLWithPath: source.path + ".rgba")
    let expected = Int64(width) * Int64(height) * 4
    let existing = try? FileManager.default.attributesOfItem(atPath: raw.path)
    if (existing?[.size] as? NSNumber)?.int64Value != expected {
      let capacity = try? source.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
      if let free = capacity?.volumeAvailableCapacityForImportantUsage, free < expected + 32 * 1024 * 1024 {
        throw imageError("لا توجد مساحة كافية لملف بكسلات الصورة الطويلة")
      }
      let temporary = URL(fileURLWithPath: raw.path + ".partial-" + UUID().uuidString)
      defer { try? FileManager.default.removeItem(at: temporary) }
      if CGImageSourceGetType(imageSource) as String? == "public.png" {
        var w: Int32 = 0, h: Int32 = 0
        var error = [CChar](repeating: 0, count: 512)
        guard LIImportPNG(source.path, temporary.path, &w, &h, &error, 512) == 1 else {
          throw imageError(String(cString: error))
        }
        guard Int(w) == width, Int(h) == height else { throw imageError("أبعاد الصورة تغيرت أثناء فتحها") }
      } else {
        // ImageIO fallback is deliberately bounded; huge inputs must use PNG.
        guard Int64(width) * Int64(height) <= 8_000_000 else {
          throw imageError("الصور الطويلة جدًا على iPhone تتطلب PNG في هذه النسخة؛ لم تُصغّر الصورة")
        }
        guard let image = CGImageSourceCreateImageAtIndex(imageSource, 0,
          [kCGImageSourceShouldCache: false] as CFDictionary), image.bitsPerComponent <= 8
        else { throw imageError("تعذر فك الصورة ذات 8 بت") }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        try bytes.withUnsafeMutableBytes { storage in
          guard let context = CGContext(data: storage.baseAddress, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
          else { throw imageError("تعذر تخصيص منطقة معالجة الصورة") }
          context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        for i in stride(from: 0, to: bytes.count, by: 4) {
          let a = Int(bytes[i + 3])
          if a > 0 && a < 255 { for c in 0..<3 { bytes[i+c] = UInt8(min(255, (Int(bytes[i+c])*255+a/2)/a)) } }
        }
        try Data(bytes).write(to: temporary)
      }
      try? FileManager.default.removeItem(at: raw)
      try FileManager.default.moveItem(at: temporary, to: raw)
    }
    var cacheURL = raw
    var cacheAttributes = URLResourceValues()
    cacheAttributes.isExcludedFromBackup = true
    try? cacheURL.setResourceValues(cacheAttributes)
    var colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    var profileLength = 0
    if let profile = LICopyPNGProfile(source.path, &profileLength) {
      defer { LIFreeBuffer(profile) }
      if let embedded = CGColorSpace(iccData: Data(bytes: profile, count: profileLength) as CFData), embedded.model == .rgb {
        colorSpace = embedded
      }
    }
    return StoredImage(source: source, raw: raw, width: width, height: height, colorSpace: colorSpace)
  }

  static func export(_ uri: String, json: String) throws -> String {
    let image = try open(uri)
    let layers = try JSONDecoder().decode([DrawingLayer].self, from: Data(json.utf8))
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("manhwa-\(UUID().uuidString).png")
    let error = UnsafeMutablePointer<CChar>.allocate(capacity: 512)
    error.initialize(repeating: 0, count: 512)
    defer { error.deinitialize(count: 512); error.deallocate() }
    guard let writer = LIWriterOpen(image.source.path, file.path, Int32(image.width), Int32(image.height), error, 512)
    else { try? FileManager.default.removeItem(at: file); throw imageError(String(cString: error)) }
    defer { LIWriterClose(writer) }
    let input = try FileHandle(forReadingFrom: image.raw)
    defer { try? input.close() }
    do {
      let stripeHeight = max(1, min(256, 8 * 1024 * 1024 / (image.width * 4)))
      var y = 0
      while y < image.height {
        let count = min(stripeHeight, image.height - y)
        guard var base = try input.read(upToCount: image.width * count * 4), base.count == image.width * count * 4
        else { throw imageError("ملف بكسلات الصورة غير مكتمل") }
        var overlay = [UInt8](repeating: 0, count: base.count)
        try overlay.withUnsafeMutableBytes { buffer in
          guard let context = CGContext(data: buffer.baseAddress, width: image.width, height: count,
            bitsPerComponent: 8, bytesPerRow: image.width * 4, space: image.colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
          else { throw imageError("تعذر إنشاء شريحة التصدير") }
          context.translateBy(x: 0, y: CGFloat(count)); context.scaleBy(x: 1, y: -1)
          context.translateBy(x: 0, y: -CGFloat(y))
          DrawingRenderer.draw(context, layers: layers)
        }
        let written: Int32 = base.withUnsafeMutableBytes { buffer in
          overlay.withUnsafeBufferPointer { upper in
            let pointer = buffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            LICompositeRGBA(pointer, upper.baseAddress!, image.width * count)
            return LIWriterRows(writer, pointer, Int32(count))
          }
        }
        guard written == 1 else { throw imageError(String(cString: error)) }
        y += count
      }
      guard LIWriterFinish(writer) == 1 else { throw imageError(String(cString: error)) }
      return file.absoluteString
    } catch { try? FileManager.default.removeItem(at: file); throw error }
  }
}

final class DrawingFonts {
  static let lock = NSLock()
  static var names: [String: String] = [:]
  static func register(_ uri: String) throws -> String {
    lock.lock(); defer { lock.unlock() }
    if let name = names[uri] { return name }
    guard let url = URL(string: uri), url.isFileURL,
      let provider = CGDataProvider(url: url as CFURL), let cgFont = CGFont(provider),
      let name = cgFont.postScriptName as String?
    else { throw imageError("ملف الخط غير صالح") }
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    names[uri] = name
    return name
  }
  static func font(_ name: String, size: CGFloat) -> UIFont {
    if name.hasPrefix("file:"), let registered = try? register(name) { return UIFont(name: registered, size: size) ?? .systemFont(ofSize: size) }
    if name == "serif" { return UIFont(name: "Georgia", size: size) ?? .systemFont(ofSize: size) }
    if name == "monospace" { return .monospacedSystemFont(ofSize: size, weight: .regular) }
    return .systemFont(ofSize: size)
  }
}
