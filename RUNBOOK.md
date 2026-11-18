# Deployment runbook (Task 7)

Sections 1–16 follow the assignment's required list. Read `docs/ARCHITECTURE.md` first for the local / Floci / real-AWS distinction.

## 1. Architecture diagram
See `docs/ARCHITECTURE.md` §4 (local containers) and §7 (proposed AWS). Mermaid renders on GitHub/GitLab; to export an image: `npx -p @mermaid-js/mermaid-cli mmdc -i docs/ARCHITECTURE.md -o docs/diagram.png`.

## 2. Prerequisites and tool versions
| Tool | Tested/target version | Check |
|---|---|---|
| Docker Engine + Compose v2 | Engine ≥ 24, Compose ≥ 2.20 (authoring checked config with Compose v5.7.1 only) | `docker compose version` |
| RAM / disk | ≥ 8 GB free RAM (SQL Server ≥ 2 GB, ES 1 GB), ≥ 15 GB disk | |
| CPU arch | **linux/amd64.** SQL Server image has no native arm64 build; on Apple Silicon enable Rosetta emulation or use a PostgreSQL variant | |
| OpenTofu ≥ 1.6 (1.9.0 used for fmt check) or Terraform ≥ 1.6 | | `tofu version` |
| AWS CLI v2 | | `aws --version` |
| `curl`, `openssl`, `bash` | | |
| Linux only | `sudo sysctl -w vm.max_map_count=262144` (Elasticsearch) | |

## 3. Repository structure
```
docker-compose.yml          app stack (platform, storefront[profile], sqlserver, elasticsearch, redis)
docker-compose.floci.yml    Floci AWS emulator (separate project)
.env.example                configuration template (no secrets)
scripts/                    up, validate, persistence-test, failure-drill, backup, restore, rollback,
                            pin-images, generate-env, floci-up, floci-apply, cleanup, test-all
terraform/modules/network   VPC, 3 subnet tiers, SG chain
terraform/envs/floci        EMULATOR-ONLY (own provider config)
terraform/envs/aws          REAL AWS reference design (never applied)
.github/workflows/ci.yml    CI/CD
docs/                       ARCHITECTURE, RUNBOOK, SECURITY, COST, TROUBLESHOOTING, STATUS, PRESENTATION
evidence/                   test output and screenshots (no secrets)
```

## 4. Environment variables
Defined in `.env.example`. Key ones: image refs (`*_IMAGE`), `MSSQL_SA_PASSWORD`, `REDIS_PASSWORD`, `VC_DB_NAME`, `SEARCH_PROVIDER`, `PLATFORM_INTERNAL_URL`, `STOREFRONT_API_USER/PASSWORD`, host ports. Create `.env`: `./scripts/generate-env.sh` (random secrets, mode 600). Never commit `.env`.

## 5. Local setup and deployment
```bash
./scripts/generate-env.sh
./scripts/pin-images.sh              # optional but recommended: records digests in .env.lock
./scripts/up.sh                      # phase 1: sqlserver, elasticsearch, redis, platform (first start: minutes)
# Open http://localhost:8090 and complete the Platform setup wizard:
#   - set the admin password (do NOT keep defaults)
#   - install the modules/sample data you need, restart when asked
#   - create a user for the storefront (Security -> Users), e.g. "frontend", and note its password
# Put that password in .env as STOREFRONT_API_PASSWORD, then:
./scripts/up.sh --with-storefront    # phase 2
./scripts/validate.sh
```
Stop: `docker compose --profile storefront down` (data kept). Start again: `./scripts/up.sh --with-storefront`.

## 6. Floci setup and resource provisioning (EMULATED AWS)
```bash
./scripts/floci-up.sh       # starts Floci, runs `aws sts get-caller-identity` / `aws s3 ls` against :4566
./scripts/floci-apply.sh    # tofu init/apply in terraform/envs/floci, then verifies via AWS CLI
```
Emulator config is isolated in `terraform/envs/floci/provider.tf` (endpoint overrides, dummy keys, skip_* flags). The real env uses a different directory, backend and provider block. Emulated services used: S3, EC2 (VPC/subnets/SG), IAM, Secrets Manager, CloudWatch Logs, ECS. Limitations: see ARCHITECTURE §9. If a resource type is unsupported by the emulator, comment it out and record it in `docs/STATUS.md` rather than claiming it works.

