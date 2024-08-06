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

locals {

  default_tags = {
    provisioner = "Terraform"
  }

  ingress_with_sg_block = coalesce(try(lookup(var.vgw_security_group, "ingress_with_sg", []), []), [])
  ingress_with_sg = length(local.ingress_with_sg_block) > 0 ? [
    for sg in local.ingress_with_sg_block : {
      from_port                = try(lookup(sg, "port"), 443)
      to_port                  = try(lookup(sg, "port"), 443)
      protocol                 = try(lookup(sg, "protocol"), "tcp")
      source_security_group_id = sg.security_group_id
    }

  ] : []

  egress_with_sg_block = coalesce(try(lookup(var.vgw_security_group, "egress_with_sg", []), []), [])
  egress_with_sg = length(local.egress_with_sg_block) > 0 ? [
    for sg in local.egress_with_sg_block : {
      from_port                = try(lookup(sg, "port"), 443)
      to_port                  = try(lookup(sg, "port"), 443)
      protocol                 = try(lookup(sg, "protocol"), "tcp")
      source_security_group_id = sg.security_group_id
    }

  ] : []

  # Inject tags to target group
  target_groups = [for tg in var.target_groups : merge(tg, { tags = {
    resource_name = module.resource_names["alb_tg"].standard
  } })]

  # Need to construct the alb_dns_records as a map of object (alias A record)
  alb_dns_records = {
    (module.resource_names["alb"].standard) = {
      type = "A"
      # These name and zone_id must refer to a zone which is not managed by Cloud Map
      name    = module.alb.lb_dns_name
      zone_id = module.alb.lb_zone_id
      alias = {
        name                   = module.alb.lb_dns_name
        zone_id                = module.alb.lb_zone_id
        evaluate_target_health = true
      }
    }
  }

  alb_domain_name = module.alb.lb_dns_name

  # ACM cert doesnt allow first domain name > 64 chars. Hence, add a SAN for the standard name of ALB in-case the actual ALB name > 32 characters and a shortened name is used for ALB
  # We still would like to use the standard name in the custom A-record
  san = module.resource_names["alb"].recommended_per_length_restriction != module.resource_names["alb"].standard ? ["${module.resource_names["alb"].standard}.${var.dns_zone_name}"] : []

  # ACM first domain name must be < 64 characters
  actual_domain_name  = "${module.resource_names["virtual_gateway"].standard}.${var.namespace_name}"
  updated_domain_name = length(local.actual_domain_name) < 64 ? local.actual_domain_name : "${var.logical_product_family}-${var.logical_product_service}.${var.namespace_name}"
  private_cert_san    = local.actual_domain_name != local.updated_domain_name ? [local.actual_domain_name] : []

  # Role policies

  task_exec_role_default_managed_policies_map = merge({
    envoy_access         = "arn:aws:iam::aws:policy/AWSAppMeshEnvoyAccess"
    ecs_task_exec        = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
    envoy_preview_access = "arn:aws:iam::aws:policy/AWSAppMeshPreviewEnvoyAccess"
  }, var.ecs_exec_role_managed_policy_arns)

  task_role_default_managed_policies_map = merge({
    envoy_access         = "arn:aws:iam::aws:policy/AWSAppMeshEnvoyAccess"
    ecs_task_exec        = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
    envoy_preview_access = "arn:aws:iam::aws:policy/AWSAppMeshPreviewEnvoyAccess"
  }, var.ecs_role_managed_policy_arns)

  # This policy is required by AppMesh to pull certificates from PCA
  ecs_role_default_policy_json = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PrivateCertAuthorityAccess",
            "Effect": "Allow",
            "Action": [
                "acm-pca:GetCertificateAuthorityCertificate"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Sid": "ExportCertificate",
            "Effect": "Allow",
            "Action": [
                "acm:ExportCertificate"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
  }
EOF
  # Concat the default policy with optional policies passed in by user as input
  ecs_role_custom_policy_json = length(var.ecs_role_custom_policy_json) > 0 ? [local.ecs_role_default_policy_json, var.ecs_role_custom_policy_json] : [local.ecs_role_default_policy_json]

  task_exec_policy_arns_map = length(var.ecs_exec_role_custom_policy_json) > 0 ? merge(local.task_exec_role_default_managed_policies_map, { custom_policy = module.ecs_task_execution_policy[0].policy_arn }) : local.task_exec_role_default_managed_policies_map
  task_policy_arns_map      = merge(local.task_role_default_managed_policies_map, { custom_policy = module.ecs_task_policy.policy_arn })

  # Containers

  # Virtual Gateway task definition always contains 1 container (envoy proxy)
  vgw_container = {
    name = "envoy"
    # See README.md or https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html for latest version
    image_tag = length(var.envoy_proxy_image) > 0 ? var.envoy_proxy_image : "public.ecr.aws/appmesh/aws-appmesh-envoy:v1.29.6.0-prod"
    log_configuration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/fargate/task/${module.resource_names["vgw_ecs_app"].standard}"
        awslogs-region        = var.region
        awslogs-create-group  = "true"
        awslogs-stream-prefix = "envoy"
      }
    }
    # Port mappings in envoy proxy should be same as virtual gateway listener port as well as the ALB health check port
    port_mappings = [
      {
        hostPort      = var.vgw_listener_port
        protocol      = "tcp"
        containerPort = var.vgw_listener_port
      },
      # Port for stats - (curl -s http://<vgw_discovery_endpoint>:9901/stats)
      {
        hostPort      = "9901"
        protocol      = "tcp"
        containerPort = "9901"
      }
    ]
    environment = {
      APPMESH_VIRTUAL_NODE_NAME = "mesh/${var.app_mesh_id}/virtualGateway/${module.resource_names["virtual_gateway"].standard}"
    }

    healthcheck = {
      "retries" : 3,
      "command" : [
        "CMD-SHELL",
        "curl -s http://localhost:9901/server_info | grep state | grep -q LIVE"
      ]
      "timeout" : 2,
      "interval" : 5,
      "startPeriod" : 60
    }
    # These parameters don't need to change for the virtual gateway, hence are not added as variables.
    user                     = "1337"
    memory                   = null
    cpu                      = 0
    memory_reservation       = null
    essential                = true
    readonly_root_filesystem = false
  }

  tags = merge(local.default_tags, var.tags)
}
