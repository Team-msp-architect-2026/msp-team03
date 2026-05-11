# 🛡️ Aegis-Pi Risk Twin

### Safe-Edge 기반 멀티 공장 중앙 관제 Risk Twin 플랫폼

<div align="center">

  <img src="https://img.shields.io/badge/Status-In%20Progress-orange" alt="Status" />
  <img src="https://img.shields.io/badge/Kubernetes-K3s-FFC61C?logo=kubernetes&logoColor=white" alt="K3s" />
  <img src="https://img.shields.io/badge/Cloud-AWS%20EKS-FF9900?logo=amazonwebservices&logoColor=white" alt="AWS EKS" />
  <img src="https://img.shields.io/badge/GitOps-Argo%20CD-EF7B4D?logo=argo&logoColor=white" alt="Argo CD" />
  <img src="https://img.shields.io/badge/VPN-Tailscale-246BFD?logo=tailscale&logoColor=white" alt="Tailscale" />
  <img src="https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform&logoColor=white" alt="Terraform" />
  <img src="https://img.shields.io/badge/Automation-Ansible-EE0000?logo=ansible&logoColor=white" alt="Ansible" />
  <img src="https://img.shields.io/badge/IoT-AWS%20IoT%20Core-FF9900?logo=amazonwebservices&logoColor=white" alt="AWS IoT" />

</div>

<br>

> **기존 Safe-Edge의 단일 공장 고가용성 엣지를 3개 공장 + AWS Hub 구조로 확장하고, IoT 데이터 기반 Risk Score를 중앙 대시보드로 제공하는 Risk Twin 플랫폼입니다.**

---

## 🔎 빠른 검토 순서

| 순서 | 확인할 내용 | 문서 |
|:---:|:---|:---|
| 1 | 프로젝트 문제 정의와 전체 구조 | [README.md](README.md) |
| 2 | 현재 구축된 `factory-a` 기준선 | [docs/architecture/00_current_architecture.md](docs/architecture/00_current_architecture.md) |
| 3 | 최종 Cloud / VPC / Hub-Spoke 구조 | [docs/planning/15_cloud_architecture_final.md](docs/planning/15_cloud_architecture_final.md) |
| 4 | 핵심 설계 결정과 근거 | [docs/adr/README.md](docs/adr/README.md) |
| 5 | 마일스톤 진행 상태 | [docs/issues/MASTER_CHECKLIST.md](docs/issues/MASTER_CHECKLIST.md) |
| 6 | 장애 검증 결과 | [docs/ops/09_failover_failback_test_results.md](docs/ops/09_failover_failback_test_results.md) |

---

## 👥 팀원

