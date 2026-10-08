import ExpoModulesCore

public final class LongImageModule: Module {
  public func definition() -> ModuleDefinition {
    Name("LongImage")
    AsyncFunction("inspect") { (uri: String) -> [String: Int] in
      let image = try ImageStore.open(uri)
      return ["width": image.width, "height": image.height]
    }.runOnQueue(.global(qos: .userInitiated))
    AsyncFunction("inspectFont") { (uri: String) -> Bool in
      _ = try DrawingFonts.register(uri); return true
    }.runOnQueue(.global(qos: .userInitiated))
    AsyncFunction("exportPng") { (uri: String, layers: String) -> String in
      try ImageStore.export(uri, json: layers)
    }.runOnQueue(.global(qos: .userInitiated))
    View(LongImageView.self) {
      Events("onStroke", "onFailure")
      Prop("source") { (view: LongImageView, source: String) in view.load(source) }
      Prop("layers") { (view: LongImageView, layers: String) in view.setLayers(layers) }
      Prop("tool") { (view: LongImageView, tool: String) in view.setTool(tool) }
      Prop("brushColor") { (view: LongImageView, color: String) in view.brushColor = color }
      Prop("brushSize") { (view: LongImageView, size: Double) in view.brushSize = size }
    }
  }
}
