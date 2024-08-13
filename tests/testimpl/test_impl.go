package common

import (
        "context"
        "strings"
        "testing"
        "github.com/aws/aws-sdk-go-v2/aws"
        "github.com/aws/aws-sdk-go-v2/config"
        "github.com/aws/aws-sdk-go-v2/service/acm"
        //"github.com/aws/aws-sdk-go-v2/service/acmpca"
        "github.com/aws/aws-sdk-go-v2/service/appmesh"
        "github.com/aws/aws-sdk-go-v2/service/ec2"
        "github.com/aws/aws-sdk-go-v2/service/elasticloadbalancingv2"
        //"github.com/aws/aws-sdk-go-v2/service/route53"
        "github.com/aws/aws-sdk-go-v2/service/servicediscovery"
        "github.com/gruntwork-io/terratest/modules/terraform"
        "github.com/launchbynttdata/lcaf-component-terratest/types"
        "github.com/stretchr/testify/require"
)

const expectedAlbState           = "active"
const expectedCertStatus         = "ISSUED"
const expectedEnableDnsHostnames = true
const expectedEnableDnsSupport   = true
//const expectedPcaStatus          = "ACTIVE"
const expectedTlsMode            = "STRICT"
const expectedVgwStatus          = "ACTIVE"

// See https://dev.azure.com/launch-dso/platform-accelerators/_workitems/edit/172 for details on commented out portions

