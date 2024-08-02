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

resource "random_integer" "priority" {
  min = 10000
  max = 50000
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name                 = local.vpc_name
  cidr                 = var.vpc_cidr
  private_subnets      = var.private_subnets
  azs                  = var.availability_zones
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = var.tags
}

module "ecs_platform" {
  source  = "terraform.registry.launch.nttdata.com/module_collection/ecs_appmesh_platform/aws"
  version = "~> 1.0"

  vpc_id                  = module.vpc.vpc_id
  private_subnets         = module.vpc.private_subnets
  gateway_vpc_endpoints   = var.gateway_vpc_endpoints
  interface_vpc_endpoints = var.interface_vpc_endpoints
  route_table_ids         = concat([module.vpc.default_route_table_id], module.vpc.private_route_table_ids)

  logical_product_family     = var.logical_product_family
  logical_product_service    = var.logical_product_service
  vpce_security_group        = var.vpce_security_group
  region                     = var.region
  environment                = var.class_env
  environment_number         = var.instance_env
  resource_number            = var.instance_resource
  container_insights_enabled = true

  namespace_name        = local.namespace_name
  namespace_description = "Namespace for testing appmesh ingress"

  tags = var.tags

  depends_on = [module.vpc]
}

module "ecs_ingress" {
  source = "../.."

  region            = var.region
  class_env         = var.class_env
  instance_env      = var.instance_env
  instance_resource = var.instance_resource

  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets

  namespace_name  = module.ecs_platform.namespace_name
  namespace_id    = module.ecs_platform.namespace_id
  ecs_cluster_arn = module.ecs_platform.fargate_arn
  app_mesh_id     = module.ecs_platform.app_mesh_id

  alb_sg              = var.alb_sg
  use_https_listeners = true
  dns_zone_name       = var.dns_zone_name
  private_zone        = var.private_zone
  zone_id             = var.zone_id
  target_groups = [
    {
      backend_protocol = "https"
      backend_port     = 443
      target_type      = "ip"
      health_check = {
        port                = 443
        path                = "/health"
        healthy_threshold   = 5
        unhealthy_threshold = 2
        protocol            = "HTTPS"
      }
    }
  ]

  force_new_deployment              = var.force_new_deployment
  ignore_changes_desired_count      = false
  ignore_changes_task_definition    = false
  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  private_ca_arn            = var.private_ca_arn
  tls_enforce               = true
  vgw_health_check_path     = "/"
  vgw_health_check_protocol = "http"
  vgw_listener_port         = 443
  vgw_listener_protocol     = "http"
  vgw_tls_mode              = "STRICT"
  vgw_security_group        = var.vgw_security_group

  app_port           = var.app_port
  app_image_tag      = var.app_image_tag
  match_path_prefix  = "/health"
  app_security_group = var.app_security_group

  tags = var.tags

  depends_on = [module.ecs_platform, module.vpc]
}
