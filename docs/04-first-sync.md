# 04. GitOps 저장소 연결과 첫 배포

**목표:** Argo CD가 비공개 `demo-gitops:demo`를 읽고 v1 Pod 다섯 개를 띄우도록 합니다. CI의 쓰기 ID와 Argo CD의 읽기 ID는 분리합니다.

## 1. Git 읽기 ID 구성

👁️ **설명** — 비공개 Azure Repos는 익명 clone을 허용하지 않습니다. Kubernetes 서비스 계정의 토큰을 Azure가 신뢰하도록 연결하면 repo-server가 장기 PAT 없이 저장소를 읽을 수 있습니다. `issuer`는 **어느 클러스터인지**, `subject`는 **그 안의 어느 서비스 계정인지** 제한합니다.

🟢 **실행 · 참가자 PC / PowerShell**, 이어서 **브라우저 / Azure DevOps**

```powershell
az aks update -g $rg -n $aks --enable-oidc-issuer --enable-workload-identity
$reader = az identity create -g $rg -n id-workshop-git-reader | ConvertFrom-Json
$issuer = az aks show -g $rg -n $aks --query oidcIssuerProfile.issuerUrl -o tsv
$sa = kubectl get deployment argocd-repo-server -n argocd -o jsonpath='{.spec.template.spec.serviceAccountName}'
az identity federated-credential create -g $rg --identity-name id-workshop-git-reader -n repo-server --issuer $issuer --subject "system:serviceaccount:argocd:$sa" --audiences api://AzureADTokenExchange
```

Azure DevOps **Organization settings → Users**에서 관리 ID를 추가합니다. 이름이 같다면 `$reader.principalId`와 대조합니다. 비공개 Repos 읽기가 가능한 Basic 액세스, 실습 프로젝트의 **View project-level information**, `demo-gitops` 저장소의 **Read**만 필요합니다. 프로젝트 전체 Contributors에는 추가하지 않습니다. 조직 정책상 관리 ID 등록이 제한되면 관리자에게 요청하세요.

📋 **확인** — Azure의 관리 ID를 만든 것만으로 Azure Repos 권한이 생기지는 않습니다. 조직에 추가한 ID와 `$reader.principalId`, 읽기 권한을 준 저장소를 대조하세요.

## 2. repo-server에 ID 연결

🟢 **실행 · 같은 PowerShell**

```powershell
kubectl annotate sa $sa -n argocd "azure.workload.identity/client-id=$($reader.clientId)" --overwrite
kubectl patch deployment argocd-repo-server -n argocd --type merge -p '{"spec":{"template":{"metadata":{"labels":{"azure.workload.identity/use":"true"}}}}}'
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=3m
@{apiVersion='v1';kind='Secret';metadata=@{name='demo-gitops';namespace='argocd';labels=@{'argocd.argoproj.io/secret-type'='repository'}};stringData=@{type='git';project='demo';url=$repo;useAzureWorkloadIdentity='true'}} |
  ConvertTo-Json -Depth 6 | kubectl apply -f -
```

이 Secret에는 PAT가 없습니다. 실습에서는 실행 중인 repo-server에 설정을 적용합니다. 장기 운영 환경에서는 확장 업그레이드가 설정을 덮어쓰지 않도록 [확장 구성과 Workload Identity](https://learn.microsoft.com/azure/azure-arc/kubernetes/tutorial-use-gitops-argocd)로 관리하세요.

## 3. Application 생성 및 관찰

👁️ **설명** — `AppProject`는 *어느 저장소에서 어느 네임스페이스로 배포해도 되는지* 정하고, `Application`은 *그 저장소의 어떤 브랜치와 경로를 따라갈지* 지정합니다. `demo` 네임스페이스에 앱 YAML을 직접 적용하지 마세요. Git에서 읽어 생성하는 것이 이번 단계의 관찰 대상입니다.

🟢 **실행 · 같은 PowerShell**

```powershell
foreach ($f in 'project','application') {
  (Get-Content ".\bootstrap\$f.yaml" -Raw).Replace('GITOPS_REPO_URL',$repo) | kubectl apply -f -
  if ($LASTEXITCODE -ne 0) { throw "$f 등록 실패" }
}
kubectl wait -n demo --for=create rollout/demo-app --timeout=5m
kubectl argo rollouts status demo-app -n demo --timeout 5m
kubectl get application demo-app -n argocd
kubectl get rs -n demo -l app=demo-app
```

**예상 결과:** `Synced`이며 v1 ReplicaSet의 `READY`가 5입니다. 최초 배포는 비교할 이전 버전이 없어 카나리 정지를 하지 않습니다.

📋 **확인 · 어느 커밋을 배포했나요?**

```powershell
kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.revision}'
kubectl get rollout demo-app -n demo -o jsonpath='{.spec.template.spec.containers[0].image}'
```

첫 출력은 **03의 GitOps 커밋 SHA**, 두 번째 출력의 `@sha256:…` 부분은 **03의 ACR digest**와 같아야 합니다. `Synced`는 명세가 Git과 일치한다는 뜻이지 Pod가 요청에 응답한다는 뜻은 아닙니다. 위 ReplicaSet의 Ready 수까지 확인하세요.

**트러블슈팅:** `ComparisonError`는 Git URL·Read 권한·페더레이션 subject부터, `ImagePullBackOff`는 Git이 아니라 ACR digest·kubelet의 AcrPull부터 확인합니다.

**완료 체크:** Git 커밋이 동기화됐고 v1 Pod 5개가 Ready입니다.

[← 이전](03-pipeline.md) · [목차](../README.md) · [다음: 카나리 →](05-canary.md)
