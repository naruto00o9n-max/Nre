package expo.modules.longimage

import android.graphics.*
import org.json.JSONArray

object Renderer {
  fun draw(canvas: Canvas, layers: JSONArray) {
    for (i in 0 until layers.length()) {
      val layer = layers.getJSONObject(i)
      if (!layer.optBoolean("visible", true)) continue
      val alpha = (layer.optDouble("opacity", 1.0).coerceIn(0.0, 1.0) * 255).toInt()
      val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor(layer.optString("color", "#ffffff")); this.alpha = alpha
      }
      if (layer.optString("type") == "text") {
        paint.textSize = layer.optDouble("size", 48.0).toFloat()
        val font = layer.optString("font", "sans-serif")
        paint.typeface = if(font.startsWith("file:")) Typeface.createFromFile(java.io.File(android.net.Uri.parse(font).path!!)) else Typeface.create(font, Typeface.NORMAL)
        paint.textAlign = Paint.Align.RIGHT
        val lines = layer.optString("text").split("\n")
        lines.forEachIndexed { index, line ->
          canvas.drawText(line, layer.getDouble("x").toFloat(), layer.getDouble("y").toFloat() + index * paint.textSize * 1.3f, paint)
        }
      } else {
        val points = layer.optJSONArray("points") ?: continue
        if (points.length() == 0) continue
        paint.strokeWidth = layer.optDouble("size", 12.0).toFloat()
        paint.strokeCap = Paint.Cap.ROUND; paint.strokeJoin = Paint.Join.ROUND
        val first = points.getJSONArray(0)
        if (points.length() == 1) {
          canvas.drawCircle(first.getDouble(0).toFloat(), first.getDouble(1).toFloat(), paint.strokeWidth/2, paint)
        } else {
          paint.style = Paint.Style.STROKE
          val path = Path(); path.moveTo(first.getDouble(0).toFloat(), first.getDouble(1).toFloat())
          for(j in 1 until points.length()) { val p=points.getJSONArray(j); path.lineTo(p.getDouble(0).toFloat(),p.getDouble(1).toFloat()) }
          canvas.drawPath(path,paint)
        }
      }
    }
  }
}
