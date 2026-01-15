

# Prequsities

## Terraform Azure Lab (simple RG + Storage Account)

This repo is a minimal, workspace-based Terraform project that creates:

- An **Azure Resource Group**
- A **Storage Account** (demo workload, not the backend)

It uses remote state in **Azure Storage** (`backend azurerm`) and separate `.tfvars` files for `dev`, `pre`, and `prd`.

## 0) Prerequisites
- Azure subscription and permissions
- Azure CLI (`az`) logged in: `az login`
- Terraform (or your alias `terraform119`)
- Git + GitHub Desktop (optional) + VS Code


## 1) Create backend storage (one-time)

```bash

$RG = "A838492_adamczyz"
$SA = "terraformbackendadam"
$CON = "tfstate"
$KEY = "infra-azureiaasappgw.tfstate"

# Resource group for state
az group create -n $RG -l polandcentral

# Storage account for state (name must be globally unique; adjust)
az storage account create -n $SA -g $RG -l polandcentral --sku Standard_LRS --kind StorageV2

# Container to hold tfstate files
az storage container create --name $CON   --account-name $SA

# (Optional) Get an access key if you use key-based auth for backend
az storage account keys list -g rg-tfstate -n sttfstate00011 --query "[0].value" -o tsv
```

Update the `backend-*.hcl` files with your actual `storage_account_name`.

## 2) Create a Service Principal for Terraform (one-time)
```bash
az ad sp create-for-rbac --name sp-terraform-a838492 --role Contributor --scopes /subscriptions/<your-subscription-id>
```
Note the `appId`, `tenant`, and `password` from the output.

## 3) Export environment variables (Git Bash) 
```bash
export ARM_CLIENT_ID="<appId>" 
export ARM_CLIENT_SECRET="<password>"
export ARM_TENANT_ID="<tenant>" 
export ARM_SUBSCRIPTION_ID="<subscription-id>"

# If using access-key backend auth
export ARM_ACCESS_KEY="<storage-access-key>"
```

```powershell
$env:ARM_CLIENT_ID        = "<appId>"
$env:ARM_CLIENT_SECRET    = "<password>"
$env:ARM_TENANT_ID        = "<tenant>"
$env:ARM_SUBSCRIPTION_ID  = "<subscription-id>"
```
(From your longer list, only the `ARM_*` variables are needed for this Azure demo.)

## 4) Initialize per environment
Use your alias `terraform119` if present, otherwise `terraform`.

```bash

# Initialize once with single backend
terraform init -backend-config="backend.hcl"

# DEV
terraform workspace new dev || true
terraform workspace select dev
terraform plan -out dev.plan -var-file dev.tfvars

# PRE
terraform workspace new pre || true
terraform workspace select pre
terraform plan -out pre.plan -var-file pre.tfvars

# PRD
terraform workspace new prd || true
terraform workspace select prd
terraform plan -out prd.plan -var-file prd.tfvars
```

## 5) Apply after PR approval
```bash
terraform workspace select dev  # or pre/prd
terraform apply "dev.plan"
```

## 6) Git & Pull Request flow
```bash
# Create a feature branch
git checkout -b feat/simple-azure-rg

# Stage & commit
git add --all
git commit -m "Add minimal Azure RG + Storage Account with remote state"

# Push and set upstream
git push --set-upstream origin feat/simple-azure-rg
```
Then in GitHub: **Compare & pull request** ➜ assign reviewers ➜ **Create pull request** ➜ after approval: **Merge pull request** ➜ **Confirm merge** ➜ **Delete branch**.

## Notes
- `required_version` in `main.tf` is `>= 1.6.0`. If your environment uses an alias like `terraform119`, ensure it points to a compatible Terraform version.
- The backend `key` differs per environment (`dev.tfstate`, `pre.tfstate`, `prd.tfstate`) via separate `backend-*.hcl` files.
- Storage account names must be lowercase, unique, and ≤ 24 chars.
- If you prefer Azure AD auth for backend, omit `ARM_ACCESS_KEY` and login with `az login`.
