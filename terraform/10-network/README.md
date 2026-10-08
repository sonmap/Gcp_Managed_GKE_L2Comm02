# 10-network

## 최종 설계값

| 구분 | Range | CIDR | 용도 |
|---|---|---|---|
| Node Primary | Primary | `10.252.1.0/24` | GKE Node IP |
| Pod Secondary | `pods-prod-edp-l2comm-an3` | `100.64.128.0/19` | Pod IP |
| Service | GKE Managed | 미설정 | ClusterIP Service |
| Control Plane | Master CIDR | `10.254.5.0/28` | Private Control Plane |

Service Secondary Range는 Subnet에 생성하지 않습니다.

> Control Plane은 요청하신 `10.x.x.x/28` 조건을 만족하는 기존 값
> `10.254.5.0/28`을 유지합니다.

## 사전 확인

```bash
gcloud compute networks subnets list \
  --project=gcp-prod-edp-hub-vpchost \
  --regions=asia-northeast3
```

기존 Subnet/Route/On-Prem 네트워크와 아래 CIDR 중복이 없어야 합니다.

```text
10.252.1.0/24
100.64.128.0/19
10.254.5.0/28
```

특히 `100.64.128.0/19`은 사내 CGNAT/VPN/보안장비 사용 여부를 확인합니다.

## 적용

기존 GKE Autopilot과 기존 Infra Manager Deployment는 삭제된 상태를 기준으로 합니다.
기존 L2Comm 전용 Subnet도 정리한 뒤 새 설계로 생성합니다.

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
Primary: 10.252.1.0/24
Secondary Pods: 100.64.128.0/19
Service Secondary: 없음
```

30 단계에서 GKE Autopilot Cluster를 새로 생성하며 Service Range는 별도로 지정하지 않습니다.
