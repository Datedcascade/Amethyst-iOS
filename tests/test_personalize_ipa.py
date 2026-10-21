import hashlib
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
import zipfile

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/personalize_ipa.py"

class PersonalPackageTests(unittest.TestCase):
    def test_private_configuration_preserves_original_package(self):
        workspace = SCRIPT.parent.parent.resolve()
        (workspace / "artifacts").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace / "artifacts", prefix="personal-package-test-") as directory:
            root = Path(directory)
            self.assertTrue(root.resolve().is_relative_to(workspace / "artifacts"))
            source, output, config = root / "source.ipa", root / "personal.ipa", root / "config.plist"
            with zipfile.ZipFile(source, "w") as archive:
                archive.writestr("Payload/Test.app/Info.plist", plistlib.dumps({"CFBundleExecutable": "Test"}))
                archive.writestr("Payload/Test.app/Test", b"test executable bytes")
            original_hash = hashlib.sha256(source.read_bytes()).digest()
            config.write_bytes(plistlib.dumps({"CurseForgeAPIKey": "test-key"}))
            subprocess.run([sys.executable, str(SCRIPT), str(source), str(output), "--config", str(config)], check=True, capture_output=True)
            self.assertEqual(hashlib.sha256(source.read_bytes()).digest(), original_hash)
            with zipfile.ZipFile(source) as original, zipfile.ZipFile(output) as personal:
                for name in original.namelist():
                    self.assertEqual(original.read(name), personal.read(name))
                self.assertEqual(plistlib.loads(personal.read("Payload/Test.app/PersonalServices.plist"))["CurseForgeAPIKey"], "test-key")
            result = subprocess.run([sys.executable, str(SCRIPT), str(output), str(root / "again.ipa"), "--config", str(config)], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((root / "again.ipa").exists())

if __name__ == "__main__":
    unittest.main()

