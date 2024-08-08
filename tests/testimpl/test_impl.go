package common

import (
        "context"
        "testing"

        "github.com/aws/aws-sdk-go-v2/aws"
        "github.com/aws/aws-sdk-go-v2/config"
        "github.com/aws/aws-sdk-go-v2/service/acmpca"
        "github.com/aws/aws-sdk-go-v2/service/appmesh"
        "github.com/aws/aws-sdk-go-v2/service/ec2"
        "github.com/aws/aws-sdk-go-v2/service/servicediscovery"
        "github.com/gruntwork-io/terratest/modules/terraform"
        "github.com/launchbynttdata/lcaf-component-terratest/types"
        "github.com/stretchr/testify/require"
)

const expectedPcaStatus          = "ACTIVE"
const expectedVgwStatus          = "ACTIVE"
const expectedTlsMode            = "STRICT"
const expectedEnableDnsHostnames = true
const expectedEnableDnsSupport   = true


func TestComposableComplete(t *testing.T, ctx types.TestContext) {
        acmpcaClient  := GetAWSAcmpcaClient(t)
        appmeshClient := GetAWSAppmeshClient(t)
        ec2Client     := GetAWSEc2Client(t)
        sdsClient     := GetAWSServicediscoveryClient(t)

	vpcId         := terraform.Output(t, ctx.TerratestTerraformOptions(), "vpc_id")
	appMeshId     := terraform.Output(t, ctx.TerratestTerraformOptions(), "app_mesh_id")
	privateCaArn  := terraform.Output(t, ctx.TerratestTerraformOptions(), "private_ca_arn")
        vgwArn        := terraform.Output(t, ctx.TerratestTerraformOptions(), "virtual_gateway_arn")
        vgwName       := terraform.Output(t, ctx.TerratestTerraformOptions(), "virtual_gateway_name")
	namespaceName := terraform.Output(t, ctx.TerratestTerraformOptions(), "namespace_name")
	namespaceId   := terraform.Output(t, ctx.TerratestTerraformOptions(), "namespace_id")
/*	dnsZoneName   := terraform.Output(t, ctx.TerratestTerraformOptions(), "dns_zone_name")
	dnsZoneId     := terraform.Output(t, ctx.TerratestTerraformOptions(), "dns_zone_id")
	albDns        := terraform.Output(t, ctx.TerratestTerraformOptions(), "alb_dns")
	albArn        := terraform.Output(t, ctx.TerratestTerraformOptions(), "alb_arn")
	albId         := terraform.Output(t, ctx.TerratestTerraformOptions(), "alb_id")
        albCertArn    := terraform.Output(t, ctx.TerratestTerraformOptions(), "alb_cert_arn")
        vgwCertArn    := terraform.Output(t, ctx.TerratestTerraformOptions(), "virtual_gateway_cert_arn")
*/

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
                //RequireEqualString(t, expectedVgwStatus, string(vgw.Status), "virtual gateway status")
		RequireEqualString(t, vgwName, *vgw.VirtualGatewayName, "virtual gateway name")
		RequireEqualString(t, vgwArn, *vgw.Metadata.Arn, "virtual gateway ARN")
		tls := vgw.Spec.Listeners[0].Tls
                RequireEqualString(t, expectedTlsMode, string(tls.Mode), "virtual gateway listener TLS mode")
	})

        t.Run("TestACMPCAActive", func(t *testing.T) {
		output, err := acmpcaClient.DescribeCertificateAuthority(context.TODO(), &acmpca.DescribeCertificateAuthorityInput{CertificateAuthorityArn: &privateCaArn})
                if err != nil {
                        t.Errorf("Error describing ACM PCA: %v", err)
    		}
		ca := *output.CertificateAuthority
                RequireEqualString(t, privateCaArn, *ca.Arn, "ACM private CA ARN")
                RequireEqualString(t, expectedPcaStatus, string(ca.Status), "ACM private CA status")
        })

        t.Run("TestSDSNamespace", func(t *testing.T) {
		output, err := sdsClient.GetNamespace(context.TODO(), &servicediscovery.GetNamespaceInput{Id: &namespaceId})
                if err != nil {
                        t.Errorf("Error getting namespace for service discovery: %v", err)
    		}
                RequireEqualString(t, namespaceName, *output.Namespace.Name, "namespace name")
        })
}


func RequireEqualString(t *testing.T, expected string, actual string, resource_type string) bool {
        require.Equal(t, expected, actual, "Expected %s to be %s, but got %s", resource_type, expected, actual)
        return true
}

func RequireEqualBool(t *testing.T, expected bool, actual bool, resource_type string) bool {
        require.Equal(t, expected, actual, "Expected %s to be %s, but got %s", resource_type, expected, actual)
        return true
}

func GetAWSAcmpcaClient(t *testing.T) *acmpca.Client {
        awsAcmpcaClient := acmpca.NewFromConfig(GetAWSConfig(t))
        return awsAcmpcaClient
}

func GetAWSAppmeshClient(t *testing.T) *appmesh.Client {
        awsAppmeshClient := appmesh.NewFromConfig(GetAWSConfig(t))
        return awsAppmeshClient
}

func GetAWSEc2Client(t *testing.T) *ec2.Client {
        awsEc2Client := ec2.NewFromConfig(GetAWSConfig(t))
        return awsEc2Client
}

func GetAWSServicediscoveryClient(t *testing.T) *servicediscovery.Client {
        awsServicediscoveryClient := servicediscovery.NewFromConfig(GetAWSConfig(t))
        return awsServicediscoveryClient
}

func GetAWSConfig(t *testing.T) (cfg aws.Config) {
        cfg, err := config.LoadDefaultConfig(context.TODO())
        require.NoErrorf(t, err, "unable to load SDK config, %v", err)
        return cfg
}
