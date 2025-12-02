output "pages_url" {
  description = "Cloudflare Pages URL"
  value       = "https://${cloudflare_pages_project.frontend.subdomain}.pages.dev"
}

output "project_name" {
  description = "Project name"
  value       = cloudflare_pages_project.frontend.name
}

output "subdomain" {
  description = "Pages subdomain"
  value       = cloudflare_pages_project.frontend.subdomain
}

