# This variables file creates a public ingress with tls enabled in the provided DNS zone
# The appmesh is configured to not use tls for service-to-service communication. This is useful when users dont have access
# to private CA instance to generate certificates for appmesh
# Before using this file, update all the fields with <> with correct values for your installation.

logical_product_family  = "launch"
logical_product_service = "int-ing"
instance_env            = 0
class_env               = "sandbox"

vpc_id = "<vpc-ic>"
private_subnets = [
  " <list-of-private-subnets>"
]

public_subnets = [
  "<list-of-public-subnets>"
]

is_internal = false

vgw_listener_port    = 80
vgw_logs_text_format = <<-EOF
[%START_TIME%] "%REQ(:METHOD)% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)% %PROTOCOL%" %RESPONSE_CODE% %RESPONSE_FLAGS% %BYTES_RECEIVED% %BYTES_SENT% %DURATION% %RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)% "%REQ(X-FORWARDED-FOR)%" "%REQ(USER-AGENT)%" "%REQ(X-REQUEST-ID)%" "%REQ(:AUTHORITY)%" "%UPSTREAM_HOST%"
EOF

namespace_name  = "<cloud-map-ns-name>"
namespace_id    = "<cloud-map-ns-id>"
ecs_cluster_arn = "<ecs-cluster-arn>"
app_mesh_id     = "<app-mesh-name/id>"
# If this is in another account, then IAM policy must be assigned to the PCA to allow access from this account
# not required when tls_enforce is false
# private_ca_arn = ""
alb_sg = {
  description         = "Allow traffic from everywhere on 80 and 443"
  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  egress_cidr_blocks  = ["0.0.0.0/0"]
  egress_rules        = ["all-all"]
}
target_groups = [
  {
    backend_protocol = "http"
    backend_port     = 80
    target_type      = "ip"
    health_check = {
      port                = 80
      path                = "/health"
      healthy_threshold   = 5
      unhealthy_threshold = 2
      protocol            = "HTTP"
    }
  }
]
dns_zone_name = "<dns-zone-name>"
# public dns
private_zone            = false
subject_alternate_names = ["<additional-names-on-the-alb-cert>>"]
# The heartbeat app must be running on port > 1000 (appmesh requirement)
app_port = "<app-port>"

vgw_security_group = {
  ingress_rules       = ["http-8080-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules        = ["all-all"]
  egress_cidr_blocks  = ["0.0.0.0/0"]
}
force_new_deployment              = true
redeploy_on_apply                 = true
ignore_changes_desired_count      = false
ignore_changes_task_definition    = false
health_check_grace_period_seconds = 120
wait_for_steady_state             = false
task_cpu                          = 512
task_memory                       = 1024
desired_count                     = 1
#alb_logs_bucket_id                = ""
idle_timeout = 300

# Health check application

# To pull public image, NAT gateway must be configured and associated with private subnets
app_image_tag = "<app-image-in-ecr>"
app_environment = {

}
match_path_prefix = "/health"

app_security_group = {
  ingress_rules       = ["http-8080-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules        = ["all-all"]
  egress_cidr_blocks  = ["0.0.0.0/0"]
}
app_desired_count = 1

tags = {}

use_https_listeners       = true
tls_enforce               = false
vgw_health_check_path     = "/"
vgw_health_check_protocol = "http"
vgw_tls_mode              = "STRICT"
vgw_tls_ports             = []
app_task_cpu              = 512
app_task_memory           = 1024

additional_cnames = ["<vanity-url-if-any>"]
