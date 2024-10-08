// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

## VPC related outputs

output "resource_names" {
  description = "A map of resource_name_types to generated resource names used in this module"
  value       = { for k, v in var.resource_names_map : k => module.resource_names[k].standard }
}

output "app_sg_id" {
  description = "The ID of the VPC Endpoint Security Group"
  value       = module.ecs_app_heart_beat.ecs_sg_id
}
## ALB related outputs

output "alb_dns" {
  description = "AWS provided DNS record of the ALB"
  value       = module.alb.lb_dns_name
}

output "alb_arn" {
  description = "The ID and ARN of the application load balancer created by the module"
  value       = try(module.alb.lb_arn, module.alb.lb_id)
}

output "alb_id" {
  description = "The ID and ARN of the application load balancer created by the module"
  value       = try(module.alb.lb_id, module.alb.lb_arn)
}

output "alb_sg_id" {
  description = "ID of the ALB Security Group"
  value       = module.alb.security_group_id
}

output "alb_https_listener_arns" {
  description = "ARNs of the HTTPS Listeners attached to the ALB"
  value       = try(module.alb.https_listener_arns, "")
}

output "alb_http_listener_arns" {
  description = "ARNs of the HTTP Listeners attached to the ALB"
  value       = try(module.alb.http_tcp_listener_arns, "")
}

## DNS and Certs

output "dns_zone_id" {
  description = "Zone ID of the hosted zone for ALB records provided as input."
  value       = try(data.aws_route53_zone.dns_zone[0].zone_id, "")
}
output "dns_zone_name" {
  description = "Name of the Route53 DNS Zone where custom DNS records will be created. Required if use_https_listeners=true"
  value       = try(var.dns_zone_name, "")
}
output "alb_dns_records" {
  description = "Custom DNS record for the ALB"
  value       = try([for key, value in module.alb_dns_records[0].record_fqdns : value], [])
}

output "alb_additional_dns_names" {
  description = "Additional DNS records for the ALB"
  value       = flatten([for dns_record in module.additional_cnames : [for key, value in dns_record.record_fqdns : key]])
}

output "private_ca_arn" {
  description = "ARN of the Private CA. This is used to sign private certificates used in App Mesh. Required when TLS is enabled in App Mesh"
  value       = var.private_ca_arn
}

output "alb_cert_arn" {
  description = "ARN of the certificate provisioned for ALB by ACM"
  value       = try(module.acm[0].acm_certificate_arn, "")
}

output "virtual_gateway_cert_arn" {
  description = "ARN of the certificate provisioned for the virtual gateway when var.tls_enforce is true"
  value       = try(module.private_certs[0].certificate_arn, "")
}

output "virtual_gateway_arn" {
  description = "ARN of the Virtual Gateway"
  value       = module.virtual_gateway.arn
}

output "virtual_gateway_task_definition_name" {
  description = "Revision of the Virtual Gateway ECS app task definition."
  value       = module.virtual_gateway_ecs_service.task_definition_family
}

output "virtual_gateway_task_definition_version" {
  description = "Revision of the Virtual Gateway ECS app task definition."
  value       = module.virtual_gateway_ecs_service.task_definition_revision
}

output "virtual_gateway_name" {
  description = "Name of the Virtual Gateway"
  value       = module.resource_names["virtual_gateway"].standard
}

output "tls_enforce" {
  description = "Whether TLS is enforced on the Virtual Gateway. If true, all the Virtual Nodes should also enable TLS"
  value       = var.tls_enforce
}

output "namespace_id" {
  description = "ID of the Cloud Map namespace to be used for Service Discovery"
  value       = module.sds.id
}

output "namespace_name" {
  description = "Name of the Cloud Map namespace to be used for Service Discovery"
  value       = var.namespace_name
}

output "heartbeat_app_task_definition_name" {
  description = "Task Definition Version of the HeartBeat application"
  value       = try(module.ecs_app_heart_beat.task_definition_name, "")
}

output "heartbeat_app_task_definition_version" {
  description = "Task Definition Version of the HeartBeat application"
  value       = module.ecs_app_heart_beat.task_definition_version
}
