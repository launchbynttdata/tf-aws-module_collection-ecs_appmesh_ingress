package common

import (
        "context"
        "testing"

        "github.com/aws/aws-sdk-go-v2/aws"
        "github.com/aws/aws-sdk-go-v2/config"
        "github.com/aws/aws-sdk-go-v2/service/acmpca"
        "github.com/aws/aws-sdk-go-v2/service/appmesh"
        "github.com/aws/aws-sdk-go-v2/service/ec2"
        "github.com/gruntwork-io/terratest/modules/terraform"
        "github.com/launchbynttdata/lcaf-component-terratest/types"
        "github.com/stretchr/testify/require"
)


func TestComposableComplete(t *testing.T, ctx types.TestContext) {
        acmpcaClient := GetAWSAcmpcaClient(t)
        appmeshClient := GetAWSAppmeshClient(t)
        ec2Client := GetAWSEc2Client(t)

	vpcId := terraform.Output(t, ctx.TerratestTerraformOptions(), "vpc_id")
	appMeshId := terraform.Output(t, ctx.TerratestTerraformOptions(), "app_mesh_id")
	vgwName := terraform.Output(t, ctx.TerratestTerraformOptions(), "virtual_gateway_name")
	vgwCaArn := terraform.Output(t, ctx.TerratestTerraformOptions(), "virtual_gateway_cert_arn")

	expectedTlsMode := "STRICT"


        t.Run("TestDoesVPCSupportDNS", func(t *testing.T) {
		output, err := ec2Client.DescribeVpcAttribute(context.TODO(), &ec2.DescribeVpcAttributeInput{VpcId: &vpcId, Attribute: "enableDnsSupport"})
                if err != nil {
                        t.Errorf("Error describing VPC attribute: %v", err)
    		}
                RequireEqualBool(t, true, *output.EnableDnsSupport.Value, "VPC enableDnsSupport")
        })
        t.Run("TestDoesVPCSupportDNSHostnames", func(t *testing.T) {
		output, err := ec2Client.DescribeVpcAttribute(context.TODO(), &ec2.DescribeVpcAttributeInput{VpcId: &vpcId, Attribute: "enableDnsHostnames"})
                if err != nil {
                        t.Errorf("Error describing VPC attribute: %v", err)
    		}
                RequireEqualBool(t, true, *output.EnableDnsHostnames.Value, "VPC enableDnsHostnames")
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
                RequireEqualString(t, vgwName, *output.VirtualGateway.VirtualGatewayName, "virtual gateway name")
		tls := *output.VirtualGateway.Spec.Listeners[0].Tls
                RequireEqualString(t, expectedTlsMode, string(tls.Mode), "virtual gateway listener TLS mode")
        })

        t.Run("TestACMPCAActive", func(t *testing.T) {
		output, err := acmpcaClient.DescribeCertificateAuthority(context.TODO(), &acmpca.DescribeCertificateAuthorityInput{CertificateAuthorityArn: &vgwCaArn})
                if err != nil {
                        t.Errorf("Error describing ACM PCA: %v", err)
    		}
		ca := *output.CertificateAuthority
                RequireEqualString(t, vgwCaArn, *ca.Arn, "ACM private CA ARN")
                RequireEqualString(t, "ACTIVE", string(ca.Status), "ACM private CA status")
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

func GetAWSConfig(t *testing.T) (cfg aws.Config) {
        cfg, err := config.LoadDefaultConfig(context.TODO())
        require.NoErrorf(t, err, "unable to load SDK config, %v", err)
        return cfg
}
