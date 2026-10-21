import java.io.*;
import java.net.*;
import java.util.*;

public class BTAClassVisibilityTests {
    public static void main(String[] args) throws Exception {
        File folder = new File(args[0]);
        List<URL> all = new ArrayList<>();
        all.add(new File(folder,"bta.jar").toURI().toURL());
        all.add(new File(folder,"bridge.jar").toURI().toURL());
        all.add(new File(args[1]).toURI().toURL());
        for (File jar : folder.listFiles()) if (jar.getName().endsWith(".jar")) all.add(jar.toURI().toURL());
        ClassLoader platform = ClassLoader.getSystemClassLoader().getParent();
        URL[] previous = {all.get(1),all.get(2)};
        try (URLClassLoader parent = new URLClassLoader(previous,platform)) {
            try {
                Class.forName("org.lwjgl.opengl.Display",false,parent).getDeclaredMethods();
                throw new AssertionError("The old parent classpath unexpectedly sees BTA's GameWindowGLFW");
            } catch (NoClassDefFoundError expected) {
                System.out.println("Reproduced old bridge/client class visibility failure: "+expected);
            }
        }
        try (URLClassLoader parent = new URLClassLoader(all.toArray(new URL[0]),platform)) {
            Class<?> display = Class.forName("org.lwjgl.opengl.Display",false,parent);
            Class<?> gameWindow = Class.forName("net.minecraft.client.render.window.GameWindowGLFW",false,parent);
            if (display.getMethod("getWindow").getReturnType()!=gameWindow) throw new AssertionError("Bridge and game classes use different loaders");
            System.out.println("BTA bridge and client resolve together without initializing iOS graphics natives");
        }
    }
}

