# 03. Azure Repos와 CI 연결

**목표:** `demo-app` 저장소와 파이프라인을 만들고, 첫 실행으로 v1 이미지와 Helm 차트를 ACR에 올립니다. 파이프라인에는 Argo CD에 Sync를 요청할 `ci` 토큰을 비밀 변수로 넣습니다.

## 1. 앱 저장소 준비

👁️ **설명** — 이번 단계에서 Git 저장소는 **앱 소스용 `demo-app` 하나**뿐입니다. 배포 명세(차트)는 파이프라인이 빌드마다 만들어 ACR에 올리므로 별도 배포용 저장소가 필요하지 않습니다.

🟢 **실행 · 브라우저 / Azure DevOps → Repos**, 이후 **PC / PowerShell**

1. 비공개 실습 프로젝트에서 **Repos → Files → 상단 저장소 이름 ▼ → New repository**를 엽니다. 유형 **Git**, 이름 `demo-app`, **Add a README** 해제 후 **Create**를 선택합니다.
2. **Clone → HTTPS** 주소를 복사합니다. 마지막 경로가 `/_git/demo-app`인지 확인하세요.
3. PC로 돌아와 다음을 실행합니다. 로컬 원격 설정은 바꾸지 않고 새 저장소에만 push합니다.

```powershell
$appUrl = Read-Host 'demo-app HTTPS URL'
git push $appUrl HEAD:refs/heads/main
```

📋 **확인** — 브라우저에서 `demo-app`의 **main** 브랜치를 열면 루트에 `azure-pipelines.yml`, `app/`, `chart/`, `ci/`가 보여야 합니다. `chart/demo-app/values.yaml`의 이미지 주소가 `example.invalid`인 것은 정상입니다. 파이프라인이 빌드할 때마다 실제 ACR 주소와 digest로 바꿔 차트를 만듭니다.

## 2. ACR 서비스 연결

👁️ **설명** — 파이프라인이 ACR에 이미지와 차트를 push할 때 쓰는 ID입니다. 02에서 Bicep이 만든 관리 ID `id-ci-<AKS 이름>`이 **이 ACR 하나에 대해서만 `AcrPush`**를 가지고 있습니다. 서비스 연결을 **Managed identity** 방식으로 만들면 Azure DevOps가 이 ID에 페더레이션 자격 증명을 자동으로 추가합니다. 비밀번호도 앱 등록도 필요 없습니다. Argo CD를 부르는 `ci` 토큰과는 별개이므로, 이미지 push가 실패하면 이 연결을, Sync 요청이 실패하면 `ci` 토큰을 봅니다.

🟢 **실행 · 참가자 PC / PowerShell** — 고를 관리 ID 이름을 확인합니다.

```powershell
az deployment group show -g $rg -n demo-infra --query properties.outputs.ciIdentityName.value -o tsv
```

🟢 **실행 · 브라우저 / Azure DevOps → Project settings → Service connections → New service connection**

1. **Azure Resource Manager**를 고르고 **Next**를 누릅니다.
2. Identity type에서 **Managed identity**를 고릅니다.

| 구역 | 항목 | 값 |
|---|---|---|
| Step 1: Managed identity details | Subscription for Managed Identity | 실습 구독 |
| Step 1 | Resource group for Managed Identity | 02의 `$rg` |
| Step 1 | Managed Identity | 위에서 확인한 `id-ci-<AKS 이름>` |
| Step 2: Azure Scope | Scope Level | `Subscription` |
| Step 2 | Subscription for service connection | 실습 구독 |
| Step 2 | Resource group for service connection | 02의 `$rg` |
| Step 3: Service connection details | Service Connection Name | `demo-acr-push` — YAML의 `azureSubscription: demo-acr-push`와 같아야 합니다. |
| Security | Grant access permission to all pipelines | **체크하지 않습니다.** 4절 첫 실행 때 이 파이프라인만 승인합니다. |

3. **Save**를 누릅니다.

📋 **확인** — 목록에 `demo-acr-push`가 보이고, PC에서 아래 명령의 결과가 1 이상입니다. Azure DevOps가 관리 ID에 페더레이션 자격 증명을 추가했다는 뜻입니다.

```powershell
$ciId = az deployment group show -g $rg -n demo-infra --query properties.outputs.ciIdentityName.value -o tsv
az identity federated-credential list -g $rg --identity-name $ciId --query "length(@)"
```

⚠️ **주의** — 연결 화면의 범위(리소스 그룹)는 *어디를 대상으로 하는 연결인지*를 적는 값일 뿐 권한을 주지 않습니다. 실제 권한은 Bicep이 준 ACR 범위 `AcrPush` 하나뿐입니다. 구독 Contributor 같은 넓은 역할을 추가하지 마세요.

## 3. Argo CD에서 `ci` 토큰 만들기

👁️ **설명** — 파이프라인은 admin 계정을 쓰지 않습니다. 02에서 Bicep이 만든 전용 계정 `ci`는 `demo` 프로젝트의 `demo-app` 하나에 대해 **조회, 차트 버전 변경, Sync**만 할 수 있습니다. 삭제나 다른 앱 조작은 거부됩니다. 토큰은 만들 때 **한 번만** 보이므로 바로 파이프라인 비밀 변수에 붙여 넣습니다.

🟢 **실행 · 브라우저 / Argo CD UI**

