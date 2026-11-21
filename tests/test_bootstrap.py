import pathlib
import unittest

BOOTSTRAP = pathlib.Path(__file__).resolve().parent.parent / "bootstrap"


class BootstrapTests(unittest.TestCase):
    def test_application_is_manual_sync(self):
        text = (BOOTSTRAP / "application.yaml").read_text(encoding="utf-8")
        self.assertNotIn("automated", text)
        self.assertIn("ACR_LOGIN_SERVER/helm", text)
        self.assertIn("chart: demo-app", text)


if __name__ == "__main__":
    unittest.main()
