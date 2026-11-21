import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dev = shutil.copytree(ROOT / "gitops-seed/dev", Path(tmp.name) / "dev")
        self.manifest = self.dev / "kustomization.yaml"

    def release(self, digest):
        return subprocess.run([sys.executable, ROOT / "ci/release.py", self.dev,
                               "demo.azurecr.io/demo-app", digest], capture_output=True, text=True)

    def test_bad_digest(self):
        before = self.manifest.read_bytes()
        result = self.release("latest")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("invalid digest", result.stderr)
        self.assertEqual(self.manifest.read_bytes(), before)

    def test_repeat_digest(self):
        digest = "sha256:" + "ab" * 32
        first = self.release(digest)
        self.assertEqual(first.returncode, 0, first.stderr)
        rendered = subprocess.check_output(["kubectl", "kustomize", self.dev], text=True)
        self.assertIn("image: demo.azurecr.io/demo-app@" + digest, rendered)
        before = self.manifest.read_bytes()
        self.assertEqual(self.release(digest).returncode, 0)
        self.assertEqual(self.manifest.read_bytes(), before)
