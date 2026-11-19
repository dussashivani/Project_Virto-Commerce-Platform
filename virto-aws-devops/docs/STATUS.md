# Honest status and deviations

Last updated by the authoring session; update after you run things.

| Area | State |
|---|---|
| Compose files | Written; `docker compose config` passes (Compose v5.7.1). **Not started**: authoring sandbox had no Docker daemon. |
| Platform env var names (`ConnectionStrings__*`, `Search__*`) | From Virto docs/appsettings reference. Verify on first boot (`docker compose logs platform`). |
| Platform listening port 80 / data paths `/opt/virtocommerce/platform/...` | From Virto docs (`App_Data/Modules` path) and image convention; verify with `docker compose exec platform ls /opt/virtocommerce/platform`. |
| Storefront env var names (`VirtoCommerce__Endpoint__*`) and `/app/wwwroot/cms-content` path | Derived from storefront appsettings docs; **unverified in the image**. Check `docker run --rm --entrypoint ls virtocommerce/storefront /app`. |
| Image tags | `latest` placeholders. Must pin; record in `evidence/image-versions.txt`. |
| OpenTofu | Installed 1.9.0 in sandbox; `fmt -check` passes on all `.tf`. `validate` **not run** (provider registry blocked). CI runs it. |
| Floci | Not started locally. Service list from floci.io; Terraform endpoints block follows the documented `localhost:4566` pattern. Individual resource support must be confirmed by `floci-apply.sh`. |
| Real AWS | Reference IaC only. **Nothing deployed.** |
| vc-frontend alternative | Not implemented. |
| Deviation | Storefront is a compose *profile* started after Platform initialisation, because it needs a Platform user. |
