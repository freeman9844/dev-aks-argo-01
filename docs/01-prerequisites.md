# 01. 시작 전 점검

**목표:** 다른 팀의 구독이나 클러스터에 영향을 주지 않고 실습할 준비를 합니다.

## 1. 도구와 구독 확인

👁️ **설명** — `az`는 Azure 리소스를, `kubectl`은 클러스터 안의 리소스를 관리합니다. Azure 로그인이 되어 있어도 AKS에 연결된 것은 아닙니다. AKS 연결은 02에서 별도 kubeconfig로 설정합니다.

🟢 **실행 · 참가자 PC / PowerShell 7** — 아직 교재를 받지 않았다면 다음 두 줄로 시작합니다. 이미 clone했다면 해당 폴더로 이동한 뒤 `Get-Command`부터 실행하세요.

```powershell
git clone https://github.com/freeman9844/dev-aks-argo-01.git
Set-Location dev-aks-argo-01
Get-Command az, git, kubectl, helm
az bicep version
kubectl argo rollouts version --client
az account show --query "{subscription:name, state:state}" -o table
```

예상 결과는 사용할 구독과 `Enabled`입니다. 로그인되지 않았다면 `az login` 후 실습 구독을 선택하세요. `k8s-extension`이 없으면 `az extension add -n k8s-extension`을 실행합니다. [Rollouts CLI 설치 안내](https://argo-rollouts.readthedocs.io/en/stable/installation/#kubectl-plugin-installation)에서 운영체제에 맞는 플러그인을 준비하세요.

📋 **확인** — `kubectl`은 있어도 `argo rollouts` 하위 명령은 없을 수 있습니다. 버전 출력이 없으면 05까지 미루지 말고 플러그인을 먼저 설치하세요.

## 2. 실습 경계 확인

🟢 **실행 · 브라우저 / Azure Portal과 Azure DevOps** — 구독의 **Quotas**와 실습 프로젝트의 **Project settings → Pipelines → Parallel jobs**를 확인합니다. 아래 두 권한은 별개입니다. 구독에 VM을 만들 수 있어도 조직의 빌드 에이전트를 쓸 수 없는 경우가 있습니다.

- Azure에서는 새 그룹·AKS·ACR·확장을 만들고 kubelet과 CI ID에 **ACR 범위 역할**을 부여할 수 있어야 합니다. Korea Central에서 `Standard_D4s_v5` 2대분(8 vCPU)의 가용 할당량을 확인합니다.
- Azure DevOps에서는 비공개 실습 프로젝트, Git 저장소, 서비스 연결, 호스팅 에이전트 병렬 작업을 사용할 수 있어야 합니다. 04에서는 GitOps 저장소 읽기 전용 ID를 사용합니다.
- **비용:** 노드, 디스크, 네트워크, Basic ACR은 실습 중 과금될 수 있습니다. Azure DevOps Basic 좌석도 조직에 따라 유료입니다. 그룹 삭제 전까지 과금이 멈췄다고 가정하지 마세요.

**트러블슈팅:** `AuthorizationFailed`이면 구독을 바꿔 우회하지 말고 해당 리소스 생성·역할 할당 권한을 관리자에게 확인합니다.

📋 **완료 체크**

- [ ] 사용할 구독 이름과 DevOps 조직·프로젝트를 확인했습니다.
- [ ] 호스팅 에이전트를 사용할 수 있고, 실습 종료 후 유료 자원을 삭제할 수 있습니다.

[목차](../README.md) · [다음: 인프라 →](02-infrastructure.md)