func TestComposableComplete(t *testing.T, ctx types.TestContext) {
	albArn        := terraform.Output(t, ctx.TerratestTerraformOptions(), "alb_arn")
	//albDns        := terraform.Output(t, ctx.TerratestTerraformOptions(), "alb_dns")
	albCertArn    := terraform.Output(t, ctx.TerratestTerraformOptions(), "alb_cert_arn")
	appMeshId     := terraform.Output(t, ctx.TerratestTerraformOptions(), "app_mesh_id")
	//dnsZoneId     := terraform.Output(t, ctx.TerratestTerraformOptions(), "dns_zone_id")
	//dnsZoneName   := terraform.Output(t, ctx.TerratestTerraformOptions(), "dns_zone_name")
	namespaceId   := terraform.Output(t, ctx.TerratestTerraformOptions(), "namespace_id")
	namespaceName := terraform.Output(t, ctx.TerratestTerraformOptions(), "namespace_name")
	//privateCaArn  := terraform.Output(t, ctx.TerratestTerraformOptions(), "private_ca_arn")
	vgwArn        := terraform.Output(t, ctx.TerratestTerraformOptions(), "virtual_gateway_arn")
	vgwCertArn    := terraform.Output(t, ctx.TerratestTerraformOptions(), "virtual_gateway_cert_arn")
	vgwName       := terraform.Output(t, ctx.TerratestTerraformOptions(), "virtual_gateway_name")
	vpcId         := terraform.Output(t, ctx.TerratestTerraformOptions(), "vpc_id")


        ec2Client := GetAWSEc2Client(t)
        t.Run("TestDoesVPCSupportDNS", func(t *testing.T) {
		output, err := ec2Client.DescribeVpcAttribute(context.TODO(), &ec2.DescribeVpcAttributeInput{VpcId: &vpcId, Attribute: "enableDnsSupport"})
                if err != nil {
                        t.Errorf("Error describing VPC attribute: %v", err)
		}
                RequireEqualBool(t, expectedEnableDnsSupport, *output.EnableDnsSupport.Value, "VPC enableDnsSupport")
        })
        t.Run("TestDoesVPCSupportDNSHostnames", func(t *testing.T) {
		output, err := ec2Client.DescribeVpcAttribute(context.TODO(), &ec2.DescribeVpcAttributeInput{VpcId: &vpcId, Attribute: "enableDnsHostnames"})
                if err != nil {
                        t.Errorf("Error describing VPC attribute: %v", err)
		}
                RequireEqualBool(t, expectedEnableDnsHostnames, *output.EnableDnsHostnames.Value, "VPC enableDnsHostnames")
        })


        appmeshClient := GetAWSAppmeshClient(t)
        t.Run("TestAppmeshExists", func(t *testing.T) {
		output, err := appmeshClient.DescribeMesh(context.TODO(), &appmesh.DescribeMeshInput{MeshName: &appMeshId})
                if err != nil {
                        t.Errorf("Error describing mesh: %v", err)
		}
                RequireEqualString(t, appMeshId, *output.Mesh.MeshName, "mesh name/mesh id")
        })
        t.Run("TestVirtualGateway", func(t *testing.T) {
		output, err := appmeshClient.DescribeVirtualGateway(context.TODO(), &appmesh.DescribeVirtualGatewayInput{MeshName: &appMeshId, VirtualGatewayName: &vgwName})
                if err != nil {
                        t.Errorf("Error describing virtual gateway: %v", err)
		}
		vgw := *output.VirtualGateway
                RequireEqualString(t, expectedVgwStatus, string(vgw.Status.Status), "virtual gateway status")
		RequireEqualString(t, vgwName, *vgw.VirtualGatewayName, "virtual gateway name")
		RequireEqualString(t, vgwArn, *vgw.Metadata.Arn, "virtual gateway ARN")
		tls := vgw.Spec.Listeners[0].Tls
                RequireEqualString(t, expectedTlsMode, string(tls.Mode), "virtual gateway listener TLS mode")
	})

        /* acmpcaClient := GetAWSAcmpcaClient(t)
        t.Run("TestACMPCAActive", func(t *testing.T) {
		output, err := acmpcaClient.DescribeCertificateAuthority(context.TODO(), &acmpca.DescribeCertificateAuthorityInput{CertificateAuthorityArn: &privateCaArn})
                if err != nil {
                        t.Errorf("Error describing ACM PCA (%s): %v", privateCaArn, err)
		}
		ca := *output.CertificateAuthority
                RequireEqualString(t, privateCaArn, *ca.Arn, "wtf ACM private CA ARN")
                RequireEqualString(t, expectedPcaStatus, string(ca.Status), "wtf ACM private CA status")
        }) */


        acmClient := GetAWSAcmClient(t)
        t.Run("TestALBCert", func(t *testing.T) {
		output, err := acmClient.DescribeCertificate(context.TODO(), &acm.DescribeCertificateInput{CertificateArn: &albCertArn})
		if err != nil {
			t.Errorf("Error describing ALB certificate: %v", err)
		}
		certificate := *output.Certificate
                RequireEqualString(t, albCertArn, *certificate.CertificateArn, "ALB Cert ARN")
                //RequireEqualString(t, privateCaArn, *certificate.CertificateAuthorityArn, "issuing CA for ALB Cert")
                RequireEqualString(t, expectedCertStatus, string(certificate.Status), "ALB Cert status")
        })
        t.Run("TestVGWCert", func(t *testing.T) {
		output, err := acmClient.DescribeCertificate(context.TODO(), &acm.DescribeCertificateInput{CertificateArn: &vgwCertArn})
                if err != nil {
                        t.Errorf("Error describing virtual gateway certificate: %v", err)
		}
		certificate := *output.Certificate
                RequireEqualString(t, vgwCertArn, *certificate.CertificateArn, "VGW Cert ARN")
                //RequireEqualString(t, privateCaArn, *certificate.CertificateAuthorityArn, "issuing CA for VGW Cert")
                RequireEqualString(t, expectedCertStatus, string(certificate.Status), "VGW Cert status")
        })


	sdsClient := GetAWSServicediscoveryClient(t)
        t.Run("TestSDSNamespace", func(t *testing.T) {
		output, err := sdsClient.GetNamespace(context.TODO(), &servicediscovery.GetNamespaceInput{Id: &namespaceId})
                if err != nil {
                        t.Errorf("Error getting namespace for service discovery: %v", err)
		}
                RequireEqualString(t, namespaceName, *output.Namespace.Name, "namespace name")
                require.Equal(t, *output.Namespace.Name, strings.ToLower(*output.Namespace.Name), "Namespace is using mixed case, expected all lower case")
        })


        /*route53Client := GetAWSRoute53Client(t)
	t.Run("TestHostedZone", func(t *testing.T) {
		output, err := route53Client.GetHostedZone(context.TODO(), &route53.GetHostedZoneInput{Id: &dnsZoneId})
                if err != nil {
                        t.Errorf("Error getting DNS hosted zone: %v", err)
		}
                require.Equal(t, *output.HostedZone.Name, strings.ToLower(*output.HostedZone.Name), "Hosted zone name is using mixed case, expected all lower case")
                RequireEqualString(t, dnsZoneName, *output.HostedZone.Name, "DNS hosted zone name")
		require.Contains(t, output.VPCs, vpcId, "VPC id %s is not associated with hosted zone %s (%s)", vpcId, dnsZoneName, dnsZoneId)
        })
	t.Run("TestALBDNSRecord", func(t *testing.T) {
		output, err := route53Client.ListResourceRecordSets(context.TODO(), &route53.ListResourceRecordSetsInput{HostedZoneId: &dnsZoneId, StartRecordName: &albDns, StartRecordType: "A"})
                if err != nil {
                        t.Errorf("Error listing records for DNS hosted zone: %v", err)
		}
                require.Equal(t, albDns, strings.ToLower(albDns), "ALB DNS record is using mixed case, expected all lower case")
		//  When listing w/ both record name and record type as inputs, it will be the first record set returned, if found
		require.Equal(t, output.ResourceRecordSets[0].Name, albDns, "ALB DNS record %s was not found in hosted zone %s (%s)", albDns, dnsZoneName, dnsZoneId)
        })*/


        elbv2Client := GetAWSElbv2Client(t)
	t.Run("TestALB", func(t *testing.T) {
		output, err := elbv2Client.DescribeLoadBalancers(context.TODO(), &elasticloadbalancingv2.DescribeLoadBalancersInput{LoadBalancerArns: []string{albArn}})
                if err != nil {
                        t.Errorf("Error describing alb: %v", err)
		}
		loadBalancers := output.LoadBalancers
		require.Equal(t, 1, len(loadBalancers), "Expected exactly 1 ALB with the ARN %s", albArn)
                RequireEqualString(t, albArn, *loadBalancers[0].LoadBalancerArn, "ALB ARN")
		RequireEqualString(t, vpcId, *loadBalancers[0].VpcId, "ALB VPC ID")
		RequireEqualString(t, expectedAlbState, string(loadBalancers[0].State.Code), "ALB state")
        })
}


