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

variable "logical_product_family" {
  type        = string
  description = <<EOF
    (Required) Name of the product family for which the resource is created.
    Example: org_name, department_name.
  EOF
  nullable    = false
  default     = "launch"

  validation {
    condition     = can(regex("^[_\\-A-Za-z0-9]+$", var.logical_product_family))
    error_message = "The variable must contain letters, numbers, -, _, and .."
  }
}

variable "logical_product_service" {
  type        = string
  description = <<EOF
    (Required) Name of the product service for which the resource is created.
    For example, backend, frontend, middleware etc.
  EOF
  nullable    = false
  default     = "backend"

  validation {
    condition     = can(regex("^[_\\-A-Za-z0-9]+$", var.logical_product_service))
    error_message = "The variable must contain letters, numbers, -, _, and .."
  }
}

variable "class_env" {
  type        = string
  description = "(Required) Environment where resource is going to be deployed. For example. dev, qa, uat"
  nullable    = false
  default     = "dev"

  validation {
    condition     = length(regexall("\\b \\b", var.class_env)) == 0
    error_message = "Spaces between the words are not allowed."
  }
}

variable "instance_env" {
  type        = number
  description = "Number that represents the instance of the environment."
  default     = 0

  validation {
    condition     = var.instance_env >= 0 && var.instance_env <= 999
    error_message = "Instance number should be between 1 to 999."
  }
}

variable "instance_resource" {
  type        = number
  description = "Number that represents the instance of the resource."
  default     = 0

  validation {
    condition     = var.instance_resource >= 0 && var.instance_resource <= 100
    error_message = "Instance number should be between 1 to 100."
  }
}

variable "region" {
  description = "AWS Region in which the infra needs to be provisioned"
  default     = "us-east-2"
}

variable "resource_names_map" {
  description = "A map of key to resource_name that will be used by tf-launch-module_library-resource_name to generate resource names"
  type = map(object(
    {
      name       = string
      max_length = optional(number, 60)
    }
  ))
  default = {
    alb_sg = {
      name       = "alb-sg"
      max_length = 60
    }
    vgw_ecs_sg = {
      name       = "vgw-sg"
      max_length = 60
    }
    health_check_app_ecs_sg = {
      name       = "hc-app-sg"
      max_length = 60
    }
    alb = {
      name       = "alb"
      max_length = 32
    }
    alb_tg = {
      name       = "albtg"
      max_length = 60
    }
    virtual_gateway = {
      name       = "vgw"
      max_length = 60
    }
    sds_vg = {
      name       = "sds-vg"
      max_length = 60
    }
    s3_logs = {
      name       = "alblogs"
      max_length = 60
    }
    acm = {
      name       = "acm"
      max_length = 60
    }
    task_exec_policy = {
      name       = "exec-plcy"
      max_length = 60
    }
    task_policy = {
      name       = "task-plcy"
      max_length = 60
    }
    vgw_ecs_app = {
      name       = "vgw-svc"
      max_length = 60
    }
    health_check_ecs_app = {
      name       = "hc-svc"
      max_length = 60
    }
    vgw_ecs_td = {
      name       = "vgw-td"
      max_length = 60
    }
    health_check_ecs_td = {
      name       = "hc-td"
      max_length = 60
    }
  }
}

### VPC related variables
variable "vpc_id" {
  description = "The VPC ID of the VPC where infrastructure will be provisioned"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnets"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of public subnets"
  type        = list(string)
  default     = []
}

variable "vgw_security_group" {
  description = "Security group for the Virtual Gateway ECS application. By default, it allows traffic from ALB on the app_port"
  type = object({
    ingress_rules            = optional(list(string))
    ingress_cidr_blocks      = optional(list(string))
    ingress_with_cidr_blocks = optional(list(map(string)))
    egress_rules             = optional(list(string))
    egress_cidr_blocks       = optional(list(string))
    egress_with_cidr_blocks  = optional(list(map(string)))
    ingress_with_sg          = optional(list(map(string)))
    egress_with_sg           = optional(list(map(string)))
  })

  default = null
}

## ECS Cluster
variable "ecs_cluster_arn" {
  description = "ARN of the ECS Cluster where the services are to be created"
  type        = string
}

## App Mesh
variable "app_mesh_id" {
  description = "ID of the App Mesh where virtual Gateway is to be created. ID and Name are the same for App Mesh"
  type        = string
}

### Cloud Map Namespace related variables
variable "namespace_name" {
  description = "Name of the Cloud Map namespace to be used for Service Discovery"
  type        = string
}

