# Personal Ely.by build

## Status

The native iOS app, offline identity tests, standard IPA, and TrollStore package
built successfully with Xcode 26.6 on GitHub's macOS runner. Build record:
https://github.com/Datedcascade/Amethyst-iOS/actions/runs/39517925273

Both downloaded artifact archives matched GitHub's SHA-256 digests. The IPA was
checked for its arm64 executable, account bridge, launcher JAR, Ely.by helper,
and all four Java runtimes. The Ely.by helper matched its pinned SHA-256 digest
in both install packages. Device sign-in, skins, server access, and compatibility
with your particular iOS versions still need testing.

Your prepared fork is https://github.com/Datedcascade/Amethyst-iOS.
Local install packages and their checksums are in `artifacts/`.

## Build from Windows using GitHub

1. Fork https://github.com/Taylen-chud/Amethyst-iOS into your own GitHub account.
2. Upload/commit the changed files from this workspace to your fork, preserving
   their folder paths. Include `Natives/authenticator/ElyAuthenticator.m` and
   `.github/workflows/personal-ely.yml`, which are new files. Do not upload the
   `.git` folder. The rest of the original source stays in your fork.
3. In your fork, open **Actions** and enable workflows if prompted.
4. Select **Personal Ely.by IPA**, choose **Run workflow**, and select your branch.
5. When the run succeeds, open it and download **Amethyst-Ely-iOS** under Artifacts
   for sideloading, or **Amethyst-Ely-iOS-TrollStore** for the TrollStore variant.
6. Extract the downloaded ZIP to find the IPA. Sign/install it with your chosen
   sideloading tool. This workflow does not provide an Apple provisioning profile
   or a development signature. JIT must also be enabled for Minecraft to run well.

If the run fails, share the first failed step's log, with credentials removed.
The original project has substantial native dependencies and external runtime
downloads, so a fresh build can take around 20 minutes.

## Build on a Mac

Install full Xcode, select it as the active developer directory, then install:

```sh
brew install make cmake ldid
brew install --cask temurin@8
git submodule update --init --recursive
gmake -j3 package PLATFORM=2 RELEASE=1
```

The IPA is written to `artifacts/`. For a TrollStore package, run:

```sh
gmake -j3 package PLATFORM=2 RELEASE=1 TROLLSTORE_JIT_ENT=1
```

## Sign in and verify

Open the account picker, choose **Add account > Ely.by**, and enter your email or
username and password. For two-factor authentication, enter your current code
in the separate optional field. A failed attempt can be retried from Add account.
Passwords are used only for the sign-in request. Access tokens are saved in the
iOS Keychain; account JSON files contain profile metadata and a client identifier.

Check these on your device:

- Sign in successfully, and confirm that the account is labeled Ely.by.
- Close/reopen the launcher and select the account to test token refresh.
- Check incorrect credentials and two-factor authentication failure/retry.
- Launch a supported Minecraft version and check your skin.
- Join a server configured for Ely.by authentication.
- Add an offline account, install a new Minecraft version, and launch it.
- Restart and check that the offline username and UUID stay the same.
- Verify that invalid offline usernames and names belonging to saved online
  accounts are rejected.
- Switch between Microsoft, Ely.by, and offline accounts and check each launch.
- Delete the Ely.by account and confirm it disappears; its local Keychain token
  is deleted using the launcher's existing account deletion path.

Ely.by accounts authenticate with Ely.by services. They do not grant access to
servers that require Microsoft/Mojang authentication. Old Minecraft versions
and mod combinations require separate compatibility testing. The Cosmetica
agent is skipped for Ely.by game launches to avoid competing skin providers.

Downloads are available regardless of the selected account provider. Offline
accounts need only a username (3–16 ASCII letters, numbers, or underscores),
use the standard case-sensitive Minecraft offline UUID, and require no network
authentication. Offline accounts support single-player and servers configured
for offline mode. Microsoft demo accounts retain their existing demo behavior.

Existing local accounts migrate to offline profiles on load. Their former
all-zero UUID changes to a username-derived UUID. Existing world files are not
modified or moved; inventory, advancements, and other player data associated
with the old UUID may need a separate migration. Back up existing worlds first.

The manual workflow runs offline identity and username-validation tests before
building. Those tests and both package builds passed on the GitHub runner.
Both standard IPA and TrollStore packages target the project's existing iOS 14+
minimum, which includes iOS 15. Installation and JIT on your other phone depend
on the sideloading/debugging method available on that device; iOS 27 compatibility
has not been verified by this work. A jailbreak alone does not establish which
TrollStore installation method is available, so use the package appropriate to
your existing installation tool.

Accounts are still stored by username, as in the original launcher. Adding an
Ely.by account with the same name as another saved provider is rejected; remove
the conflicting account first. If Ely.by rejects an expired token, remove the
saved account and sign in again.

## Dependencies and references

### LiveContainer and StikDebug in a second container

When launched without JIT inside LiveContainer, Amethyst now enables its own
`isJITNeeded` setting and installs the bundled Universal JIT script in
`LCAppInfo.plist` on devices requiring it. It exports the script to Documents
for manual import and prompts for a restart. It does not send a guest bundle ID
to an externally installed StikDebug: LiveContainer handles the host identity,
script and second-container handoff before starting the guest.

On iOS 17+, the initial account-menu JIT check now stops its spinner and explains
that JIT is checked at launch. Previously it left "Checking for JIT" visible
even though the check was deferred. LiveContainer guests also use this flow
when the guest does not report `get-task-allow` itself. TXM detection now first
checks the device tree, matching LiveContainer, instead of relying solely on
an OS-version heuristic that can misclassify older hardware.

In LiveContainer Settings > JIT, select **StikDebug (Another LiveContainer)**.
Import the pairing file into StikDebug, convert StikDebug to a shared app,
connect LocalDevVPN, and keep a second LiveContainer free. Restart Amethyst's
LiveContainer after its setup prompt, then run Amethyst from the app list.
If automatic configuration cannot be saved, hold Amethyst > Settings > enable
**Launch with JIT** and select `UniversalJIT26.js` from Amethyst's Documents
folder for devices requiring a script. Keep the JIT request open while the
handoff completes. Do not pre-enable JIT on the container with an unrelated
script. See [LiveContainer's JIT guide](https://livecontainer.github.io/docs/guides/jit-support).

The launch path is compile-checked in CI; this change still requires device
testing. A world startup failure after successful JIT acquisition can have a
separate cause; collect Amethyst's latest log and any iOS crash report.

- Ely.by API: https://docs.ely.by/en/minecraft-auth.html
- Game integration: https://docs.ely.by/en/authlib-injector.html
- Bundled at build time: authlib-injector 1.2.8 from its official GitHub release,
  checked against the release's SHA-256 digest before packaging.
- authlib-injector source/license: https://github.com/yushijinhun/authlib-injector

The implementation uses Ely.by's documented password API for personal builds.
Ely.by recommends OAuth for distributed launchers; an OAuth application and
registered redirect configuration would be needed for that alternative.

