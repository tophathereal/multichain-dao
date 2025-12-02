terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  # Local state file
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Simple Cloudflare Pages Project (Direct Upload mode)
resource "cloudflare_pages_project" "frontend" {
  account_id        = var.cloudflare_account_id
  name              = var.project_name
  production_branch = "main"

  # No build - we upload static files directly
  build_config {
    build_command   = ""
    destination_dir = ""
    root_dir        = ""
  }

  deployment_configs {
    production {
      compatibility_date  = "2024-01-01"
      compatibility_flags = []
    }
  }
}
