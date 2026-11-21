import unittest

from app.server import version_payload


class VersionTests(unittest.TestCase):
    def test_version_payload(self):
        self.assertEqual(version_payload("v1", "abc123"), {"version": "v1", "commit": "abc123"})
