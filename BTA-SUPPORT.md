# Better than Adventure and personal service defaults

Profiles > + > Better than Adventure! installs the official BTA 8.0.1 package.
The installer checks its SHA-256, extracts only `jarmods/bta.jar`, and creates a
Java 17 profile with a separate `bta-8.0.1` game folder. Existing worlds are not
imported. Game libraries download through the normal launcher on first Play.

The metadata follows the official Prism/MultiMC package, uses Amethyst's patched
LWJGL 3.3.3, and puts BTA's `legacy-lwjgl3` library ahead of bundled LWJGLX. BTA's
client classes/resources take precedence over vanilla Beta's client JAR. Desktop
native libraries are not installed. Discord rich presence is disabled in the
new game folder because its desktop SDK is unavailable on iOS. iOS graphics,
controls and world startup still need testing; this installer is experimental.

This integration currently targets 8.0.1 only; it does not automatically update
or claim compatibility with historic BTA versions or mod loaders.

Sources:
- https://www.betterthanadventure.net/downloads/
- https://www.betterthanadventure.net/installation-guide/
- https://downloads.betterthanadventure.net/bta-client/release/v8.0.1/bta.v8.0.1.mmc.zip

`tests/test_bta_manifest.py` checks runtime/library metadata. With the official
archive at `research/bta.v8.0.1.mmc.zip`, it also verifies the pinned package,
dependency list, client hash and Java class version without executing the game.

The personal CurseForge default is read from the optional bundled
`PersonalServices.plist`, with a `CurseForgeAPIKey` string. This file is ignored
by Git and is not published to the public fork. The supplied key was validated
against the official CurseForge API. A user-saved Keychain key overrides it;
Remove Key disables the bundled default too. Builds without the private file
continue to require entering a key in Settings. Only the locally prepared
personal IPA includes the supplied default; public CI artifacts do not.