func RequireEqualString(t *testing.T, expected string, actual string, resource_type string) {
        require.Equal(t, expected, actual, "Expected %s to be %s, but got %s", resource_type, expected, actual)
}

func RequireEqualBool(t *testing.T, expected bool, actual bool, resource_type string) {
        require.Equal(t, expected, actual, "Expected %s to be %s, but got %s", resource_type, expected, actual)
}

func GetAWSAcmClient(t *testing.T) *acm.Client {
        awsAcmClient := acm.NewFromConfig(GetAWSConfig(t))
        return awsAcmClient
}

/* func GetAWSAcmpcaClient(t *testing.T) *acmpca.Client {
        awsAcmpcaClient := acmpca.NewFromConfig(GetAWSConfig(t))
        return awsAcmpcaClient
} */

func GetAWSAppmeshClient(t *testing.T) *appmesh.Client {
        awsAppmeshClient := appmesh.NewFromConfig(GetAWSConfig(t))
        return awsAppmeshClient
}

func GetAWSEc2Client(t *testing.T) *ec2.Client {
        awsEc2Client := ec2.NewFromConfig(GetAWSConfig(t))
        return awsEc2Client
}

func GetAWSElbv2Client(t *testing.T) *elasticloadbalancingv2.Client {
        awsElbv2Client := elasticloadbalancingv2.NewFromConfig(GetAWSConfig(t))
        return awsElbv2Client
}

/* func GetAWSRoute53Client(t *testing.T) *route53.Client {
        awsRoute53Client := route53.NewFromConfig(GetAWSConfig(t))
        return awsRoute53Client
} */

func GetAWSServicediscoveryClient(t *testing.T) *servicediscovery.Client {
        awsServicediscoveryClient := servicediscovery.NewFromConfig(GetAWSConfig(t))
        return awsServicediscoveryClient
}

func GetAWSConfig(t *testing.T) (cfg aws.Config) {
        cfg, err := config.LoadDefaultConfig(context.TODO())
        require.NoErrorf(t, err, "unable to load SDK config, %v", err)
        return cfg
}
