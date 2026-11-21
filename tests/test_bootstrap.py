import pathlib
import unittest

BOOTSTRAP = pathlib.Path(__file__).resolve().parent.parent / "bootstrap"


class BootstrapTests(unittest.TestCase):
    def test_application_is_manual_sync(self):
        text = (BOOTSTRAP / "application.yaml").read_text(encoding="utf-8")
        self.assertNotIn("automated", text)
        self.assertIn("ACR_LOGIN_SERVER/helm", text)
        self.assertIn("chart: demo-app", text)

    def test_project_permits_rollout_children_for_ui_tree(self):
        # Argo CD는 프로젝트가 허용하지 않은 종류를 리소스 트리에서 숨깁니다.
        text = (BOOTSTRAP / "project.yaml").read_text(encoding="utf-8")
        for group, kind in [("apps", "ReplicaSet"), ("''", "Pod")]:
            self.assertRegex(text, rf"- group: {group}\s+kind: {kind}\b")


if __name__ == "__main__":
    unittest.main()
