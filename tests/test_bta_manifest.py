"""Validate the pinned BTA launch metadata without launching downloaded code."""
import hashlib
import io
import json
from pathlib import Path
import struct
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]

class BTAManifestTests(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads((ROOT / "Natives/resources/bta/bta-8.0.1.json").read_text())

    def test_runtime_and_mobile_libraries(self):
        self.assertEqual(self.manifest["javaVersion"]["majorVersion"], 17)
        self.assertEqual(self.manifest["lwjglVersion"], "3.3.3")
        self.assertNotIn("inheritsFrom", self.manifest)
        for lib in self.manifest["libraries"]:
            self.assertNotIn("natives-", lib["name"])
            if not lib["name"].startswith("org.lwjgl:"):
                artifact = lib["downloads"]["artifact"]
                self.assertTrue(artifact["url"].startswith("https://"))
                self.assertNotIn("..", artifact["path"].split("/"))
                self.assertGreater(artifact["size"], 0)
                self.assertRegex(artifact["sha1"], r"^[0-9a-f]{40}$")
        vanilla = self.manifest["libraries"][-1]["downloads"]["artifact"]
        self.assertEqual(vanilla["sha1"], "43db9b498cb67058d2e12d394e6507722e71bb45")

    @unittest.skipUnless((ROOT / "research/bta.v8.0.1.mmc.zip").exists(), "Official package not present")
    def test_metadata_matches_official_package(self):
        data = (ROOT / "research/bta.v8.0.1.mmc.zip").read_bytes()
        self.assertEqual(hashlib.sha256(data).hexdigest(), "22fca951e22f9572e2e23437ce828bb67424f773eb913082e2e36aa917764236")
        with zipfile.ZipFile(io.BytesIO(data)) as package:
            upstream = json.loads(package.read("patches/net.minecraft.json"))
            client = package.read("jarmods/bta.jar")
        self.assertEqual(self.manifest["minecraftArguments"], upstream["minecraftArguments"])
        self.assertEqual(self.manifest["amethystClientSHA1"], hashlib.sha1(client).hexdigest())
        self.assertEqual({lib["name"] for lib in self.manifest["libraries"][:-2]}, {lib["name"] for lib in upstream["libraries"]})
        with zipfile.ZipFile(io.BytesIO(client)) as jar:
            main = self.manifest["mainClass"].replace(".", "/") + ".class"
            self.assertEqual(struct.unpack(">H", jar.read(main)[6:8])[0], 61)

if __name__ == "__main__":
    unittest.main()