## 7. Real AWS deployment design and steps (PROPOSED, not performed)
Prerequisite: written authorization for paid resources, AWS account, a domain + ACM certificate, ECR repos, remote state bucket.
1. `aws ecr create-repository` for platform/storefront; mirror pinned upstream images (`docker pull` → `docker tag` → `docker push`) and scan (ECR scan-on-push).
2. `cd terraform/envs/aws && cp terraform.tfvars.example terraform.tfvars` (fill; file is git-ignored) then `tofu init -backend-config=...`.
3. `tofu plan -out plan.bin`, review, then `tofu apply plan.bin` (only with approval).
4. Complete gaps the reference does not yet cover: search tier, storefront ECS service/task definition (mirror the platform ones), DB connection-string assembly from the Secrets Manager JSON (small entrypoint script or SSM-to-env pattern), S3 asset provider configuration, `cms-content` delivery (bake into image or EFS), HTTP→HTTPS redirect, WAF, autoscaling.
5. Run the Platform setup wizard once through the ALB, restrict `/admin` by IP/WAF.
6. Validate: ALB target health, `curl -I https://<host>/`, CloudWatch logs, alarm test.

## 8. Ports and endpoints
| Endpoint | Where | Notes |
|---|---|---|
| `http://localhost:8090` | Platform admin/API | published on 127.0.0.1 |
| `http://localhost:8080` | Storefront | profile `storefront` |
| `sqlserver:1433`, `elasticsearch:9200`, `redis:6379` | internal network only | not published |
| `http://localhost:4566` | Floci | emulator |
| AWS: `:443` ALB → `:80` tasks | | TLS terminates at ALB |

## 9. Database initialization and persistence
The Platform creates and migrates the `VC_DB_NAME` database on first start (connection string from env). Data lives in volume `mssql_data`; `platform_appdata` holds modules/uploads; `cms_content` holds themes. Prove persistence: `./scripts/persistence-test.sh` (writes DB row + file, restarts, reads back). `docker compose down` keeps volumes; `-v`/`cleanup.sh --volumes` deletes them.

## 10. Health checks and testing
`docker compose ps` (health column) · `./scripts/validate.sh` · `./scripts/persistence-test.sh` · `./scripts/failure-drill.sh` · `./scripts/test-all.sh` (offline static checks, also in CI). Manual: open both URLs and log in to the admin; browse the storefront; `docker compose exec storefront bash -c 'exec 3<>/dev/tcp/platform/80 && echo ok'`.

## 11. Logs and troubleshooting
`docker compose logs -f platform` (or any service), `docker compose ps -a`, `docker inspect --format '{{json .State.Health}}' <container>`. Common errors: `docs/TROUBLESHOOTING.md`.

## 12. Security considerations
`docs/SECURITY.md` (what is implemented locally vs proposed).

## 13. Backup, restore, rollback
- Backup: `./scripts/backup.sh` → `backups/<ts>/{db.bak,platform_appdata.tgz,cms_content.tgz,SHA256SUMS}`.
- Restore: `./scripts/restore.sh backups/<ts>` (verifies checksums, asks to confirm, stops platform, restores, restarts). Then `validate.sh`.
- Rollback of a bad upgrade: (1) `backup.sh` before upgrading; (2) keep the previous `.env.lock`; (3) `./scripts/rollback.sh <old .env.lock>`; if the new version already migrated the DB schema, also restore the backup (migrations are not reversible).
- AWS: ECS circuit-breaker auto-rolls back failed deployments; redeploy previous task-definition revision; RDS point-in-time restore to a new instance.

## 14. Cleanup
`./scripts/cleanup.sh` (stops, keeps data) · `./scripts/cleanup.sh --volumes` (deletes all data + Floci state). Emulated infra: `cd terraform/envs/floci && tofu destroy`. Real AWS: `tofu destroy` (RDS has deletion protection and a final snapshot; disable deliberately).

## 15. Cost
`docs/COST.md` (estimates, assumptions). Local and Floci cost nothing; no AWS spend occurred.

## 16. Known limitations and improvements
- Storefront image is legacy; pairing with the Platform is unverified until run (see STATUS).
- Not run in the authoring sandbox (no Docker daemon): runtime evidence must be captured by the operator.
- `tofu validate`/provider schema checks could not be run offline (registry blocked); only `fmt` was verified locally; CI runs `validate`.
- AWS IaC lacks the search tier, storefront service, redirect/WAF and autoscaling.
- Local `sa` DB login and disabled ES security. Improve: dedicated DB user, ES TLS/auth.
- Pin all images by digest; add SBOM + Cosign signing; add Renovate/Dependabot.
