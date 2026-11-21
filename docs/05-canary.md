# 05. 카나리 승격과 Git 롤백

**목표:** 새 버전이 모든 사용자에게 한꺼번에 배포되지 않도록 멈춘 뒤, 승격과 복구를 직접 관찰합니다.

### 1. v2 릴리스 · Azure DevOps → Repos

`demo-app`의 `app/VERSION` 값을 `v1`에서 `v2`로 바꿔 `main`에 병합합니다. **자동 CI 한 건만** 실행되는지 확인합니다. 수동으로 같은 빌드를 추가하지 마세요. GitOps 저장소에서 새 digest가 기록된 커밋 SHA를 복사합니다.

```powershell
kubectl argo rollouts get rollout demo-app -n demo --watch
```

`Paused`가 되면 Ctrl+C로 **관찰만** 종료합니다. `kubectl get rs -n demo`를 지금과 60초 후에 실행합니다. 예상 결과는 두 번 모두 **v1 Ready 4개, v2 Ready 1개**입니다. 이는 Pod 비율이지 실제 요청의 정확한 20%를 뜻하지 않습니다.

### 2. 실제 응답 비교 · PowerShell

```powershell
$sets = (kubectl get rs -n demo -l app=demo-app -o json | ConvertFrom-Json).items
foreach ($rs in $sets | Where-Object { $_.status.readyReplicas -gt 0 }) {
  $hash = $rs.metadata.labels.'rollouts-pod-template-hash'
  $pod = kubectl get pods -n demo -l "rollouts-pod-template-hash=$hash" -o jsonpath='{.items[0].metadata.name}'
  kubectl exec -n demo $pod -- python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8080/version').read().decode())"
}
```

**예상 결과:** 한 응답은 `v1`, 다른 응답은 `v2`이고 `commit`도 다릅니다. `kubectl argo rollouts promote demo-app -n demo`로 승격한 뒤 `kubectl argo rollouts status demo-app -n demo --timeout 5m`과 `kubectl get rs -n demo`로 **v2 Ready 5개**를 확인합니다.

### 3. Git으로 복구 · PowerShell

```powershell
$gitopsDir = Join-Path ([IO.Path]::GetTempPath()) ("gitops-" + (New-Guid))
git clone -b demo --single-branch $repo $gitopsDir
git -C $gitopsDir log -2 --oneline
$v2Commit = Read-Host '되돌릴 v2 이미지 변경 커밋 SHA'
git -C $gitopsDir revert --no-edit $v2Commit
if ($LASTEXITCODE -ne 0) { throw 'revert 실패: push하지 마세요.' }
git -C $gitopsDir push origin demo
```

Argo CD가 **revert 커밋**에 동기화된 뒤 Rollout을 관찰합니다. 다시 `Paused`이면 승격합니다. v1 Ready 5개·v2 0개, `/version` 응답의 원래 SHA까지 확인해야 복구가 끝난 것입니다.

**트러블슈팅:** GitOps 커밋 직후의 `Healthy`는 이전 버전의 상태일 수 있습니다. `kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.revision}'`을 기대하는 커밋과 먼저 비교하세요.

**완료 체크:** 4:1 정지, 두 버전의 응답, 승격, Git revert 복구를 확인했습니다.

[← 이전](04-first-sync.md) · [목차](../README.md) · [다음: 정리 →](06-cleanup.md)
