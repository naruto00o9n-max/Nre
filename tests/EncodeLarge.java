import expo.modules.longimage.StreamingPng;
import java.io.*;
public class EncodeLarge {
 public static void main(String[] args)throws Exception{
  int w=2000,h=100000;int[] row=new int[w];
  try(StreamingPng png=new StreamingPng(new FileOutputStream(args[0]),w,h)){
   for(int y=0;y<h;y++){for(int x=0;x<w;x++)row[x]=PngTest.pixel(x,y);png.writeRow(row);}png.finish();
  }
  System.out.println("Encoded 2000 x 100000 with -Xmx32m");
 }
}
