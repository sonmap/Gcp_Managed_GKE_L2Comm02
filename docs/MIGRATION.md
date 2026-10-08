# L2Comm -> L2Comm02 Migration Notes

`Gcp_Managed_GKE_L2Comm02`는 기존 PoC 검증 결과를 기반으로 IP 고갈과 운영 확장성을 고려해 Network 설계를 변경한 버전입니다.

## 주요 변경점

| 항목 | 기존 L2Comm | L2Comm02 최종 |
|---|---|---|
| Node Primary | `10.254.0.0/28` | `10.252.1.0/24` |
| Pod Secondary | `10.254.2.0/23` | `100.64.128.0/19` |
| Service Secondary | `10.254.4.0/24` | 별도 Secondary 미사용 |
| Service CIDR | Subnet Secondary | GKE Managed / 별도 CIDR 미설정 |
| Control Plane | `10.254.5.0/28` | `10.254.5.0/28` 유지 |
| Image Build | Git 변경 시 Trigger | 동일, Batch 실행과 분리 |
| Runtime | Scheduler -> Workflow -> GKE Job | 동일 |

## 현재 상태

기존 GKE Autopilot과 기존 Infra Manager Deployment는 삭제된 상태입니다.
기존 L2Comm 전용 Subnet을 수동 정리한 뒤 신규 Network를 생성합니다.

권장 순서:

```text
1. 기존 GKE Cluster 삭제 확인
2. 기존 L2Comm 전용 Subnet 삭제 확인
3. 신규 CIDR 중복 확인
4. 10-network 적용
   - Node Primary 10.252.1.0/24
   - Pod Secondary 100.64.128.0/19
   - Service Secondary 없음
5. Subnet 최종 상태 확인
6. 20-source-connection 확인
7. 30-infra-manager 적용
   - GKE Autopilot 신규 생성
8. 40-scheduler 재생성/검증
9. GKE Job / BigQuery 결과 확인
```

## CIDR 사전 확인

```text
10.252.1.0/24
- 기존 서버망/Shared VPC/Subnet/Peering과 중복 여부

100.64.128.0/19
- 사내 CGNAT/VPN/보안장비 사용 여부
- Interconnect를 통한 On-Prem Return Route 가능 여부

10.254.5.0/28
- Private Control Plane용 10.x /28
- VPC/Peering/On-Prem Route와 중복 여부
```

## 동일 VPC 내부 통신

동일 Shared VPC 내에서 정상 등록된 Subnet/Secondary Range 사이에는 별도 Static Route를 추가하지 않습니다.

```text
Pod 100.64.128.x
  -> GCP VPC system route
  -> GCP 내부 172.x / 10.x 서비스
```

단, 대상 서비스의 Firewall/HFP/Network Policy가 Pod Source 대역을 허용해야 합니다.

## On-Prem 통신

```text
Pod 100.64.128.0/19
  -> Cloud Router / Interconnect
  -> On-Prem

On-Prem
  -> Return Route 100.64.128.0/19
  -> GCP
```

GCP -> On-Prem Forward Route만 존재하고 Return Route가 없으면 통신이 실패합니다.
