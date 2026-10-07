# 30-infra-manager

## 사전 조건

1. `00-bootstrap` 완료
2. `10-network` 완료
3. `20-source-connection`에서 `Gcp_Managed_GKE_L2Comm02` Repository 연결 완료
4. 신규 CIDR 중복 검토 완료

최종 Network 기준:

```text
Node Primary  : 10.254.0.0/26
Pod Secondary : 100.64.0.0/21
Service       : GKE Managed / 별도 CIDR 미설정
Control Plane : 10.254.5.0/28
```

현재 GKE Autopilot Cluster는 강제 삭제된 상태이므로 30 단계에서 새 Cluster를 생성합니다.

## 적용

```bash
gcloud infra-manager deployments apply \
  projects/gcp-prod-edp-edge-509423/locations/asia-northeast3/deployments/l2comm-platform \
  --service-account=projects/gcp-prod-edp-edge-509423/serviceAccounts/sa-l2comm-inframgr@gcp-prod-edp-edge-509423.iam.gserviceaccount.com \
  --git-source-repo=https://github.com/sonmap/Gcp_Managed_GKE_L2Comm02.git \
  --git-source-directory=terraform/30-infra-manager \
  --git-source-ref=main
```

## 확인

```bash
gcloud container clusters describe gke-l2comm-batch-an3 \
  --project=gcp-prod-edp-edge-509423 \
  --region=asia-northeast3
```

```bash
gcloud builds triggers list \
  --project=gcp-prod-edp-edge-509423 \
  --region=asia-northeast3
```

```bash
gcloud workflows describe wf-l2comm-gke-job \
  --project=gcp-prod-edp-edge-509423 \
  --location=asia-northeast3
```

Cluster 생성 후 확인 포인트:

```text
Subnet        : subnet-prod-edp-l2comm-gke-an3
Node Primary  : 10.254.0.0/26
Pod Range     : pods-prod-edp-l2comm-an3 = 100.64.0.0/21
Service Range : 별도 Subnet Secondary 없음
Control Plane : 10.254.5.0/28
```
