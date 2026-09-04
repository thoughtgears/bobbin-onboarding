output "notification_channel_ids" {
  description = <<-EOT
    The created notification channel's resource name per project, e.g.
    projects/<id>/notificationChannels/<n>. Attach this channel to the
    alert policies you want investigated.
  EOT
  value = {
    for project_id, channel in google_monitoring_notification_channel.bobbin :
    project_id => channel.name
  }
}

output "granted_roles" {
  description = <<-EOT
    The exact roles this module grants to tenant_service_account. This
    is the complete access list — nothing else is ever requested.
  EOT
  value       = local.roles
}

output "project_numbers" {
  description = <<-EOT
    Project number per project id. Send these to Bobbin — alerts cannot
    reach the tenant topic until we grant your projects' Cloud Monitoring
    service agent publish rights on it, which is the one step this
    module cannot do on your behalf (see main.tf).
  EOT
  value = {
    for project_id, project in data.google_project.target :
    project_id => project.number
  }
}
