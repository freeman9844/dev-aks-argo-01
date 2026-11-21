// =============================================================================
// AKS + Argo CD(CD 엔진) 1단계 실습 인프라 (docs/02-infrastructure.md)
//
// 이 템플릿이 실습 리소스 그룹에 만드는 리소스입니다.
//   1. AKS 클러스터            - 이미지를 실행하는 곳(OIDC 발급자·워크로드 ID 사용)
//   2. Argo CD 확장            - AKS에 붙는 Microsoft.ArgoCD 클러스터 확장
//                                (UI/API 공개, CI 전용 계정 ci, 워크로드 ID 연결)
//   3. ACR (Basic)             - CI가 빌드한 이미지와 Helm 차트를 저장하는 곳
//   4. AcrPull 역할 할당       - AKS 노드(kubelet)가 ACR에서 이미지를 읽는 권한
//   5. Argo CD용 관리 ID       - Argo CD가 ACR에서 Helm 차트를 읽을 때 쓰는 ID
//      + 페더레이션 자격 증명  - argocd-repo-server ServiceAccount를 이 관리 ID와 연결
//      + AcrPull 역할 할당     - 이 관리 ID가 ACR을 읽는 권한
//   6. CI용 관리 ID           - Azure DevOps 서비스 연결이 ACR에 푸시할 때 쓰는 ID
//      + AcrPush 역할 할당     - 이 관리 ID가 ACR에 이미지·차트를 쓰는 권한
//
// 노드 VM Scale Set, 가상 네트워크, Load Balancer·공인 IP는 AKS가 별도의
// "노드 리소스 그룹(MC_...)"에 자동으로 만들며, 이 파일에는 선언하지 않습니다.
//
// 이 템플릿이 다루지 않는 것:
//   - Argo Rollouts 컨트롤러 : 02 단계에서 Helm으로 설치
//   - CI 관리 ID의 페더레이션 : 03 단계에서 서비스 연결(Managed identity)을 만들 때 Azure DevOps가 자동 생성
//   - ci 계정의 API 토큰     : 03 단계에서 Argo CD UI로 생성(계정과 권한만 여기서 선언)
//
// ⚠️ 실습 단순화를 위해 Argo CD UI/API를 공인 IP(LoadBalancer)로 공개합니다.
//    운영 환경에서는 사설 빌드 에이전트 + 내부 LB/Ingress + SSO를 사용하세요.
//
// 배포 예시 (실습 전용 새 리소스 그룹에서 실행):
//   az deployment group what-if -g $rg -f .\infra\main.bicep -p aksName=$aks acrName=$acr
//   az deployment group create  -g $rg -n demo-infra -f .\infra\main.bicep -p aksName=$aks acrName=$acr
// =============================================================================

// ----- 매개변수 ---------------------------------------------------------------

// 리소스 위치. 기본값은 대상 리소스 그룹의 지역입니다(실습은 koreacentral).
param location string = resourceGroup().location

// AKS 클러스터 이름. API 서버 DNS 접두사로도 사용합니다. 예: aks-argo-1a2b3c4d
param aksName string

// ACR 이름. Azure 전체에서 고유해야 하며 영문 소문자·숫자 5~50자만 허용됩니다.
// 로그인 서버는 "<acrName>.azurecr.io"가 됩니다. 예: acrargo1a2b3c4d
param acrName string

// 노드 VM 크기. 4 vCPU·16 GiB로 Argo CD, Argo Rollouts, 데모 앱 Pod 5개를
// 노드 2대에 여유 있게 올릴 수 있습니다. 구독 할당량이 부족하면 바꿔서 배포합니다.
param nodeVmSize string = 'Standard_D4s_v5'

// ----- 1. AKS 클러스터 ---------------------------------------------------------