1. 02에서 연 Argo CD에서 **Settings → Accounts → ci**를 선택합니다.
2. **Tokens** 영역의 **GENERATE NEW**를 누르고 **Expires In**에 실습 기간(예: `7d`)을 입력한 뒤 생성합니다.
3. 나타난 토큰을 복사해 다음 절의 `argocdToken` 변수에 바로 붙여 넣습니다. 메모장, 채팅, 스크린샷에 남기지 않습니다.

## 4. 파이프라인 등록과 첫 실행

🟢 **실행 · 브라우저 / Pipelines → New pipeline**

1. **Pipelines → New pipeline**(첫 파이프라인이면 **Create Pipeline**)에서 **Azure Repos Git → demo-app → Existing Azure Pipelines YAML file**을 선택합니다. 브랜치 `main`, 경로 `/azure-pipelines.yml`로 **Continue**합니다.
2. 검토 화면의 **Variables → New variable**에서 아래 네 개를 추가합니다.

| 이름 | 값 | 비밀 여부 |
|---|---|---|
| `acrName` | 02의 `$acr` | 아니요 |
| `acrLoginServer` | 02의 `$loginServer` (`https://` 없이) | 아니요 |
| `argocdServer` | 02의 `$argocdServer` (IP만, `https://` 없이) | 아니요 |
| `argocdToken` | 3절에서 만든 토큰 | **Keep this value secret** 체크 |

3. **Save → Run**으로 실행합니다. 리소스 승인 요청이 뜨면 연결·저장소가 실습 대상인지 확인한 뒤 해당 파이프라인만 승인하세요.

👁️ **설명 · 두 Job이 하는 일** — [`azure-pipelines.yml`](../azure-pipelines.yml)은 두 Job으로 나뉩니다.

| Job | 하는 일 | 결과물 |
|---|---|---|
| `Build` | 단위 테스트 → 이미지 빌드·push → digest를 values에 고정 → 차트 `1.0.<빌드 ID>` 패키징·push | ACR의 `demo-app` 이미지, `helm/demo-app` 차트 |
| `Deploy` | Argo CD 서버에서 같은 버전 CLI를 내려받아 `ci` 토큰으로 로그인 확인 → Application이 있으면 차트 버전 지정 → Sync 요청 → Sync 완료 대기 | Argo CD History의 새 항목 |

📋 **확인 · 첫 실행 결과** — 두 Job 모두 성공하지만 `Deploy`에는 **경고 1건**이 있어야 정상입니다.

```text
Argo CD Application demo-app이 아직 없습니다. 04 단계에서 Application을 만든 뒤 파이프라인을 다시 실행하세요. (차트 1.0.<빌드 ID> 은 ACR에 푸시됨)
```

Application은 04에서 UI로 만듭니다. 그 전까지 파이프라인은 ACR에 차트만 올리고 배포는 하지 않습니다. 같은 로그 위쪽의 `Username: ci`는 토큰과 주소가 맞다는 뜻입니다.

**Jobs → Build → Push image and Helm chart to ACR** 로그에서 아래 두 줄을 찾아 값을 기록합니다.

```text
<앱 커밋 SHA> -> <ACR>/demo-app:<태그> -> sha256:<digest>
chart: oci://<ACR>/helm/demo-app:1.0.<빌드 ID>
```

PC에서도 ACR에 실제로 올라갔는지 확인합니다.

```powershell
az acr manifest list-metadata -r $acr -n demo-app --query "[].digest" -o tsv
az acr repository show-tags -n $acr --repository helm/demo-app -o tsv
```

첫 출력에 로그의 digest가, 두 번째 출력에 로그의 차트 버전이 있어야 합니다.

**트러블슈팅**

| 증상 | 원인과 조치 |
|---|---|
| `Build`의 push에서 `unauthorized` | 서비스 연결이 `id-ci-<AKS 이름>`을 가리키는지, 그 ID에 실습 ACR의 `AcrPush`가 있는지 확인합니다. Argo CD 토큰과는 무관합니다. |
| `Build`의 Azure 로그인에서 `AADSTS700213`·`No matching federated identity` | 2절 확인 명령의 결과가 0입니다. 서비스 연결을 삭제하고 2절을 다시 수행합니다. |
| `Deploy`가 `curl`에서 실패 | `argocdServer`에 `https://`나 공백이 없는지, 02의 공인 IP가 그대로인지 확인합니다. |
| `Deploy`가 `account get-user-info`에서 실패 | 토큰이 틀렸거나 만료됐습니다. 3절에서 새로 만들어 `argocdToken`을 바꿉니다. |
| Application이 있는데 `PermissionDenied` | 계정 `ci`의 권한이 템플릿과 다릅니다. 확장 설정은 직접 고치지 말고 02의 배포 명령을 다시 실행합니다. |
| 코드를 push했는데 실행이 바로 안 보임 | 자동 실행은 1~2분 늦게 시작할 수 있습니다. 같은 커밋으로 수동 실행을 추가하지 말고 기다립니다. |

📋 **완료 체크**

- [ ] 첫 실행이 성공했고 `Deploy`의 경고는 "Application이 아직 없음" 1건뿐입니다.
- [ ] 이미지 digest와 차트 버전 `1.0.<빌드 ID>`를 기록했습니다.

[← 이전](02-infrastructure.md) · [목차](../README.md) · [다음: 첫 배포 →](04-first-sync.md)
