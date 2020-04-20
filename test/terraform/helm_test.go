package test

import (
	"fmt"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	appsv1 "k8s.io/api/apps/v1"
	"k8s.io/apiextensions-apiserver/pkg/apis/apiextensions"

	"github.com/gruntwork-io/terratest/modules/helm"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/random"
)

// This file contains examples of how to use terratest to test helm chart template logic by rendering the templates
// using `helm template`, and then reading in the rendered templates.
// There are two tests:
// - TestHelmBasicExampleTemplateRenderedDeployment: An example of how to read in the rendered object and check the
//   computed values.
// - TestHelmBasicExampleTemplateRequiredTemplateArgs: An example of how to check that the required args are indeed
//   required for the template to render.

// An example of how to verify the rendered template object of a Helm Chart given various inputs.
func TestHelmBasicExampleTemplateRenderedDeployment(t *testing.T) {
	t.Parallel()

	// Path to the helm chart we will test
	helmChartPath, err := filepath.Abs("../../install/helm/agones/")
	releaseName := "helm-basic"
	require.NoError(t, err)

	// Since we aren't deploying any resources, there is no need to setup kubectl authentication or helm home.

	// Set up the namespace; confirm that the template renders the expected value for the namespace.
	namespaceName := "medieval-" + strings.ToLower(random.UniqueId())
	logger.Logf(t, "Namespace: %s\n", namespaceName)

	// Setup the args. For this test, we will set the following input values:
	// - containerImageRepo=nginx
	// - containerImageTag=1.15.8
	options := &helm.Options{
		SetValues: map[string]string{
			"agones.metrics.prometheusEnabled": "true",
			"agones.crds.install":              "true",
			"agones.image.tag":                 "1.6.0",
			"fullnameOverride":                 strings.Repeat("a", 64),
		},
		KubectlOptions: k8s.NewKubectlOptions("", "", namespaceName),
	}
	options.SetValues["agones.controller.http.port"] = "90000"

	// Run RenderTemplate to render the template and capture the output. Note that we use the version without `E`, since
	// we want to assert that the template renders without any errors.
	// Additionally, although we know there is only one yaml file in the template, we deliberately path a templateFiles
	// arg to demonstrate how to select individual templates to render.
	output := helm.RenderTemplate(t, options, helmChartPath, releaseName, []string{"templates/controller.yaml"})

	// Now we use kubernetes/client-go library to render the template output into the Deployment struct. This will
	// ensure the Deployment resource is rendered correctly.
	var deployment appsv1.Deployment
	helm.UnmarshalK8SYaml(t, output, &deployment)

	// Verify the namespace matches the expected supplied namespace.
	assert.Equal(t, namespaceName, deployment.Namespace)

	// Finally, we verify the deployment pod template spec is set to the expected container image value
	expectedContainerImage := "gcr.io/agones-images/agones-controller:1.6.0"
	deploymentContainers := deployment.Spec.Template.Spec.Containers
	assert.Len(t, deploymentContainers, 1)
	assert.Equal(t, expectedContainerImage, deploymentContainers[0].Image)

	output = helm.RenderTemplate(t, options, helmChartPath, releaseName, []string{"templates/crds/fleet.yaml"})

	// Now we use kubernetes/client-go library to render the template output into the Deployment struct. This will
	// ensure the Deployment resource is rendered correctly.
	var fleet apiextensions.CustomResourceDefinition
	helm.UnmarshalK8SYaml(t, output, &fleet)
	assert.Equal(t, "", fleet.Spec.Validation.OpenAPIV3Schema.ID)
	assert.Equal(t, "", fleet.Name)

	options.SetValues["agones.crds.install"] = "false"
	output = helm.RenderTemplate(t, options, helmChartPath, releaseName, []string{"templates/crds/fleet.yaml"})
	fmt.Printf("%+v \n", output)
	err = helm.UnmarshalK8SYamlE(t, output, &fleet)
	assert.NoError(t, err)
	assert.Equal(t, "", fleet.Name)
}
