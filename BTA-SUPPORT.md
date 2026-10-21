# Better than Adventure and personal service defaults

Build and package checks passed for source commit
`bc0f8469dd0c375915eee1640dbccc54196b0b09`:
https://github.com/Datedcascade/Amethyst-iOS/actions/runs/39542044680

The verified personal IPA and TrollStore packages are in
`artifacts/bta-personal/`, alongside SHA-256 checksums and installation notes.
Both original CI archives matched GitHub's digests. Checks confirmed the arm64
executable, BTA installer and profile metadata, launcher classpath change, and
private configuration; personalization preserved the original app entries.

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

The startup repair pins sizes and SHA-1 hashes for all 19 downloadable libraries,
including fastutil 8.5.15. Existing launcher-owned BTA 8.0.1 metadata is refreshed
on Play. File progress remains incomplete until each download is moved and
verified; this prevents the launcher from starting with a missing dependency.
The old-phone log confirmed missing fastutil, with working Java 17 and JIT.
The newer phone's separate LiveContainer exit still needs device verification.

Modpacks now has Modrinth and CurseForge tabs. CurseForge client ZIP manifests
resolve required project/file IDs through the official API, check hashes, and
extract overrides into a separate instance folder. Fabric/Quilt metadata is
installed automatically; Forge/NeoForge must first be installed through Profiles
+ with the exact version requested by the pack. Packs with API-blocked required
files report the project/file IDs and stop instead of installing an incomplete
pack. This does not guarantee that desktop mods are compatible with iOS.

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

To prepare a personal IPA from an extracted CI download, keep the private plist
locally and run `python3 scripts/personalize_ipa.py original.ipa personal.ipa`.
Import the resulting package into LiveContainer or sign it normally with your
sideloading tool. The script preserves every original ZIP entry byte-for-byte
and adds the configuration; it does not provide an Apple signing identity.

