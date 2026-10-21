package net.kdt.pojavlaunch;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import java.io.*;
import java.lang.reflect.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.function.Predicate;
import net.kdt.pojavlaunch.uikit.UIKit;

/** Runs the official client action without Swing prompts or System.exit(). */
public final class ModpackLoaderInstaller {
    private static Object clientAction(ClassLoader loader) throws Exception {
        Class<?> installer = Class.forName("net.minecraftforge.installer.SimpleInstaller", true, loader);
        installer.getField("headless").setBoolean(null, true);
        Class<?> util = Class.forName("net.minecraftforge.installer.json.Util", true, loader);
        Object install = util.getMethod("loadInstallProfile").invoke(null);
        Class<?> callback = Class.forName("net.minecraftforge.installer.actions.ProgressCallback", true, loader);
        Object progress = callback.getMethod("withOutputs", OutputStream[].class)
                .invoke(null, (Object)new OutputStream[]{System.out});
        Class<?> actions = Class.forName("net.minecraftforge.installer.actions.Actions", true, loader);
        Object client = actions.getField("CLIENT").get(null);
        for (Method method : actions.getMethods()) {
            if (method.getName().equals("getAction") && method.getParameterTypes().length == 2)
                return method.invoke(client, install, progress);
        }
        throw new IOException("Unsupported Forge/NeoForge client installer API");
    }

    private static Method runMethod(Object action) throws NoSuchMethodException {
        try { return action.getClass().getMethod("run", File.class, File.class); }
        catch (NoSuchMethodException e) {
            return action.getClass().getMethod("run", File.class, Predicate.class, File.class);
        }
    }

    private static JsonObject read(File file) throws IOException {
        try (Reader input = new InputStreamReader(new FileInputStream(file), StandardCharsets.UTF_8)) {
            return new JsonParser().parse(input).getAsJsonObject();
        }
    }

    private static void save(File file, JsonObject request) throws IOException {
        Path temporary = file.toPath().resolveSibling(file.getName()+".tmp");
        Files.write(temporary, request.toString().getBytes(StandardCharsets.UTF_8));
        try { Files.move(temporary, file.toPath(), StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE); }
        catch (AtomicMoveNotSupportedException e) { Files.move(temporary, file.toPath(), StandardCopyOption.REPLACE_EXISTING); }
    }

    public static void run(String installerPath, String requestPath) throws Throwable {
        File requestFile = new File(requestPath).getCanonicalFile();
        File root = new File(System.getenv("GAME_DIR")).getCanonicalFile();
        if (!requestFile.equals(new File(root, "amethyst-pending-loader.json")))
            throw new IOException("Invalid loader request location");
        JsonObject request = read(requestFile);
        if (request.get("schema").getAsInt()!=1 || !new File(request.get("gameRoot").getAsString()).getCanonicalFile().equals(root))
            throw new IOException("Invalid loader request");
        try {
            request.addProperty("status", "running");
            save(requestFile, request);
            Object action = clientAction(ClassLoader.getSystemClassLoader());
            Method run = runMethod(action);
            System.out.println("[ModpackLoader] Running official client action: " + request.get("versionID").getAsString());
            Object result = run.getParameterTypes().length==2
                    ? run.invoke(action, root, new File(installerPath))
                    : run.invoke(action, root, (Predicate<String>)ignored -> true, new File(installerPath));
            if (!Boolean.TRUE.equals(result)) throw new IOException("The official loader installer reported a failure. See latestlog.txt.");
            String id = request.get("versionID").getAsString();
            JsonObject installed = read(new File(root, "versions/"+id+"/"+id+".json"));
            if (!id.equals(installed.get("id").getAsString())) throw new IOException("Loader version verification failed");
            request.addProperty("status", "complete");
            save(requestFile, request);
        } catch (Throwable failure) {
            Throwable cause = failure instanceof InvocationTargetException ? ((InvocationTargetException)failure).getCause() : failure;
            cause.printStackTrace();
            request.addProperty("status", "failed");
            request.addProperty("error", cause.toString());
            save(requestFile, request);
            UIKit.showError("Loader installation failed", "The modpack files are preserved. Restart Amethyst to retry.\n"+cause, true);
            return;
        }
        UIKit.showError("Loader installed", "Restart Amethyst to finish adding the modpack profile. Its files are already downloaded.", true);
    }

    // CI validates the reflection contract against real official installer JARs,
    // using an isolated loader so bundled installer dependencies are exercised.
    public static void main(String[] args) throws Exception {
        if (args.length!=2 || !args[0].equals("--inspect-installer")) throw new IllegalArgumentException("Expected --inspect-installer <jar>");
        try (URLClassLoader loader = new URLClassLoader(new URL[]{new File(args[1]).toURI().toURL()}, ClassLoader.getSystemClassLoader().getParent())) {
            Object action = clientAction(loader);
            System.out.println("Verified official client action: " + runMethod(action));
        }
    }
}

