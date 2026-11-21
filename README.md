# AKS GitOps 워크숍: Azure Pipelines에서 카나리 롤백까지

이미지 빌드가 성공했는데 왜 AKS에는 아직 이전 버전이 떠 있을까요? 이 워크숍에서는 코드 한 줄을 바꾸고 **앱 커밋 → 이미지 digest → GitOps 커밋 → 실제 Pod 응답**을 따라가며 답을 확인합니다.

```text
Azure Repos: demo-app/main
  └─ Azure Pipelines ── 빌드·푸시 ──▶ ACR (앱 이미지)
         └─ digest 커밋 ──▶ Azure Repos: demo-gitops/demo
                                 │ Git에서 원하는 상태 읽기
                         AKS: Argo CD Extension
                                 ↓ Rollout 동기화
                         Argo Rollouts: v1 × 4 + v2 × 1 → 수동 승격
```

GitHub는 **교재 배포처**입니다. 실습 때 Azure Pipelines와 Argo CD가 읽는 곳은 참가자 자신의 **Azure Repos**입니다. CI가 AKS에 직접 배포하지 않으며, ACR에 이미지만 올려도 배포되지 않습니다.

## 모듈 목차

| 모듈 | 실습을 마치면 확인할 수 있는 것 |
|---|---|
| [01. 시작 전 점검](docs/01-prerequisites.md) | 도구·권한·구독·비용 범위 |
| [02. AKS와 Argo CD 확장 설치](docs/02-infrastructure.md) | Ready 노드 2개, Argo CD 확장, Rollouts 컨트롤러 |
| [03. Azure Repos와 CI 연결](docs/03-pipeline.md) | v1 이미지의 ACR digest와 GitOps 커밋 일치 |
| [04. Argo CD로 첫 배포](docs/04-first-sync.md) | GitOps 동기화와 v1 Pod 5개 |
| [05. 카나리 승격과 Git 롤백](docs/05-canary.md) | 두 버전의 HTTP 응답, 4:1 정지, 승격, 복구 |
| [06. 정리](docs/06-cleanup.md) | 실습 과금 종료와 자격 증명 회수 |

**진행 방법:** 명령은 별도 표시가 없으면 워크숍 저장소 루트의 같은 PowerShell 7 세션에서 실행합니다. **브라우저** 단계는 Azure DevOps UI에서 수행합니다. 예상 결과는 실행할 명령이 아닙니다. 중간에 멈추더라도 [정리](docs/06-cleanup.md)를 진행하세요.

**실환경 검증 기록:** Korea Central에서 AKS 노드 2대와 `Microsoft.ArgoCD` 확장을 배포했습니다. v1 4개·v2 1개 상태가 60초 동안 유지되고 두 버전이 서로 다른 소스 SHA를 반환하는 것을 확인했습니다. 승격 후 v2 5개, Git revert 후 v1 5개가 Ready였습니다. 실습 그룹과 AKS 노드 그룹은 삭제했습니다. 참가자의 구독 할당량·조직 정책·권한에 따라 결과가 달라질 수 있습니다.
