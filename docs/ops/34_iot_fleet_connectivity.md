# IoT Fleet Connectivity Runbook

상태: source of truth
기준일: 2026-06-09

## 목적

AWS IoT Fleet Indexing의 Thing connectivity를 `factory-a/b/c` 운영 지표로 사용하는 기준을 정리한다. 이 문서는 `edge-iot-publisher` persistent MQTT 전환 이후의 현재 기준이다.

## 현재 기준

- AWS IoT Fleet Indexing은 `thingIndexingMode=REGISTRY`, `thingConnectivityIndexingMode=STATUS`로 활성화한다.
- `edge-iot-publisher`는 프로세스 생명주기 동안 MQTT 연결을 유지한다.
- MQTT client ID는 IoT Thing 이름과 같아야 한다.
- 각 factory의 `edge-iot-publisher` Deployment는 `replicaCount=1`, `strategy=Recreate`를 유지한다.
- outbox JSON 파일은 QoS 1 publish ack가 완료된 뒤에만 삭제한다.
- publish 실패, ack timeout, reconnect 실패 시 outbox 파일은 유지하고 다음 loop에서 재시도한다.
- SIGTERM/SIGINT 시 publisher는 graceful MQTT disconnect를 시도한다.

현재 배포 기준:

```text
source repo commit: 36eae8c Use persistent MQTT connection for edge publisher
GitOps repo commit: 7fc8cae Deploy persistent MQTT publisher image
image: 611058323802.dkr.ecr.ap-south-1.amazonaws.com/aegis/edge-iot-publisher:sha-36eae8c
digest: sha256:c86dd7f7544035acb8ce9093f0c7614e8f0726cacd264ee27eadd46887c92517
```

## Thing과 client ID

| Factory | Thing name | MQTT client ID |
| --- | --- | --- |
| `factory-a` | `AEGIS-IoTThing-factory-a` | `AEGIS-IoTThing-factory-a` |
| `factory-b` | `AEGIS-IoTThing-factory-b` | `AEGIS-IoTThing-factory-b` |
| `factory-c` | `AEGIS-IoTThing-factory-c` | `AEGIS-IoTThing-factory-c` |

GitOps chart는 `edgeIotPublisher.iot.clientId`가 비어 있으면 `AEGIS-IoTThing-{{ factory.id }}`를 기본값으로 사용한다. 값을 override할 때도 위 표와 일치시켜야 한다.

## short-lived 방식과 persistent 방식의 차이

이전 publisher는 outbox 파일을 보낼 때마다 `CONNECT -> PUBLISH -> DISCONNECT`를 수행했다. 이 방식은 데이터 유입에는 문제가 없지만, 조회 시점의 MQTT 세션이 대부분 닫혀 있으므로 Fleet Indexing의 `connected`가 `false`로 보였다.

현재 publisher는 outbox 구조는 유지하면서 MQTT 세션을 지속 연결로 유지한다. 따라서 AWS IoT 콘솔과 CLI에서 Thing connectivity를 현재 연결 상태 지표로 사용할 수 있다.

발표 설명:

```text
초기 publisher는 메시지 단위로 MQTT 연결을 열고 닫는 short-lived 방식이라 데이터는 정상 유입돼도 IoT Core의 Thing connectivity는 disconnected로 표시됐다. 이후 outbox 기반 재시도 구조는 유지하면서 publisher를 persistent MQTT 연결 방식으로 개선했다. 각 factory publisher는 Thing 이름과 동일한 client ID로 AWS IoT Core에 연결을 유지하고, Fleet Indexing으로 세 factory의 연결 상태를 콘솔에서 실시간 확인할 수 있다.
```

## 검증

Fleet Indexing 설정:

```bash
aws iot get-indexing-configuration
```

정상 기준:

```text
thingIndexingMode: REGISTRY
thingConnectivityIndexingMode: STATUS
thingGroupIndexingMode: OFF
managedFields includes connectivity.connected, connectivity.timestamp, connectivity.disconnectReason, connectivity.clientId
```

Thing connectivity:

```bash
aws iot get-thing-connectivity-data --thing-name AEGIS-IoTThing-factory-a
aws iot get-thing-connectivity-data --thing-name AEGIS-IoTThing-factory-b
aws iot get-thing-connectivity-data --thing-name AEGIS-IoTThing-factory-c
```

정상 기준:

```text
connected: true
disconnectReason: NONE
```

현재 확인 결과:

```text
AEGIS-IoTThing-factory-a: connected=true, disconnectReason=NONE
AEGIS-IoTThing-factory-b: connected=true, disconnectReason=NONE
AEGIS-IoTThing-factory-c: connected=true, disconnectReason=NONE
```

