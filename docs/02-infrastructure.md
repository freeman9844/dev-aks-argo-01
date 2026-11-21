# 02. AKS와 Argo CD 확장 설치

**목표:** [Bicep 템플릿](../infra/main.bicep) 하나로 ACR, AKS, kubelet의 AcrPull 및 `Microsoft.ArgoCD` 확장을 설치합니다. Helm은 **Argo Rollouts**에만 사용합니다.

## 1. 새 그룹에 인프라 배포

👁️ **설명** — 리소스 그룹은 삭제 경계입니다. `$lab`을 한 번만 생성해 이번 실습 자원을 한 그룹에 모읍니다. `what-if`는 실제 AKS를 만들기 전에 *무엇이 만들어질지* 확인하는 명령입니다.

🟢 **실행 · 참가자 PC / PowerShell 7**

```powershell
$lab = (New-Guid).ToString('N').Substring(0,8)
$rg = "rg-argo-$lab"; $aks = "aks-argo-$lab"; $acr = "acrargo$lab"
$region = 'koreacentral'
if ((az group exists -n $rg) -ne 'false') { throw '새 실습 그룹을 사용하세요.' }
az group create -n $rg -l $region --tags workshop=aks-argo-canary
$params = @("aksName=$aks","acrName=$acr")
az deployment group what-if -g $rg -f .\infra\main.bicep -p @params
```

📋 **확인** — 미리 보기에 AKS, ACR, `Microsoft.ArgoCD` 확장, AcrPull 역할 할당이 신규로 표시되어야 합니다.

⚠️ **주의** — 아래 `create`부터 노드와 디스크 비용이 발생합니다. 기존 자원 수정·삭제가 보이면 중단하세요.

🟢 **실행 · 같은 PowerShell**

```powershell
az deployment group create -g $rg -n demo-infra -f .\infra\main.bicep -p @params
$loginServer = az acr show -g $rg -n $acr --query loginServer -o tsv
$nodeGroup = az aks show -g $rg -n $aks --query nodeResourceGroup -o tsv
az k8s-extension show -g $rg --cluster-name $aks --cluster-type managedClusters -n argocd --query provisioningState -o tsv
```

## 2. 두 컨트롤러 구분하기

👁️ **설명** — `argocd` 네임스페이스에는 Git을 읽어 배포 명세를 반영하는 구성 요소가 있습니다. 하지만 확장을 설치했다고 해서 카나리도 바로 실행되는 것은 아닙니다. 별도 Rollouts 컨트롤러가 `Rollout` 리소스를 보고 새 버전 Pod를 몇 개 띄울지 결정합니다.

🟢 **실행 · 같은 PowerShell**

```powershell
$env:KUBECONFIG = Join-Path ([IO.Path]::GetTempPath()) "$aks.yaml"
az aks get-credentials -g $rg -n $aks --file $env:KUBECONFIG
kubectl get nodes
kubectl get pods -n argocd
helm upgrade --install argo-rollouts argo-rollouts --repo https://argoproj.github.io/argo-helm --version 2.43.12 -n argo-rollouts --create-namespace --wait
kubectl create namespace demo
kubectl get crd rollouts.argoproj.io
```

📋 **확인** — 확장은 `Succeeded`, 노드 2개는 `Ready`, 마지막 출력에는 `rollouts.argoproj.io`가 보여야 합니다. `$rg`, `$aks`, `$acr`, `$loginServer`, `$nodeGroup`과 `$env:KUBECONFIG`의 **파일 경로**를 기록해 두세요. kubeconfig 파일 내용은 공유하지 않습니다.

**트러블슈팅:** 노드는 Ready인데 `argocd` Pod가 아직 없다면 별도 Helm 설치를 하지 마세요. 확장 프로비저닝 상태와 `kubectl get events -n argocd --sort-by=.lastTimestamp`를 먼저 확인합니다.

**완료 체크:** Argo CD Pod와 Rollout CRD가 모두 보입니다.

[← 이전](01-prerequisites.md) · [목차](../README.md) · [다음: CI →](03-pipeline.md)
