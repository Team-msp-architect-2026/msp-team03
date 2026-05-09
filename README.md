# 🛡️ Aegis-Pi Risk Twin

> **MSP Architect Training 2026 · MSP Team03**

Safe-Edge 기반 단일 공장 엣지를 **멀티 공장 중앙 관제 구조**로 확장하는 Risk Twin 플랫폼

---

## 👥 팀원

| 역할 | 이름 | 주요 담당 | GitHub |
|------|------|-----------|--------|
| 팀장 | 김민수 | factory-a/c · Control/Management VPC · CI/CD | @ |
| 팀원 | 김종원 | factory-b · Data/Dashboard VPC | @ |

---

## 🎯 프로젝트 목표

- 🏭 Raspberry Pi 3-node K3s 기반 `factory-a` Safe-Edge를 AWS EKS Hub와 연결해 멀티 공장 중앙 관제 구조 구현
- 🔒 Tailscale Mesh VPN으로 Hub-Spoke 간 보안 통신 레이어 확립
- 🚀 GitOps(ArgoCD) + CI/CD(GitHub Actions) 기반 배포 파이프라인으로 운영 자동화

---

## 🏗️ 시스템 아키텍처

```
🏭 factory-a (Raspberry Pi K3s)
    └── 🔐 Tailscale VPN
          └── ☁️  AWS EKS Hub  (ap-south-1)
                ├── ArgoCD      (GitOps, multi-cluster)
                ├── Prometheus  (remote_write → AMP)
                ├── Grafana     (AMP datasource)
                └── Admin UI    (HTTPS, ALB + Route53/ACM)

📡 IoT Layer
    BME280 / Camera / Mic / AI inference
    → AWS IoT Core → S3 (raw/)
    → Risk Normalizer → AMP → Grafana

📊 Data/Dashboard VPC  (Phase 6+)
    ALB / Dashboard Web-API / Risk Engine / RDS / Redis
```

> 📖 상세 아키텍처 → [docs/architecture/](docs/architecture/)

---

## 🛠️ 기술 스택

| 계층 | 기술 |
|------|------|
| 🏭 Edge | Raspberry Pi · K3s v1.34 · Longhorn · MetalLB |
| 🔁 GitOps | ArgoCD · Helm · GitHub Actions |
| ☁️ Cloud | AWS EKS · VPC · IAM/IRSA · IoT Core · S3 · AMP |
| 🔐 Networking | Tailscale Mesh VPN · Tailscale Kubernetes Operator |
| 📈 Monitoring | Prometheus Agent · AMP · Grafana |
| 🏗️ Infra-as-Code | Terraform · Ansible |
| 🌐 DNS/TLS | Route53 · ACM · AWS Load Balancer Controller |

---

## 📅 구현 단계

| 단계 | 내용 | 상태 |
|------|------|:----:|
| M0 | factory-a Safe-Edge 기준선 | ✅ 완료 |
| M1 | AWS EKS Hub 기준선 | 🔄 Issue 0~10 완료 |
| M2 | Hub-Spoke Mesh VPN 연결 | 🔄 Issue 1~6 완료 |
| M3 | 배포 파이프라인 | 🟡 설계 중 |
| M4 | Edge Agent · 데이터 파이프라인 | ⏳ 대기 |
| M5 | factory-b/c 테스트베드 확장 | ⏳ 대기 |
| M6 | Risk Twin Dashboard VPC | ⏳ 대기 |
| M7 | 통합 검증 | ⏳ 대기 |

> 전체 체크리스트 → [docs/issues/MASTER_CHECKLIST.md](docs/issues/MASTER_CHECKLIST.md)

---

## 🚀 빠른 시작

```bash
git clone git@github.com:Team-msp-architect-2026/msp-team03.git
cd msp-team03
```

**Hub 재구성**
```bash
scripts/build/build-all.sh             # EKS + foundation 전체
scripts/build/build-all.sh --admin-ui  # Admin UI 포함
```

**Hub 전체 삭제**
```bash
scripts/destroy/destroy-all.sh
```

> 📖 운영 상세 → [docs/ops/00_quick_start.md](docs/ops/00_quick_start.md)

---

## 📂 디렉토리 구조

```
.
├── 📁 .github/              # Issue/PR 템플릿, CODEOWNERS
├── 📁 docs/
│   ├── adr/                 # Architecture Decision Records (001~004)
│   ├── architecture/        # 현재/목표 아키텍처
│   ├── issues/              # 마일스톤 추적 (M0~M7)
│   ├── ops/                 # 운영 Runbook (00~21)
│   ├── planning/            # 설계 및 결정 문서
│   ├── specs/               # 기능 명세
│   ├── demo/                # 데모 시나리오
│   ├── product/             # 제품 요구사항
│   ├── report/              # 결과 보고서
│   └── presentation/        # 발표 자료
├── 📁 infra/                # Terraform (hub · foundation · mesh-vpn)  [예정]
├── 📁 apps/                 # 애플리케이션 소스  [예정]
├── 📁 charts/               # Helm Charts  [예정]
├── 📁 scripts/              # build · destroy · iot · ops 스크립트  [예정]
└── README.md
```

---

## 📚 문서 네비게이션

| 문서 | 경로 |
|------|------|
| 📋 프로젝트 개요 | [docs/planning/00_project_overview.md](docs/planning/00_project_overview.md) |
| 🗺️ 현재 아키텍처 | [docs/architecture/00_current_architecture.md](docs/architecture/00_current_architecture.md) |
| 🎯 목표 아키텍처 | [docs/architecture/01_target_architecture.md](docs/architecture/01_target_architecture.md) |
| ⚡ 빠른 시작 | [docs/ops/00_quick_start.md](docs/ops/00_quick_start.md) |
| 🏭 factory-a 현황 | [docs/ops/05_factory_a_status.md](docs/ops/05_factory_a_status.md) |
| ✅ 마일스톤 체크리스트 | [docs/issues/MASTER_CHECKLIST.md](docs/issues/MASTER_CHECKLIST.md) |
| 📝 ADR 목록 | [docs/adr/README.md](docs/adr/README.md) |
| 💰 비용 기준 | [docs/ops/15_aws_cost_baseline.md](docs/ops/15_aws_cost_baseline.md) |

---

## 🤝 기여 방법

[CONTRIBUTING.md](CONTRIBUTING.md) 참조

## 📄 라이선스

[MIT](LICENSE)
