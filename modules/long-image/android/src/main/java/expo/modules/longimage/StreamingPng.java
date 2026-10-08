package expo.modules.longimage;

import java.io.*;
import java.util.zip.*;

/** RGBA8 PNG encoder. Keeps one row and a fixed compression buffer in memory. */
public final class StreamingPng implements AutoCloseable {
  private final DataOutputStream out;
  private final Deflater deflater = new Deflater(6);
  private final byte[] compressed = new byte[32768];
  private final byte[] row;
  private final int width, height;
  private int rows;
  public StreamingPng(OutputStream stream, int width, int height) throws IOException {
    if (width <= 0 || height <= 0 || width > 100000) throw new IllegalArgumentException("Invalid dimensions");
    this.width=width; this.height=height; row=new byte[Math.addExact(Math.multiplyExact(width,4),1)];
    out=new DataOutputStream(stream);
    out.write(new byte[]{(byte)137,80,78,71,13,10,26,10});
    ByteArrayOutputStream header=new ByteArrayOutputStream();
    DataOutputStream data=new DataOutputStream(header);
    data.writeInt(width); data.writeInt(height); data.write(new byte[]{8,6,0,0,0});
    chunk("IHDR",header.toByteArray(),13);
  }
  private void chunk(String type, byte[] bytes, int length) throws IOException {
    byte[] tag=type.getBytes(java.nio.charset.StandardCharsets.US_ASCII);
    out.writeInt(length); out.write(tag); out.write(bytes,0,length);
    CRC32 crc=new CRC32(); crc.update(tag); crc.update(bytes,0,length); out.writeInt((int)crc.getValue());
  }
  public void writeRow(int[] argb) throws IOException {
    if (rows >= height || argb.length != width) throw new IllegalStateException("Invalid row");
    row[0]=0;
    for(int x=0;x<width;x++){ int c=argb[x],i=1+x*4; row[i]=(byte)(c>>16);row[i+1]=(byte)(c>>8);row[i+2]=(byte)c;row[i+3]=(byte)(c>>>24); }
    deflater.setInput(row);
    while(!deflater.needsInput()){ int n=deflater.deflate(compressed); if(n>0)chunk("IDAT",compressed,n); }
    rows++;
  }
  public void finish() throws IOException {
    if(rows!=height)throw new IllegalStateException("Incomplete image");
    deflater.finish(); while(!deflater.finished()){int n=deflater.deflate(compressed);if(n>0)chunk("IDAT",compressed,n);}
    chunk("IEND",new byte[0],0); out.flush();
  }
  public void close() throws IOException { deflater.end();out.close(); }
}
