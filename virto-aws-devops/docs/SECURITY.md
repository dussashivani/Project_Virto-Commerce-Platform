# Security and operations (Task 5)

Legend: **LOCAL** = implemented and checkable in this repo. **PROPOSED** = designed/IaC-referenced for real AWS, not deployed.

| Control | Status | Detail |
|---|---|---|
| No hard-coded secrets | LOCAL | `.env` generated with random secrets, git-ignored; `.env.example` has placeholders; `test-all.sh` scans for AWS keys/private keys. Emulator creds `test/test` are dummies by design. |
| Secrets in AWS | PROPOSED | Secrets Manager, injected by ECS `secrets`; random password in IaC (note: it lands in Terraform state, so use encrypted remote state). |
| Least-privilege IAM | LOCAL (emulator) + PROPOSED | Task role: GetSecretValue on one secret, S3 object RW on one bucket, logs write on two groups. Separate execution role for image pull/secret fetch. CI role (OIDC, no static keys) is proposed. |
| Network boundaries | LOCAL + PROPOSED | Compose: DB/ES/Redis unpublished, storefront cannot reach them, ports bound to 127.0.0.1. AWS: 3 subnet tiers, SG chain ALB→app→data. |
| TLS | PROPOSED | ALB HTTPS listener with ACM cert, TLS 1.3/1.2 policy; HTTP→HTTPS redirect to add; local runs plain HTTP on localhost. |
| DB access | LOCAL + PROPOSED | No host port; app uses `sa` locally (**weakness**). Production: dedicated least-privilege DB login, private RDS, SG from app tier only, encryption at rest. |
| Image pinning and scanning | PARTIAL | `pin-images.sh` writes digests; Trivy in CI (non-blocking for third-party images). Default tags in `.env.example` are `latest` placeholders until pinned. |
| Logs | LOCAL + PROPOSED | json-file with rotation; `docker compose logs`. AWS: awslogs to CloudWatch, 30-day retention. |
| Health checks | LOCAL | container healthchecks and `validate.sh`. |
| Monitoring/alerting | PROPOSED | CloudWatch alarms (ALB 5xx, RDS CPU) → SNS; add ECS CPU/mem, RDS storage, Redis evictions. |
| Backup/restore | LOCAL + PROPOSED | `backup.sh`/`restore.sh` (native .bak + volume tarballs + checksums). AWS: RDS 14-day PITR and final snapshot, S3 versioning, AWS Backup for EFS. Restore drills still needed. |
| Availability/scaling | PROPOSED | 2 AZs, Multi-AZ RDS, ≥2 tasks, service autoscaling on CPU/ALB requests; single-writer concerns: see ARCHITECTURE §7. |
| Known local weaknesses | | ES security disabled; `sa` login; storefront legacy image; admin default credentials must be changed at first login; no TLS locally. |
