import ExpoModulesCore
import UIKit

final class ImageTiles: UIView {
  override class var layerClass: AnyClass { CATiledLayer.self }
  private let stateLock = NSLock()
  private var image: StoredImage?
  private var layers: [DrawingLayer] = []
  override init(frame: CGRect) {
    super.init(frame: frame)
    isOpaque = false
    let tiled = layer as! CATiledLayer
    tiled.tileSize = CGSize(width: 512, height: 512)
    tiled.levelsOfDetail = 9
    tiled.levelsOfDetailBias = 4
    contentScaleFactor = UIScreen.main.scale
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
  func setImage(_ value: StoredImage) { stateLock.lock(); image=value; stateLock.unlock(); setNeedsDisplay() }
  func setLayers(_ value: [DrawingLayer]) { stateLock.lock(); layers=value; stateLock.unlock(); setNeedsDisplay() }
  override func draw(_ rect: CGRect) {
    stateLock.lock(); let image=self.image, layers=self.layers; stateLock.unlock()
    guard let image, let context=UIGraphicsGetCurrentContext() else { return }
    let region=rect.intersection(CGRect(x:0,y:0,width:image.width,height:image.height))
    guard !region.isEmpty else { return }
    let x=max(0,Int(floor(region.minX))), y=max(0,Int(floor(region.minY)))
    let w=min(image.width-x,Int(ceil(region.maxX))-x), h=min(image.height-y,Int(ceil(region.maxY))-y)
    guard w>0,h>0 else { return }
    let scale=max(0.001,abs(context.ctm.a))
    var sample=1
    while sample<256 && CGFloat(sample)*scale<0.75 { sample *= 2 }
    let outputWidth=(w+sample-1)/sample, outputHeight=(h+sample-1)/sample
    var bytes=[UInt8](repeating:0,count:outputWidth*outputHeight*4)
    let decoded=bytes.withUnsafeMutableBufferPointer { buffer in
      LIReadTile(image.raw.path,Int32(image.width),Int32(image.height),Int32(x),Int32(y),
        Int32(outputWidth),Int32(outputHeight),Int32(sample),buffer.baseAddress!)
    }
    guard decoded == 1, let provider=CGDataProvider(data:Data(bytes) as CFData),
      let tile=CGImage(width:outputWidth,height:outputHeight,bitsPerComponent:8,bitsPerPixel:32,
        bytesPerRow:outputWidth*4,space:image.colorSpace,
        bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
        provider:provider,decode:nil,shouldInterpolate:sample>1,intent:.defaultIntent)
    else { return }
    context.saveGState()
    context.clip(to: CGRect(x:0,y:0,width:image.width,height:image.height))
    UIColor.white.setFill(); context.fill(region)
    UIImage(cgImage:tile).draw(in:CGRect(x:x,y:y,width:w,height:h))
    DrawingRenderer.draw(context,layers:layers)
    context.restoreGState()
  }
}

public final class LongImageView: ExpoView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
  let onStroke=EventDispatcher()
  let onFailure=EventDispatcher()
  private let scroll=UIScrollView()
  private let tiles=ImageTiles(frame:.zero)
  private var generation=0
  private var source=""
  private var image:StoredImage?
  private var tool="pan"
  private var pendingFit=false
  private var points:[[Double]]=[]
  private let preview = CAShapeLayer()
  var brushColor="#ffffff"
  var brushSize=48.0
  private lazy var brush=UIPanGestureRecognizer(target:self,action:#selector(drawStroke(_:)))
  private lazy var tap=UITapGestureRecognizer(target:self,action:#selector(placeText(_:)))

  public required init(appContext:AppContext?=nil) {
    super.init(appContext:appContext)
    clipsToBounds=true
    backgroundColor=UIColor(red:0.07,green:0.09,blue:0.12,alpha:1)
    scroll.delegate=self
    scroll.maximumZoomScale=16
    scroll.bouncesZoom=true
    scroll.addSubview(tiles); addSubview(scroll)
    preview.fillColor = nil; preview.lineCap = .round; preview.lineJoin = .round
    tiles.layer.addSublayer(preview)
    brush.maximumNumberOfTouches=1; brush.delegate=self; tiles.addGestureRecognizer(brush)
    tap.delegate=self; tiles.addGestureRecognizer(tap)
    if let pinch=scroll.pinchGestureRecognizer { tap.require(toFail:pinch) }
    setTool("pan")
  }
  override public func layoutSubviews() {
    super.layoutSubviews(); scroll.frame=bounds
    if pendingFit { fit() }
  }
  private func fit() {
    guard let image,bounds.width>0 else { return }
    pendingFit=false
    scroll.minimumZoomScale=min(1,bounds.width/CGFloat(image.width))
    scroll.zoomScale=scroll.minimumZoomScale
    scroll.contentOffset = .zero
  }
  func load(_ value:String) {
    guard source != value else { return }
    source=value;generation+=1;let version=generation
    DispatchQueue.global(qos:.userInitiated).async { [weak self] in
      do {
        let image=try ImageStore.open(value)
        DispatchQueue.main.async {
          guard let self,self.generation==version else { return }
          self.image=image
          self.scroll.zoomScale=1
          self.tiles.frame=CGRect(x:0,y:0,width:image.width,height:image.height)
          self.scroll.contentSize=self.tiles.bounds.size
          self.tiles.setImage(image)
          self.pendingFit=true;self.setNeedsLayout()
        }
      } catch {
        let message=error.localizedDescription
        DispatchQueue.main.async { [weak self] in
          guard let self,self.generation==version else {return}
          self.onFailure(["message":message])
        }
      }
    }
  }
  func setLayers(_ value:String) {
    do { tiles.setLayers(try JSONDecoder().decode([DrawingLayer].self,from:Data(value.utf8))) }
    catch { onFailure(["message":error.localizedDescription]) }
  }
  func setTool(_ value:String) {
    tool=value
    scroll.panGestureRecognizer.isEnabled=value=="pan"
    brush.isEnabled=value=="brush"
    tap.isEnabled=value=="text" || value=="move"
  }
  public func viewForZooming(in scrollView:UIScrollView) -> UIView? { tiles }
  public func gestureRecognizer(_ gestureRecognizer:UIGestureRecognizer,shouldRecognizeSimultaneouslyWith otherGestureRecognizer:UIGestureRecognizer) -> Bool { true }
  private func point(_ recognizer:UIGestureRecognizer) -> [Double] {
    let p=recognizer.location(in:tiles)
    return [Double(min(tiles.bounds.width,max(0,p.x))),Double(min(tiles.bounds.height,max(0,p.y)))]
  }
  @objc private func drawStroke(_ recognizer:UIPanGestureRecognizer) {
    switch recognizer.state {
    case .began: points=[point(recognizer)]; updatePreview()
    case .changed: points.append(point(recognizer)); updatePreview()
    case .ended:
      points.append(point(recognizer)); emit(points,type:"stroke");points=[]; preview.path=nil
    case .cancelled,.failed: points=[]; preview.path=nil
    default: break
    }
  }
  private func updatePreview() {
    guard let first=points.first else { return }
    let xs=points.map { $0[0] }, ys=points.map { $0[1] }
    let margin=brushSize/2+1
    let left=(xs.min() ?? first[0])-margin, top=(ys.min() ?? first[1])-margin
    let path=UIBezierPath(); path.move(to:CGPoint(x:first[0]-left,y:first[1]-top))
    for point in points.dropFirst() { path.addLine(to:CGPoint(x:point[0]-left,y:point[1]-top)) }
    CATransaction.begin();CATransaction.setDisableActions(true)
    preview.frame=CGRect(x:left,y:top,width:(xs.max() ?? first[0])-left+margin,height:(ys.max() ?? first[1])-top+margin)
    preview.strokeColor=DrawingRenderer.color(brushColor,opacity:1).cgColor
    preview.lineWidth=CGFloat(brushSize);preview.path=path.cgPath
    CATransaction.commit()
  }
  @objc private func placeText(_ recognizer:UITapGestureRecognizer) {
    if recognizer.state == .ended { emit([point(recognizer)],type:tool) }
  }
  private func emit(_ points:[[Double]],type:String) {
    guard let data=try? JSONSerialization.data(withJSONObject:points),let json=String(data:data,encoding:.utf8) else {return}
    onStroke(["points":json,"type":type])
  }
}