| 역할 | 이름 | 주요 담당 | GitHub |
|:---:|:---:|:---|:---:|
| 팀장 | 김민수 | factory-a/c · Control/Management VPC · CI/CD | [@gitminsoo](https://github.com/gitminsoo) |
| 팀원 | 김종원 | factory-b · Data/Dashboard VPC | [@JJong-03](https://github.com/JJong-03) |

---

## 📖 1. Project Overview

### 🚨 Problem: Safe-Edge의 한계

이전 프로젝트인 Safe-Edge는 Raspberry Pi 3-node K3s 기반의 **단일 공장 생존형 엣지**로, RPO 0초 / RTO 2분 이내의 고가용성 기준선을 완성했습니다. 그러나 현장 확장 관점에서 다음 세 가지 한계가 드러났습니다.

1. **중앙 관제 부재** — 여러 공장의 상태를 하나의 화면에서 볼 수 없음
2. **위험도 표준화 없음** — 공장별 AI/센서 이벤트가 단순 로컬 시각화에 그침
3. **Fleet 운영 구조 없음** — 공장이 늘어날수록 배포/운영 관리가 선형으로 증가

### 💡 Solution: Risk Twin으로 확장

Aegis-Pi는 Safe-Edge 기준선을 유지하면서, **AWS EKS Hub + Tailscale Mesh VPN + Dual VPC 구조**로 이를 확장합니다.

- **Factory Spoke** — factory-a(운영형), factory-b/c(테스트베드)를 독립 K3s 클러스터로 운영
- **Control/Management VPC** — Hub ArgoCD / Tailscale Operator / Prometheus → AMP 기반 중앙 배포 및 관측
- **Data/Dashboard VPC** — IoT Core → S3 → Risk Engine → 중앙 대시보드 제공 (제어 평면과 완전 분리)
- **Risk Twin** — 센서/AI/시스템 상태를 통합 위험 스코어로 환산, 공장별 상태 카드 제공

---

## 🏆 2. Key Contributions

### 1. 검증된 Safe-Edge 기준선 위에 구축

기존 Safe-Edge의 핵심 성과인 **Longhorn 동기식 복제(RPO 0초)**, **30초 tolerationSeconds 기반 Failover**, **master OS cron Failback**은 `factory-a` 운영형 Spoke로 그대로 계승합니다. LAN 제거·전원 제거 실제 장애 테스트에서 모두 Failover/Failback 성공을 검증했습니다.

### 2. 제어 평면과 데이터 평면의 구조적 분리 (Dual VPC)

사용자 대시보드가 ArgoCD / Tailscale / EKS API 등 제어 평면에 **직접 접근하지 않도록** VPC를 두 개로 분리하는 아키텍처를 설계했습니다.

| VPC | 역할 | 핵심 컴포넌트 |
|:---|:---|:---|
| **Control/Management VPC** | 중앙 배포 · 운영 관측 | EKS Hub · ArgoCD · Tailscale Operator · Prometheus → AMP · Grafana |
| **Data/Dashboard VPC** | 데이터 처리 · 사용자 인터페이스 | Event Processor · Risk Engine · Dashboard Web/API · RDS · Redis · OpenSearch |

이 분리 덕분에 Dashboard VPC는 처리된 S3 데이터와 latest status store만 read-only로 조회하며, 클러스터 접근 권한 없이도 독립 배포·확장이 가능합니다.

### 3. Tailscale Mesh VPN으로 Hub-Spoke 연결

VPN 어플라이언스 없이 Tailscale Kubernetes Operator를 EKS Hub에 배포해 **Hub → factory-a K3s API** 경로를 구성했습니다. ArgoCD가 Tailnet 내부 IP로 각 Spoke에 접근하며, Spoke 측에서는 `factory-a-master` 노드 하나만 Tailnet에 참여시켜 공격 면을 최소화했습니다.

```
ArgoCD (EKS) → argocd-factory-a-master-tailnet (egress proxy) → factory-a-master:6443
```

M2에서 ArgoCD `factory-a` cluster `Successful`, `factory-a-podinfo-smoke` Sync/Healthy를 실측 확인했습니다.

### 4. 명확한 IaC 책임 경계

인프라 복잡도가 올라갈수록 역할 경계가 흐려지는 문제를 방지하기 위해, 처음부터 책임 경계를 고정했습니다.

| 도구 | 역할 |
|:---|:---|
| **Terraform** | AWS 인프라 (VPC · EKS · IAM/IRSA · Route53/ACM) |
| **Ansible** | Kubernetes bootstrap (namespace · ArgoCD · Prometheus · Grafana · Ingress) |
| **GitHub Actions** | CI (이미지 빌드 · ECR push) |
| **GitHub + ArgoCD** | CD (ApplicationSet 기반 멀티 Spoke rollout) |

이 경계 덕분에 `destroy-all.sh` 한 번으로 Hub 전체를 삭제하고, `build-all.sh` 한 번으로 동일한 상태로 재생성할 수 있습니다.

### 5. Edge Agent 패턴으로 데이터 평면 독립화

각 factory의 InfluxDB / Kubernetes API 값을 직접 클라우드로 노출하지 않고, **Edge Agent**가 표준 schema로 정제한 뒤 AWS IoT Core로 송신합니다. Dashboard VPC는 IoT Core → S3 → Risk Engine을 통한 처리 결과만 조회합니다. 이 구조는 공장별 프로토콜 차이를 흡수하고, `factory-b/c`의 dummy mode 재사용을 가능하게 합니다.

---

## 🏗️ 3. Architecture

### 현재 구축 기준 (factory-a + Hub 검증 완료)

```
🏭 factory-a  (Raspberry Pi 3-node K3s)
   ├── monitoring ns  : InfluxDB · Prometheus · Grafana
   ├── ai-apps ns     : AI inference · BME280 · audio detection
   └── Tailscale      : factory-a-master → Tailnet

🔐 Tailscale Mesh VPN
   └── argocd-factory-a-master-tailnet (egress proxy in EKS)

☁️  AWS EKS Hub  (ap-south-1)  ← 검증 완료, 비용 절감을 위해 현재 off
   ├── argocd         : multi-cluster GitOps
   ├── observability  : Prometheus Agent → AMP · Grafana (AMP datasource)
   └── Admin UI       : ArgoCD / Grafana HTTPS (Route53 · ACM · ALB)

📡 IoT Layer  ← 검증 완료
   factory-a IoT Thing → IoT Rule → S3 raw/
```

### 목표 구조 (M3 이후)

```
factory-a / factory-b / factory-c
    │  (K3s Spoke + Edge Agent)
    │
    ├──[Tailscale]──────────────────────────────────────────────────┐
    │                                                               ▼
    │                              ☁️  Control / Management VPC (2번 VPC)
    │                                   EKS Hub · ArgoCD · Tailscale Operator
    │                                   Prometheus Agent → AMP · Grafana
    │                                   GitHub Actions → ECR → ApplicationSet
    │
    └──[AWS IoT Core]──────────────────────────────────────────────▶
                        S3 raw/ → Event Processor → Risk Engine
                                                         │
                              📊 Data / Dashboard VPC (1번 VPC)
                                   ALB · WAF · Auth
                                   Dashboard Web · Backend API
                                   RDS · Redis · OpenSearch
                                   공장별 Risk Score 카드
```

### Architecture Diagrams

#### Data Plane
<img width="1171" height="840" alt="data_plane" src="https://github.com/user-attachments/assets/65a77e70-8c6d-41f1-aeb3-6bc4974f088f" />

#### Control Plane
<img width="1281" height="721" alt="control_plane" src="https://github.com/user-attachments/assets/708f028a-acfa-4efa-ab5f-71cdce10abc9" />

#### Cloud Infra
<img width="782" height="772" alt="cloud_infra" src="https://github.com/user-attachments/assets/2e0c4143-74ff-43dc-9b1f-3b93757f0c9a" />


#### Architecture detail overview
<img width="1491" height="1383" alt="01_re4" src="https://github.com/user-attachments/assets/4226e03c-8d87-48ba-9a91-5600278b78ec" />



---

## 🛠️ 4. Tech Stack

| 계층 | 기술 | 선택 이유 |
|:---|:---|:---|
| 🏭 **Edge Cluster** | K3s v1.34 (ARM64) | 라즈베리파이 ARM64 엣지에 최적화된 경량 Kubernetes. 단일 바이너리로 OOM을 방지하며 `tolerationSeconds` 30초 튜닝으로 빠른 Failover |
| 💾 **Edge Storage** | Longhorn 3-node | 동기식 미러링으로 worker2 파괴 시에도 worker1에 데이터 100% 보존. RPO 0초 달성의 핵심 |
| 🔁 **GitOps** | ArgoCD + Helm | 선언적 배포로 Git이 단일 진실 원천(SSOT). ApplicationSet으로 factory 수가 늘어도 배포 규칙 하나로 확장 |
| 🔐 **Mesh VPN** | Tailscale Kubernetes Operator | 별도 VPN 어플라이언스 없이 EKS → K3s API 경로 구성. Egress proxy 패턴으로 ArgoCD가 Tailnet IP로 직접 접근 |
| ☁️ **Cloud Infra** | AWS EKS · VPC · IAM/IRSA | Spoke 수에 관계없이 Hub 하나로 중앙 배포/관측. IRSA로 Pod 수준 최소 권한 AWS 접근 |
| 📡 **IoT Pipeline** | AWS IoT Core → S3 | 공장별 디바이스를 Thing/Policy 단위로 격리. IoT Rule로 raw 데이터를 S3에 자동 적재, 처리 레이어와 분리 |
| 📈 **Observability** | Prometheus Agent → AMP → Grafana | Prometheus Agent가 remote_write로 AMP에 push. Grafana는 AMP datasource로 쿼리. 운영자 관측은 Control VPC 안에서 완결 |
| 🌐 **DNS/TLS** | Route53 · ACM · AWS Load Balancer Controller | ALB Ingress + ACM으로 HTTPS 자동 발급. Admin UI는 공유 Public ALB 뒤에 배치 |
| 🏗️ **IaC** | Terraform + Ansible | Terraform은 불변 인프라(VPC · EKS · IAM), Ansible은 멱등성 보장 소프트웨어 bootstrap. 역할 경계를 명확히 분리 |
| 🔄 **CI/CD** | GitHub Actions · ECR | 이미지 빌드 → ECR push → ArgoCD sync 흐름으로 배포 자동화. factory별 values를 분리해 동일 chart로 다른 환경 배포 |
| 🤖 **AI Inference** | YOLOv8 · YAMNet · BME280 | 시각(화재/자세)과 청각(이상 소음), 환경 센서 3종을 결합한 멀티모달 위험 감지 |
| 📊 **Time-Series DB** | InfluxDB 1.8 (arm64) | AI 이진 감지값과 센서 데이터 시계열 저장. 엣지 환경에서 RDBMS 대비 경량 운영 |

---

## ⚖️ 5. 핵심 설계 원칙

| 설계 항목 | 결정 | 근거 |
|:---|:---|:---|
| **VPC 분리** | Control/Management VPC와 Data/Dashboard VPC를 완전 분리 | 사용자 대시보드가 제어 평면(ArgoCD·EKS API)에 직접 붙지 않도록 구조적으로 차단 |
| **Edge Storage** | AI Snapshot을 Longhorn PVC → node-local hostPath로 변경 | Failover 시 RWO PVC Multi-Attach 문제 방지. 추론 결과는 InfluxDB PVC(Longhorn)에 유지 ([ADR 001](docs/adr/001-ai-snapshot-pvc-to-hostpath.md)) |
| **Failback 방식** | Kubernetes CronJob → master OS cron | CronJob NFS 타임아웃·CrashLoopBackOff 이슈 제거. OS 레벨에서 worker2 Ready 확인 후 kubectl만 실행 ([ADR 002](docs/adr/002-failback-cron-instead-of-k8s-cronjob.md)) |
| **IaC 경계** | Terraform(인프라) · Ansible(bootstrap) · GitHub Actions(CI) · ArgoCD(CD) | 역할이 섞이면 destroy/rebuild 시 순서 의존성이 복잡해짐. 경계를 고정해 `build-all.sh` 한 번 재생성 가능하게 유지 |
| **Hub-Spoke 연결** | Tailscale Operator (VPN 어플라이언스 없음) | BGP·VPN 게이트웨이 없이 단일 Operator 배포만으로 EKS → 각 K3s API 경로 확보. Spoke는 대표 노드 1개만 Tailnet 참여 |
| **데이터 평면 접근** | Edge Agent 패턴 (Dashboard VPC는 처리 결과만 조회) | Dashboard가 InfluxDB·K3s API에 직접 붙지 않아 확장성 확보. factory 추가 시 Agent만 배포하면 됨 |

---

## 📅 6. 구현 단계

| 단계 | 내용 | 상태 |
|:---|:---|:---:|
| **M0** | factory-a Safe-Edge 기준선 구축 및 실장 검증 | ✅ 완료 |
| **M1** | AWS EKS Hub 기준선 (VPC · EKS · ArgoCD · AMP · Admin UI) | 🔄 Issue 0~10/12 검증 완료 |
| **M2** | Hub-Spoke Tailscale Mesh VPN 연결 | 🔄 Issue 1~6 검증 완료 |
| **M3** | GitHub Actions · ECR · ArgoCD 배포 파이프라인 | 🟡 설계 중 |
| **M4** | Edge Agent · IoT Core → S3 데이터 파이프라인 | ⏳ 대기 |
| **M5** | factory-b (Mac VM) · factory-c (Windows VM) 테스트베드 확장 | ⏳ 대기 |
| **M6** | Risk Twin · Data/Dashboard VPC · 중앙 관제 화면 | ⏳ 대기 |
| **M7** | 3 factory 통합 검증 | ⏳ 대기 |

> 마일스톤 상세 체크리스트 → [docs/issues/MASTER_CHECKLIST.md](docs/issues/MASTER_CHECKLIST.md)

---

## 🔄 7. 시스템 동작 흐름

### factory-a 로컬 정상 상태
```
BME280 / 카메라 / 마이크
    → AI Pods (YOLOv8 · YAMNet · BME280 sensor)
    → InfluxDB safe_edge_db  (Longhorn PVC 영속화)
    → Grafana 10.10.10.202   (센서 · AI 통합 대시보드)
```

### factory-a Failover 발생 시 (worker2 장애)
```
worker2 NotReady 감지 (tolerationSeconds: 30초)
    → AI · audio · BME280 Pods → worker1 자동 이동
    → Longhorn 복제본 worker1 유지로 데이터 무손실
    → master OS cron failback (1분 주기)
    → worker2 복구 확인 후 Pods 원복
```

### Hub 데이터 흐름 (재구성 시)
```
factory-a Edge Agent
    → AWS IoT Core (aegis/factory-a/sensor · system_status · …)
    → IoT Rule → S3 raw/
    → Event Processor → Risk Engine
    → Dashboard API → 공장별 Risk Score 카드
```

---

## 🚀 8. 빠른 시작

```bash
git clone git@github.com:Team-msp-architect-2026/msp-team03.git
cd msp-team03
```

이 repository에서는 먼저 문서 진입점을 확인합니다.

| 목적 | 문서 |
|:---|:---|
| 전체 프로젝트 요약 | [README.md](README.md) |
| 문서 구조와 현재 상태 | [docs/README.md](docs/README.md) |
| 현재 아키텍처 | [docs/architecture/00_current_architecture.md](docs/architecture/00_current_architecture.md) |
| 확정 클라우드 아키텍처 | [docs/planning/15_cloud_architecture_final.md](docs/planning/15_cloud_architecture_final.md) |
| 마일스톤 체크리스트 | [docs/issues/MASTER_CHECKLIST.md](docs/issues/MASTER_CHECKLIST.md) |

운영 명령은 작업 repository 기준 기록입니다. 이 평가용 문서 repository에는 실제 `scripts/`, `infra/`, `apps/`, `charts/` 구현 파일을 포함하지 않습니다.

```bash
scripts/build/build-all.sh             # 작업 repo 기준: EKS + foundation 재구성
scripts/build/build-all.sh --admin-ui  # 작업 repo 기준: Admin UI 포함 재구성
scripts/destroy/destroy-all.sh         # 작업 repo 기준: Hub/Foundation/IoT 전체 삭제
```

> 📖 상세 운영 가이드 → [docs/ops/00_quick_start.md](docs/ops/00_quick_start.md)
> 💰 비용 기준 (Hub off 기준 $0.00/hr) → [docs/ops/15_aws_cost_baseline.md](docs/ops/15_aws_cost_baseline.md)

---

## 📂 9. 디렉토리 구조

```
.
├── 📁 .github/              # Issue / PR 템플릿, CODEOWNERS
├── 📁 docs/
│   ├── adr/                 # Architecture Decision Records (001~004)
│   ├── architecture/        # 현재 구조 · 목표 구조
│   ├── issues/              # 마일스톤 추적 (M0~M7)
│   ├── ops/                 # 운영 Runbook (00~21)
│   ├── planning/            # 설계 결정 · 계획 문서
│   ├── specs/               # 기능 명세 (모니터링 대시보드)
│   ├── demo/                # 데모 시나리오
│   ├── product/             # 제품 요구사항 · 사용자 흐름
│   ├── report/              # 결과 보고서
│   └── presentation/        # 발표 자료
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

실제 애플리케이션 코드, Terraform, Helm chart, 운영 스크립트는 작업 repository에서 관리한다. 이 repository는 평가자가 설계, 운영 판단, 검증 결과를 빠르게 검토할 수 있도록 Markdown 문서를 중심으로 구성한다.

---

## 📚 10. 문서 네비게이션

| 문서 | 경로 |
|:---|:---|
| 📋 프로젝트 개요 | [docs/planning/00_project_overview.md](docs/planning/00_project_overview.md) |
| 🗺️ 현재 아키텍처 | [docs/architecture/00_current_architecture.md](docs/architecture/00_current_architecture.md) |
| 🎯 목표 아키텍처 | [docs/architecture/01_target_architecture.md](docs/architecture/01_target_architecture.md) |
| ☁️ 확정 클라우드 아키텍처 | [docs/planning/15_cloud_architecture_final.md](docs/planning/15_cloud_architecture_final.md) |
| ⚡ 빠른 시작 | [docs/ops/00_quick_start.md](docs/ops/00_quick_start.md) |
| 🏭 factory-a 현황 | [docs/ops/05_factory_a_status.md](docs/ops/05_factory_a_status.md) |
| 🧪 Failover/Failback 실측 결과 | [docs/ops/09_failover_failback_test_results.md](docs/ops/09_failover_failback_test_results.md) |
| 🔐 Tailscale Hub-Spoke Runbook | [docs/ops/20_tailscale_hub_spoke_runbook.md](docs/ops/20_tailscale_hub_spoke_runbook.md) |
| ✅ 마일스톤 체크리스트 | [docs/issues/MASTER_CHECKLIST.md](docs/issues/MASTER_CHECKLIST.md) |
| 📝 ADR 목록 | [docs/adr/README.md](docs/adr/README.md) |
| 💰 비용 기준 | [docs/ops/15_aws_cost_baseline.md](docs/ops/15_aws_cost_baseline.md) |
| 🏗️ 책임 경계 정의 | [docs/planning/11_delivery_ownership_flow.md](docs/planning/11_delivery_ownership_flow.md) |

---

## 🤝 기여 방법

[CONTRIBUTING.md](CONTRIBUTING.md) 참조

## 📄 라이선스

[MIT](LICENSE)
