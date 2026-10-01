# 30-infra-manager

## 사전 조건

1. `00-bootstrap` 완료
2. `10-network` 완료
3. `20-source-connection`에서 `Gcp_Managed_GKE_L2Comm02` Repository 연결 완료
4. 신규 CIDR 중복 검토 완료

## 적용

기존 L2Comm PoC의 동일 Infrastructure Manager deployment를 업데이트하는 경우:

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
gcloud builds triggers list \
  --project=gcp-prod-edp-edge-509423 \
  --region=asia-northeast3
```

```bash
gcloud container clusters describe gke-l2comm-batch-an3 \
  --project=gcp-prod-edp-edge-509423 \
  --region=asia-northeast3
```

```bash
gcloud workflows describe wf-l2comm-gke-job \
  --project=gcp-prod-edp-edge-509423 \
  --location=asia-northeast3
```

## 중요

기존 Cluster가 `10.254.2.0/23` Pod range와 `10.254.4.0/24` Service secondary range를 사용 중이라면 L2Comm02의 Network 변경을 단순 In-place 수정으로 적용하지 않습니다. `docs/MIGRATION.md`를 먼저 확인합니다.
