"""Add an ignored personal services configuration to an IPA before signing."""
import argparse
import hashlib
from pathlib import Path
import plistlib
import shutil
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("input", type=Path)
parser.add_argument("output", type=Path)
parser.add_argument("--config", type=Path, default=Path(__file__).resolve().parents[1] / "Natives/resources/PersonalServices.plist")
args = parser.parse_args()
if args.input.resolve() == args.output.resolve():
    parser.error("Input and output must be different files")
services = plistlib.loads(args.config.read_bytes())
key = services.get("CurseForgeAPIKey")
if not isinstance(key, str) or not key.strip():
    parser.error("Configuration must contain a nonempty CurseForgeAPIKey")
with zipfile.ZipFile(args.input) as archive:
    bundles = [n for n in archive.namelist() if n.startswith("Payload/") and n.endswith(".app/Info.plist") and n.count("/") == 2]
    if len(bundles) != 1:
        parser.error("Expected exactly one application bundle")
    target = bundles[0].removesuffix("Info.plist") + "PersonalServices.plist"
    if target in archive.namelist():
        parser.error("Package already contains personal configuration; use the original CI package")
args.output.parent.mkdir(parents=True, exist_ok=True)
with args.input.open("rb") as source, args.output.open("xb") as output:
    shutil.copyfileobj(source, output)
with zipfile.ZipFile(args.output, "a", compression=zipfile.ZIP_DEFLATED) as archive:
    archive.writestr(target, plistlib.dumps({"CurseForgeAPIKey": key.strip()}))
with zipfile.ZipFile(args.output) as archive:
    assert plistlib.loads(archive.read(target))["CurseForgeAPIKey"] == key.strip()
print("Prepared personal package; import it into LiveContainer or sign it with your sideloading tool.")
print("SHA256:", hashlib.file_digest(args.output.open("rb"), "sha256").hexdigest())

