# 40-scheduler

Cloud Scheduler가 `wf-l2comm-gke-job` Workflow를 호출하여 GKE Autopilot Job을 실행하는 단계입니다.

> 이 단계에서는 Docker Image를 다시 Build하지 않습니다. 30 단계에서 생성된 Cloud Build Trigger는 Git 소스 변경 시에만 Image를 Build하며, Scheduler 실행 시에는 Artifact Registry의 기존 Image를 재사용합니다.

## 실행 흐름

```text
Cloud Scheduler
   -> Workflows Executions API
   -> wf-l2comm-gke-job
   -> GKE Kubernetes Job
   -> Artifact Registry Image Pull
   -> GKE Autopilot Pod
   -> Python Batch
   -> BigQuery
   -> Job Complete / Pod 종료
```

## 1. Scheduler Job 생성

매일 오전 09:00(KST) 예시입니다.

```bash
gcloud scheduler jobs create http sch-l2comm-gke-job \
  --project=gcp-prod-edp-edge-509423 \
  --location=asia-northeast3 \
  --schedule="0 9 * * *" \
  --time-zone="Asia/Seoul" \
  --uri="https://workflowexecutions.googleapis.com/v1/projects/gcp-prod-edp-edge-509423/locations/asia-northeast3/workflows/wf-l2comm-gke-job/executions" \
  --http-method=POST \
  --oauth-service-account-email="sa-l2comm-workflow@gcp-prod-edp-edge-509423.iam.gserviceaccount.com" \
  --oauth-token-scope="https://www.googleapis.com/auth/cloud-platform" \
  --headers="Content-Type=application/json" \
  --message-body='{"argument":"{}"}'
```

## 2. 즉시 테스트

```bash
gcloud scheduler jobs run sch-l2comm-gke-job \
  --project=gcp-prod-edp-edge-509423 \
  --location=asia-northeast3
```

## 3. Workflow 확인

```bash
gcloud workflows executions list wf-l2comm-gke-job \
  --project=gcp-prod-edp-edge-509423 \
  --location=asia-northeast3 \
  --limit=10
```

## 4. GKE Job 확인

```bash
kubectl get jobs -n l2comm-batch
```

Job 로그:

```bash
JOB_NAME=$(kubectl get jobs -n l2comm-batch \
  --sort-by=.metadata.creationTimestamp \
  -o jsonpath='{.items[-1:].metadata.name}')

kubectl logs -n l2comm-batch \
  $(kubectl get pod -n l2comm-batch \
    -l job-name=${JOB_NAME} \
    -o jsonpath='{.items[0].metadata.name}')
```

정상 예시:

```text
Loading 43 GCP regions into pjt-c-admin.dlk_sample.gcp_region_inventory
Completed: pjt-c-admin.dlk_sample.gcp_region_inventory, rows=43
```

## 5. BigQuery 결과 확인

```bash
bq query \
  --project_id=pjt-c-admin \
  --use_legacy_sql=false \
  'SELECT COUNT(*) AS row_count
   FROM `pjt-c-admin.dlk_sample.gcp_region_inventory`'
```

PoC 검증 기준은 `row_count = 43`입니다.
