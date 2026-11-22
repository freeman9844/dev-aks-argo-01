"""Helm 차트의 이미지를 ACR digest로 고정하는 CI 보조 스크립트입니다.

azure-pipelines.yml의 Build Job이 이미지를 ACR에 push한 직후 호출합니다.

    python3 ci/set_chart_image.py chart/demo-app "$ACR_LOGIN_SERVER/demo-app" "$digest"

왜 태그가 아니라 digest인가요?
  - 태그(예: demo-app:v2)는 나중에 다른 이미지를 가리키도록 덮어쓸 수 있습니다.
  - digest(sha256:...)는 이미지 내용의 해시라서 바뀌지 않습니다.
  - 차트 버전 1.0.<빌드 ID> 하나가 정확히 이미지 하나를 가리키므로,
    Argo CD History에서 이전 차트 버전으로 Rollback하면 이미지도 정확히 그때로 돌아갑니다.

동작:
  1. digest 형식을 검사합니다. 잘못되면 파일을 건드리지 않고 종료 코드 2로 실패합니다.
  2. <차트>/values.yaml의 image 항목을 {repository, digest}로 바꿉니다.
     차트 템플릿(templates/rollout.yaml)은 이 값을 "<repository>@<digest>"로 조합합니다.
  3. 같은 값으로 다시 실행해도 결과 파일이 같습니다(멱등).

저장소에 커밋된 values.yaml에는 자리표시자(example.invalid, 빈 digest)만 들어 있습니다.
실제 ACR 주소와 digest는 빌드할 때마다 이 스크립트가 채우고, 그 결과는 차트 패키지에만 담겨
ACR(helm/demo-app)로 올라갑니다. 저장소의 values.yaml은 바뀌지 않습니다(커밋하지 않음).
"""

import argparse
import json
import re
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description="Pin the chart image to an ACR digest.")
    # 차트 폴더 경로. 이 안의 values.yaml을 수정합니다. 예: chart/demo-app
    parser.add_argument("chart", type=Path)
    # 태그나 digest를 뺀 이미지 저장소 주소. 예: acrargo1a2b3c4d.azurecr.io/demo-app
    parser.add_argument("repository")
    # ACR이 알려 준 이미지 digest. 예: sha256:0123...(16진수 64자)
    parser.add_argument("digest")
    args = parser.parse_args()

    # digest 형식만 허용합니다. "latest" 같은 태그나 빈 값이 들어오면 차트가 움직이는
    # 이미지를 가리키게 되므로, 파일을 쓰기 전에 여기서 막습니다(parser.error는 종료 코드 2).
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", args.digest):
        parser.error("invalid digest: expected sha256 followed by 64 lowercase hex digits")

    path = args.chart / "values.yaml"
    # values.yaml은 JSON 형식으로 저장되어 있습니다. JSON은 그대로 올바른 YAML이므로 Helm이 읽을 수 있고,
    # CI 에이전트에 YAML 라이브러리(PyYAML)를 따로 설치하지 않아도 표준 라이브러리 json만으로 고칠 수 있습니다.
    values = json.loads(path.read_text(encoding="utf-8"))

    # image 항목 전체를 새로 씁니다. 다른 값(replicas 등)은 그대로 둡니다.
    values["image"] = {"repository": args.repository, "digest": args.digest}

    # 들여쓰기와 마지막 줄바꿈을 고정해 같은 입력이면 항상 같은 파일이 나오게 합니다.
    path.write_text(json.dumps(values, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()