resource aks 'Microsoft.ContainerService/managedClusters@2024-10-01' = {
  name: aksName
  location: location
  // 컨트롤 플레인용 시스템 할당 관리 ID. 노드 리소스 그룹의 네트워크·LB를 관리합니다.
  // 이미지 pull에 쓰는 kubelet ID는 이와 별개로 AKS가 자동 생성합니다(아래 4번 참고).
  identity: { type: 'SystemAssigned' }
  properties: {
    // API 서버 FQDN 접두사. kubernetesVersion을 지정하지 않으므로 지역 기본 버전으로 생성됩니다.
    // 실습 단순화를 위해 API 서버는 공용 엔드포인트(비공개 클러스터 아님)를 사용합니다.
    dnsPrefix: aksName
    // Kubernetes RBAC 사용. Argo CD 등 구성 요소가 ServiceAccount 권한 범위 안에서 동작합니다.
    enableRBAC: true
    // OIDC 발급자: 클러스터가 ServiceAccount 토큰을 발급하는 주소를 공개합니다.
    // Entra ID는 이 주소를 신뢰해 Pod의 토큰을 관리 ID 토큰으로 교환합니다(아래 5번).
    oidcIssuerProfile: { enabled: true }
    // 워크로드 ID: 레이블이 붙은 Pod에 관리 ID 정보(AZURE_CLIENT_ID 등)와 토큰 파일을 주입합니다.
    securityProfile: { workloadIdentity: { enabled: true } }
    agentPoolProfiles: [
      {
        // 시스템 노드 풀 하나에 실습 워크로드까지 함께 올립니다(운영 환경에서는 사용자 풀 분리 권장).
        name: 'system'
        mode: 'System'
        // 노드 2대 고정(자동 크기 조정 없음). 비용을 줄이면서 실습 구성 요소를 여유 있게 올리는 최소 구성입니다.
        count: 2
        vmSize: nodeVmSize
        osType: 'Linux'
        // 노드는 노드 리소스 그룹의 VM Scale Set 하나에 인스턴스 2개로 만들어집니다.
        type: 'VirtualMachineScaleSets'
      }
    ]
    networkProfile: {
      // Azure CNI Overlay: 노드는 VNet 서브넷 IP를, Pod는 별도의 오버레이 주소 범위를 사용해
      // VNet 주소 공간을 아낍니다. VNet은 AKS가 노드 리소스 그룹에 자동으로 만듭니다.
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      // 노드의 아웃바운드 통신(이미지 pull 등)에 Standard Load Balancer를 사용합니다.
      loadBalancerSku: 'standard'
    }
  }
}

// ----- 2. Argo CD 클러스터 확장 ------------------------------------------------

// CI 전용 로컬 계정 ci의 권한(Argo CD RBAC). demo 프로젝트의 demo-app 하나에 대해
// 조회(get)·대상 차트 버전 변경(update)·동기화(sync)만 허용합니다. 삭제나 다른 앱 접근은 거부됩니다.
// argocd app get/wait은 프로젝트의 Sync Window도 읽으므로 demo 프로젝트 조회(projects, get)가 필요합니다.
// 파일 줄바꿈(CRLF)이 정책에 섞이지 않도록 LF로 직접 연결합니다.
var ciPolicy = join([
  'p, role:ci, projects, get, demo, allow'
  'p, role:ci, applications, get, demo/demo-app, allow'
  'p, role:ci, applications, update, demo/demo-app, allow'
  'p, role:ci, applications, sync, demo/demo-app, allow'
  'g, ci, role:ci'
], '\n')