Kubernetes 배포 안전성:

```bash
scripts/ops/check-spoke-publisher-safety.sh
```

정상 기준:

```text
factory-a/b/c each has one edge-iot-publisher Deployment
desired replicas: 1
running publisher pods: 1
strategy: Recreate
```

Pod 설정 확인 예:

```bash
kubectl --kubeconfig "${FACTORY_KUBECONFIG}" -n ai-apps get deploy aegis-spoke-edge-iot-publisher \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}{.spec.template.spec.containers[0].env[?(@.name=="AEGIS_IOT_CLIENT_ID")].value}{"\n"}'
```

Publisher 로그 확인:

```bash
kubectl --kubeconfig "${FACTORY_KUBECONFIG}" -n ai-apps logs deploy/aegis-spoke-edge-iot-publisher --tail=100
```

정상 기준은 `factory_state`와 `infra_state` publish가 반복 성공하는 것이다.

## Hub-only 재시작 시 동작

Hub EKS, ArgoCD, Tailscale egress는 관리/control plane이다. Hub를 삭제해도 Spoke K3s의 publisher Pod와 AWS IoT 연결은 직접 경로로 계속 동작할 수 있다.

Hub-only 비용 절감 흐름:

```bash
# 퇴근 시
scripts/destroy/destroy-hub.sh --plan-only [MFA_OTP]
scripts/destroy/destroy-hub.sh --yes [MFA_OTP]

# 출근 시
scripts/build/build-hub.sh [MFA_OTP]
scripts/build/build-admin-ui-after-ns.sh [MFA_OTP]
HUB_ONLY_RECONNECT=true scripts/build/register-spoke-factory-a.sh [MFA_OTP]
HUB_ONLY_RECONNECT=true scripts/build/register-spoke-factory-b.sh [MFA_OTP]
HUB_ONLY_RECONNECT=true scripts/build/register-spoke-factory-c.sh [MFA_OTP]
scripts/ops/check-spoke-publisher-safety.sh
```

이 모드에서는 `stop-dummy-generators.sh`, `destroy-data-pipe.sh`, `build-data-pipe.sh`를 실행하지 않는다. 기존 Spoke publisher와 data-pipeline을 유지해야 AWS IoT 연결과 데이터 적재가 계속된다.

## Failover와 종료 시 동작

- 정상 Pod 종료: Kubernetes가 SIGTERM을 보내고 publisher가 MQTT disconnect를 시도한다. Fleet Indexing은 짧은 시간 안에 disconnected로 바뀔 수 있다.
- 강제 종료 또는 네트워크 단절: DISCONNECT 패킷 없이 끊기며 AWS IoT keepalive timeout 이후 disconnected로 판단된다.
- Pod 재스케줄: 새 Pod가 같은 Thing client ID로 연결하고 Fleet Indexing은 다시 connected가 된다.
- Hub만 삭제: Spoke Pod가 유지되면 AWS IoT 연결도 유지된다.

`Recreate` 전략과 `replicaCount=1`은 같은 MQTT client ID를 가진 두 Pod가 동시에 떠서 서로 연결을 끊는 상황을 줄이기 위한 필수 기준이다.

## 장애 대응

### connected=false인데 데이터는 들어오는 경우

가능성:

- publisher가 아직 short-lived image를 사용 중이다.
- `AEGIS_IOT_CLIENT_ID`가 Thing name과 다르다.
- Pod가 재시작 중이거나 AWS IoT reconnect 중이다.
- 같은 client ID를 쓰는 legacy local publisher나 다른 Pod가 동시에 연결 중이다.

확인:

```bash
aws iot search-index --query-string "connectivity.connected:true" --max-results 20
scripts/ops/check-spoke-publisher-safety.sh
```

### ImagePull 403 Forbidden

Spoke K3s는 EKS node role을 상속받지 않으므로 `ai-apps/ecr-registry` imagePullSecret의 ECR token이 만료되면 새 image rollout이 실패한다. 자세한 해결 절차는 `docs/ops/04_troubleshooting.md`의 ECR pull secret 항목을 따른다.

### IoT index가 아직 준비되지 않은 경우

Fleet Indexing을 처음 켠 직후에는 `IndexNotReadyException`이 날 수 있다. 잠시 기다렸다가 같은 `get-thing-connectivity-data` 명령을 다시 실행한다.

## AWS 콘솔 확인 경로

```text
AWS IoT Core console
-> Manage
-> Things
-> AEGIS-IoTThing-factory-a/b/c
-> connectivity/status 영역 확인
```

Fleet Indexing 설정은 AWS IoT Core console의 `Settings` 또는 `Fleet indexing` 메뉴에서 확인한다.
