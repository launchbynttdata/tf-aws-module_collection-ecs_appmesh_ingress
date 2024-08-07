# Complete example with TLS enabled
This example will provision a AppMesh ingress along with all its dependencies.

## Known Issues
1. Unable to provision all resources in 1 go. Need to do it in 2 batches
   ```shell
   # Apply the VPC and ecs_platform modules first
    terraform apply -target module.vpc
   # Apply remaining that is ecs_ingress
    terraform apply
    ```
2. Make sure that the app image is in the ECR of the same account not cross account. The VPC endpoints work only within same account. This example uses private network through VPC endpoints
3. Egress port 443 should be open for security groups of ECS Service to be able to pull images from ECR
4. Make sure the VPC endpoints are configured for AppMesh. Without that the ECS task containers would hang in pending state forever
5. This example module assumes that the `dns_zone` is already created. `private_ca` can be optionally created on passed in as input parameter. ECR image for app is already pushed to an ECR repo
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0, < 1.6 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.5.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_random"></a> [random](#provider\_random) | 3.6.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | 5.0.0 |
| <a name="module_ecs_platform"></a> [ecs\_platform](#module\_ecs\_platform) | terraform.registry.launch.nttdata.com/module_collection/ecs_appmesh_platform/aws | ~> 1.0 |
| <a name="module_ecs_ingress"></a> [ecs\_ingress](#module\_ecs\_ingress) | ../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [random_integer.priority](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/integer) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_logical_product_family"></a> [logical\_product\_family](#input\_logical\_product\_family) | (Required) Name of the product family for which the resource is created.<br>    Example: org\_name, department\_name. | `string` | `"launch"` | no |
| <a name="input_logical_product_service"></a> [logical\_product\_service](#input\_logical\_product\_service) | (Required) Name of the product service for which the resource is created.<br>    For example, backend, frontend, middleware etc. | `string` | `"backend"` | no |
| <a name="input_class_env"></a> [class\_env](#input\_class\_env) | (Required) Environment where resource is going to be deployed. For example. dev, qa, uat | `string` | `"dev"` | no |
| <a name="input_instance_env"></a> [instance\_env](#input\_instance\_env) | Number that represents the instance of the environment. | `number` | `0` | no |
| <a name="input_instance_resource"></a> [instance\_resource](#input\_instance\_resource) | Number that represents the instance of the resource. | `number` | `0` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS Region in which the infra needs to be provisioned | `string` | `"us-east-2"` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block related to the VPC | `string` | `"10.1.0.0/16"` | no |
| <a name="input_private_subnets"></a> [private\_subnets](#input\_private\_subnets) | List of private subnet cidrs | `list(string)` | <pre>[<br>  "10.1.1.0/24",<br>  "10.1.2.0/24",<br>  "10.1.3.0/24"<br>]</pre> | no |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | List of availability zones for the VPC | `list(string)` | <pre>[<br>  "us-east-2a",<br>  "us-east-2b",<br>  "us-east-2c"<br>]</pre> | no |
| <a name="input_interface_vpc_endpoints"></a> [interface\_vpc\_endpoints](#input\_interface\_vpc\_endpoints) | List of VPC endpoints to be created | <pre>map(object({<br>    service_name        = string<br>    subnet_names        = optional(list(string), [])<br>    private_dns_enabled = optional(bool, false)<br>    tags                = optional(map(string), {})<br>  }))</pre> | `{}` | no |
| <a name="input_gateway_vpc_endpoints"></a> [gateway\_vpc\_endpoints](#input\_gateway\_vpc\_endpoints) | List of VPC endpoints to be created | <pre>map(object({<br>    service_name        = string<br>    subnet_names        = optional(list(string), [])<br>    private_dns_enabled = optional(bool, false)<br>    tags                = optional(map(string), {})<br>  }))</pre> | `{}` | no |
| <a name="input_vpce_security_group"></a> [vpce\_security\_group](#input\_vpce\_security\_group) | Default security group to be attached to all VPC endpoints | <pre>object({<br>    ingress_rules            = optional(list(string))<br>    ingress_cidr_blocks      = optional(list(string))<br>    ingress_with_cidr_blocks = optional(list(map(string)))<br>    egress_rules             = optional(list(string))<br>    egress_cidr_blocks       = optional(list(string))<br>    egress_with_cidr_blocks  = optional(list(map(string)))<br>  })</pre> | `null` | no |
| <a name="input_private_ca_arn"></a> [private\_ca\_arn](#input\_private\_ca\_arn) | ARN of the Private CA. This is used to sign private certificates used in App Mesh. Required when TLS is enabled in App Mesh | `string` | n/a | yes |
| <a name="input_vgw_security_group"></a> [vgw\_security\_group](#input\_vgw\_security\_group) | Security group for the Virtual Gateway ECS application. By default, it allows traffic from ALB on the app\_port | <pre>object({<br>    ingress_rules            = optional(list(string))<br>    ingress_cidr_blocks      = optional(list(string))<br>    ingress_with_cidr_blocks = optional(list(map(string)))<br>    egress_rules             = optional(list(string))<br>    egress_cidr_blocks       = optional(list(string))<br>    egress_with_cidr_blocks  = optional(list(map(string)))<br>  })</pre> | `null` | no |
| <a name="input_alb_sg"></a> [alb\_sg](#input\_alb\_sg) | Security Group for the ALB. https://github.com/terraform-aws-modules/terraform-aws-security-group/blob/master/rules.tf | <pre>object({<br>    description              = optional(string)<br>    ingress_rules            = optional(list(string))<br>    ingress_cidr_blocks      = optional(list(string))<br>    egress_rules             = optional(list(string))<br>    egress_cidr_blocks       = optional(list(string))<br>    ingress_with_cidr_blocks = optional(list(map(string)))<br>    egress_with_cidr_blocks  = optional(list(map(string)))<br>  })</pre> | n/a | yes |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Zone ID of the hosted DNS zone.  Cannot be associated with CloudMap | `string` | n/a | yes |
| <a name="input_dns_zone_name"></a> [dns\_zone\_name](#input\_dns\_zone\_name) | Name of the Route53 DNS Zone where custom DNS records will be created. Required if use\_https\_listeners=true. Cannot be associated with CloudMap | `string` | n/a | yes |
| <a name="input_private_zone"></a> [private\_zone](#input\_private\_zone) | Whether the dns\_zone\_name provided above is a private or public hosted zone. Required if dns\_zone\_name is not empty | `string` | n/a | yes |
| <a name="input_force_new_deployment"></a> [force\_new\_deployment](#input\_force\_new\_deployment) | Enable to force a new task deployment of the service when terraform apply is executed. | `bool` | `false` | no |
| <a name="input_health_check_grace_period_seconds"></a> [health\_check\_grace\_period\_seconds](#input\_health\_check\_grace\_period\_seconds) | Seconds to ignore failing load balancer health checks on newly instantiated tasks to prevent premature shutdown, up to 7200. Only valid for services configured to use load balancers | `number` | `0` | no |
| <a name="input_app_image_tag"></a> [app\_image\_tag](#input\_app\_image\_tag) | Docker image for the heartBeat application, in the format <docker\_image><docker\_tag> | `string` | n/a | yes |
| <a name="input_app_port"></a> [app\_port](#input\_app\_port) | The port at which the health check application is running | `number` | n/a | yes |
| <a name="input_app_security_group"></a> [app\_security\_group](#input\_app\_security\_group) | Security group for the health check ECS application. Need to open ports if one wants to access the heart-beat application manually. | <pre>object({<br>    ingress_rules            = optional(list(string))<br>    ingress_cidr_blocks      = optional(list(string))<br>    ingress_with_cidr_blocks = optional(list(map(string)))<br>    egress_rules             = optional(list(string))<br>    egress_cidr_blocks       = optional(list(string))<br>    egress_with_cidr_blocks  = optional(list(map(string)))<br>  })</pre> | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of custom tags to be associated with the resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at  http://www.apache.org/licenses/LICENSE-2.0  Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License. |
| <a name="output_app_mesh_id"></a> [app\_mesh\_id](#output\_app\_mesh\_id) | n/a |
| <a name="output_virtual_gateway_name"></a> [virtual\_gateway\_name](#output\_virtual\_gateway\_name) | n/a |
| <a name="output_virtual_gateway_arn"></a> [virtual\_gateway\_arn](#output\_virtual\_gateway\_arn) | n/a |
| <a name="output_virtual_gateway_cert_arn"></a> [virtual\_gateway\_cert\_arn](#output\_virtual\_gateway\_cert\_arn) | n/a |
| <a name="output_alb_dns"></a> [alb\_dns](#output\_alb\_dns) | output "private\_ca\_arn" { value = module.ecs\_ingress.private\_ca\_arn } |
| <a name="output_alb_id"></a> [alb\_id](#output\_alb\_id) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
