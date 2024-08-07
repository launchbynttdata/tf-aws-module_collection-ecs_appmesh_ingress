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
output "namespace_name" {
  value = module.ecs_platform.namespace_name
}
output "dns_zone_name" {
  value = module.ecs_ingress.dns_zone_name
}
output "dns_zone_id" {
  value = module.ecs_ingress.dns_zone_id
}
output "private_ca_arn" {
  value = module.ecs_ingress.private_ca_arn
}
