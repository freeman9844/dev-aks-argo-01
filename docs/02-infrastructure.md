# 02. AKS와 Argo CD 확장 설치

**목표:** [Bicep 템플릿](../infra/main.bicep) 하나로 ACR, AKS, kubelet의 AcrPull 및 `Microsoft.ArgoCD` 확장을 설치합니다. Helm은 **Argo Rollouts**에만 사용합니다.

### 1. 새 그룹에 인프라 배포 · PowerShell

```powershell
$lab = (New-Guid).ToString('N').Substring(0,8)
$rg = "rg-argo-$lab"; $aks = "aks-argo-$lab"; $acr = "acrargo$lab"
$region = 'koreacentral'
if ((az group exists -n $rg) -ne 'false') { throw '새 실습 그룹을 사용하세요.' }
az group create -n $rg -l $region --tags workshop=aks-argo-canary
$params = @("aksName=$aks","acrName=$acr")
az deployment group what-if -g $rg -f .\infra\main.bicep -p @params
```

미리 보기에 기존 자원 수정·삭제가 없는지 확인한 후 실행합니다.

```powershell
az deployment group create -g $rg -n demo-infra -f .\infra\main.bicep -p @params
$loginServer = az acr show -g $rg -n $acr --query loginServer -o tsv
$nodeGroup = az aks show -g $rg -n $aks --query nodeResourceGroup -o tsv
az k8s-extension show -g $rg --cluster-name $aks --cluster-type managedClusters -n argocd --query provisioningState -o tsv
```

### 2. 두 컨트롤러 구분하기

```powershell
$env:KUBECONFIG = Join-Path ([IO.Path]::GetTempPath()) "$aks.yaml"
az aks get-credentials -g $rg -n $aks --file $env:KUBECONFIG
kubectl get nodes
kubectl get pods -n argocd
helm upgrade --install argo-rollouts argo-rollouts --repo https://argoproj.github.io/argo-helm --version 2.43.12 -n argo-rollouts --create-namespace --wait
kubectl create namespace demo
kubectl get crd rollouts.argoproj.io
```

**예상 결과:** 확장은 `Succeeded`, 노드 2개는 `Ready`입니다. Argo CD는 **Git 동기화**, Rollouts는 **카나리 일시 정지·승격**을 담당합니다. `$rg`, `$aks`, `$acr`, `$loginServer`, `$nodeGroup`, `$env:KUBECONFIG`를 기록해 두면 새 터미널에서도 복구할 수 있습니다.

**트러블슈팅:** 노드는 Ready인데 `argocd` Pod가 아직 없다면 별도 Helm 설치를 하지 마세요. 확장 프로비저닝 상태와 `kubectl get events -n argocd --sort-by=.lastTimestamp`를 먼저 확인합니다.

**완료 체크:** Argo CD Pod와 Rollout CRD가 모두 보입니다.

[← 이전](01-prerequisites.md) · [목차](../README.md) · [다음: CI →](03-pipeline.md)
