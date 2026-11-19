# Troubleshooting

## Candidate issues to expect on first run
| Symptom | Root cause | Fix |
|---|---|---|
| `sqlserver` exits immediately, log: *password does not meet complexity* | SA password lacks upper/lower/digit/symbol or is < 8 chars | regenerate with `scripts/generate-env.sh` (adds a complexity suffix); `docker compose down -v` first if the volume was initialised with another password |
| `sqlserver` exits / hangs on Apple Silicon | amd64-only image | enable Rosetta emulation in Docker Desktop, or choose a different DB |
| `elasticsearch` restarts, log: *max virtual memory areas vm.max_map_count too low* | host kernel setting | `sudo sysctl -w vm.max_map_count=262144` (persist in `/etc/sysctl.d/`) |
| `platform` unhealthy for minutes on first run | initial DB migration and module load | wait; `docker compose logs -f platform`; healthcheck allows 90 s start + retries |
| Platform logs *Login failed for user 'sa'* | DB volume created with an old password | `down -v` then `up`, or reset password inside SQL Server |
| Storefront returns 5xx / logs 401 | frontend user missing/wrong password, or modules the storefront needs not installed on Platform | create the user, fix `.env`, `docker compose --profile storefront up -d --force-recreate storefront`; install required modules |
| Storefront cannot parse Platform responses | legacy image vs new Platform API mismatch | pin an older Platform tag or use vc-frontend (see ARCHITECTURE §6) |
| Floci `tofu apply` fails on one resource | emulator does not implement that operation | note the resource in `docs/STATUS.md`, remove it from the emulated env, keep it in `envs/aws` |

## Worked example (fill in with YOUR real incident before the interview)
> The interviewer asked for **one issue actually encountered, with root cause and resolution**. I did not run the stack when preparing this repo, so I cannot supply a real incident honestly. After your run, replace this block.

Template:
1. **Symptom** (exact log line / HTTP code):
2. **Investigation** (commands: `docker compose ps`, `logs`, `inspect`, `exec`):
3. **Root cause**:
4. **Resolution** (command/config change, commit):
5. **Prevention** (healthcheck/doc/test added):
