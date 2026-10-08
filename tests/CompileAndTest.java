import javax.tools.ToolProvider;
import java.nio.file.*;
public class CompileAndTest {
 public static void main(String[] args)throws Exception{
  Files.createDirectories(Path.of("tests/.classes"));
  int code=ToolProvider.getSystemJavaCompiler().run(null,null,null,"-d","tests/.classes","modules/long-image/android/src/main/java/expo/modules/longimage/StreamingPng.java","tests/PngTest.java","tests/EncodeLarge.java");
  if(code!=0)throw new AssertionError("Compilation failed");
  Process p=new ProcessBuilder("java","-Xmx128m","-cp","tests/.classes","PngTest","tests/long-roundtrip.png").inheritIO().start();
  if(p.waitFor()!=0)throw new AssertionError("PNG test failed");
  Process large=new ProcessBuilder("java","-Xmx32m","-cp","tests/.classes","EncodeLarge","tests/large-roundtrip.png").inheritIO().start();
  if(large.waitFor()!=0)throw new AssertionError("Large export failed");
  Process verify=new ProcessBuilder("python","tests/verify_large.py","tests/large-roundtrip.png").inheritIO().start();
  if(verify.waitFor()!=0)throw new AssertionError("Large pixels changed");
 }
}
