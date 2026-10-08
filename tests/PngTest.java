import expo.modules.longimage.StreamingPng;
import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.*;
public class PngTest {
 public static void main(String[] args)throws Exception {
  File file=new File(args[0]);int width=257,height=50000;
  try(StreamingPng png=new StreamingPng(new FileOutputStream(file),width,height)){
   int[] row=new int[width];for(int y=0;y<height;y++){for(int x=0;x<width;x++)row[x]=pixel(x,y);png.writeRow(row);}png.finish();
  }
  BufferedImage decoded=ImageIO.read(file);
  if(decoded.getWidth()!=width||decoded.getHeight()!=height)throw new AssertionError("Dimensions changed");
  for(int y=0;y<height;y++)for(int x=0;x<width;x++)if(decoded.getRGB(x,y)!=pixel(x,y))throw new AssertionError("Pixel changed at "+x+","+y);
  boolean rejected=false;
  try(StreamingPng png=new StreamingPng(new ByteArrayOutputStream(),2,3)){png.writeRow(new int[2]);try{png.finish();}catch(IllegalStateException e){rejected=true;}}
  if(!rejected)throw new AssertionError("Incomplete export accepted");
  System.out.println("PASS: 257 x 50000, all 12,850,000 RGBA pixels match, incomplete export rejected");
 }
 static int pixel(int x,int y){return ((x+y)%256)<<24 | ((x*7+y)%256)<<16 | ((y*3+x)%256)<<8 | ((x^y)&255);}
}
