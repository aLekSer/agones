// Copyright 2020 Google LLC All Rights Reserved.
//
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

package test

import (
	"flag"
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

var project string

func TestTerraformGKEInstallConfig(t *testing.T) {
	fmt.Println(project)
	terraformOptions := &terraform.Options{
		TerraformDir: "../../build/terraform/gke/",
		Vars: map[string]interface{}{
			"project":     project,
			"name":        "terratest-cluster",
			"values_file": "",
		},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	output := terraform.Output(t, terraformOptions, "host")
	assert.Contains(t, output, "https://")
}

func TestMain(m *testing.M) {
	projectFlag := flag.String("project", "agones", "name of the proejct")
	flag.Parse()
	project = *projectFlag
	m.Run()
}
