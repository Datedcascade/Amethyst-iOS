import java.io.*;
import java.lang.reflect.*;
import java.net.*;
import java.util.function.Predicate;

/** Exercises actual official processors against an isolated Minecraft fixture. */
public class ForgeClientInstallSmokeTest {
    public static void main(String[] args) throws Exception {
        File installer = new File(args[0]).getCanonicalFile();
        File root = new File(args[1]).getCanonicalFile();
        try (URLClassLoader loader = new URLClassLoader(new URL[]{installer.toURI().toURL()}, ClassLoader.getSystemClassLoader().getParent())) {
            Class<?> runner = Class.forName("net.kdt.pojavlaunch.ModpackLoaderInstaller");
            Method factory = runner.getDeclaredMethod("clientAction", ClassLoader.class);
            factory.setAccessible(true);
            Object action = factory.invoke(null, loader);
            Object success;
            try { success = action.getClass().getMethod("run",File.class,File.class).invoke(action,root,installer); }
            catch (NoSuchMethodException e) {
                success = action.getClass().getMethod("run",File.class,Predicate.class,File.class).invoke(action,root,(Predicate<String>)ignored->true,installer);
            }
            if (!Boolean.TRUE.equals(success)) throw new AssertionError("Official client action returned false");
            File installed = new File(root,"versions/1.20.1-forge-47.4.0/1.20.1-forge-47.4.0.json");
            File patched = new File(root,"libraries/net/minecraftforge/forge/1.20.1-47.4.0/forge-1.20.1-47.4.0-client.jar");
            if (!installed.isFile() || !patched.isFile() || patched.length()==0) throw new AssertionError("Missing installed loader or processed client");
            System.out.println("Full Forge client installation and processor outputs verified");
        }
    }
}

