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
output "vpc_id" {
  value = module.vpc.vpc_id
}
output "app_mesh_id" {
  value = module.ecs_platform.app_mesh_id
}
output "virtual_gateway_name" {
  value = module.ecs_ingress.virtual_gateway_name
}
output "virtual_gateway_arn" {
  value = module.ecs_ingress.virtual_gateway_arn
}
output "virtual_gateway_cert_arn" {
  value = module.ecs_ingress.virtual_gateway_cert_arn
}
#output "private_ca_arn" {
#  value = module.ecs_ingress.private_ca_arn
#}
output "alb_dns" {
  value = module.ecs_ingress.alb_dns
}
output "alb_id" {
  value = module.ecs_ingress.alb_id
}
