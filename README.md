<!--
링크 규칙: 상세 문서는 GitHub Wiki 페이지로 연결한다.
형식: https://github.com/Team-msp-architect-2026/msp-team03/wiki/<page-name>
-->

# 🛡️ Aegis-Pi Risk Twin

### Safe-Edge 기반 멀티 공장 중앙 관제 Risk Twin 플랫폼

<div align="center">

  <img src="https://img.shields.io/badge/Status-Phase%208%20Integrated-2ea44f" alt="Status" />
  <img src="https://img.shields.io/badge/Edge-K3s-FFC61C?logo=kubernetes&logoColor=white" alt="K3s" />
  <img src="https://img.shields.io/badge/Cloud-AWS%20EKS-FF9900?logo=amazonwebservices&logoColor=white" alt="AWS EKS" />
  <img src="https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform&logoColor=white" alt="Terraform" />
  <img src="https://img.shields.io/badge/GitOps-Argo%20CD-EF7B4D?logo=argo&logoColor=white" alt="Argo CD" />
  <img src="https://img.shields.io/badge/VPN-Tailscale-246BFD?logo=tailscale&logoColor=white" alt="Tailscale" />
  <img src="https://img.shields.io/badge/IoT-AWS%20IoT%20Core-FF9900?logo=amazonwebservices&logoColor=white" alt="AWS IoT" />
  <img src="https://img.shields.io/badge/API-FastAPI-009688?logo=fastapi&logoColor=white" alt="FastAPI" />
  <img src="https://img.shields.io/badge/Frontend-React%2018-61DAFB?logo=react&logoColor=black" alt="React" />
  <img src="https://img.shields.io/badge/AI-Amazon%20Bedrock-FF9900?logo=amazonwebservices&logoColor=white" alt="Bedrock" />

</div>

<br>

> **기존 Safe-Edge의 단일 공장 고가용성 엣지를 3개 공장 + AWS Hub 구조로 확장하고, IoT 데이터 기반 Safety Score를 중앙 대시보드·일간 보고서·알림으로 제공하는 Risk Twin 플랫폼입니다.**

기준일: 2026-06-09 · 상태: Phase 8 통합 완료 (실환경 통합 smoke test 대기)

---

## 🔎 빠른 검토 순서

