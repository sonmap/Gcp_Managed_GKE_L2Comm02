# 10-network

## 최종 설계값

| 구분 | Range | CIDR | 용도 |
|---|---|---|---|
| Node Primary | Primary | `10.254.0.0/26` | GKE Node IP |
| Pod Secondary | `pods-prod-edp-l2comm-an3` | `100.64.0.0/21` | Pod IP |
| Service | GKE Managed | 미설정 | ClusterIP Service |
| Control Plane | Master CIDR | `10.254.5.0/28` | Private Control Plane |

Service Secondary Range는 Subnet에 생성하지 않습니다.

## 사전 확인

```bash
gcloud compute networks subnets list \
  --project=gcp-prod-edp-hub-vpchost \
  --regions=asia-northeast3
```

기존 Subnet/Route/On-Prem 네트워크와 아래 CIDR 중복이 없어야 합니다.

```text
10.254.0.0/26
100.64.0.0/21
10.254.5.0/28
```

특히 `100.64.0.0/21`은 사내 CGNAT/VPN/보안장비 사용 여부를 확인합니다.

## 적용

현재 GKE Autopilot Cluster는 강제 삭제된 상태이므로,
먼저 10-network에서 Subnet/Pod Secondary Range를 최종 값으로 맞춘 뒤
30-infra-manager에서 Cluster를 재생성합니다.

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
Secondary Pods: 100.64.0.0/21
Service Secondary: 없음
```

30 단계에서 GKE Autopilot Cluster를 새로 생성하며 Service Range는 별도로 지정하지 않습니다.
