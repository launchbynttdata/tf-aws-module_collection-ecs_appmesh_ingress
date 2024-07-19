# tf-aws-module_collection-ecs_appmesh_ingress

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![License: CC BY-NC-ND 4.0](https://img.shields.io/badge/License-CC_BY--NC--ND_4.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-nd/4.0/)

## Overview

This terraform module creates an ingress route into the ECS Cluster using App Mesh through an Application Load Balancer and a `Virtual Gateway`.

This module provisions an Application Load Balancer (ALB) with a HTTPs listener, listening on port `443`. All incoming traffic to this App Mesh are routed through this load balancer. The ALB routes traffic to the Virtual Gateway through the `envoy proxy` running as an ECS Service.
Once the traffic reaches the Virtual Gateway listener, there can be multiple `gateway routes` configured at the Virtual gateway to route the traffic to respective backends (ECS Service) through the configured Virtual Services that uses CloudMap service discovery to discover the ECS task instances.
This module just configures a single gateway route `/health` for the ALB to perform health checks on. It is a single HTTP server configured to return `200 OK`.

The following AWS resources are provisioned in this module
- Application Load Balancer
  - Listeners
  - Target Group
  - Security Group
- ACM Certificate for Load Balancer
- Public DNS record for Load Balancer. Optionally, creates a vanity URL (CName record)
- Virtual Gateway
  - ECS Service
  - Task Definition
  - Security Group
  - IAM roles for Task and Task Execution
- Health Check ECS application
  - ECS Service
  - Task Definition
  - Virtual Service
  - Virtual Node
  - Service Discovery Service
  - Private Certificate for Service Discovery Endpoint
- Virtual Gateway route for the above Health Check service

Below are some important considerations for the App Mesh Ingress configuration on ECS cluster
- All ingress traffic must pass through the Virtual Gateway
- In order for the ALB health checks to not fail for a deployed Virtual Gateway in ECS (without any actual apps deployed), it must have a backend configured for health-checks. In this module, we deploy a simple HTTP server for health checks of Virtual gateway.
- The backend services that do not need route from outside the Mesh may not have a route configured in Virtual Gateway.
  - These services can be accessed by other services inside the Mesh using the Service Discovery endpoints (configured using CloudMap)
  - The security group of these services must allow ingress traffic on the `application port` for these services
- All the backend services that need a route from outside the Mesh must have a `gateway route` configured in the Virtual gateway
  - Virtual gateway supports 2 kinds of routing
    - Path based routing
    - Matching Hostname header based routing
- ALB is configured with HTTPs listener. In order to provision certificates for TLS, a custom domain name must be configured for the ALB. TLS certificates cannot be provisioned for the default AWS URL.
  - We use an `internal` ALB in this project
  - An HTTP listener is also configured to redirect all traffic at port `80` to `443`.
  - An `A record` is created in the `public` hosted zone in the AWS account
  - A certificate is provisioned for the `A record` as the first domain name in the ACM certificate
    - Additional SANs can be added for other CNAME records pointing to the ALB. This can be useful for `hostname` header based routing.
- ALB Target Group must be configured for `HTTPS` at port `443`. The health check port should ideally be `443` but can be any other port
  - The health check port must match the `application port` of the `envoy proxy` container in the task definition for Virtual Gateway ECS Service. The Virtual Gateway `listener port` and the `health check port` should also be the same.
  - The health check path can be anything, defaulting to `/`. If anything else is selected like `/health`, the corresponding `gateway route` must be configured to have the same `match_path_prefix`
- ALB Security group should allow ingress traffic on port `443` and optionally `80` (will be auto redirected by HTTP listener)
- Virtual Gateway Security Group configured on the ECS Service allows ingress traffic only from the `ALB Security Group`
  - Optionally, it can allow ingress traffic on `9901` port to check stats on the App Mesh.



## Usage
A sample variable file `example.tfvars` is available in the root directory which can be used to test this module. User needs to follow the below steps to execute this module
1. Update the `example.tfvars` to manually enter values for all fields marked within `<>` to make the variable file usable
2. Create a file `provider.tf` with the below contents
   ```
    provider "aws" {
      profile = "<profile_name>"
      region  = "<region_name>"
    }
    ```
   If using `SSO`, make sure you are logged in `aws sso login --profile <profile_name>`
3. Make sure terraform binary is installed on your local. Use command `type terraform` to find the installation location. If you are using `asdf`, you can run `asfd install` and it will install the correct terraform version for you. `.tool-version` contains all the dependencies.
4. Run the `terraform` to provision infrastructure on AWS
    ```
    # Initialize
    terraform init
    # Plan
    terraform plan -var-file example.tfvars
    # Apply (this is create the actual infrastructure)
    terraform apply -var-file example.tfvars -auto-approve
   ```
## Known Issues
1. The ALB is currently set to only work with TLS listener in this module. Unable to make it work for both HTTP and TLS listener in if/else. The parent module is not supporting


## Pre-Commit hooks

[.pre-commit-config.yaml](.pre-commit-config.yaml) file defines certain `pre-commit` hooks that are relevant to terraform, golang and common linting tasks. There are no custom hooks added.

`commitlint` hook enforces commit message in certain format. The commit contains the following structural elements, to communicate intent to the consumers of your commit messages:

- **fix**: a commit of the type `fix` patches a bug in your codebase (this correlates with PATCH in Semantic Versioning).
- **feat**: a commit of the type `feat` introduces a new feature to the codebase (this correlates with MINOR in Semantic Versioning).
- **BREAKING CHANGE**: a commit that has a footer `BREAKING CHANGE:`, or appends a `!` after the type/scope, introduces a breaking API change (correlating with MAJOR in Semantic Versioning). A BREAKING CHANGE can be part of commits of any type.
footers other than BREAKING CHANGE: <description> may be provided and follow a convention similar to git trailer format.
- **build**: a commit of the type `build` adds changes that affect the build system or external dependencies (example scopes: gulp, broccoli, npm)
- **chore**: a commit of the type `chore` adds changes that don't modify src or test files
- **ci**: a commit of the type `ci` adds changes to our CI configuration files and scripts (example scopes: Travis, Circle, BrowserStack, SauceLabs)
- **docs**: a commit of the type `docs` adds documentation only changes
- **perf**: a commit of the type `perf` adds code change that improves performance
- **refactor**: a commit of the type `refactor` adds code change that neither fixes a bug nor adds a feature
- **revert**: a commit of the type `revert` reverts a previous commit
- **style**: a commit of the type `style` adds code changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc)
- **test**: a commit of the type `test` adds missing tests or correcting existing tests

