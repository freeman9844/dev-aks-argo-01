# 06. 정리와 과금 종료 확인

**목표:** 다음 빌드가 시작되지 않게 한 후 실습 전용 자원과 권한을 회수합니다.

## 1. Azure DevOps 정리

👁️ **설명** — Azure 리소스 그룹과 Azure DevOps 프로젝트는 서로 다른 관리 경계입니다. 그룹을 지워도 파이프라인이 다음 커밋에 반응하거나 조직의 유료 좌석이 남을 수 있어 DevOps부터 정리합니다.

🟢 **실행 · 브라우저 / Azure DevOps**

04에서 연 **Argo CD → Log out**을 선택하고 `kubectl port-forward`를 실행한 창에서 Ctrl+C를 누릅니다. 포워딩 종료는 로컬 접속만 닫으며 AKS 과금은 계속됩니다.

Azure DevOps에서는 **Pipelines → 대상 파이프라인 → ⋯ → Settings**에서 **Processing of new run requests → Disabled**로 저장합니다. 조직 UI에서 이름이 다르면 파이프라인 설정의 실행 요청 처리 옵션을 찾으세요.

![demo-release의 Pipeline settings: Processing of new run requests가 Disabled로 선택됐고 목록 제목 옆에 Disabled 배지가 표시됨](images/06-devops-pipeline-disabled.png)

저장 후에는 파이프라인 이름 옆에 **Disabled** 배지가 붙습니다. 이후 **Project settings → Service connections**에서 *이번 실습 연결*을 선택합니다. 다른 팀이 사용하는 연결은 삭제하지 않습니다.

파이프라인 설정에서 새 실행을 비활성화하고 진행 중인 실행이 없는지 확인합니다. 실습 전용 `demo-acr-push` 서비스 연결을 삭제하고 빌드 ID의 `demo` 브랜치 쓰기 권한을 회수합니다. **Organization settings → Users**에서 04에서 추가한 읽기 ID의 액세스와 Basic 좌석을 회수합니다. CI용 앱 등록이나 관리 ID를 그룹 밖에 따로 만들었다면 전용인지 확인한 뒤 정리합니다. Git 저장소와 빌드 로그는 Azure 그룹을 삭제해도 남습니다.

## 2. 삭제 대상 확인

🟢 **실행 · 참가자 PC / PowerShell**

```powershell
az account show --query name -o tsv
az group show -n $rg --query "{name:name,tag:tags.workshop}" -o table
az resource list -g $rg -o table
$nodeGroup = az aks show -g $rg -n $aks --query nodeResourceGroup -o tsv
```

⚠️ **주의** — **실습에서 새로 만든 그룹이고 다른 리소스가 없을 때만** 진행하세요. 위에서 읽은 `$nodeGroup`은 AKS가 VM과 디스크를 관리하는 별도 그룹입니다. 삭제 대상과 혼동하지 마세요. AKS 삭제 후에는 이름을 다시 조회할 수 없으므로 지금 기록합니다. 중간 실패로 AKS를 만들지 못했다면 기록한 전용 그룹만 확인하며, 공유 그룹이나 다른 노드 그룹을 대신 삭제하지 않습니다.

```powershell
az group delete -n $rg
az group exists -n $rg
if ($nodeGroup) { az group exists -n $nodeGroup }
```

예상 결과는 두 그룹 모두 `false`입니다. 02에서 만든 임시 kubeconfig와 05에서 생성한 GitOps clone도 더 필요하지 않으면 해당 경로만 정리하세요.

**트러블슈팅:** 삭제 중 `true`이면 `az group show -n $rg --query properties.provisioningState`로 확인합니다. `Deleting`은 아직 완료가 아닙니다.

📋 **완료 체크**

- [ ] 파이프라인이 비활성화됐고, 전용 서비스 연결과 읽기 ID의 조직 액세스를 회수했습니다.
- [ ] `az group exists`가 실습 그룹과 그 노드 그룹 모두에 `false`를 반환했습니다.
- [ ] 다시 시연할 때 남겨 쓸 교재·Git 이력과 삭제한 인프라를 구분할 수 있습니다.

[← 이전](05-canary.md) · [목차로 돌아가기](../README.md)
