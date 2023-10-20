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

variable "naming_prefix" {
  description = "Prefix for the provisioned resources."
  type        = string
  default     = "example"
}

variable "environment" {
  description = "Environment in which the resource should be provisioned like dev, qa, prod etc."
  type        = string
  default     = "dev"
}

variable "environment_number" {
  description = "The environment count for the respective environment. Defaults to 000. Increments in value of 1"
  type        = string
  default     = "000"
}

variable "resource_number" {
  description = "The resource count for the respective resource. Defaults to 000. Increments in value of 1"
  type        = string
  default     = "000"
}

variable "region" {
  description = "AWS Region in which the infra needs to be provisioned"
  default     = "us-east-2"
}

### VPC related variables

variable "vpc_cidr" {
  default = "10.1.0.0/16"
}

variable "private_subnets" {
  description = "List of private subnet cidrs"
  default     = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
}

variable "availability_zones" {
  description = "List of availability zones for the VPC"
  default     = ["us-east-2a", "us-east-2b", "us-east-2c"]
}

## VPC Endpoint related
### VPC Endpoints related variables
variable "interface_vpc_endpoints" {
  description = "List of VPC endpoints to be created"
  type = map(object({
    service_name        = string
    subnet_names        = optional(list(string), [])
    private_dns_enabled = optional(bool, false)
    tags                = optional(map(string), {})
  }))

  default = {}
}

variable "gateway_vpc_endpoints" {
  description = "List of VPC endpoints to be created"
  type = map(object({
    service_name        = string
    subnet_names        = optional(list(string), [])
    private_dns_enabled = optional(bool, false)
    tags                = optional(map(string), {})
  }))

  default = {}
}

variable "vpce_security_group" {
  description = "Default security group to be attached to all VPC endpoints"
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

## Ingress related

variable "private_ca_arn" {
  description = "ARN of the Private CA. This is used to sign private certificates used in App Mesh. Required when TLS is enabled in App Mesh"
  type        = string
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
  })

  default = null
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

variable "dns_zone_name" {
  description = "Name of the  Route53 DNS Zone where custom DNS records will be created. Required if use_https_listeners=true"
  type        = string
}

variable "private_zone" {
  description = "Whether the dns_zone_name provided above is a private or public hosted zone. Required if dns_zone_name is not empty"
  type        = string
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

variable "health_check_grace_period_seconds" {
  type        = number
  description = "Seconds to ignore failing load balancer health checks on newly instantiated tasks to prevent premature shutdown, up to 7200. Only valid for services configured to use load balancers"
  default     = 0
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

variable "tags" {
  description = "A map of custom tags to be associated with the resources"
  type        = map(string)
  default     = {}
}
