# L2Comm -> L2Comm02 Migration Notes

`Gcp_Managed_GKE_L2Comm02`는 기존 PoC 검증 결과를 기반으로 IP 고갈과 운영 확장성을 고려해 Network 설계를 변경한 버전입니다.

## 주요 변경점

| 항목 | 기존 L2Comm | L2Comm02 최종 |
|---|---|---|
| Node Primary | `10.254.0.0/28` | `10.254.0.0/26` |
| Pod Secondary | `10.254.2.0/23` | `100.64.0.0/21` |
| Service Secondary | `10.254.4.0/24` | 별도 Secondary 미사용 |
| Service CIDR | Subnet Secondary | GKE Managed / 별도 CIDR 미설정 |
| Control Plane | `10.254.5.0/28` | `10.254.5.0/28` 유지 |
| Image Build | Git 변경 시 Trigger | 동일, Batch 실행과 분리 |
| Runtime | Scheduler -> Workflow -> GKE Job | 동일 |

## 현재 상태

기존 GKE Autopilot Cluster는 **강제 삭제된 상태**입니다.

따라서 기존 Cluster의 Pod/Service CIDR을 In-place 변경하는 절차가 아니라,
Subnet/Secondary Range를 최종 설계에 맞춘 후 **Autopilot Cluster를 신규 재생성**하는 흐름으로 진행합니다.

권장 순서:

```text
1. 기존 GKE Cluster 삭제 상태 확인
2. 신규 CIDR 중복 확인
3. 10-network 적용
   - Node Primary 10.254.0.0/26
   - Pod Secondary 100.64.0.0/21
   - Service Secondary 없음
4. Subnet 최종 상태 확인
5. 20-source-connection 확인
6. 30-infra-manager 적용
   - GKE Autopilot 신규 생성
7. 40-scheduler 검증
8. GKE Job / BigQuery 결과 확인
```

## CIDR 사전 확인

네트워크팀에서 다음을 확인합니다.

```text
10.254.0.0/26
- 기존 서버망/Shared VPC/Subnet/Peering과 중복 여부

100.64.0.0/21
- 사내 CGNAT/VPN/보안장비 사용 여부
- Interconnect를 통한 On-Prem Return Route 가능 여부

10.254.5.0/28
- VPC/Peering/On-Prem Route와 중복 여부
```

## 동일 VPC 내부 통신

동일 Shared VPC 내에서 정상 등록된 Subnet/Secondary Range 사이에는 별도 Static Route를 추가하지 않습니다.

```text
Pod 100.64.x.x
  -> GCP VPC system route
  -> GCP 내부 172.x / 10.x 서비스
```

단, 대상 서비스의 Firewall/HFP/Network Policy가 Pod Source 대역을 허용해야 합니다.

## On-Prem 172.x 통신

```text
Pod 100.64.0.0/21
  -> Cloud Router / Interconnect
  -> On-Prem 172.x

On-Prem 172.x
  -> Return Route 100.64.0.0/21
  -> GCP
```

GCP -> On-Prem Forward Route만 존재하고 Return Route가 없으면 통신이 실패합니다.
