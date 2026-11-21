# 03. Azure Repos와 이미지 빌드

**목표:** v1을 빌드하고 ACR에 푸시한 뒤 **동일한 digest**를 별도 GitOps 저장소에 남깁니다.

## 1. 두 저장소 준비

👁️ **설명** — `demo-app`에는 *이미지를 만드는 재료*가, `demo-gitops`에는 *AKS가 실행할 이미지 주소*가 들어갑니다. 배포용 저장소에 앱 소스 전체를 넣으면 Argo CD가 읽을 `dev` 경로가 맞지 않습니다.

🟢 **실행 · 브라우저 / Azure DevOps → Repos**, 이후 **PC / PowerShell**

비공개 실습 프로젝트에 README 없는 빈 저장소 `demo-app`, `demo-gitops`를 만듭니다. 각 저장소의 **Clone → HTTPS**에서 URL을 복사합니다. 아래 명령은 로컬 원격 설정을 변경하지 않으며 새 저장소에만 실행합니다.

```powershell
$appUrl = Read-Host 'demo-app HTTPS URL'
$repo = Read-Host 'demo-gitops HTTPS URL'
git push $appUrl HEAD:refs/heads/main
$tree = git rev-parse HEAD:gitops-seed
$seed = git commit-tree $tree -m "Initialize workshop GitOps state"
git push $repo "${seed}:refs/heads/demo"
```

GitOps 저장소 루트에는 `dev/kustomization.yaml`이 보여야 합니다. seed는 처음 한 번만 게시합니다.

📋 **확인** — 브라우저의 브랜치 선택기를 확인하세요. 앱 쪽은 **main → `azure-pipelines.yml`**, GitOps 쪽은 **demo → `dev/kustomization.yaml`**이 보여야 합니다. 지금은 이미지 이름이 `example.invalid`인 것이 정상입니다. 첫 CI가 이 값을 교체합니다.

## 2. CI 권한 구성

👁️ **설명** — 한 번의 빌드에 두 ID가 쓰입니다. ACR에 쓰는 ID는 **서비스 연결**의 ID이고, Git에 쓰는 ID는 **프로젝트 Build Service**입니다. 이미지 푸시가 성공하고 Git 푸시만 실패했다면 ACR 권한을 넓혀도 해결되지 않습니다.

🟢 **실행 · 브라우저 / Project settings**

| 대상 | 설정 |
|---|---|
| Service connections | Azure Resource Manager 연결 `demo-acr-push`: Workload identity federation으로 인증하고 해당 ID에 **실습 ACR의 AcrPush만** 부여합니다. 구독 Contributor는 필요 없습니다. |
| Repos → `demo-gitops` → Branches → `demo` → Branch security | `<프로젝트> Build Service (<조직>)`에 Read와 Contribute를 허용합니다. Force push와 정책 우회는 허용하지 않습니다. ID가 없다면 첫 실행 후 다시 조회합니다. |
| Pipelines 설정 | job authorization을 현재 프로젝트와 명시적으로 참조한 저장소로 제한합니다. 실습 운영자만 파이프라인을 편집·실행하도록 하고 보호된 리소스 사용 승인은 해당 파이프라인에만 부여합니다. |

## 3. 실행하고 digest 비교

🟢 **실행 · 브라우저 / Pipelines → New pipeline**

**Azure Repos Git → demo-app → Existing Azure Pipelines YAML file → main → `/azure-pipelines.yml`**을 선택합니다. 변수 `acrName`, `acrLoginServer`에 02의 실제 값을 넣고 실행합니다. 사전 승인 요청이 뜨면 대상 연결·저장소와 브랜치를 확인합니다.

**예상 결과:** `Build`의 `publish` 로그에 SHA·태그·digest가 보이고, `UpdateGit`이 성공합니다. `demo-gitops:demo`의 `dev/kustomization.yaml`에서 `images[0].digest`가 로그와 같은지 확인합니다. 이 시점에는 **아직 앱이 배포되지 않았습니다.**

📋 **확인 · 같은 이미지인가요?** `Repos → Files → demo-gitops → demo`에서 `dev/kustomization.yaml`의 `newName`과 `digest`를 확인하세요. 아래 명령은 *실제 ACR에 게시된* digest 목록을 반환합니다. 파일의 값이 이 목록에 있어야 합니다.

```powershell
az acr manifest list-metadata -r $acr -n demo-app --query "[].digest" -o tsv
```

**트러블슈팅:** `TF401027 GenericContribute`는 ACR 문제가 아닙니다. 오류의 빌드 ID와 GitOps `demo` 브랜치 권한을 확인합니다. `non-fast-forward`라면 같은 커밋의 수동·자동 실행이 경합했는지 확인하고 강제 푸시는 하지 않습니다.

**완료 체크:** 이미지 digest와 대응하는 GitOps 커밋을 기록했습니다.

[← 이전](02-infrastructure.md) · [목차](../README.md) · [다음: 첫 배포 →](04-first-sync.md)
