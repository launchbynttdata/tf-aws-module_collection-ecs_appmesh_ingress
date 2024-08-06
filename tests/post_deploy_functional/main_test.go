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

package main

import (
	"testing"

	"github.com/launchbynttdata/lcaf-component-terratest/lib"
	"github.com/launchbynttdata/lcaf-component-terratest/types"
	testimpl "github.com/launchbynttdata/tf-aws-module_collection-ecs_appmesh_ingress/tests/testimpl"
)

const (
	testConfigsExamplesFolderDefault = "../../examples"
	infraTFVarFileNameDefault        = "test.tfvars"
)

func TestAppmeshIngressModule(t *testing.T) {
	// The terraform provider ignores the aws cloud map attributes, but notices when AWS changes them from null to empty map
	// This is why the terraform apply is not idempotent, though the second apply will not change anything
	ctx := types.CreateTestContextBuilder().
		SetTestConfig(&testimpl.ThisTFModuleConfig{}).
		SetTestConfigFolderName(testConfigsExamplesFolderDefault).
		SetTestConfigFileName(infraTFVarFileNameDefault).
/*		SetTestSpecificFlags(map[string]types.TestFlags{
			"with_tls_enforced": {
				"IS_TERRAFORM_IDEMPOTENT_APPLY": false,
			},
		}).
*/
		Build()

	lib.RunSetupTestTeardown(t, *ctx, testimpl.TestComposableComplete)
}