variable "namespace_id" {
  description = "ID of the Cloud Map namespace to be used for Service Discovery"
  type        = string
}

## ALB related variables
variable "load_balancer_type" {
  description = "The type of the load balancer. Default is 'application'"
  type        = string
  default     = "application"
}

variable "is_internal" {
  description = "Whether this load balancer is internal or public facing"
  type        = bool
  default     = true
}

variable "alb_sg" {
  description = "Security Group for the ALB. https://github.com/terraform-aws-modules/terraform-aws-security-group/blob/master/rules.tf"
  type = object({
    description              = optional(string)
    ingress_rules            = optional(list(string))
    ingress_cidr_blocks      = optional(list(string))
    egress_rules             = optional(list(string))
    egress_cidr_blocks       = optional(list(string))
    ingress_with_cidr_blocks = optional(list(map(string)))
    egress_with_cidr_blocks  = optional(list(map(string)))
  })
}

variable "target_groups" {
  description = <<EOT
    List of target groups for the ALB"
    `target_type` can be ip, instance
    `health_check` must be set for backend_protocol=HTTPS.
    Valid health_check attributes are healthy_threshold, unhealthy_threshold, path, port, protocol
      - protocol must be HTTP, HTTPS etc.
  EOT
  type = list(object({
    # Need to use name_prefix instead of name as the lifecycle property create_before_destroy is set
    name_prefix      = optional(string, "albtg-")
    backend_protocol = optional(string)
    backend_port     = optional(number)
    target_type      = optional(string)
    health_check     = optional(map(string), {})
  }))
}

variable "dns_zone_id" {
  description = "Zone ID of the hosted zonee"
  type        = string
  default     = null
}

variable "subject_alternate_names" {
  description = "Additional domain names to be added to the certificate created for ALB. Domain names must be FQDN."
  type        = list(string)
  default     = []
}

variable "dns_zone_name" {
  description = "Name of the Route53 DNS Zone where custom DNS records will be created. Required if use_https_listeners=true"
  type        = string
  default     = ""
}

variable "private_zone" {
  description = "Whether the dns_zone_name provided above is a private or public hosted zone. Required if dns_zone_name is not empty"
  type        = string
  default     = ""
}

variable "idle_timeout" {
  description = "The time in seconds that the connection is allowed to be idle."
  type        = number
  default     = 60
}

variable "alb_logs_bucket_id" {
  description = "S3 bucket ID for ALB logs"
  type        = string
  default     = ""
}

variable "alb_logs_bucket_prefix" {
  description = "S3 bucket prefix for ALB logs"
  type        = string
  default     = null
}

variable "use_https_listeners" {
  description = "Whether to enable HTTPs in the ALB"
  type        = bool
  default     = true
}

