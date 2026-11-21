import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DIGEST = "sha256:" + "ab" * 32


class SetChartImageTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.chart = shutil.copytree(ROOT / "chart/demo-app", Path(tmp.name) / "demo-app")
        self.values = self.chart / "values.yaml"

    def pin(self, digest):
        return subprocess.run([sys.executable, ROOT / "ci/set_chart_image.py", self.chart,
                               "demo.azurecr.io/demo-app", digest], capture_output=True, text=True)

    def render(self):
        return subprocess.run(["helm", "template", "demo", self.chart], capture_output=True, text=True)

    def test_bad_digest(self):
        before = self.values.read_bytes()
        result = self.pin("latest")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("invalid digest", result.stderr)
        self.assertEqual(self.values.read_bytes(), before)

    def test_renders_pinned_image(self):
        result = self.pin(DIGEST)
        self.assertEqual(result.returncode, 0, result.stderr)
        rendered = self.render()
        self.assertEqual(rendered.returncode, 0, rendered.stderr)
        for expected in ("image: demo.azurecr.io/demo-app@" + DIGEST, "setWeight: 20",
                         "rollbackWindow:", "revisions: 3", "replicas: 5"):
            self.assertIn(expected, rendered.stdout)

    def test_repeat_digest_is_stable(self):
        self.assertEqual(self.pin(DIGEST).returncode, 0)
        before = self.values.read_bytes()
        self.assertEqual(self.pin(DIGEST).returncode, 0)
        self.assertEqual(self.values.read_bytes(), before)

    def test_placeholder_chart_fails(self):
        rendered = self.render()
        self.assertNotEqual(rendered.returncode, 0)
        self.assertIn("image.digest is required", rendered.stderr)