// Helm으로 직접 설치하지 않고 Azure가 관리하는 AKS 확장(Microsoft.ArgoCD)으로 설치합니다.
// 설치 상태는 az k8s-extension show 로 확인하며, 실습에서는 provisioningState=Succeeded를 기다립니다.
// 확장이 관리하는 ConfigMap·Service를 kubectl로 직접 고치면 확장이 되돌릴 수 있으므로,
// Argo CD 설정은 모두 아래 configurationSettings로만 바꿉니다.
resource argocd 'Microsoft.KubernetesConfiguration/extensions@2023-05-01' = {
  // 확장 인스턴스 이름. az k8s-extension 명령의 -n 값과 같습니다.
  name: 'argocd'
  // 확장 리소스는 리소스 그룹이 아니라 AKS 클러스터 범위(하위 리소스)에 붙습니다.
  scope: aks
  // 관리 ID 연결과 ACR 권한이 준비된 뒤 설치해야 repo-server가 처음부터 차트를 읽을 수 있습니다.
  dependsOn: [ argocdFederation, argocdPull ]
  properties: {
    extensionType: 'Microsoft.ArgoCD'
    // 확장의 부 버전(minor) 업데이트를 Azure가 자동 적용합니다.
    autoUpgradeMinorVersion: true
    // 클러스터 범위로 설치하고 Argo CD 구성 요소는 argocd 네임스페이스에 배포합니다.
    scope: { cluster: { releaseNamespace: 'argocd' } }
    // 확장 내부 Helm 값 재정의. 값은 모두 문자열로 전달합니다.
    // 키 안의 점(.)이 ConfigMap 키 이름의 일부이면 '\\.'로 씁니다(실제 키: accounts\.ci).
    configurationSettings: {
      // Redis HA는 Redis Pod 여러 개를 서로 다른 노드에 분산하도록 설계되어 있어(노드 4대 필요),
      // 노드 2대인 실습에서는 Pending이 생길 수 있습니다. 단일 Redis로 단순화합니다.
      'redis-ha.enabled': 'false'
      // Argo CD UI/API를 공인 IP로 공개합니다. 참가자 브라우저와 Microsoft 호스팅 에이전트(CI)가
      // 같은 주소로 접속합니다. 인증서는 자체 서명이라 브라우저 경고와 CLI --insecure가 필요합니다.
      'server.service.type': 'LoadBalancer'
      // 워크로드 ID: 확장이 argocd-repo-server ServiceAccount와 Pod에 아래 관리 ID를 연결합니다.
      'azure.workloadIdentity.enabled': 'true'
      'azure.workloadIdentity.clientId': argocdIdentity.properties.clientId
      // CI 전용 로컬 계정 ci. apiKey: UI 로그인은 불가하고 API 토큰만 발급할 수 있습니다.
      'configs.cm.accounts\\.ci': 'apiKey'
      // 위 ciPolicy. 기본 정책이 없으므로 명시되지 않은 계정(admin 제외)은 아무 권한도 없습니다.
      'configs.rbac.policy\\.csv': ciPolicy
    }
  }
}

// ----- 3. Azure Container Registry ---------------------------------------------

resource acr 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: acrName
  location: location
  // Basic: 실습용 최소 SKU. 비공개 엔드포인트·지역 복제가 필요하면 Premium을 사용합니다.
  sku: { name: 'Basic' }
  properties: {
    // 공유 관리자 계정(사용자 이름/암호)을 끕니다. 접근은 Entra ID와 RBAC 역할로만 허용합니다.
    //   - CI 푸시   : CI용 관리 ID에 AcrPush (아래 6번, 03 단계 서비스 연결이 사용)
    //   - AKS pull  : kubelet 관리 ID에 AcrPull (아래 4번)
    adminUserEnabled: false
    // 기존 레지스트리 단위 RBAC 모드. AcrPull/AcrPush 역할이 레지스트리 전체에 그대로 적용됩니다.
    // 저장소 단위 ABAC 모드(AbacRepositoryPermissions)에서는 이 역할들이 적용되지 않아 별도 역할이 필요합니다.
    roleAssignmentMode: 'LegacyRegistryPermissions'
  }
}

// ----- 4. AKS 노드 → ACR 이미지 pull 권한 ---------------------------------------

