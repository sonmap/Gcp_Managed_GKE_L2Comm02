# 20-source-connection

기존 Cloud Build 2nd-gen GitHub Connection `github-l2comm`에 새 Repository `Gcp_Managed_GKE_L2Comm02`를 연결하는 1회성 단계입니다.

> Connection 자체는 OAuth/Secret Manager 연계가 필요하므로 기존 검증된 `github-l2comm` Connection을 재사용합니다.

## 1. Connection 확인

```bash
gcloud builds connections list \
  --project=gcp-prod-edp-edge-509423 \
  --region=asia-northeast3
```

## 2. 새 Repository 연결

```bash
gcloud builds repositories create Gcp_Managed_GKE_L2Comm02 \
  --project=gcp-prod-edp-edge-509423 \
  --region=asia-northeast3 \
  --connection=github-l2comm \
  --remote-uri=https://github.com/sonmap/Gcp_Managed_GKE_L2Comm02.git
```

이미 생성되어 있으면 재생성하지 않습니다.

## 3. 확인

```bash
gcloud builds repositories list \
  --connection=github-l2comm \
  --region=asia-northeast3 \
  --project=gcp-prod-edp-edge-509423
```

아래 Repository가 보여야 합니다.

```text
Gcp_Managed_GKE_L2Comm02
https://github.com/sonmap/Gcp_Managed_GKE_L2Comm02.git
```

완료 후 `terraform/30-infra-manager`를 적용하면 `trg-l2comm02-python-image` Trigger가 이 Repository를 참조합니다.
