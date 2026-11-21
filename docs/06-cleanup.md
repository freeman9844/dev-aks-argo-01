# 06. 정리와 과금 종료 확인

**목표:** 다음 빌드가 시작되지 않게 한 후 실습 전용 자원과 권한을 회수합니다.

### 1. Azure DevOps 정리 · 브라우저

파이프라인 설정에서 새 실행을 비활성화하고 진행 중인 실행이 없는지 확인합니다. 실습 전용 `demo-acr-push` 서비스 연결을 삭제하고 빌드 ID의 `demo` 브랜치 쓰기 권한을 회수합니다. **Organization settings → Users**에서 04에서 추가한 읽기 ID의 액세스와 Basic 좌석을 회수합니다. CI용 앱 등록이나 관리 ID를 그룹 밖에 따로 만들었다면 전용인지 확인한 뒤 정리합니다. Git 저장소와 빌드 로그는 Azure 그룹을 삭제해도 남습니다.

### 2. 삭제 대상 확인 · PowerShell

```powershell
az account show --query name -o tsv
az group show -n $rg --query "{name:name,tag:tags.workshop}" -o table
az resource list -g $rg -o table
$nodeGroup = az aks show -g $rg -n $aks --query nodeResourceGroup -o tsv
```

**실습에서 새로 만든 그룹이고 다른 리소스가 없을 때만** 진행하세요. 중간 실패로 AKS를 만들지 못했다면 기록한 전용 그룹만 확인하며, 공유 그룹이나 다른 노드 그룹을 대신 삭제하지 않습니다.

```powershell
az group delete -n $rg
az group exists -n $rg
if ($nodeGroup) { az group exists -n $nodeGroup }
```

예상 결과는 두 그룹 모두 `false`입니다. 02에서 만든 임시 kubeconfig와 05에서 생성한 GitOps clone도 더 필요하지 않으면 해당 경로만 정리하세요.

**트러블슈팅:** 삭제 중 `true`이면 `az group show -n $rg --query properties.provisioningState`로 확인합니다. `Deleting`은 아직 완료가 아닙니다.

**완료 체크:** 파이프라인 비활성화, 전용 자격 증명 회수, 실습 그룹 및 노드 그룹 삭제를 확인했습니다.

[← 이전](05-canary.md) · [목차로 돌아가기](../README.md)
