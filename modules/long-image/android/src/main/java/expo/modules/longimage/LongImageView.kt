package expo.modules.longimage

import android.content.Context
import android.graphics.*
import android.net.Uri
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import expo.modules.kotlin.AppContext
import expo.modules.kotlin.views.ExpoView
import expo.modules.kotlin.viewevent.EventDispatcher
import org.json.JSONArray
import java.util.concurrent.Executors
import kotlin.math.*

class LongImageView(context: Context, appContext: AppContext) : ExpoView(context, appContext) {
  private val onStroke by EventDispatcher()
  private val onFailure by EventDispatcher()
  private val worker=Executors.newSingleThreadExecutor()
  private var decoder: BitmapRegionDecoder?=null
  private val tiles=LinkedHashMap<String,Bitmap>(16,0.75f,true)
  private val pending=mutableSetOf<String>()
  private var generation=0
  private var imageWidth=0; private var imageHeight=0
  private var zoom=1f; private var offsetX=0f; private var offsetY=0f
  private var lastX=0f; private var lastY=0f
  private var layers=JSONArray(); private var points=JSONArray()
  var tool="pan"; var brushColor="#ffffff"; var brushSize=24f
  private var currentSource=""
  private var multiTouch=false
  private val scaler=ScaleGestureDetector(context,object: ScaleGestureDetector.SimpleOnScaleGestureListener(){
    override fun onScale(detector: ScaleGestureDetector): Boolean {
      val old=zoom; zoom=(zoom*detector.scaleFactor).coerceIn(0.005f,16f)
      offsetX=detector.focusX-(detector.focusX-offsetX)*zoom/old
      offsetY=detector.focusY-(detector.focusY-offsetY)*zoom/old
      points=JSONArray();invalidate();return true
    }
  })
  init { setWillNotDraw(false) }
  fun setLayers(json: String) { layers=JSONArray(json);invalidate() }
  fun load(uri: String) {
    if(uri==currentSource)return
    currentSource=uri;generation++;val version=generation
    tiles.values.forEach { it.recycle() };tiles.clear();pending.clear();imageWidth=0;imageHeight=0
    worker.execute {
      try {
        decoder?.recycle()
        val next=context.contentResolver.openInputStream(Uri.parse(uri))!!.use { BitmapRegionDecoder.newInstance(it,false) } ?: error("Unsupported image")
        decoder=next
        post { if(version==generation){imageWidth=next.width;imageHeight=next.height;fit();invalidate()} }
      } catch(e:Exception){post{onFailure(mapOf("message" to (e.message ?: "تعذر فتح الصورة")))}}
    }
  }
  private fun fit(){if(width>0 && imageWidth>0){zoom=width.toFloat()/imageWidth;offsetX=0f;offsetY=0f}}
  override fun onSizeChanged(w:Int,h:Int,oldw:Int,oldh:Int){super.onSizeChanged(w,h,oldw,oldh);if(oldw==0)fit()}
  override fun onDraw(canvas: Canvas) {
    super.onDraw(canvas);canvas.drawColor(Color.rgb(19,23,31))
    if(imageWidth==0)return
    var sample=1;while(sample<128 && zoom*sample<0.6f)sample*=2
    val edge=512*sample
    val left=max(0,floor(-offsetX/zoom/edge).toInt());val top=max(0,floor(-offsetY/zoom/edge).toInt())
    val right=min((imageWidth-1)/edge,floor((width-offsetX)/zoom/edge).toInt())
    val bottom=min((imageHeight-1)/edge,floor((height-offsetY)/zoom/edge).toInt())
    canvas.save();canvas.translate(offsetX,offsetY);canvas.scale(zoom,zoom)
    canvas.clipRect(0,0,imageWidth,imageHeight)
    canvas.drawColor(Color.WHITE)
    for(y in top..bottom)for(x in left..right){
      val rect=Rect(x*edge,y*edge,minOf((x+1)*edge,imageWidth),minOf((y+1)*edge,imageHeight))
      val key="$sample:$x:$y";val bitmap=tiles[key]
      if(bitmap!=null)canvas.drawBitmap(bitmap,null,rect,Paint(Paint.FILTER_BITMAP_FLAG))
      else if(pending.add(key)){
        val version=generation;val requestedSample=sample
        worker.execute {
          try {
            val decoded=decoder?.decodeRegion(rect,BitmapFactory.Options().apply {inSampleSize=requestedSample;inPreferredConfig=Bitmap.Config.ARGB_8888})
            post {
              if(version==generation){pending.remove(key);if(decoded!=null){tiles[key]=decoded;while(tiles.size>24){val oldest=tiles.entries.first();tiles.remove(oldest.key);oldest.value.recycle()}};invalidate()}
              else decoded?.recycle()
            }
          }catch(e:Exception){post{if(version==generation){pending.remove(key);onFailure(mapOf("message" to (e.message ?: "Decode failed")))}}}
        }
      }
    }
    Renderer.draw(canvas,layers)
    if(points.length()>0){val stroke=org.json.JSONObject().put("type","stroke").put("points",points).put("color",brushColor).put("size",brushSize);Renderer.draw(canvas,JSONArray().put(stroke))}
    canvas.restore()
  }
  private fun point(x:Float,y:Float)=JSONArray().put(((x-offsetX)/zoom).coerceIn(0f,imageWidth.toFloat()).toDouble()).put(((y-offsetY)/zoom).coerceIn(0f,imageHeight.toFloat()).toDouble())
  override fun onTouchEvent(event:MotionEvent):Boolean {
    if(imageWidth==0)return true
    scaler.onTouchEvent(event)
    when(event.actionMasked){
      MotionEvent.ACTION_DOWN->{multiTouch=false;parent.requestDisallowInterceptTouchEvent(true);lastX=event.x;lastY=event.y;points=JSONArray();if(tool=="brush")points.put(point(event.x,event.y))}
      MotionEvent.ACTION_POINTER_DOWN->{multiTouch=true;points=JSONArray()}
      MotionEvent.ACTION_MOVE->{
        if(event.pointerCount==1 && !scaler.isInProgress){
          if(tool=="pan"){offsetX+=event.x-lastX;offsetY+=event.y-lastY}
          else if(tool=="brush")points.put(point(event.x,event.y))
        }
        lastX=event.x;lastY=event.y;invalidate()
      }
      MotionEvent.ACTION_UP->{
        if(!multiTouch && tool=="brush" && points.length()>0)onStroke(mapOf("points" to points.toString(),"type" to "stroke"))
        else if(!multiTouch && (tool=="text" || tool=="move"))onStroke(mapOf("points" to JSONArray().put(point(event.x,event.y)).toString(),"type" to tool))
        points=JSONArray();parent.requestDisallowInterceptTouchEvent(false);invalidate()
      }
      MotionEvent.ACTION_CANCEL->{points=JSONArray();invalidate()}
    }
    return true
  }
  override fun onDetachedFromWindow(){super.onDetachedFromWindow();generation++;tiles.values.forEach{it.recycle()};tiles.clear();worker.execute{decoder?.recycle();decoder=null};worker.shutdown()}
}
