# Need to fill the properties within <> like dns_zone_id, private_ca_arn, dns_zone_name, private_zone, app_image_tag, app_port
# These above variables are made required so that the user must enter those

interface_vpc_endpoints = {
  ecrdkr = {
    service_name        = "ecr.dkr"
    private_dns_enabled = true
  }
  ecrapi = {
    service_name        = "ecr.api"
    private_dns_enabled = true
  }
  ecs = {
    service_name        = "ecs"
    private_dns_enabled = true
  }
  logs = {
    service_name        = "logs"
    private_dns_enabled = true
  }
  appmeshenvoymgmt = {
    service_name        = "appmesh-envoy-management"
    private_dns_enabled = true
  }
  appmesh = {
    service_name        = "appmesh"
    private_dns_enabled = true
  }
}

gateway_vpc_endpoints = {
  s3 = {
    service_name        = "s3"
    private_dns_enabled = true
  }
}

vpce_security_group = {
  ingress_rules       = ["https-443-tcp", "http-80-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules        = ["all-all"]
  egress_cidr_blocks  = ["0.0.0.0/0"]
}

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

#dns_zone_id and dns_zone_id must refer to the same zone and the zone cannot be one which is managed by Cloud Map
dns_zone_id = "<dns_zone_id>"
#dns_zone_name should be tied to a real domain known to Route 53
dns_zone_name = "<dns_zone_name>"
private_zone  = "<private_zone>" # bool

force_new_deployment              = true
health_check_grace_period_seconds = 120

private_ca_arn = "arn:aws:acm-pca:us-east-2:020127659860:certificate-authority/aae3aa9a-a2d0-42ac-a16b-0fc6d54b109c"

# Virtual gateway

vgw_security_group = {
  egress_rules        = ["all-all"]
  egress_cidr_blocks  = ["0.0.0.0/0"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_with_cidr_blocks = [
    {
      from_port = 9901
      to_port   = 9901
      protocol  = "tcp"
    },
    {
      from_port = 443
      to_port   = 443
      protocol  = "tcp"
    }
  ]
}

app_image_tag = "<app_image_tag>"
app_port      = "<app_port>" # number

app_security_group = {
  egress_rules        = ["all-all"]
  egress_cidr_blocks  = ["0.0.0.0/0"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_with_cidr_blocks = [
    {
      from_port = 8080
      to_port   = 8080
      protocol  = "tcp"
    }
  ]
}
