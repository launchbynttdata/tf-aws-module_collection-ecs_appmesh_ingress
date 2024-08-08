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

module "resource_names" {
  source  = "terraform.registry.launch.nttdata.com/module_library/resource_name/launch"
  version = "~> 1.0"

  for_each = var.resource_names_map

  logical_product_family  = var.logical_product_family
  logical_product_service = var.logical_product_service
  region                  = join("", split("-", var.region))
  class_env               = var.class_env
  cloud_resource_type     = each.value.name
  instance_env            = var.instance_env
  instance_resource       = var.instance_resource
  maximum_length          = each.value.max_length
}

# ALB Security Group
module "sg_alb" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.17.1"

  vpc_id                   = var.vpc_id
  name                     = module.resource_names["alb_sg"].recommended_per_length_restriction
  description              = lookup(var.alb_sg, "description", "Security Group for ALB")
  ingress_cidr_blocks      = coalesce(try(lookup(var.alb_sg, "ingress_cidr_blocks", []), []), [])
  ingress_rules            = coalesce(try(lookup(var.alb_sg, "ingress_rules", []), []), [])
  ingress_with_cidr_blocks = coalesce(try(lookup(var.alb_sg, "ingress_with_cidr_blocks", []), []), [])
  egress_cidr_blocks       = coalesce(try(lookup(var.alb_sg, "egress_cidr_blocks", []), []), [])
  egress_rules             = coalesce(try(lookup(var.alb_sg, "egress_rules", []), []), [])
  egress_with_cidr_blocks  = coalesce(try(lookup(var.alb_sg, "egress_with_cidr_blocks", []), []), [])

  tags = merge(local.tags, { resource_name = module.resource_names["alb_sg"].standard })
}

# A S3 bucket for ALB logging is only created when a pre-existing bucket is not specified as input
module "alb_logs_s3" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.8.2"

  count = length(var.alb_logs_bucket_id) > 0 ? 0 : 1

  bucket = module.resource_names["s3_logs"].recommended_per_length_restriction

  # Allow deletion of non-empty bucket
  force_destroy = true
  # Required for ALB logs
  attach_elb_log_delivery_policy = true

  # Restrict all public access by default
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  tags = merge(local.tags, { resource_name = module.resource_names["s3_logs"].standard })
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name               = module.resource_names["alb"].recommended_per_length_restriction
  internal           = var.is_internal
  load_balancer_type = var.load_balancer_type

  #SG is created by separate module
  create_security_group = false
  idle_timeout          = var.idle_timeout

  vpc_id          = var.vpc_id
  subnets         = var.private_subnets
  security_groups = [module.sg_alb.security_group_id]

  access_logs = {
    bucket = length(var.alb_logs_bucket_id) > 0 ? var.alb_logs_bucket_id : module.alb_logs_s3[0].s3_bucket_id
    # This is required for this issue https://github.com/hashicorp/terraform-provider-aws/issues/16674
    enabled = true
    prefix  = var.alb_logs_bucket_prefix
  }

  # Target Group is set with `name_prefix` as create_before_destroy is set in the parent module
  # health_check must be set for HTTPs target group
  target_groups = local.target_groups


  # These values will always be fixed, hence hard-coded
  #TODO: Unable to get the else condition working
  http_tcp_listeners = var.use_https_listeners ? [
    {
      port        = 80
      protocol    = "HTTP"
      action_type = "redirect"
      redirect = {
        port        = 443
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
    ] : [

  ]

  https_listeners = var.use_https_listeners ? [{
    port               = 443
    protocol           = "HTTPS"
    target_group_index = 0
    certificate_arn    = module.acm[0].acm_certificate_arn
    ssl_policy         = var.listener_ssl_policy_default
  }] : []

  http_tcp_listeners_tags = merge(local.tags, { resource_name = module.resource_names["alb"].standard })

  tags = merge(local.tags, { resource_name = module.resource_names["acm"].standard })

  depends_on = [module.alb_logs_s3]
}


module "alb_dns_records" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/dns_record/aws"
  version = "~> 1.0.0"

  #This zone cannot be associated with CloudMap
  zone_id = var.dns_zone_id
  records = local.alb_dns_records
}

