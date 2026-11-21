# 01. 시작 전 점검

**목표:** 다른 팀의 구독이나 클러스터에 영향을 주지 않고 실습할 준비를 합니다.

### 1. 도구와 구독 확인 · PowerShell 7

```powershell
git clone https://github.com/freeman9844/dev-aks-argo-01.git
Set-Location dev-aks-argo-01
Get-Command az, git, kubectl, helm
az bicep version
kubectl argo rollouts version --client
az account show --query "{subscription:name, state:state}" -o table
```

예상 결과는 사용할 구독과 `Enabled`입니다. 로그인되지 않았다면 `az login` 후 실습 구독을 선택하세요. `k8s-extension`이 없으면 `az extension add -n k8s-extension`을 실행합니다. [Rollouts CLI 설치 안내](https://argo-rollouts.readthedocs.io/en/stable/installation/#kubectl-plugin-installation)에서 운영체제에 맞는 플러그인을 준비하세요.

### 2. 실습 경계 확인 · Azure Portal / Azure DevOps

- Azure에서는 새 그룹·AKS·ACR·확장을 만들고 kubelet과 CI ID에 **ACR 범위 역할**을 부여할 수 있어야 합니다. Korea Central에서 `Standard_D4s_v5` 2대분(8 vCPU)의 가용 할당량을 확인합니다.
- Azure DevOps에서는 비공개 실습 프로젝트, Git 저장소, 서비스 연결, 호스팅 에이전트 병렬 작업을 사용할 수 있어야 합니다. 04에서는 GitOps 저장소 읽기 전용 ID를 사용합니다.
- **비용:** 노드, 디스크, 네트워크, Basic ACR은 실습 중 과금될 수 있습니다. Azure DevOps Basic 좌석도 조직에 따라 유료입니다. 그룹 삭제 전까지 과금이 멈췄다고 가정하지 마세요.

**트러블슈팅:** `AuthorizationFailed`이면 구독을 바꿔 우회하지 말고 해당 리소스 생성·역할 할당 권한을 관리자에게 확인합니다.

**완료 체크:** 구독 이름, 참가자 전용 DevOps 프로젝트, 정리 책임자를 확인했습니다.

[목차](../README.md) · [다음: 인프라 →](02-infrastructure.md)
