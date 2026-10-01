# L2Comm -> L2Comm02 Migration Notes

`Gcp_Managed_GKE_L2Comm02`는 기존 PoC를 그대로 복제한 것이 아니라, IP 고갈과 운영 확장성을 고려해 Network 설계를 변경한 버전입니다.

## 주요 변경점

| 항목 | 기존 L2Comm | L2Comm02 |
|---|---|---|
| Node Primary | `10.254.0.0/28` | `10.254.0.0/26` |
| Pod Secondary | `10.254.2.0/23` | `100.64.0.0/18` |
| Service Secondary | `10.254.4.0/24` | 별도 Secondary 미사용 |
| Service CIDR | Subnet Secondary | GKE Managed `34.118.224.0/20` |
| Control Plane | `10.254.5.0/28` | `10.254.5.0/28` 유지 |
| Image Build | Git 변경 시 Trigger | 동일, Batch 실행과 분리 |
| Runtime | Scheduler -> Workflow -> GKE Job | 동일 |

## 중요: 기존 Cluster의 단순 In-place 변경으로 보지 않음

Pod Secondary Range를 `10.254.2.0/23`에서 `100.64.0.0/18`로 이동하고 Service Range 방식을 변경하는 것은 기존 Cluster/Secondary Range를 단순 수정하는 작업으로 처리하지 않는 것을 권장합니다.

권장 절차:

```text
1. 기존 PoC 자원/사용 여부 확인
2. 신규 CIDR 중복 확인
3. 기존 Cluster를 유지해야 하면 신규 Subnet/Cluster 이름과 비중복 CIDR 별도 확보
4. 기존 Cluster를 대체한다면 서비스 중단 계획 후 기존 Cluster/Range 정리
5. 10-network 적용
6. 20-source-connection 적용
7. 30-infra-manager 적용
8. 40-scheduler 검증
```

## CIDR 사전 확인

반드시 네트워크팀에서 다음을 확인합니다.

```text
10.254.0.0/26
- 기존 서버망/Shared VPC/Subnet/Peering과 중복 여부

100.64.0.0/18
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
  -> GCP 내부 172.x 서비스
```

단, 대상 서비스의 Firewall/HFP/Network Policy가 Pod Source 대역을 허용해야 합니다.

## On-Prem 172.x 통신

```text
Pod 100.64.0.0/18
  -> Cloud Router / Interconnect
  -> On-Prem 172.x

On-Prem 172.x
  -> Return Route 100.64.0.0/18
  -> GCP
```

GCP -> On-Prem Forward Route만 존재하고 Return Route가 없으면 통신이 실패합니다.
