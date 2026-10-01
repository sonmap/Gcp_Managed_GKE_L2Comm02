# 10-network

## 설계값

| 구분 | CIDR |
|---|---|
| Node Primary | `10.254.0.0/26` |
| Pod Secondary | `100.64.0.0/18` |
| Service | GKE Managed `34.118.224.0/20` |
| Control Plane | `10.254.5.0/28` (30 단계) |

## 사전 확인

```bash
gcloud compute networks subnets list \
  --project=gcp-prod-edp-hub-vpchost \
  --regions=asia-northeast3
```

기존 Subnet/Route/On-Prem 네트워크와 아래 CIDR 중복이 없어야 합니다.

```text
10.254.0.0/26
100.64.0.0/18
10.254.5.0/28
```

특히 `100.64.0.0/18`은 사내 CGNAT/VPN/보안장비 사용 여부를 확인합니다.

## 적용

```bash
cd terraform/10-network
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

## 확인

```bash
gcloud compute networks subnets describe subnet-prod-edp-l2comm-gke-an3 \
  --project=gcp-prod-edp-hub-vpchost \
  --region=asia-northeast3
```

기대값:

```text
Primary: 10.254.0.0/26
Secondary Pods: 100.64.0.0/18
Service Secondary: 없음
```

Service IP는 30 단계에서 GKE Autopilot 기본 관리형 `34.118.224.0/20`을 사용합니다.
