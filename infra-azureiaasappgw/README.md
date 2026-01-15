
# AppGW Lab (no module) — mirrors UEFA prod workflow (single backend + workspaces)

This repository builds a **minimal Azure Application Gateway** lab using **HTTP only** and **Standard\_v2**, with **no Terraform modules**. It mirrors your **prod workflow**:

*   A **single** `backend "azurerm"` with a **single** `key` in `main.tf`.
*   **Workspaces** separate environments (`lab-nonprod-we`, `lab-prod-we`).
*   Per-environment `*.tfvars` provide the nested structure.

> **Note on state files**: With the azurerm backend, the *default* workspace uses the `key` as-is. Any **non-default** workspace writes to a different blob by suffixing the key with `env:<workspace>` (e.g., `infra-azureiaasappgw.tfstateenv:lab-nonprod-we`). No extra code is required—this is built into Terraform.

***

## ✅ Prerequisites (one-time)

```bash
az login
# az account set --subscription "<your LAB subscription id>"

    $rg = "A838492_adamczyz"
    $sa = "terraformbackendadam"
    $container  = "tfstate"
    $key    = "infra-azureiaasappgw.tfstate"

az group create --name  $rg--location "West Europe"
az storage account create --name  $sa --resource-group  $rg--sku Standard_LRS
az storage container create --name  $container --account-name  $sa
```

***

## ✅ Initialize (once)

```bash
terraform init
```

***

## ✅ Deploy NonProd (PowerShell-safe)

```powershell
$workspace = "lab-nonprod-we"
terraform workspace new $workspace
terraform workspace select $workspace
terraform plan -out "$workspace.plan" -var-file lab-nonprod-we.tfvars
terraform apply "$workspace.plan"
```

***

## ✅ Deploy Prod (PowerShell-safe)

```powershell
$workspace = "lab-prod-we"
terraform workspace new $workspace
terraform workspace select $workspace
terraform plan -out "$workspace.plan" -var-file lab-prod-we.tfvars
terraform apply "$workspace.plan"
```

***

## ✅ What gets created

*   Resource Group: `${var.env}-appgw-rg`
*   VNet: `${var.env}-vnet` (10.0.0.0/16)
*   Subnet: `${var.env}-appgw-subnet` (10.0.1.0/24)
*   Public IP: `${var.env}-appgw-pip` (Static, Standard)
*   Application Gateway: `${var.env}-appgw` with:
    *   Frontend IP (public)
    *   Frontend ports: from `application_gateway_details.frontend_ports` (HTTP 80)
    *   Backend pools from `application_gateway_details.backends`
    *   HTTP settings per backend
    *   HTTP listeners from `application_gateway_details.listeners`
    *   Basic routing rules and optional path-based rules

***

## ✅ Notes & Gotchas

*   **No modules** are used; everything is inline using `azurerm_*` resources.
*   **No SSL/WAF** is configured for the lab.
*   The lab ignores `firewall_policy_id`, redirects, and imported certs; those maps can remain empty.
*   The `subnet` string inside `application_gateway_details` is **not consumed** because this lab creates its own VNet/Subnet. It is kept only to mirror prod’s shape.
*   If you provide multiple top-level entries under `application_gateway_details`, the lab uses the **first** entry.
*   **Dynamic blocks** iterate over maps in tfvars:
    *   `frontend_ports`
    *   `backends`
    *   `listeners`
    *   `basic_routing_rules`
    *   `path_based_routing_rules`
*   **Important fix applied**:
    *   `backend_address_pool` uses `ip_addresses` and `fqdns` attributes (not nested blocks).
    *   `locals` use `try(var.application_gateway_details.shared01, local.default_appgw_details)` to avoid type mismatch errors.
*   **PowerShell tip**: Use `$workspace` variable and quote `"$workspace.plan"` to avoid “Too many command line arguments” errors.

***

# Pushing to GitHub

## Prerequisites
Ensure Git is installed on your system and you have a GitHub account. Open a terminal in your Terraform project directory containing the working `.tf` files. Run `terraform init` if not done to identify files to ignore, but avoid committing Terraform state or lock files.[1][2][3]

## Create .gitignore
Create a `.gitignore` file in your project root to exclude Terraform artifacts like `.terraform/`, `*.tfstate`, `*.tfplan`, `override.tf`, and `.terraform.lock.hcl`. Use this standard template from GitHub:

```
# Local .terraform directories
.terraform/

# .terraform-version
.terraform-version

# Terraform Binary
terraform

# Terraform .terraform.lock.hcl
.terraform.lock.hcl

# Terraform Plan
*.tfplan
*.tfplan.json

# Terraform State
*.tfstate
*.tfstate.*

# Terraform Variables
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Terraform CLI configuration
.terraformrc
terraform.rc
```

## Initialize Git Repository
If your directory is not yet a Git repo, run `git init -b main` to create one with a `main` branch. Add your Terraform files with `git add .` (this stages everything except ignored items). Commit with `git commit -m "Initial Terraform configuration"`.

## Create GitHub Repository
Log in to GitHub.com, click "New" to create a repository. Name it (e.g., "my-terraform-project"), add a description, choose public/private, but **do not** initialize with README, .gitignore, or license to avoid push conflicts.

## Push to GitHub
Copy the new repo's HTTPS URL (e.g., `https://github.com/czyzadam/terraform.git`). Add the remote: `git remote add origin <URL>`. Verify with `git remote -v`. Push: `git push -u origin main`. Authenticate if prompted (use a PAT for HTTPS).

## Verify and Next Steps
Refresh GitHub to confirm files uploaded. Future changes: edit files, `git add .`, `git commit -m "Update"`, `git push`. Use branches for features and PRs for collaboration.[3][1]