// 기본 제공 역할 AcrPull(이미지 읽기 전용)의 역할 정의 ID입니다.
var pullRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
resource pull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  // ACR·AKS·역할로 결정되는 고정 GUID라 템플릿을 다시 배포해도 할당이 중복 생성되지 않습니다.
  name: guid(acr.id, aks.id, pullRole)
  // 구독이나 리소스 그룹이 아닌 이 ACR 하나에만 권한을 줍니다(최소 권한).
  scope: acr
  properties: {
    roleDefinitionId: pullRole
    // 방금 만든 관리 ID는 Entra ID 복제 전이라 조회가 실패할 수 있으므로 주체 유형을 명시합니다.
    principalType: 'ServicePrincipal'
    // 실제로 이미지를 pull하는 주체는 컨트롤 플레인 ID가 아니라 노드의 kubelet ID입니다.
    // AKS가 노드 리소스 그룹에 자동 생성한 사용자 할당 관리 ID("<aksName>-agentpool")를 가리킵니다.
    principalId: aks.properties.identityProfile.kubeletidentity.objectId
  }
}

// ----- 5. Argo CD → ACR Helm 차트 읽기용 관리 ID ---------------------------------

// Argo CD repo-server가 ACR의 OCI Helm 차트를 내려받을 때 쓰는 사용자 할당 관리 ID입니다.
// 비밀번호나 토큰을 저장하지 않고, Kubernetes ServiceAccount 토큰을 Entra ID 토큰으로 교환합니다.
resource argocdIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-argocd-${aksName}'
  location: location
}

// 페더레이션 자격 증명: "이 클러스터(OIDC 발급자)의 argocd 네임스페이스 argocd-repo-server
// ServiceAccount"가 제시한 토큰만 위 관리 ID로 교환할 수 있게 신뢰 관계를 맺습니다.
resource argocdFederation 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: argocdIdentity
  name: 'argocd-repo-server'
  properties: {
    issuer: aks.properties.oidcIssuerProfile.issuerURL
    subject: 'system:serviceaccount:argocd:argocd-repo-server'
    audiences: [ 'api://AzureADTokenExchange' ]
  }
}

// 이 관리 ID에 ACR 하나에 대한 AcrPull(읽기 전용)만 줍니다. 차트 push는 CI(AcrPush)만 합니다.
resource argocdPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, argocdIdentity.id, pullRole)
  scope: acr
  properties: {
    roleDefinitionId: pullRole
    principalType: 'ServicePrincipal'
    principalId: argocdIdentity.properties.principalId
  }
}

// ----- 6. CI → ACR 푸시용 관리 ID -------------------------------------------------

// Azure DevOps 파이프라인이 ACR에 이미지와 Helm 차트를 푸시할 때 쓰는 사용자 할당 관리 ID입니다.
// 03 단계에서 서비스 연결을 "Managed identity" 방식으로 만들며 이 ID를 고르면, Azure DevOps가
// 이 ID에 페더레이션 자격 증명을 자동으로 추가합니다. 비밀번호나 앱 등록이 필요 없습니다.
resource ciIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-ci-${aksName}'
  location: location
}

// 기본 제공 역할 AcrPush(이미지 읽기·쓰기)의 역할 정의 ID입니다. 구독 Contributor 대신 이 ACR 하나에만 줍니다.
var pushRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec')
resource ciPush 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, ciIdentity.id, pushRole)
  scope: acr
  properties: {
    roleDefinitionId: pushRole
    principalType: 'ServicePrincipal'
    principalId: ciIdentity.properties.principalId
  }
}
// ----- 출력 ---------------------------------------------------------------------

// 이후 단계에서 쓰는 값입니다. acrLoginServer는 03 단계 파이프라인 변수 acrLoginServer와 같은 값입니다.
output aksName string = aks.name
output acrLoginServer string = acr.properties.loginServer
output acrId string = acr.id
// 02에서 repo-server Pod의 AZURE_CLIENT_ID와 비교해 워크로드 ID 연결을 확인합니다.
output argocdIdentityClientId string = argocdIdentity.properties.clientId
// 03에서 서비스 연결을 만들 때 고르는 CI용 관리 ID 이름입니다.
output ciIdentityName string = ciIdentity.name