# DNS Zone where the records for the ALB will be created, cannot be associated with CloudMap
data "aws_route53_zone" "dns_zone" {
  count = length(var.dns_zone_name) > 0 || var.use_https_listeners ? 1 : 0

  name         = var.dns_zone_name
  private_zone = var.private_zone
}

# Certificate Manager (not a private CA) where the certs for ALB will be provisioned
module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.3.2"

  count = var.use_https_listeners ? 1 : 0

  domain_name               = "${module.resource_names["alb"].recommended_per_length_restriction}.${var.dns_zone_name}"
  subject_alternative_names = local.alb_san
  zone_id                   = data.aws_route53_zone.dns_zone[count.index].zone_id

  tags = merge(local.tags, { resource_name = module.resource_names["acm"].standard })

  # Can't validate the SANs if they aren't in the dns_records
  depends_on = [module.alb_dns_records]
}

# Service Discovery services for Virtual Gateway
module "sds" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/service_discovery_service/aws"
  version = "~> 1.0.0"

  name         = module.resource_names["virtual_gateway"].standard
  namespace_id = var.namespace_id

  tags = merge(local.tags, { resource_name = module.resource_names["virtual_gateway"].standard })
}

# Create private certificate for virtual gateway
module "private_certs" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/acm_private_cert/aws"
  version = "~> 1.0.0"

  private_ca_arn = var.private_ca_arn

  domain_name               = local.updated_domain_name
  subject_alternative_names = local.private_cert_san

  tags = merge(local.tags, { resource_name = module.resource_names["virtual_gateway"].standard })

  depends_on = [module.acm]
}

module "virtual_gateway" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/virtual_gateway/aws"
  version = "~> 1.0.0"

  name      = module.resource_names["virtual_gateway"].standard
  mesh_name = var.app_mesh_id

  tls_enforce       = var.tls_enforce
  health_check_path = var.vgw_health_check_path
  # Always same as the listener port. Should be removed from the parent module
  health_check_port                    = var.vgw_listener_port
  health_check_protocol                = var.vgw_health_check_protocol
  listener_port                        = var.vgw_listener_port
  listener_protocol                    = var.vgw_listener_protocol
  tls_mode                             = var.vgw_tls_mode
  tls_ports                            = var.vgw_tls_ports
  text_format                          = var.vgw_logs_text_format
  acm_certificate_arn                  = module.private_certs.certificate_arn
  trust_acm_certificate_authority_arns = [var.private_ca_arn]

  tags = merge(local.tags, { resource_name = module.resource_names["virtual_gateway"].standard })

}

module "ecs_task_execution_policy" {
  count = length(var.ecs_exec_role_custom_policy_json) > 0 ? 1 : 0

  source  = "cloudposse/iam-policy/aws"
  version = "~> 2.0.1"

  enabled                       = true
  namespace                     = "${var.logical_product_family}-${join("", split("-", var.region))}"
  stage                         = var.instance_env
  environment                   = var.class_env
  name                          = "${var.resource_names_map["task_exec_policy"].name}-${var.instance_resource}"
  iam_policy_enabled            = true
  iam_override_policy_documents = [var.ecs_exec_role_custom_policy_json]

  tags = local.tags

  # Attempts to avoid 409 concurrency issue with IAM policies
  depends_on = [module.alb_logs_s3]
}

module "ecs_task_policy" {
  source  = "cloudposse/iam-policy/aws"
  version = "~> 2.0.1"

  enabled                     = true
  namespace                   = "${var.logical_product_family}-${join("", split("-", var.region))}"
  stage                       = var.instance_env
  environment                 = var.class_env
  name                        = "${var.resource_names_map["task_policy"].name}-${var.instance_resource}"
  iam_policy_enabled          = true
  iam_source_policy_documents = local.ecs_role_custom_policy_json

