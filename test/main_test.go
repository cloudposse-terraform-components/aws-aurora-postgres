package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestTerraformHelloWorld(t *testing.T) {
	t.Parallel()

	// Define a simple Terraform configuration as a string
	terraformConfig := `
		variable "greeting" {
			default = "Hello, World!"
		}

		output "greeting_message" {
			value = var.greeting
		}
	`

	// Write the configuration to a temporary file
	tempDir, err := os.MkdirTemp("", "terratest-")
	if err != nil {
		t.Fatalf("Failed to create temp directory: %v", err)
	}
	defer os.RemoveAll(tempDir) // Clean up after the test

	tempFile := tempDir + "/main.tf"
	err = os.WriteFile(tempFile, []byte(terraformConfig), 0644)
	if err != nil {
		t.Fatalf("Failed to write Terraform config to file: %v", err)
	}

	// Define Terraform options
	terraformOptions := &terraform.Options{
		// Path to the temporary directory with the Terraform config
		TerraformDir: tempDir,

		// Variables to pass to Terraform
		Vars: map[string]interface{}{
			"greeting": "Hello, testing!",
		},
	}

	// Run Terraform init and apply, and fail the test if there are any errors
	defer terraform.Destroy(t, terraformOptions) // Cleanup after the test
	terraform.InitAndApply(t, terraformOptions)

	// Verify outputs
	greetingMessage := terraform.Output(t, terraformOptions, "greeting_message")

	// Assert that the output matches the expected value
	assert.Equal(t, "Hello, testing!", greetingMessage, "Greeting message does not match")
}

