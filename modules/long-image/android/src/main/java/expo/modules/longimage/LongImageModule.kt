package expo.modules.longimage

import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import android.graphics.*
import android.net.Uri
import java.io.File
import java.io.FileOutputStream
import org.json.JSONArray

class LongImageModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("LongImage")
    AsyncFunction("inspectFont") { uri: String ->
      val path=Uri.parse(uri).path ?: error("Invalid font path")
      Typeface.createFromFile(File(path))
      true
    }
    AsyncFunction("inspect") { uri: String ->
      val context=appContext.reactContext ?: error("Context unavailable")
      val options=BitmapFactory.Options().apply { inJustDecodeBounds=true }
      context.contentResolver.openInputStream(Uri.parse(uri))!!.use { BitmapFactory.decodeStream(it,null,options) }
      require(options.outWidth>0 && options.outHeight>0) { "صيغة الصورة غير مدعومة" }
      mapOf("width" to options.outWidth,"height" to options.outHeight)
    }
    AsyncFunction("exportPng") { uri: String, json: String ->
      val context=appContext.reactContext ?: error("Context unavailable")
      val layers=JSONArray(json)
      val file=File(context.cacheDir,"manhwa-${System.currentTimeMillis()}.png")
      try {
        context.contentResolver.openInputStream(Uri.parse(uri))!!.use { input ->
          val decoder=BitmapRegionDecoder.newInstance(input,false) ?: error("Unsupported decoder")
          try {
            require(decoder.width in 1..32768) { "عرض الصورة يتجاوز الحد التجريبي 32768" }
            val stripeHeight=(8*1024*1024 / (decoder.width*4)).coerceIn(1,256)
            StreamingPng(FileOutputStream(file),decoder.width,decoder.height).use { png ->
              val row=IntArray(decoder.width)
              var y=0
              while(y<decoder.height) {
                val end=minOf(y+stripeHeight,decoder.height)
                val decoded=decoder.decodeRegion(Rect(0,y,decoder.width,end),BitmapFactory.Options().apply { inPreferredConfig=Bitmap.Config.ARGB_8888 }) ?: error("Decode failed")
                val bitmap=decoded.copy(Bitmap.Config.ARGB_8888,true) ?: error("Allocation failed")
                decoded.recycle()
                try {
                  val canvas=Canvas(bitmap); canvas.translate(0f,-y.toFloat()); Renderer.draw(canvas,layers)
                  for(r in 0 until bitmap.height){bitmap.getPixels(row,0,decoder.width,0,r,decoder.width,1);png.writeRow(row)}
                } finally { bitmap.recycle() }
                y=end
              }
              png.finish()
            }
          } finally { decoder.recycle() }
        }
        Uri.fromFile(file).toString()
      } catch(e: Exception) { file.delete(); throw e }
    }
    View(LongImageView::class) {
      Events("onStroke", "onFailure")
      Prop("source") { view: LongImageView, value: String -> view.load(value) }
      Prop("layers") { view: LongImageView, value: String -> view.setLayers(value) }
      Prop("tool") { view: LongImageView, value: String -> view.tool=value }
      Prop("brushColor") { view: LongImageView, value: String -> view.brushColor=value }
      Prop("brushSize") { view: LongImageView, value: Double -> view.brushSize=value.toFloat() }
    }
  }
}
