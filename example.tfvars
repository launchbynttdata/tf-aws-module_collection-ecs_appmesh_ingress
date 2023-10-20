naming_prefix = "<naming_prefix>"

# VPC and subnets where all the resources will be created
vpc_id          = "<vpc_id>"
private_subnets = ["<list of private_subnets"]

# CloudMap Namespace name
namespace_name = "<cloudmap_namespace_name>"
# ECS cluster ARN where all the services and task definitions will be created
ecs_cluster_arn = "<ecs_cluster_arn>"
# ID of App Mesh already provisioned
app_mesh_id = "<app_mesh_name_or_id>"

# Must allow ingress on 443 and optionally on 80
alb_sg = {
  description         = "Security group for ALB"
  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_with_cidr_blocks = [
    {
      from_port = 443
      to_port   = 443
      protocol  = "tcp"
    },
    {
      from_port = 80
      to_port   = 80
      protocol  = "tcp"
    }
  ]
  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}

# Should be always true
use_https_listeners = true
# Public hosted zone in the respective AWS account
dns_zone_name = "<public_host_zone_name>"
# Should be public as current requirement
private_zone = false

target_groups = [
  {
    backend_protocol = "https"
    backend_port     = 443
    target_type      = "ip"
    health_check = {
      # Port must be same as vgw ecs service app port and vgw listener and health check port, preferrably 443
      port = "<https_port>"
      # path must be same as gateway route `match_path_prefix`
      path                = "/<path>"
      healthy_threshold   = 5
      unhealthy_threshold = 2
      protocol            = "HTTPS"
    }
  }
]

# ARN for the Private CA to sign the private certs
private_ca_arn = "<private_ca_arn>"

# Virtual gateway
# tls is always enforced
tls_enforce               = true
vgw_health_check_path     = "/"
vgw_health_check_protocol = "http"

vgw_listener_port     = 443
vgw_listener_protocol = "http"

vgw_tls_mode = "<STRICT or PERMISSIVE>"
# List of ports if other than 443 are used
vgw_tls_ports        = []
vgw_logs_text_format = <<-EOF
[%START_TIME%] "%REQ(:METHOD)% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)% %PROTOCOL%" %RESPONSE_CODE% %RESPONSE_FLAGS% %BYTES_RECEIVED% %BYTES_SENT% %DURATION% %RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)% "%REQ(X-FORWARDED-FOR)%" "%REQ(USER-AGENT)%" "%REQ(X-REQUEST-ID)%" "%REQ(:AUTHORITY)%" "%UPSTREAM_HOST%"
EOF
# Health check service application port
app_port = "<health_check_app_port>"

# ECS

# Must allow ingress on vgw_listener_port and envoy_proxy port for stats
vgw_security_group = {
  egress_rules        = ["all-all"]
  egress_cidr_blocks  = ["0.0.0.0/0"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_with_cidr_blocks = [
    {
      # envoy stats port
      from_port = 9901
      to_port   = 9901
      protocol  = "tcp"
    },
    {
      # vgw listener port
      from_port = 443
      to_port   = 443
      protocol  = "tcp"
    }
  ]
}

# docker image for http health check
app_image_tag = "<health_check_app_docker_image_tag>"
# must be same as ALB target group health check path
match_path_prefix = "/<path>"

# must allow ingress on app_port
app_security_group = {
  egress_rules        = ["all-all"]
  egress_cidr_blocks  = ["0.0.0.0/0"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_with_cidr_blocks = [
    {
      from_port = 9081
      to_port   = 9081
      protocol  = "tcp"
    }
  ]
}
