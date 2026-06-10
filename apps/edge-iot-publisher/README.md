# Edge IoT Publisher

`edge-iot-publisher` reads canonical AEGIS JSON files from the local spool/outbox and publishes them to AWS IoT Core. It does not collect sensor data directly.

Current deployment baseline as of 2026-06-09:

```text
image: 611058323802.dkr.ecr.ap-south-1.amazonaws.com/aegis/edge-iot-publisher:sha-36eae8c
digest: sha256:c86dd7f7544035acb8ce9093f0c7614e8f0726cacd264ee27eadd46887c92517
```

## Configuration

| Environment variable | Default |
| --- | --- |
| `AEGIS_OUTBOX_DIR` | `/var/lib/aegis/outbox` |
| `AEGIS_DATA_PLANE_INSTANCE_ID` | `edge-iot-publisher-{hostname}` |
| `AEGIS_IOT_ENDPOINT` | required |
| `AEGIS_IOT_PORT` | `8883` |
| `AEGIS_IOT_CLIENT_ID` | `AEGIS_DATA_PLANE_INSTANCE_ID` |
| `AEGIS_IOT_CA_FILE` | required |
| `AEGIS_IOT_CERT_FILE` | required |
| `AEGIS_IOT_KEY_FILE` | required |
| `AEGIS_IOT_TIMEOUT_SECONDS` | `10` |
| `AEGIS_IOT_RECONNECT_MIN_DELAY_SECONDS` | `1` |
| `AEGIS_IOT_RECONNECT_MAX_DELAY_SECONDS` | `60` |
| `AEGIS_PUBLISHER_BACKOFF_SECONDS` | `5` |
| `AEGIS_PUBLISHER_MAX_BACKOFF_SECONDS` | `60` |

## Behavior

The default MQTT implementation uses `paho-mqtt` and keeps one TLS MQTT connection open for the publisher process lifetime. Messages are published with QoS 1, so the local outbox file is deleted only after the MQTT publish ack completes. If the connection drops, reconnect fails, or the ack does not complete, the file remains in the outbox and is retried after reconnect/backoff.

The publisher scans only `*.json` files directly under the outbox root. It ignores `tmp/` and `quarantine/` directories.

For every valid message it:

1. overwrites `published_at` with the actual publish time,
2. overwrites `data_plane_instance_id` with the publisher instance ID,
3. publishes to `aegis/{factory_id}/{source_type}`,
4. deletes the local outbox file after successful QoS 1 publish ack.

Invalid JSON or schema-invalid files are moved to `outbox/quarantine/`. Publish failures leave the file in the outbox for retry.

For AWS IoT Fleet Indexing connectivity, `AEGIS_IOT_CLIENT_ID` must match the Thing name:

```text
factory-a: AEGIS-IoTThing-factory-a
factory-b: AEGIS-IoTThing-factory-b
factory-c: AEGIS-IoTThing-factory-c
```

The Kubernetes chart defaults this value to `AEGIS-IoTThing-<factory-id>`.

## Local Run

```bash
AEGIS_IOT_ENDPOINT=example-ats.iot.ap-northeast-2.amazonaws.com \
AEGIS_IOT_CA_FILE=/etc/aegis/iot/AmazonRootCA1.pem \
AEGIS_IOT_CERT_FILE=/etc/aegis/iot/device.pem.crt \
AEGIS_IOT_KEY_FILE=/etc/aegis/iot/private.pem.key \
python3 apps/edge-iot-publisher/edge_iot_publisher.py --once
```

Run continuously:

```bash
python3 apps/edge-iot-publisher/edge_iot_publisher.py --loop
```

## Operations

The Spoke Deployment must stay at one running publisher pod per factory. Keep the Helm chart values at `replicaCount: 1` and the Deployment strategy at `Recreate`; otherwise two pods with the same MQTT client ID can disconnect each other.

AWS IoT connectivity check:

```bash
aws iot get-thing-connectivity-data --thing-name AEGIS-IoTThing-factory-a
aws iot get-thing-connectivity-data --thing-name AEGIS-IoTThing-factory-b
aws iot get-thing-connectivity-data --thing-name AEGIS-IoTThing-factory-c
```

See `docs/ops/34_iot_fleet_connectivity.md` for the full runbook.

## Tests

```bash
python3 -m unittest discover -s apps/edge-iot-publisher/tests
python3 -m py_compile apps/edge-iot-publisher/edge_iot_publisher.py
```
