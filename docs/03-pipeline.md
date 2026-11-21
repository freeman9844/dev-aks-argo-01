# 03. Azure Repos와 이미지 빌드

**목표:** v1을 빌드하고 ACR에 푸시한 뒤 **동일한 digest**를 별도 GitOps 저장소에 남깁니다.

### 1. 두 저장소 준비 · Azure DevOps → Repos

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

### 2. CI 권한 구성 · Project settings

| 대상 | 설정 |
|---|---|
| Service connections | Azure Resource Manager 연결 `demo-acr-push`: Workload identity federation으로 인증하고 해당 ID에 **실습 ACR의 AcrPush만** 부여합니다. 구독 Contributor는 필요 없습니다. |
| Repos → `demo-gitops` → Branches → `demo` → Branch security | `<프로젝트> Build Service (<조직>)`에 Read와 Contribute를 허용합니다. Force push와 정책 우회는 허용하지 않습니다. ID가 없다면 첫 실행 후 다시 조회합니다. |
| Pipelines 설정 | job authorization을 현재 프로젝트와 명시적으로 참조한 저장소로 제한합니다. 실습 운영자만 파이프라인을 편집·실행하도록 하고 보호된 리소스 사용 승인은 해당 파이프라인에만 부여합니다. |

### 3. 실행하고 digest 비교 · Pipelines → New pipeline

**Azure Repos Git → demo-app → Existing Azure Pipelines YAML file → main → `/azure-pipelines.yml`**을 선택합니다. 변수 `acrName`, `acrLoginServer`에 02의 실제 값을 넣고 실행합니다. 사전 승인 요청이 뜨면 대상 연결·저장소와 브랜치를 확인합니다.

**예상 결과:** `Build`의 `publish` 로그에 SHA·태그·digest가 보이고, `UpdateGit`이 성공합니다. `demo-gitops:demo`의 `dev/kustomization.yaml`에서 `images[0].digest`가 로그와 같은지 확인합니다. 이 시점에는 **아직 앱이 배포되지 않았습니다.**

**트러블슈팅:** `TF401027 GenericContribute`는 ACR 문제가 아닙니다. 오류의 빌드 ID와 GitOps `demo` 브랜치 권한을 확인합니다. `non-fast-forward`라면 같은 커밋의 수동·자동 실행이 경합했는지 확인하고 강제 푸시는 하지 않습니다.

**완료 체크:** 이미지 digest와 대응하는 GitOps 커밋을 기록했습니다.

[← 이전](02-infrastructure.md) · [목차](../README.md) · [다음: 첫 배포 →](04-first-sync.md)
