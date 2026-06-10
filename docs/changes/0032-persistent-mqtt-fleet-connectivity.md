# 0032 Persistent MQTT for IoT Fleet Connectivity

상태: accepted
결정일: 2026-06-09

## 기존 계획

`edge-iot-publisher`는 outbox JSON 파일을 AWS IoT Core로 보낼 때마다 MQTT 연결을 열고 publish 후 정상 disconnect했다. 이 구조는 S3 raw, Lambda data processor, DynamoDB/S3 processed 적재에는 충분했지만 AWS IoT Fleet Indexing의 Thing connectivity를 운영 지표로 쓰기 어려웠다.

## 변경된 실제 기준

`edge-iot-publisher`를 persistent MQTT connection 방식으로 변경했다.

- publisher 프로세스 생명주기 동안 MQTT 연결을 유지한다.
- `paho-mqtt`를 사용한다.
- QoS 1 publish ack가 완료된 경우에만 outbox JSON 파일을 삭제한다.
- publish 실패, ack timeout, reconnect 실패 시 outbox 파일은 유지한다.
- loop 중 연결이 끊기면 reconnect/backoff 후 재시도한다.
- SIGTERM/SIGINT 시 graceful disconnect를 호출한다.
- `AEGIS_IOT_CLIENT_ID`는 기존 chart 기본값인 `AEGIS-IoTThing-<factory-id>`를 유지한다.

배포 기준:

```text
source commit: 36eae8c Use persistent MQTT connection for edge publisher
GitOps commit: 7fc8cae Deploy persistent MQTT publisher image
image: 611058323802.dkr.ecr.ap-south-1.amazonaws.com/aegis/edge-iot-publisher:sha-36eae8c
digest: sha256:c86dd7f7544035acb8ce9093f0c7614e8f0726cacd264ee27eadd46887c92517
```

## 변경 이유

AWS IoT Fleet Indexing의 `connected`는 데이터 유입 여부가 아니라 현재 MQTT 세션 유지 여부를 나타낸다. short-lived publish 방식에서는 데이터가 정상 유입돼도 조회 시점에는 disconnected로 표시되는 것이 정상이었다.

운영과 발표에서 AWS IoT 콘솔의 connectivity status를 직접 보여주려면 Thing 이름과 같은 client ID로 MQTT 세션을 유지하는 방식이 더 적합하다.

## 영향

- AWS IoT 콘솔과 CLI에서 `factory-a/b/c` Thing connectivity를 운영 지표로 사용할 수 있다.
- Hub-only rebuild 중 Hub를 내려도 Spoke publisher가 살아 있으면 AWS IoT 연결과 데이터 유입은 유지된다.
- Pod failover 또는 rollout 시에는 짧은 disconnect/connect 이벤트가 발생할 수 있다.
- 같은 client ID를 쓰는 Pod가 동시에 뜨면 연결 churn이 발생하므로 `replicaCount=1`, `strategy=Recreate`를 유지해야 한다.
- legacy local dummy publisher와 K3s `edge-iot-publisher`를 동시에 실행하면 같은 client ID 충돌이 생길 수 있다.
- Spoke K3s의 ECR pull secret 만료 시 새 image rollout이 `403 Forbidden`으로 실패할 수 있으므로 pull secret 갱신 절차를 운영에 포함한다.

## 업데이트 필요한 문서

- `apps/edge-iot-publisher/README.md`
- `docs/ops/00_quick_start.md`
- `docs/ops/04_troubleshooting.md`
- `docs/ops/34_iot_fleet_connectivity.md`
- `scripts/build/README.md`
- `scripts/destroy/README.md`
- `charts/aegis-spoke/README.md`
- `envs/factory-a/README.md`

## 검증

로컬 검증:

```text
python3 -m unittest discover -s apps/edge-iot-publisher/tests: 12 tests OK
python3 -m py_compile apps/edge-iot-publisher/edge_iot_publisher.py: OK
```

배포 검증:

```text
aegis-spoke-factory-a: Synced / Healthy
aegis-spoke-factory-b: Synced / Healthy
aegis-spoke-factory-c: Synced / Healthy
factory-a/b/c publisher rollout: successfully rolled out
factory-a/b/c publisher Deployment: replicas=1, strategy=Recreate, running pod=1
```

AWS IoT Fleet Indexing:

```text
AEGIS-IoTThing-factory-a: connected=true, disconnectReason=NONE
AEGIS-IoTThing-factory-b: connected=true, disconnectReason=NONE
AEGIS-IoTThing-factory-c: connected=true, disconnectReason=NONE
```

인증서 재발급, IoT Thing/Certificate/Policy 변경은 하지 않았다.
