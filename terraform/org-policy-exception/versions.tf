# Newer than the sibling module's >= 1.5: this module's variables.tf
# validates var.organization_id and var.existing_allowed_values against
# var.parent, which needs a variable's own `validation` block to
# reference ANOTHER variable — supported from Terraform 1.9. Terraform
# 1.9 shipped mid-2024; this is not a meaningful adoption barrier.
terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0, < 8.0"
    }
  }
}
