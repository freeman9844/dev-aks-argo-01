# 05. 카나리 승격과 Git 롤백

**목표:** 새 버전이 모든 사용자에게 한꺼번에 배포되지 않도록 멈춘 뒤, 승격과 복구를 직접 관찰합니다.

## 1. v2 릴리스

👁️ **설명** — [Rollout 명세](../gitops-seed/dev/rollout.yaml)는 목표 수 5개, 첫 단계 `setWeight: 20`, 다음 단계 `pause: {}`입니다. v2 하나를 확인할 시간을 확보하기 위해 정지 시간은 지정하지 않았습니다. `Paused`는 이번 실습에서는 장애가 아니라 의도한 상태입니다.

🟢 **실행 · 브라우저 / Azure DevOps → Repos**, 관찰은 **PC / PowerShell**

`demo-app`의 `app/VERSION` 값을 `v1`에서 `v2`로 바꿔 `main`에 병합합니다. **자동 CI 한 건만** 실행되는지 확인합니다. 수동으로 같은 빌드를 추가하지 마세요. GitOps 저장소에서 새 digest가 기록된 커밋 SHA를 복사합니다.

```powershell
kubectl argo rollouts get rollout demo-app -n demo --watch
```

`Paused`가 되면 Ctrl+C로 **관찰만** 종료합니다. `kubectl get rs -n demo`를 지금과 60초 후에 실행합니다. 예상 결과는 두 번 모두 **v1 Ready 4개, v2 Ready 1개**입니다. 이는 Pod 비율이지 실제 요청의 정확한 20%를 뜻하지 않습니다.

📋 **확인 · 예상 출력 예시** — 이름 뒤의 해시는 환경마다 다릅니다. 다음 표에서 볼 것은 이름 순서가 아니라 **READY**입니다.

```text
NAME                   DESIRED   CURRENT   READY
demo-app-<기존 해시>          4         4       4
demo-app-<신규 해시>          1         1       1
```

## 2. 실제 응답 비교 및 승격

👁️ **설명** — Service를 두 번 호출하면 우연히 같은 버전만 만날 수 있습니다. 아래에서는 각 ReplicaSet의 해시로 Pod를 하나씩 고른 뒤, 그 Pod 안에서 `/version`을 호출합니다. 따라서 두 응답을 코드 변경 전후와 직접 연결할 수 있습니다.

🟢 **실행 · 참가자 PC / PowerShell**

```powershell
$sets = (kubectl get rs -n demo -l app=demo-app -o json | ConvertFrom-Json).items
foreach ($rs in $sets | Where-Object { $_.status.readyReplicas -gt 0 }) {
  $hash = $rs.metadata.labels.'rollouts-pod-template-hash'
  $pod = kubectl get pods -n demo -l "rollouts-pod-template-hash=$hash" -o jsonpath='{.items[0].metadata.name}'
  kubectl exec -n demo $pod -- python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8080/version').read().decode())"
}
```

**예상 결과:** 한 응답은 `v1`, 다른 응답은 `v2`이고 `commit`도 다릅니다. `kubectl argo rollouts promote demo-app -n demo`로 승격한 뒤 `kubectl argo rollouts status demo-app -n demo --timeout 5m`과 `kubectl get rs -n demo`로 **v2 Ready 5개**를 확인합니다.

## 3. Git으로 복구

👁️ **설명** — 승격은 **현재 배포를 계속 진행**하는 동작입니다. 반대로 롤백은 **원하는 이미지 자체를 이전 digest로 바꾸는 일**입니다. AKS에서 Pod를 지우는 대신 GitOps 커밋을 되돌려야 이후 동기화에서도 v1이 유지됩니다.

🟢 **실행 · 같은 PowerShell**

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

📋 **완료 체크**

| 관찰 시점 | v1 Ready | v2 Ready | 함께 대조할 증거 |
|---|---:|---:|---|
| 카나리 정지 | 4 | 1 | 두 `/version` 응답의 서로 다른 SHA |
| 수동 승격 후 | 0 | 5 | v2 digest는 정지 때와 동일 |
| Git revert 동기화·복구 후 | 5 | 0 | 새 GitOps 커밋, **기존 v1** digest·HTTP 응답 |

[← 이전](04-first-sync.md) · [목차](../README.md) · [다음: 정리 →](06-cleanup.md)