  tags = local.tags

  #Avoids 409 concurrency issue within this module source
  depends_on = [module.ecs_task_execution_policy]
}

module "virtual_gateway_container_definition" {
  source = "git::https://github.com/cloudposse/terraform-aws-ecs-container-definition.git?ref=tags/0.61.1"

  container_name               = local.vgw_container.name
  container_image              = local.vgw_container.image_tag
  container_memory             = local.vgw_container.memory
  container_memory_reservation = local.vgw_container.memory_reservation
  container_cpu                = local.vgw_container.cpu
  essential                    = local.vgw_container.essential
  readonly_root_filesystem     = local.vgw_container.readonly_root_filesystem
  map_environment              = local.vgw_container.environment
  port_mappings                = local.vgw_container.port_mappings
  log_configuration            = local.vgw_container.log_configuration
}

# Security Group for ECS task
module "sg_ecs_service_vgw" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.17.1"

  vpc_id      = var.vpc_id
  name        = module.resource_names["vgw_ecs_sg"].standard
  description = "Security Group for Virtual Gateway ECS Service"
  # Allows traffic only from the ALB
  computed_ingress_with_source_security_group_id = concat([
    {
      # Allow ingress from ALB on the health check port of target group (virtual gateway listener)
      from_port                = try(lookup(var.target_groups[0].health_check, "port"), 443)
      to_port                  = try(lookup(var.target_groups[0].health_check, "port"), 443)
      protocol                 = "tcp"
      source_security_group_id = module.sg_alb.security_group_id
    }
  ], local.ingress_with_sg)

  computed_egress_with_source_security_group_id = concat([
    {
      # Allow egress from ALB on the health check port of target group (virtual gateway listener)
      from_port                = try(lookup(var.target_groups[0].health_check, "port"), 443)
      to_port                  = try(lookup(var.target_groups[0].health_check, "port"), 443)
      protocol                 = "tcp"
      source_security_group_id = module.sg_alb.security_group_id
    }
  ], local.egress_with_sg)
  number_of_computed_ingress_with_source_security_group_id = 1 + length(local.ingress_with_sg)
  number_of_computed_egress_with_source_security_group_id  = 1 + length(local.egress_with_sg)

  # Other traffic rules
  ingress_cidr_blocks      = coalesce(try(lookup(var.vgw_security_group, "ingress_cidr_blocks", []), []), [])
  ingress_rules            = coalesce(try(lookup(var.vgw_security_group, "ingress_rules", []), []), [])
  ingress_with_cidr_blocks = coalesce(try(lookup(var.vgw_security_group, "ingress_with_cidr_blocks", []), []), [])
  egress_cidr_blocks       = coalesce(try(lookup(var.vgw_security_group, "egress_cidr_blocks", []), []), [])
  egress_rules             = coalesce(try(lookup(var.vgw_security_group, "egress_rules", []), []), [])
  egress_with_cidr_blocks  = coalesce(try(lookup(var.vgw_security_group, "egress_with_cidr_blocks", []), []), [])

  tags = merge(local.tags, { resource_name = module.resource_names["vgw_ecs_sg"].standard })

  #Attempts to avoid 409 concurrency issue within this module source
  depends_on = [module.sg_alb]
}

# ECS Service
module "virtual_gateway_ecs_service" {
  source  = "cloudposse/ecs-alb-service-task/aws"
  version = "~> 0.67.1"