| 순서 | 확인할 내용 | 문서 |
|:---:|:---|:---|
| 1 | 프로젝트 배경과 목표 | [사업 배경과 목표](https://github.com/Team-msp-architect-2026/msp-team03/wiki/req-background) |
| 2 | 전체 시스템 아키텍처 | [시스템 아키텍처](https://github.com/Team-msp-architect-2026/msp-team03/wiki/architecture-system) |
| 3 | 현재 구현·검증 상태 | [현재 구현 상태](https://github.com/Team-msp-architect-2026/msp-team03/wiki/project-current-status) |
| 4 | 핵심 설계 결정 | [ADR 인덱스](https://github.com/Team-msp-architect-2026/msp-team03/wiki/adr-index) |
| 5 | 인수 기준과 산출물 | [인수 기준 및 산출물](https://github.com/Team-msp-architect-2026/msp-team03/wiki/srs-acceptance) |
| 6 | 전체 문서 | [Wiki 홈](https://github.com/Team-msp-architect-2026/msp-team03/wiki) |

---

## 👥 팀원

| 역할 | 이름 | 주요 담당 | GitHub |
|:---:|:---:|:---|:---:|
| 팀장 | 김민수 | factory-a/c · Control/Management VPC · CI/CD | [@gitminsoo](https://github.com/gitminsoo) |
| 팀원 | 김종원 | factory-b · Data/Dashboard VPC | [@JJong-03](https://github.com/JJong-03) |

---

## 📖 1. Overview

### 🧱 Background — Safe-Edge란?

**Safe-Edge**는 이 프로젝트의 출발점이 된 **단일 공장용 로컬 생존형 엣지 시스템**이다. 산업 현장의 폭발·화재로 엣지 장비가 물리적으로 파괴되는 상황을 가정하고, 클라우드 없이 현장에서 다음을 보장한다.

- **현장 위험 감지** — Raspberry Pi 3-node K3s(master + worker1 + worker2) 위에서 멀티모달 AI로 위험을 탐지: YOLOv8n(화재/연기·작업자 자세) + YAMNet(이상 음향) + BME280(온습도·기압)
- **데이터 무손실 (RPO 0초)** — Longhorn 3-node 동기 복제로 한 노드가 파괴돼도 다른 노드에 데이터가 그대로 남음
- **빠른 복구 (RTO ~2분)** — `tolerationSeconds` 튜닝과 master OS cron 기반 failover/failback으로 장애 노드의 워크로드를 대체 노드로 자동 이전
- **폐쇄망 독립 동작** — 네트워크가 끊겨도 현장 감시·기록이 계속되고, 로컬 InfluxDB·Grafana로 시각화

즉 Safe-Edge는 **"한 공장이 무슨 일이 있어도 살아남는"** 고가용성 엣지를 실제 장애 테스트(LAN 제거·전원 제거)로 검증한 기준선이다. Aegis-Pi는 이 기준선을 **그대로 계승하면서**, 여러 공장을 중앙에서 관제하는 단계로 확장한다.

### 🚨 Problem — 단일 공장 Safe-Edge의 한계

Safe-Edge는 한 공장의 생존성은 완성했지만, 공장이 여러 곳으로 늘어나는 멀티 공장 운영 관점에서는 한계가 있었다.

1. **중앙 관제 부재** — 여러 공장 상태를 한 화면에서 볼 수 없음
2. **위험도 표준화 없음** — 공장별 AI/센서 이벤트가 로컬 시각화에 그침
3. **Fleet 운영 구조 없음** — 공장이 늘수록 배포·운영 부담이 선형 증가

### 💡 Solution — Risk Twin으로 확장

Safe-Edge 기준선을 유지하면서 **AWS EKS Hub + Tailscale Mesh + Dual VPC** 구조로 확장하고, 공장 데이터를 **Safety Score read model**로 표준화해 대시보드·보고서·알림으로 제공한다.

- **Factory Spoke** — factory-a(운영형), factory-b/c(테스트베드)를 독립 K3s 클러스터로 운영
- **Control/Management VPC** — EKS Hub · ArgoCD · Tailscale Operator 기반 중앙 배포/관측
- **Data/Dashboard VPC** — IoT Core → 데이터 파이프라인 → 대시보드 (제어 평면과 완전 분리)
- **Risk Twin** — 센서·AI·인프라 상태를 통합 Safety Score로 환산해 공장별 상태 카드 제공

대상 사용자와 범위 → [프로젝트 개요](https://github.com/Team-msp-architect-2026/msp-team03/wiki/project-overview)

---

## ✅ 2. 현재 상태 (Phase 8 통합 완료)

두 원본 워크스트림(Edge/Hub, Data/Dashboard)이 단일 저장소로 통합됐고 주요 앱 단위 테스트가 통과했다. 잔여는 통합본 의존성 설치 후 검증과 실환경 end-to-end smoke test다.

| 영역 | 상태 | 비고 |
|:---|:---|:---|
| Factory A Safe-Edge | ✅ 배포 검증 완료 | K3s · Longhorn · failover/failback · IoT 송신 |
| Factory B/C 테스트베드 | ✅ 배포 검증 이력 | VM K3s · dummy generator · hostPath outbox |
| Data Pipeline | ✅ 구현 완료 · 테스트 통과 | DataProcessor · GraphAggregator5m · CloudInfra collector |
| Dashboard Web/API | ✅ 구현 완료 | ECS Fargate FastAPI + React SPA |
| Reporting | ✅ 구현 완료 · 배포 검증 이력 | Step Functions + 7 Lambda + Bedrock |
| Alerting / Snapshot / RBAC | ✅ 구현 완료 | Slack alert · presigned S3 · Cognito+RDS |
| 통합본 smoke test | ⏳ 대기 | 실환경 end-to-end 검증 |

상세 → [현재 구현 상태](https://github.com/Team-msp-architect-2026/msp-team03/wiki/project-current-status) · [로드맵](https://github.com/Team-msp-architect-2026/msp-team03/wiki/roadmap)

---

## 🏗️ 3. Architecture

제어 평면(Control/Management VPC)과 데이터 평면(Data/Dashboard VPC)을 **직접 연결 없이** 분리해, 사용자 대시보드가 K3s·EKS·ArgoCD 관리 API에 접근하지 않고 read model만 조회한다.

<img width="1000" height="800" alt="architecture" src="https://github.com/user-attachments/assets/d2798158-6594-491d-820d-13ebe7c73097" />

| VPC | 역할 | 핵심 구성 |
|:---|:---|:---|
| **Control / Management VPC** | 중앙 배포 · 운영 관측 | EKS Hub · ArgoCD · Tailscale Operator · Grafana · ALB Controller (단일 NAT) |
| **Data / Dashboard VPC** | 데이터 처리 · 사용자 진입점 | CloudFront/S3 SPA · ALB · ECS Fargate FastAPI · Cognito · RDS PostgreSQL · Redis |

```text
Factory A/B/C (K3s Spoke + Edge Agent)
  ├─[Tailscale]─▶ Control/Management VPC : EKS Hub · ArgoCD · GitOps sync
  └─[AWS IoT Core, mTLS]─▶ S3 raw → DataProcessor(Lambda)
                            → DynamoDB LATEST/HISTORY/GRAPH#5M/CLOUD#infra + S3 processed
                            → Data/Dashboard VPC : ECS Backend → Dashboard Web
                                                  (WebSocket/REST · Daily Report · Slack Alert)
```

상세 → [시스템 아키텍처](https://github.com/Team-msp-architect-2026/msp-team03/wiki/architecture-system) · [제어 플레인 & 데이터 플레인](https://github.com/Team-msp-architect-2026/msp-team03/wiki/architecture-control-data-plane) · [Dashboard VPC 설계](https://github.com/Team-msp-architect-2026/msp-team03/wiki/architecture-dashboard-vpc)

> 기본 운영 리전은 `ap-south-1`(CloudFront/ACM은 us-east-1). AMP/Prometheus Agent는 비용 최적화로 retired됐다.

---

## ⚙️ 4. 핵심 기능

| 기능 | 설명 | 문서 |
|:---|:---|:---|
| **Edge AI 탐지** | YOLOv8n(화재/자세) + YAMNet(음향) + BME280 멀티모달 | [Edge AI 탐지](https://github.com/Team-msp-architect-2026/msp-team03/wiki/component-edge-ai-detection) |
| **Safety Score** | 센서·AI·인프라·파이프라인 상태를 통합 점수로 환산 (100=안전, 0=위험) | [Safety Score 모델](https://github.com/Team-msp-architect-2026/msp-team03/wiki/concept-risk-score) |
| **데이터 파이프라인** | IoT → S3 raw → DataProcessor → DynamoDB/S3 read model | [Lambda Data Processor](https://github.com/Team-msp-architect-2026/msp-team03/wiki/component-data-processor) |
| **Dashboard** | Fleet/Factory/Cloud Infra/Reports/User 화면, WebSocket 준실시간 | [Dashboard Backend](https://github.com/Team-msp-architect-2026/msp-team03/wiki/component-dashboard-backend) · [API 명세](https://github.com/Team-msp-architect-2026/msp-team03/wiki/reference-api) |
| **Daily Report** | EventBridge → Step Functions → Bedrock 한국어 일간 보고서 | [Reporting Pipeline](https://github.com/Team-msp-architect-2026/msp-team03/wiki/architecture-reporting-pipeline) |
| **Alerting** | processed snapshot 기반 Slack alert, dedupe/cooldown | [Risk Alert Dispatcher](https://github.com/Team-msp-architect-2026/msp-team03/wiki/component-risk-alert-dispatcher) |
| **Image Snapshot** | 이벤트 이미지를 presigned URL로 S3 직접 업로드(MQTT는 metadata만) | [Image Snapshot Pipeline](https://github.com/Team-msp-architect-2026/msp-team03/wiki/component-image-snapshot-pipeline) |
| **Cloud Infra 관제** | Fast/Slow collector로 AWS/EKS 상태를 read model로 제공 | [Cloud Infra Collector](https://github.com/Team-msp-architect-2026/msp-team03/wiki/component-cloud-infra-collector) |
| **인증 / RBAC** | Cognito 인증 + RDS 역할·공장 접근 제어 | [인증과 RBAC](https://github.com/Team-msp-architect-2026/msp-team03/wiki/security-auth-rbac) |

---

## 🛠️ 5. Tech Stack

| 계층 | 기술 |
|:---|:---|
| 🏭 **Edge** | K3s · Longhorn · InfluxDB · YOLOv8n · YAMNet · BME280 · Edge IoT Publisher |
| 🔐 **Control** | AWS EKS Hub · ArgoCD · Tailscale Operator · Grafana · AWS Load Balancer Controller |
| 📡 **Data Pipeline** | AWS IoT Core · S3 · Lambda(DataProcessor/Collector/Notifier) · DynamoDB · EventBridge |
| 📊 **Dashboard** | React 18 + Vite · CloudFront/S3 · ALB · ECS Fargate · FastAPI · Cognito · RDS PostgreSQL · Redis |
| 📝 **Reporting** | Step Functions · Lambda ×7 · Amazon Bedrock(Claude) |
| 🏗️ **IaC / CI·CD** | Terraform · GitHub Actions · ECR · ArgoCD(ApplicationSet) |

상세·active/retired 구분 → [기술 스택](https://github.com/Team-msp-architect-2026/msp-team03/wiki/tech-stack)

---

## ⚖️ 6. 핵심 설계 결정 (ADR)

| 결정 | 요약 |
|:---|:---|
| [ECS Fargate Backend](https://github.com/Team-msp-architect-2026/msp-team03/wiki/adr-ecs-fargate-backend) | Dashboard API를 Lambda+API GW → ECS Fargate(FastAPI)로 |
| [메타데이터 RDS PostgreSQL](https://github.com/Team-msp-architect-2026/msp-team03/wiki/adr-rds-postgresql) | Aurora Serverless → RDS PostgreSQL (비용) |
| [WebSocket + DynamoDB Streams](https://github.com/Team-msp-architect-2026/msp-team03/wiki/adr-websocket-streams) | 폴링 대신 실시간 푸시 |
| [Bedrock 일간 보고서](https://github.com/Team-msp-architect-2026/msp-team03/wiki/adr-bedrock-report) | LLM 한국어 일간 보고서 |
| [DynamoDB foundation 이관](https://github.com/Team-msp-architect-2026/msp-team03/wiki/adr-dynamodb-to-foundation) | 상태 테이블을 영속 root로 |
| [Edge AI: YOLOv8n](https://github.com/Team-msp-architect-2026/msp-team03/wiki/adr-yolov8n-edge-ai) | OpenCV ML → YOLOv8n object/pose |
| [IoT Fleet: Persistent MQTT](https://github.com/Team-msp-architect-2026/msp-team03/wiki/adr-persistent-mqtt) | 상시 MQTT 연결로 connectivity 지표화 |

전체 결정 이력(32건) → [ADR 인덱스](https://github.com/Team-msp-architect-2026/msp-team03/wiki/adr-index)

---

## 🔁 7. Edge 고가용성 (Factory A 계층)

운영형 Spoke는 다중 노드 K3s와 Longhorn 동기 복제로 단일 노드 장애에도 무중단을 목표로 한다.

```text
worker2 NotReady 감지 (tolerationSeconds 단축)
  → AI · audio · 센서 Pods → worker1 자동 이동
  → Longhorn 복제본으로 데이터 무손실
  → master OS cron failback → worker2 복구 후 원복
```

- **RPO 0초** — Longhorn 3-node 동기 복제 (Edge 블록 스토리지 계층)
- **RTO ~2분** — tolerationSeconds 튜닝 기반 빠른 eviction/failover

> 위 RPO/RTO는 **Edge(Spoke) 계층** 기준이다. 클라우드 데이터 계층의 복구 목표(RDS PITR, RPO ≤ 5분)는 [비기능 요구사항](https://github.com/Team-msp-architect-2026/msp-team03/wiki/srs-nonfunctional)을 따른다.

상세 → [Failover & 복구](https://github.com/Team-msp-architect-2026/msp-team03/wiki/scenario-failover-recovery)

---

## 🚀 8. 빌드 / 운영 / 비용

Terraform root는 의존성 순서로 빌드하고 역순으로 destroy한다.

```text
build:   foundation → hub → data-pipeline → data-dashboard / reporting
destroy: data-dashboard / reporting → data-pipeline → hub → foundation(영속)
```

| 비용 계층 | 상시 가동 | 데모 운영 |
|:---|---:|---:|
| Control/Management VPC (Hub) | ~$188/월 | 가동 시간 비례 |
| Data/Dashboard VPC | ~$178/월 | ~$8~10/월 |
| destroy 후 (foundation 유지) | — | ~$0/월 |

상세 → [통합 Build/Destroy](https://github.com/Team-msp-architect-2026/msp-team03/wiki/operations-integrated-build-destroy) · [비용 기준서](https://github.com/Team-msp-architect-2026/msp-team03/wiki/reference-cost-estimate)

---

## 📚 9. 문서 네비게이션 (Wiki)

| 영역 | 문서 |
|:---|:---|
| 요구사항 | [기능 요구사항](https://github.com/Team-msp-architect-2026/msp-team03/wiki/srs-functional) · [비기능 요구사항](https://github.com/Team-msp-architect-2026/msp-team03/wiki/srs-nonfunctional) · [인수 기준](https://github.com/Team-msp-architect-2026/msp-team03/wiki/srs-acceptance) |
| 아키텍처 | [시스템](https://github.com/Team-msp-architect-2026/msp-team03/wiki/architecture-system) · [데이터 생명주기](https://github.com/Team-msp-architect-2026/msp-team03/wiki/architecture-data-lifecycle) · [IoT 데이터 계약](https://github.com/Team-msp-architect-2026/msp-team03/wiki/architecture-iot-data-contract) |
| 운영 | [Data Pipeline](https://github.com/Team-msp-architect-2026/msp-team03/wiki/operations-data-pipeline) · [Daily Report](https://github.com/Team-msp-architect-2026/msp-team03/wiki/operations-daily-report) · [Alerting](https://github.com/Team-msp-architect-2026/msp-team03/wiki/operations-alerting) |
| 참조 | [API 명세](https://github.com/Team-msp-architect-2026/msp-team03/wiki/reference-api) · [비용 기준서](https://github.com/Team-msp-architect-2026/msp-team03/wiki/reference-cost-estimate) · [용어집](https://github.com/Team-msp-architect-2026/msp-team03/wiki/concept-glossary) |
| 전체 | [Wiki 홈](https://github.com/Team-msp-architect-2026/msp-team03/wiki) |

---

## 🤝 기여 / 📄 라이선스

[CONTRIBUTING.md](CONTRIBUTING.md) · [MIT](LICENSE)