Base configuration used for this project is [commitlint-config-conventional (based on the Angular convention)](https://github.com/conventional-changelog/commitlint/tree/master/@commitlint/config-conventional#type-enum)

If you are a developer using vscode, [this](https://marketplace.visualstudio.com/items?itemName=joshbolduc.commitlint) plugin may be helpful.

`detect-secrets-hook` prevents new secrets from being introduced into the baseline. TODO: INSERT DOC LINK ABOUT HOOKS

In order for `pre-commit` hooks to work properly

- You need to have the pre-commit package manager installed. [Here](https://pre-commit.com/#install) are the installation instructions.
- `pre-commit` would install all the hooks when commit message is added by default except for `commitlint` hook. `commitlint` hook would need to be installed manually using the command below

```
pre-commit install --hook-type commit-msg
```

## To test the resource group module locally

1. For development/enhancements to this module locally, you'll need to install all of its components. This is controlled by the `configure` target in the project's [`Makefile`](./Makefile). Before you can run `configure`, familiarize yourself with the variables in the `Makefile` and ensure they're pointing to the right places.

```
make configure
```

This adds in several files and directories that are ignored by `git`. They expose many new Make targets.

2. The first target you care about is `env`. This is the common interface for setting up environment variables. The values of the environment variables will be used to authenticate with cloud provider from local development workstation.

`make configure` command will bring down `aws_env.sh` file on local workstation. Developer would need to modify this file, replace the environment variable values with relevant values.

These environment variables are used by `terratest` integration suit.

Then run this make target to set the environment variables on developer workstation.

```
make env
```

3. The first target you care about is `check`.

**Pre-requisites**
Before running this target it is important to ensure that, developer has created files mentioned below on local workstation under root directory of git repository that contains code for primitives/segments. Note that these files are `aws` specific. If primitive/segment under development uses any other cloud provider than AWS, this section may not be relevant.

- A file named `provider.tf` with contents below

```
provider "aws" {
  profile = "<profile_name>"
  region  = "<region_name>"
}
```

- A file named `terraform.tfvars` which contains key value pair of variables used.

Note that since these files are added in `gitignore` they would not be checked in into primitive/segment's git repo.

After creating these files, for running tests associated with the primitive/segment, run

```
make check
```

If `make check` target is successful, developer is good to commit the code to primitive/segment's git repo.

`make check` target

- runs `terraform commands` to `lint`,`validate` and `plan` terraform code.
- runs `conftests`. `conftests` make sure `policy` checks are successful.
- runs `terratest`. This is integration test suit.
- runs `opa` tests

# Know Issues
Currently, the `encrypt at transit` is not supported in terraform. There is an open issue for this logged with Hashicorp - https://github.com/hashicorp/terraform-provider-aws/pull/26987

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0, <= 1.6 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.58.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_resource_names"></a> [resource\_names](#module\_resource\_names) | git::https://github.com/launchbynttdata/tf-launch-module_library-resource_name.git | 1.0.1 |
| <a name="module_sg_alb"></a> [sg\_alb](#module\_sg\_alb) | terraform-aws-modules/security-group/aws | ~> 4.17.1 |
| <a name="module_alb_logs_s3"></a> [alb\_logs\_s3](#module\_alb\_logs\_s3) | terraform-aws-modules/s3-bucket/aws | ~> 3.8.2 |
| <a name="module_alb"></a> [alb](#module\_alb) | terraform-aws-modules/alb/aws | ~> 8.0 |
| <a name="module_alb_dns_record"></a> [alb\_dns\_record](#module\_alb\_dns\_record) | git::https://github.com/launchbynttdata/tf-aws-module_primitive-dns_record | n/a |
| <a name="module_acm"></a> [acm](#module\_acm) | terraform-aws-modules/acm/aws | ~> 4.3.2 |
| <a name="module_sds"></a> [sds](#module\_sds) | git::https://github.com/launchbynttdata/tf-aws-module_primitive-service_discovery_service.git | 1.0.0 |
| <a name="module_private_certs"></a> [private\_certs](#module\_private\_certs) | git::https://github.com/launchbynttdata/tf-aws-module_primitive-acm_private_cert.git | 1.0.0 |
| <a name="module_virtual_gateway"></a> [virtual\_gateway](#module\_virtual\_gateway) | git::https://github.com/launchbynttdata/tf-aws-module_primitive-virtual_gateway.git | 1.0.1 |
| <a name="module_ecs_task_execution_policy"></a> [ecs\_task\_execution\_policy](#module\_ecs\_task\_execution\_policy) | cloudposse/iam-policy/aws | ~> 0.4.0 |
| <a name="module_ecs_task_policy"></a> [ecs\_task\_policy](#module\_ecs\_task\_policy) | cloudposse/iam-policy/aws | ~> 0.4.0 |
| <a name="module_virtual_gateway_container_definition"></a> [virtual\_gateway\_container\_definition](#module\_virtual\_gateway\_container\_definition) | git::https://github.com/cloudposse/terraform-aws-ecs-container-definition.git | tags/0.59.0 |
| <a name="module_sg_ecs_service_vgw"></a> [sg\_ecs\_service\_vgw](#module\_sg\_ecs\_service\_vgw) | terraform-aws-modules/security-group/aws | ~> 4.17.1 |
| <a name="module_virtual_gateway_ecs_service"></a> [virtual\_gateway\_ecs\_service](#module\_virtual\_gateway\_ecs\_service) | cloudposse/ecs-alb-service-task/aws | ~> 0.67.1 |
| <a name="module_ecs_app_heart_beat"></a> [ecs\_app\_heart\_beat](#module\_ecs\_app\_heart\_beat) | git::https://github.com/nexient-llc/tf-aws-wrapper_module-ecs_appmesh_app.git | 0.1.0 |

## Resources

| Name | Type |
|------|------|
| [aws_route53_zone.dns_zone](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_vpc.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_logical_product_family"></a> [logical\_product\_family](#input\_logical\_product\_family) | (Required) Name of the product family for which the resource is created.<br>    Example: org\_name, department\_name. | `string` | `"launch"` | no |
| <a name="input_logical_product_service"></a> [logical\_product\_service](#input\_logical\_product\_service) | (Required) Name of the product service for which the resource is created.<br>    For example, backend, frontend, middleware etc. | `string` | `"backend"` | no |
| <a name="input_class_env"></a> [class\_env](#input\_class\_env) | (Required) Environment where resource is going to be deployed. For example. dev, qa, uat | `string` | `"dev"` | no |
| <a name="input_instance_env"></a> [instance\_env](#input\_instance\_env) | Number that represents the instance of the environment. | `number` | `0` | no |
| <a name="input_instance_resource"></a> [instance\_resource](#input\_instance\_resource) | Number that represents the instance of the resource. | `number` | `0` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS Region in which the infra needs to be provisioned | `string` | `"us-east-2"` | no |
| <a name="input_resource_names_map"></a> [resource\_names\_map](#input\_resource\_names\_map) | A map of key to resource\_name that will be used by tf-launch-module\_library-resource\_name to generate resource names | <pre>map(object(<br>    {<br>      name       = string<br>      max_length = optional(number, 60)<br>    }<br>  ))</pre> | <pre>{<br>  "acm": {<br>    "max_length": 60,<br>    "name": "acm"<br>  },<br>  "alb": {<br>    "max_length": 32,<br>    "name": "alb"<br>  },<br>  "alb_sg": {<br>    "max_length": 60,<br>    "name": "alb-sg"<br>  },<br>  "alb_tg": {<br>    "max_length": 60,<br>    "name": "albtg"<br>  },<br>  "health_check_app_ecs_sg": {<br>    "max_length": 60,<br>    "name": "hc-app-sg"<br>  },<br>  "health_check_ecs_app": {<br>    "max_length": 60,<br>    "name": "hc-svc"<br>  },<br>  "health_check_ecs_td": {<br>    "max_length": 60,<br>    "name": "hc-td"<br>  },<br>  "s3_logs": {<br>    "max_length": 60,<br>    "name": "alblogs"<br>  },<br>  "sds_vg": {<br>    "max_length": 60,<br>    "name": "sds-vg"<br>  },<br>  "task_exec_policy": {<br>    "max_length": 60,<br>    "name": "exec-plcy"<br>  },<br>  "task_policy": {<br>    "max_length": 60,<br>    "name": "task-plcy"<br>  },<br>  "vgw_ecs_app": {<br>    "max_length": 60,<br>    "name": "vgw-svc"<br>  },<br>  "vgw_ecs_sg": {<br>    "max_length": 60,<br>    "name": "vgw-sg"<br>  },<br>  "vgw_ecs_td": {<br>    "max_length": 60,<br>    "name": "vgw-td"<br>  },<br>  "virtual_gateway": {<br>    "max_length": 60,<br>    "name": "vgw"<br>  }<br>}</pre> | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The VPC ID of the VPC where infrastructure will be provisioned | `string` | n/a | yes |
| <a name="input_private_subnets"></a> [private\_subnets](#input\_private\_subnets) | List of private subnets | `list(string)` | n/a | yes |
| <a name="input_public_subnets"></a> [public\_subnets](#input\_public\_subnets) | List of public subnets | `list(string)` | `[]` | no |
| <a name="input_vgw_security_group"></a> [vgw\_security\_group](#input\_vgw\_security\_group) | Security group for the Virtual Gateway ECS application. By default, it allows traffic from ALB on the app\_port | <pre>object({<br>    ingress_rules            = optional(list(string))<br>    ingress_cidr_blocks      = optional(list(string))<br>    ingress_with_cidr_blocks = optional(list(map(string)))<br>    egress_rules             = optional(list(string))<br>    egress_cidr_blocks       = optional(list(string))<br>    egress_with_cidr_blocks  = optional(list(map(string)))<br>    ingress_with_sg          = optional(list(map(string)))<br>    egress_with_sg           = optional(list(map(string)))<br>  })</pre> | `null` | no |
| <a name="input_ecs_cluster_arn"></a> [ecs\_cluster\_arn](#input\_ecs\_cluster\_arn) | ARN of the ECS Cluster where the services are to be created | `string` | n/a | yes |
| <a name="input_app_mesh_id"></a> [app\_mesh\_id](#input\_app\_mesh\_id) | ID of the App Mesh where virtual Gateway is to be created. ID and Name are the same for App Mesh | `string` | n/a | yes |
| <a name="input_namespace_name"></a> [namespace\_name](#input\_namespace\_name) | Name of the Cloud Map namespace to be used for Service Discovery | `string` | n/a | yes |
| <a name="input_namespace_id"></a> [namespace\_id](#input\_namespace\_id) | ID of the Cloud Map namespace to be used for Service Discovery | `string` | n/a | yes |
| <a name="input_load_balancer_type"></a> [load\_balancer\_type](#input\_load\_balancer\_type) | The type of the load balancer. Default is 'application' | `string` | `"application"` | no |
| <a name="input_is_internal"></a> [is\_internal](#input\_is\_internal) | Whether this load balancer is internal or public facing | `bool` | `true` | no |
| <a name="input_alb_sg"></a> [alb\_sg](#input\_alb\_sg) | Security Group for the ALB. https://github.com/terraform-aws-modules/terraform-aws-security-group/blob/master/rules.tf | <pre>object({<br>    description              = optional(string)<br>    ingress_rules            = optional(list(string))<br>    ingress_cidr_blocks      = optional(list(string))<br>    egress_rules             = optional(list(string))<br>    egress_cidr_blocks       = optional(list(string))<br>    ingress_with_cidr_blocks = optional(list(map(string)))<br>    egress_with_cidr_blocks  = optional(list(map(string)))<br>  })</pre> | n/a | yes |
| <a name="input_target_groups"></a> [target\_groups](#input\_target\_groups) | List of target groups for the ALB"<br>    `target_type` can be ip, instance<br>    `health_check` must be set for backend\_protocol=HTTPS.<br>    Valid health\_check attributes are healthy\_threshold, unhealthy\_threshold, path, port, protocol<br>      - protocol must be HTTP, HTTPS etc. | <pre>list(object({<br>    # Need to use name_prefix instead of name as the lifecycle property create_before_destroy is set<br>    name_prefix      = optional(string, "albtg-")<br>    backend_protocol = optional(string)<br>    backend_port     = optional(number)<br>    target_type      = optional(string)<br>    health_check     = optional(map(string), {})<br>  }))</pre> | n/a | yes |
| <a name="input_dns_zone_id"></a> [dns\_zone\_id](#input\_dns\_zone\_id) | Zone ID of the hosted zonee | `string` | `null` | no |
| <a name="input_subject_alternate_names"></a> [subject\_alternate\_names](#input\_subject\_alternate\_names) | Additional domain names to be added to the certificate created for ALB. Domain names must be FQDN. | `list(string)` | `[]` | no |
| <a name="input_dns_zone_name"></a> [dns\_zone\_name](#input\_dns\_zone\_name) | Name of the Route53 DNS Zone where custom DNS records will be created. Required if use\_https\_listeners=true | `string` | `""` | no |
| <a name="input_private_zone"></a> [private\_zone](#input\_private\_zone) | Whether the dns\_zone\_name provided above is a private or public hosted zone. Required if dns\_zone\_name is not empty | `string` | `""` | no |
| <a name="input_idle_timeout"></a> [idle\_timeout](#input\_idle\_timeout) | The time in seconds that the connection is allowed to be idle. | `number` | `60` | no |
| <a name="input_alb_logs_bucket_id"></a> [alb\_logs\_bucket\_id](#input\_alb\_logs\_bucket\_id) | S3 bucket ID for ALB logs | `string` | `""` | no |
| <a name="input_alb_logs_bucket_prefix"></a> [alb\_logs\_bucket\_prefix](#input\_alb\_logs\_bucket\_prefix) | S3 bucket prefix for ALB logs | `string` | `null` | no |
| <a name="input_use_https_listeners"></a> [use\_https\_listeners](#input\_use\_https\_listeners) | Whether to enable HTTPs in the ALB | `bool` | `true` | no |
| <a name="input_listener_ssl_policy_default"></a> [listener\_ssl\_policy\_default](#input\_listener\_ssl\_policy\_default) | The security policy if using HTTPS externally on the load balancer. [See](https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/elb-security-policy-table.html). | `string` | `"ELBSecurityPolicy-TLS13-1-2-2021-06"` | no |
| <a name="input_private_ca_arn"></a> [private\_ca\_arn](#input\_private\_ca\_arn) | ARN of the Private CA. This is used to sign private certificates used in App Mesh. Required when TLS is enabled in App Mesh | `string` | `""` | no |
| <a name="input_tls_enforce"></a> [tls\_enforce](#input\_tls\_enforce) | Whether to enforce TLS in App Mesh Virtual Gateway and services | `bool` | `true` | no |
| <a name="input_vgw_logs_text_format"></a> [vgw\_logs\_text\_format](#input\_vgw\_logs\_text\_format) | The text format. | `string` | `null` | no |
| <a name="input_vgw_tls_mode"></a> [vgw\_tls\_mode](#input\_vgw\_tls\_mode) | The mode for the listener’s Transport Layer Security (TLS) configuration. Must be one of DISABLED, PERMISSIVE, STRICT. | `string` | `"DISABLED"` | no |
| <a name="input_vgw_tls_ports"></a> [vgw\_tls\_ports](#input\_vgw\_tls\_ports) | If you specify a listener port other than 443, you must specify this field. | `list(number)` | `[]` | no |
| <a name="input_vgw_health_check_path"></a> [vgw\_health\_check\_path](#input\_vgw\_health\_check\_path) | The destination path for the health check request. | `string` | `"/"` | no |
| <a name="input_vgw_health_check_protocol"></a> [vgw\_health\_check\_protocol](#input\_vgw\_health\_check\_protocol) | The protocol for the health check request. Must be one of [http http2 grpc]. | `string` | `"http"` | no |
| <a name="input_vgw_listener_port"></a> [vgw\_listener\_port](#input\_vgw\_listener\_port) | The port mapping information for the listener. | `number` | n/a | yes |
| <a name="input_vgw_listener_protocol"></a> [vgw\_listener\_protocol](#input\_vgw\_listener\_protocol) | The protocol for the port mapping. Must be one of [http http2 grpc]. | `string` | `"http"` | no |
| <a name="input_ecs_exec_role_managed_policy_arns"></a> [ecs\_exec\_role\_managed\_policy\_arns](#input\_ecs\_exec\_role\_managed\_policy\_arns) | A Map (ARNs) of AWS managed policies to be attached to the ECS Task Exec role. | `map(string)` | `{}` | no |
| <a name="input_ecs_role_managed_policy_arns"></a> [ecs\_role\_managed\_policy\_arns](#input\_ecs\_role\_managed\_policy\_arns) | A Map (ARNs) of AWS managed policies to be attached to the ECS Task role. | `map(string)` | `{}` | no |
| <a name="input_ecs_exec_role_custom_policy_json"></a> [ecs\_exec\_role\_custom\_policy\_json](#input\_ecs\_exec\_role\_custom\_policy\_json) | Custom policy to attach to ecs task execution role. Document must be valid json. | `string` | `""` | no |
| <a name="input_ecs_role_custom_policy_json"></a> [ecs\_role\_custom\_policy\_json](#input\_ecs\_role\_custom\_policy\_json) | Custom policy to attach to ecs task role. Document must be valid json. | `string` | `""` | no |
| <a name="input_envoy_proxy_image"></a> [envoy\_proxy\_image](#input\_envoy\_proxy\_image) | Optional docker image of the envoy proxy in the format `<docker_image>:<tag>`<br>    Default is `840364872350.dkr.ecr.us-east-2.amazonaws.com/aws-appmesh-envoy:v1.25.4.0-prod` | `string` | `""` | no |
| <a name="input_ecs_launch_type"></a> [ecs\_launch\_type](#input\_ecs\_launch\_type) | The launch type of the ECS service. Default is FARGATE | `string` | `"FARGATE"` | no |
| <a name="input_network_mode"></a> [network\_mode](#input\_network\_mode) | The network\_mode of the ECS service. Default is awsvpc | `string` | `"awsvpc"` | no |
| <a name="input_ignore_changes_task_definition"></a> [ignore\_changes\_task\_definition](#input\_ignore\_changes\_task\_definition) | Lifecycle ignore policy for task definition. If true, terraform won't detect changes when task\_definition is changed outside of terraform | `bool` | `true` | no |
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | If true, public IP will be assigned to this service task, else private IP | `bool` | `false` | no |
| <a name="input_ignore_changes_desired_count"></a> [ignore\_changes\_desired\_count](#input\_ignore\_changes\_desired\_count) | Lifecycle ignore policy for desired\_count. If true, terraform won't detect changes when desired\_count is changed outside of terraform | `bool` | `true` | no |
| <a name="input_task_cpu"></a> [task\_cpu](#input\_task\_cpu) | Amount of CPU to be allocated to the task | `number` | `512` | no |
| <a name="input_task_memory"></a> [task\_memory](#input\_task\_memory) | Amount of Memory to be allocated to the task | `number` | `1024` | no |
| <a name="input_health_check_grace_period_seconds"></a> [health\_check\_grace\_period\_seconds](#input\_health\_check\_grace\_period\_seconds) | Seconds to ignore failing load balancer health checks on newly instantiated tasks to prevent premature shutdown, up to 7200. Only valid for services configured to use load balancers | `number` | `0` | no |
| <a name="input_deployment_minimum_healthy_percent"></a> [deployment\_minimum\_healthy\_percent](#input\_deployment\_minimum\_healthy\_percent) | The lower limit (as a percentage of `desired_count`) of the number of tasks that must remain running and healthy in a service during a deployment | `number` | `100` | no |
| <a name="input_deployment_maximum_percent"></a> [deployment\_maximum\_percent](#input\_deployment\_maximum\_percent) | The upper limit of the number of tasks (as a percentage of `desired_count`) that can be running in a service during a deployment | `number` | `200` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | The number of instances of the task definition to place and keep running | `number` | `1` | no |
| <a name="input_deployment_controller_type"></a> [deployment\_controller\_type](#input\_deployment\_controller\_type) | Type of deployment controller. Valid values are `CODE_DEPLOY` and `ECS` | `string` | `"ECS"` | no |
| <a name="input_wait_for_steady_state"></a> [wait\_for\_steady\_state](#input\_wait\_for\_steady\_state) | If true, it will wait for the service to reach a steady state (like aws ecs wait services-stable) before continuing | `bool` | `false` | no |
| <a name="input_redeploy_on_apply"></a> [redeploy\_on\_apply](#input\_redeploy\_on\_apply) | Redeploys the service everytime a terraform apply is executed. force\_new\_deployment should also be true for this flag to work | `bool` | `false` | no |
| <a name="input_force_new_deployment"></a> [force\_new\_deployment](#input\_force\_new\_deployment) | Enable to force a new task deployment of the service when terraform apply is executed. | `bool` | `false` | no |
| <a name="input_app_task_cpu"></a> [app\_task\_cpu](#input\_app\_task\_cpu) | Amount of CPU to be allocated to the health check app task | `number` | `512` | no |
| <a name="input_app_task_memory"></a> [app\_task\_memory](#input\_app\_task\_memory) | Amount of Memory to be allocated to the health check app task | `number` | `1024` | no |
| <a name="input_app_desired_count"></a> [app\_desired\_count](#input\_app\_desired\_count) | The number of instances of the health check task definition to place and keep running | `number` | `1` | no |
| <a name="input_app_image_tag"></a> [app\_image\_tag](#input\_app\_image\_tag) | Docker image for the heartBeat application, in the format <docker\_image><docker\_tag> | `string` | n/a | yes |
| <a name="input_app_port"></a> [app\_port](#input\_app\_port) | The port at which the health check application is running | `number` | n/a | yes |
| <a name="input_app_security_group"></a> [app\_security\_group](#input\_app\_security\_group) | Security group for the health check ECS application. Need to open ports if one wants to access the heart-beat application manually. | <pre>object({<br>    ingress_rules            = optional(list(string))<br>    ingress_cidr_blocks      = optional(list(string))<br>    ingress_with_cidr_blocks = optional(list(map(string)))<br>    egress_rules             = optional(list(string))<br>    egress_cidr_blocks       = optional(list(string))<br>    egress_with_cidr_blocks  = optional(list(map(string)))<br>  })</pre> | `null` | no |
| <a name="input_match_path_prefix"></a> [match\_path\_prefix](#input\_match\_path\_prefix) | Virtual gateway route path match. Must be same as the ALB health check path | `string` | `"/"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of custom tags to be associated with the resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_resource_names"></a> [resource\_names](#output\_resource\_names) | A map of resource\_name\_types to generated resource names used in this module |
| <a name="output_app_sg_id"></a> [app\_sg\_id](#output\_app\_sg\_id) | The ID of the VPC Endpoint Security Group |
| <a name="output_alb_dns"></a> [alb\_dns](#output\_alb\_dns) | AWS provided DNS record of the ALB |
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | ARN of the ALB |
| <a name="output_alb_id"></a> [alb\_id](#output\_alb\_id) | ID of the ALB |
| <a name="output_alb_sg_id"></a> [alb\_sg\_id](#output\_alb\_sg\_id) | ID of the ALB Security Group |
| <a name="output_alb_https_listener_arns"></a> [alb\_https\_listener\_arns](#output\_alb\_https\_listener\_arns) | ARNs of the HTTPs Listeners attached to the ALB |
| <a name="output_alb_http_listener_arns"></a> [alb\_http\_listener\_arns](#output\_alb\_http\_listener\_arns) | ARNs of the HTTP Listeners attached to the ALB |
| <a name="output_alb_dns_records"></a> [alb\_dns\_records](#output\_alb\_dns\_records) | Custom DNS record for the ALB |
| <a name="output_acm_cert_arn"></a> [acm\_cert\_arn](#output\_acm\_cert\_arn) | ARN of the certificate provisioned for ALB |
| <a name="output_virtual_gateway_arn"></a> [virtual\_gateway\_arn](#output\_virtual\_gateway\_arn) | ARN of the Virtual Gateway |
| <a name="output_virtual_gateway_task_definition_name"></a> [virtual\_gateway\_task\_definition\_name](#output\_virtual\_gateway\_task\_definition\_name) | Revision of the Virtual Gateway ECS app task definition. |
| <a name="output_virtual_gateway_task_definition_version"></a> [virtual\_gateway\_task\_definition\_version](#output\_virtual\_gateway\_task\_definition\_version) | Revision of the Virtual Gateway ECS app task definition. |
| <a name="output_virtual_gateway_name"></a> [virtual\_gateway\_name](#output\_virtual\_gateway\_name) | Name of the Virtual Gateway |
| <a name="output_tls_enforce"></a> [tls\_enforce](#output\_tls\_enforce) | Whether TLS is enforced on the Virtual Gateway. If true, all the Virtual Nodes should also enable TLS |
| <a name="output_heartbeat_app_task_definition_name"></a> [heartbeat\_app\_task\_definition\_name](#output\_heartbeat\_app\_task\_definition\_name) | Task Definition Version of the HeartBeat application |
| <a name="output_heartbeat_app_task_definition_version"></a> [heartbeat\_app\_task\_definition\_version](#output\_heartbeat\_app\_task\_definition\_version) | Task Definition Version of the HeartBeat application |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
