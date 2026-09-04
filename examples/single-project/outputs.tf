output "notification_channel_ids" {
  value = module.bobbin.notification_channel_ids
}

output "granted_roles" {
  value = module.bobbin.granted_roles
}

output "project_numbers" {
  description = "Send these to Bobbin — see terraform/README.md."
  value       = module.bobbin.project_numbers
}
