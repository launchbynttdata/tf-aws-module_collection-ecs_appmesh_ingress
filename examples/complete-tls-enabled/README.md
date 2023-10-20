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

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_random"></a> [random](#provider\_random) | 3.5.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | 5.0.0 |
| <a name="module_ecs_platform"></a> [ecs\_platform](#module\_ecs\_platform) | git::https://github.com/nexient-llc/tf-aws-wrapper_module-ecs_appmesh_platform.git | 0.1.0 |
| <a name="module_ecs_ingress"></a> [ecs\_ingress](#module\_ecs\_ingress) | ../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [random_integer.priority](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/integer) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_naming_prefix"></a> [naming\_prefix](#input\_naming\_prefix) | Prefix for the provisioned resources. | `string` | `"example"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment in which the resource should be provisioned like dev, qa, prod etc. | `string` | `"dev"` | no |
| <a name="input_environment_number"></a> [environment\_number](#input\_environment\_number) | The environment count for the respective environment. Defaults to 000. Increments in value of 1 | `string` | `"000"` | no |
| <a name="input_resource_number"></a> [resource\_number](#input\_resource\_number) | The resource count for the respective resource. Defaults to 000. Increments in value of 1 | `string` | `"000"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS Region in which the infra needs to be provisioned | `string` | `"us-east-2"` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | n/a | `string` | `"10.1.0.0/16"` | no |
| <a name="input_private_subnets"></a> [private\_subnets](#input\_private\_subnets) | List of private subnet cidrs | `list` | <pre>[<br>  "10.1.1.0/24",<br>  "10.1.2.0/24",<br>  "10.1.3.0/24"<br>]</pre> | no |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | List of availability zones for the VPC | `list` | <pre>[<br>  "us-east-2a",<br>  "us-east-2b",<br>  "us-east-2c"<br>]</pre> | no |
| <a name="input_interface_vpc_endpoints"></a> [interface\_vpc\_endpoints](#input\_interface\_vpc\_endpoints) | List of VPC endpoints to be created | <pre>map(object({<br>    service_name        = string<br>    subnet_names        = optional(list(string), [])<br>    private_dns_enabled = optional(bool, false)<br>    tags                = optional(map(string), {})<br>  }))</pre> | `{}` | no |
| <a name="input_gateway_vpc_endpoints"></a> [gateway\_vpc\_endpoints](#input\_gateway\_vpc\_endpoints) | List of VPC endpoints to be created | <pre>map(object({<br>    service_name        = string<br>    subnet_names        = optional(list(string), [])<br>    private_dns_enabled = optional(bool, false)<br>    tags                = optional(map(string), {})<br>  }))</pre> | `{}` | no |
| <a name="input_vpce_security_group"></a> [vpce\_security\_group](#input\_vpce\_security\_group) | Default security group to be attached to all VPC endpoints | <pre>object({<br>    ingress_rules            = optional(list(string))<br>    ingress_cidr_blocks      = optional(list(string))<br>    ingress_with_cidr_blocks = optional(list(map(string)))<br>    egress_rules             = optional(list(string))<br>    egress_cidr_blocks       = optional(list(string))<br>    egress_with_cidr_blocks  = optional(list(map(string)))<br>  })</pre> | `null` | no |
| <a name="input_private_ca_arn"></a> [private\_ca\_arn](#input\_private\_ca\_arn) | ARN of the Private CA. This is used to sign private certificates used in App Mesh. Required when TLS is enabled in App Mesh | `string` | n/a | yes |
| <a name="input_vgw_security_group"></a> [vgw\_security\_group](#input\_vgw\_security\_group) | Security group for the Virtual Gateway ECS application. By default, it allows traffic from ALB on the app\_port | <pre>object({<br>    ingress_rules            = optional(list(string))<br>    ingress_cidr_blocks      = optional(list(string))<br>    ingress_with_cidr_blocks = optional(list(map(string)))<br>    egress_rules             = optional(list(string))<br>    egress_cidr_blocks       = optional(list(string))<br>    egress_with_cidr_blocks  = optional(list(map(string)))<br>  })</pre> | `null` | no |
| <a name="input_alb_sg"></a> [alb\_sg](#input\_alb\_sg) | Security Group for the ALB. https://github.com/terraform-aws-modules/terraform-aws-security-group/blob/master/rules.tf | <pre>object({<br>    description              = optional(string)<br>    ingress_rules            = optional(list(string))<br>    ingress_cidr_blocks      = optional(list(string))<br>    egress_rules             = optional(list(string))<br>    egress_cidr_blocks       = optional(list(string))<br>    ingress_with_cidr_blocks = optional(list(map(string)))<br>    egress_with_cidr_blocks  = optional(list(map(string)))<br>  })</pre> | n/a | yes |
| <a name="input_dns_zone_name"></a> [dns\_zone\_name](#input\_dns\_zone\_name) | Name of the  Route53 DNS Zone where custom DNS records will be created. Required if use\_https\_listeners=true | `string` | n/a | yes |
| <a name="input_private_zone"></a> [private\_zone](#input\_private\_zone) | Whether the dns\_zone\_name provided above is a private or public hosted zone. Required if dns\_zone\_name is not empty | `string` | n/a | yes |
| <a name="input_wait_for_steady_state"></a> [wait\_for\_steady\_state](#input\_wait\_for\_steady\_state) | If true, it will wait for the service to reach a steady state (like aws ecs wait services-stable) before continuing | `bool` | `false` | no |
| <a name="input_redeploy_on_apply"></a> [redeploy\_on\_apply](#input\_redeploy\_on\_apply) | Redeploys the service everytime a terraform apply is executed. force\_new\_deployment should also be true for this flag to work | `bool` | `false` | no |
| <a name="input_force_new_deployment"></a> [force\_new\_deployment](#input\_force\_new\_deployment) | Enable to force a new task deployment of the service when terraform apply is executed. | `bool` | `false` | no |
| <a name="input_health_check_grace_period_seconds"></a> [health\_check\_grace\_period\_seconds](#input\_health\_check\_grace\_period\_seconds) | Seconds to ignore failing load balancer health checks on newly instantiated tasks to prevent premature shutdown, up to 7200. Only valid for services configured to use load balancers | `number` | `0` | no |
| <a name="input_app_task_cpu"></a> [app\_task\_cpu](#input\_app\_task\_cpu) | Amount of CPU to be allocated to the health check app task | `number` | `512` | no |
| <a name="input_app_task_memory"></a> [app\_task\_memory](#input\_app\_task\_memory) | Amount of Memory to be allocated to the health check app task | `number` | `1024` | no |
| <a name="input_app_desired_count"></a> [app\_desired\_count](#input\_app\_desired\_count) | The number of instances of the health check task definition to place and keep running | `number` | `1` | no |
| <a name="input_app_image_tag"></a> [app\_image\_tag](#input\_app\_image\_tag) | Docker image for the heartBeat application, in the format <docker\_image><docker\_tag> | `string` | n/a | yes |
| <a name="input_app_port"></a> [app\_port](#input\_app\_port) | The port at which the health check application is running | `number` | n/a | yes |
| <a name="input_app_security_group"></a> [app\_security\_group](#input\_app\_security\_group) | Security group for the health check ECS application. Need to open ports if one wants to access the heart-beat application manually. | <pre>object({<br>    ingress_rules            = optional(list(string))<br>    ingress_cidr_blocks      = optional(list(string))<br>    ingress_with_cidr_blocks = optional(list(map(string)))<br>    egress_rules             = optional(list(string))<br>    egress_cidr_blocks       = optional(list(string))<br>    egress_with_cidr_blocks  = optional(list(map(string)))<br>  })</pre> | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of custom tags to be associated with the resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at  http://www.apache.org/licenses/LICENSE-2.0  Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
