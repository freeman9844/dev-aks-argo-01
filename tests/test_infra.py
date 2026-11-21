import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent


class ArgoCdFederationTests(unittest.TestCase):
    """Argo CD 워크로드 ID 페더레이션은 Bicep이 아니라 02 교재의 별도 CLI 단계에서 만듭니다."""

    def setUp(self):
        self.bicep = (ROOT / "infra" / "main.bicep").read_text(encoding="utf-8")
        self.doc = (ROOT / "docs" / "02-infrastructure.md").read_text(encoding="utf-8")

    def test_bicep_leaves_federation_to_cli_step(self):
        self.assertNotRegex(self.bicep, r"(?m)^resource .*federatedIdentityCredentials")
        self.assertRegex(self.bicep, r"(?m)^output argocdIdentityName string = argocdIdentity\.name")

    def test_doc_creates_federation_for_repo_server(self):
        cmd = re.search(r"az identity federated-credential create[^\n]*", self.doc)
        self.assertIsNotNone(cmd, "02 교재에 페더레이션 생성 명령이 없습니다")
        line = cmd.group(0)
        self.assertIn("--subject system:serviceaccount:argocd:argocd-repo-server", line)
        self.assertIn("--audiences api://AzureADTokenExchange", line)
        self.assertIn("--issuer $issuer", line)
        self.assertIn("oidcIssuerProfile.issuerUrl", self.doc)
        self.assertIn("outputs.argocdIdentityName.value", self.doc)


if __name__ == "__main__":
    unittest.main()
