import UIKit

struct DrawingLayer: Decodable {
  let id: String
  let type: String
  let visible: Bool
  let opacity: Double
  let color: String
  let size: Double
  let points: [[Double]]?
  let text: String?
  let x: Double?
  let y: Double?
  let font: String?
}

enum DrawingRenderer {
  static func color(_ value: String, opacity: Double) -> UIColor {
    let hex = UInt32(value.dropFirst(), radix: 16) ?? 0xffffff
    return UIColor(red: CGFloat((hex >> 16) & 255)/255, green: CGFloat((hex >> 8) & 255)/255,
      blue: CGFloat(hex & 255)/255, alpha: CGFloat(min(1,max(0,opacity))))
  }
  static func draw(_ context: CGContext, layers: [DrawingLayer]) {
    UIGraphicsPushContext(context); defer { UIGraphicsPopContext() }
    for layer in layers where layer.visible {
      let color = color(layer.color, opacity: layer.opacity)
      let size = CGFloat(max(1, layer.size))
      context.saveGState(); defer { context.restoreGState() }
      if layer.type == "text" {
        let font = DrawingFonts.font(layer.font ?? "sans-serif", size: size)
        let paragraph = NSMutableParagraphStyle(); paragraph.baseWritingDirection = .rightToLeft
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        for (index, line) in (layer.text ?? "").components(separatedBy: "\n").enumerated() {
          let string = NSAttributedString(string: line, attributes: attributes)
          let width = string.size().width
          string.draw(at: CGPoint(x: CGFloat(layer.x ?? 0)-width,
            y: CGFloat(layer.y ?? 0)-font.ascender+CGFloat(index)*size*1.3))
        }
      } else if let points = layer.points, let first = points.first, first.count == 2 {
        context.setStrokeColor(color.cgColor); context.setFillColor(color.cgColor)
        context.setLineWidth(size); context.setLineCap(.round); context.setLineJoin(.round)
        if points.count == 1 {
          context.fillEllipse(in: CGRect(x: first[0]-Double(size)/2,y: first[1]-Double(size)/2,width: Double(size),height: Double(size)))
        } else {
          context.beginPath(); context.move(to: CGPoint(x:first[0],y:first[1]))
          for point in points.dropFirst() where point.count == 2 { context.addLine(to: CGPoint(x:point[0],y:point[1])) }
          context.strokePath()
        }
      }
    }
  }
}