variable "listener_ssl_policy_default" {
  description = "The security policy if using HTTPS externally on the load balancer. [See](https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/elb-security-policy-table.html)."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

## App Mesh related variables
variable "private_ca_arn" {
  description = "ARN of the Private CA. This is used to sign private certificates used in App Mesh. Required when TLS is enabled in App Mesh"
  type        = string
  default     = ""
}

variable "tls_enforce" {
  description = "Whether to enforce TLS in App Mesh Virtual Gateway and services"
  type        = bool
  default     = true
}

variable "vgw_logs_text_format" {
  description = "The text format."
  type        = string
  default     = null
}

variable "vgw_tls_mode" {
  description = "The mode for the listener’s Transport Layer Security (TLS) configuration. Must be one of DISABLED, PERMISSIVE, STRICT."
  type        = string
  default     = "DISABLED"
}

variable "vgw_tls_ports" {
  description = "If you specify a listener port other than 443, you must specify this field."
  type        = list(number)
  default     = []
}

variable "vgw_health_check_path" {
  description = "The destination path for the health check request."
  type        = string
  default     = "/"
}

variable "vgw_health_check_protocol" {
  description = "The protocol for the health check request. Must be one of [http http2 grpc]."
  type        = string
  default     = "http"
}

variable "vgw_listener_port" {
  description = "The port mapping information for the listener."
  type        = number
}

variable "vgw_listener_protocol" {
  description = "The protocol for the port mapping. Must be one of [http http2 grpc]."
  type        = string
  default     = "http"
}

## ECS related variables (shared between virtual gateway and health check application)

variable "ecs_exec_role_managed_policy_arns" {
  description = "A Map (ARNs) of AWS managed policies to be attached to the ECS Task Exec role."
  type        = map(string)
  default     = {}
}

variable "ecs_role_managed_policy_arns" {
  description = "A Map (ARNs) of AWS managed policies to be attached to the ECS Task role."
  type        = map(string)
  default     = {}
}

variable "ecs_exec_role_custom_policy_json" {
  description = "Custom policy to attach to ecs task execution role. Document must be valid json."
  type        = string
  default     = ""
}

variable "ecs_role_custom_policy_json" {
  description = "Custom policy to attach to ecs task role. Document must be valid json."
  type        = string
  default     = ""
}

variable "envoy_proxy_image" {
  description = <<EOT
    Optional docker image of the envoy proxy in the format `<docker_image>:<tag>`
    Default is `840364872350.dkr.ecr.us-east-2.amazonaws.com/aws-appmesh-envoy:v1.25.4.0-prod`
  EOT
  type        = string
  default     = ""
}

variable "ecs_launch_type" {
  description = "The launch type of the ECS service. Default is FARGATE"
  type        = string
  default     = "FARGATE"
}

variable "network_mode" {
  description = "The network_mode of the ECS service. Default is awsvpc"
  type        = string
  default     = "awsvpc"
}

variable "ignore_changes_task_definition" {
  description = "Lifecycle ignore policy for task definition. If true, terraform won't detect changes when task_definition is changed outside of terraform"
  type        = bool
  default     = true
}

variable "assign_public_ip" {
  description = "If true, public IP will be assigned to this service task, else private IP"
  type        = bool
  default     = false
}

variable "ignore_changes_desired_count" {
  description = "Lifecycle ignore policy for desired_count. If true, terraform won't detect changes when desired_count is changed outside of terraform"
  type        = bool
  default     = true
}

variable "task_cpu" {
  description = "Amount of CPU to be allocated to the task"
  default     = 512
}

variable "task_memory" {
  description = "Amount of Memory to be allocated to the task"
  default     = 1024
}
variable "health_check_grace_period_seconds" {
  type        = number
  description = "Seconds to ignore failing load balancer health checks on newly instantiated tasks to prevent premature shutdown, up to 7200. Only valid for services configured to use load balancers"
  default     = 0
}

variable "deployment_minimum_healthy_percent" {
  type        = number
  description = "The lower limit (as a percentage of `desired_count`) of the number of tasks that must remain running and healthy in a service during a deployment"
  default     = 100
}

variable "deployment_maximum_percent" {
  type        = number
  description = "The upper limit of the number of tasks (as a percentage of `desired_count`) that can be running in a service during a deployment"
  default     = 200
}

variable "desired_count" {
  type        = number
  description = "The number of instances of the task definition to place and keep running"
  default     = 1
}

variable "deployment_controller_type" {
  type        = string
  description = "Type of deployment controller. Valid values are `CODE_DEPLOY` and `ECS`"
  default     = "ECS"
}

variable "wait_for_steady_state" {
  type        = bool
  description = "If true, it will wait for the service to reach a steady state (like aws ecs wait services-stable) before continuing"
  default     = false
}

variable "redeploy_on_apply" {
  description = "Redeploys the service everytime a terraform apply is executed. force_new_deployment should also be true for this flag to work"
  type        = bool
  default     = false
}

variable "force_new_deployment" {
  description = "Enable to force a new task deployment of the service when terraform apply is executed."
  type        = bool
  default     = false
}

## health check application related variables
variable "app_task_cpu" {
  description = "Amount of CPU to be allocated to the health check app task"
  default     = 512
}

variable "app_task_memory" {
  description = "Amount of Memory to be allocated to the health check app task"
  default     = 1024
}

variable "app_desired_count" {
  type        = number
  description = "The number of instances of the health check task definition to place and keep running"
  default     = 1
}

variable "app_image_tag" {
  description = "Docker image for the heartBeat application, in the format <docker_image><docker_tag>"
  type        = string
}

variable "app_port" {
  description = "The port at which the health check application is running"
  type        = number
}

variable "app_security_group" {
  description = "Security group for the health check ECS application. Need to open ports if one wants to access the heart-beat application manually."
  type = object({
    ingress_rules            = optional(list(string))
    ingress_cidr_blocks      = optional(list(string))
    ingress_with_cidr_blocks = optional(list(map(string)))
    egress_rules             = optional(list(string))
    egress_cidr_blocks       = optional(list(string))
    egress_with_cidr_blocks  = optional(list(map(string)))
  })

  default = null
}

variable "match_path_prefix" {
  description = "Virtual gateway route path match. Must be same as the ALB health check path"
  type        = string
  default     = "/"
}

variable "tags" {
  description = "A map of custom tags to be associated with the resources"
  type        = map(string)
  default     = {}
}