  # This module generates its own name. Can't use the labels module
  namespace                          = "${var.instance_env}-${join("", split("-", var.region))}"
  stage                              = var.instance_env
  environment                        = var.class_env
  name                               = var.resource_names_map["vgw_ecs_app"].name
  attributes                         = [var.instance_resource]
  delimiter                          = "-"
  alb_security_group                 = module.sg_alb.security_group_id
  container_definition_json          = module.virtual_gateway_container_definition.json_map_encoded_list
  ecs_cluster_arn                    = var.ecs_cluster_arn
  launch_type                        = var.ecs_launch_type
  vpc_id                             = var.vpc_id
  security_group_ids                 = [module.sg_ecs_service_vgw.security_group_id]
  security_group_enabled             = false
  subnet_ids                         = var.private_subnets
  ignore_changes_task_definition     = var.ignore_changes_task_definition
  ignore_changes_desired_count       = var.ignore_changes_desired_count
  task_exec_policy_arns_map          = local.task_exec_policy_arns_map
  task_policy_arns_map               = local.task_policy_arns_map
  network_mode                       = var.network_mode
  assign_public_ip                   = var.assign_public_ip
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_controller_type         = var.deployment_controller_type
  desired_count                      = var.desired_count
  task_memory                        = var.task_memory
  task_cpu                           = var.task_cpu
  wait_for_steady_state              = var.wait_for_steady_state
  # This now works but the redeploy_on_apply needs to be set to false
  force_new_deployment = var.force_new_deployment
  # Issue: https://github.com/hashicorp/terraform-provider-aws/issues/16674
  redeploy_on_apply = var.redeploy_on_apply
  service_registries = [
    {
      registry_arn   = module.sds.arn
      container_name = local.vgw_container.name
    }
  ]

  ecs_load_balancers = [
    {
      container_name   = local.vgw_container.name
      container_port   = local.vgw_container.port_mappings[0].containerPort
      target_group_arn = module.alb.target_group_arns[0]
      # If target_group is specified, elb_name must be null
      elb_name = null
    }
  ]

  tags = merge(local.tags, { resource_name = module.resource_names["vgw_ecs_app"].standard })


  #Temporary attempt to work around the following:
  # Error: creating App Mesh Virtual Node (launch-hb-useast2-dev-000-vnode-000): BadRequestException: Service Discovery can't be set without a listener.
  depends_on = [module.sds, module.virtual_gateway_container_definition, module.sg_ecs_service_vgw, module.alb]
}

# This module will provision a simple HTTP server as an ECS app used for Health Check (`/health`) for the Ingress Virtual Gateway
module "ecs_app_heart_beat" {
  #TODO: Won't work until ecs_appmesh_app has a public repo in launchbynttdata org
  # source  = "terraform.registry.launch.nttdata.com/module_collection/ecs_appmesh_app/aws"
  # version = "~> 1.0.0"
  #TODO: Used for local testing against the main branch of the ecs_appmesh_app's repo
  source = "../hackhackhack/"

  logical_product_family  = var.logical_product_family
  logical_product_service = "hb"
  class_env               = var.class_env
  region                  = var.region
  instance_env            = var.instance_env
  instance_resource       = var.instance_resource

  vpc_id               = var.vpc_id
  private_subnets      = var.private_subnets
  namespace_name       = var.namespace_name
  namespace_id         = var.namespace_id
  app_mesh_id          = var.app_mesh_id
  virtual_gateway_name = module.resource_names["virtual_gateway"].standard

  private_ca_arn     = var.private_ca_arn
  ecs_cluster_arn    = var.ecs_cluster_arn
  app_image_tag      = var.app_image_tag
  app_ports          = [var.app_port]
  ecs_security_group = var.app_security_group

  # should be same has ALB TG health check path
  match_path_prefix = var.match_path_prefix

  task_cpu                       = var.app_task_cpu
  task_memory                    = var.app_task_memory
  desired_count                  = var.app_desired_count
  force_new_deployment           = var.force_new_deployment
  ignore_changes_desired_count   = var.ignore_changes_desired_count
  ignore_changes_task_definition = var.ignore_changes_task_definition
  wait_for_steady_state          = var.wait_for_steady_state

  # Attempts to avoid 409 concurrency issue with IAM policies
  depends_on = [module.alb_logs_s3, module.ecs_task_policy, module.ecs_task_execution_policy, module.virtual_gateway]
}
