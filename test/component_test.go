package test

import (
	"fmt"
	"testing"

	"github.com/cloudposse/test-helpers/pkg/atmos"
	helper "github.com/cloudposse/test-helpers/pkg/atmos/aws-component-helper"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/stretchr/testify/assert"
)

type validationOption struct {
	DomainName          string `json:"domain_name"`
	ResourceRecordName  string `json:"resource_record_name"`
	ResourceRecordType  string `json:"resource_record_type"`
	ResourceRecordValue string `json:"resource_record_value"`
}

type zone struct {
	Arn               string            `json:"arn"`
	Comment           string            `json:"comment"`
	DelegationSetId   string            `json:"delegation_set_id"`
	ForceDestroy      bool              `json:"force_destroy"`
	Id                string            `json:"id"`
	Name              string            `json:"name"`
	NameServers       []string          `json:"name_servers"`
	PrimaryNameServer string            `json:"primary_name_server"`
	Tags              map[string]string `json:"tags"`
	TagsAll           map[string]string `json:"tags_all"`
	Vpc               []struct {
		ID     string `json:"vpc_id"`
		Region string `json:"vpc_region"`
	} `json:"vpc"`
	ZoneID string `json:"zone_id"`
}

func TestComponent(t *testing.T) {
	t.Parallel()
	// Define the AWS region to use for the tests
	awsRegion := "us-east-2"

	// Initialize the test fixture
	fixture := helper.NewFixture(t, "../", awsRegion, "test/fixtures")

	// Ensure teardown is executed after the test
	defer fixture.TearDown()
	fixture.SetUp(&atmos.Options{})

	// Define the test suite
	fixture.Suite("default", func(t *testing.T, suite *helper.Suite) {
		t.Parallel()
		suite.AddDependency("vpc", "default-test")

		// Setup phase: Create DNS zones for testing
		suite.Setup(t, func(t *testing.T, atm *helper.Atmos) {
			// Deploy the delegated DNS zone
			inputs := map[string]interface{}{
				"zone_config": []map[string]interface{}{
					{
						"subdomain": suite.GetRandomIdentifier(),
						"zone_name": "components.cptest.test-automation.app",
					},
				},
			}
			atm.GetAndDeploy("dns-delegated", "default-test", inputs)
		})

		// Teardown phase: Destroy the DNS zones created during setup
		suite.TearDown(t, func(t *testing.T, atm *helper.Atmos) {
			// Deploy the delegated DNS zone
			inputs := map[string]interface{}{
				"zone_config": []map[string]interface{}{
					{
						"subdomain": suite.GetRandomIdentifier(),
						"zone_name": "components.cptest.test-automation.app",
					},
				},
			}
			atm.GetAndDestroy("dns-delegated", "default-test", inputs)
		})

		// Test phase: Validate the functionality of the ALB component
		suite.Test(t, "basic", func(t *testing.T, atm *helper.Atmos) {
			t.Parallel()
			inputs := map[string]interface{}{
				"name":                "db",
				"database_name":       "postgres",
				"admin_user":          "postgres",
				"database_port":       5432,
				"publicly_accessible": true,
				"allowed_cidr_blocks": []string{
					"0.0.0.0/0",
				},
			}

			component := helper.NewAtmosComponent("aurora-postgres/basic", "default-test", inputs)
			component.Vars["cluster_name"] = component.GetRandomIdentifier()

			defer atm.Destroy(component)
			atm.Deploy(component)
			assert.NotNil(t, component)

			databaseName := atm.Output(component, "database_name")
			assert.Equal(t, "postgres", databaseName)

			adminUsername := atm.Output(component, "admin_username")
			assert.Equal(t, "postgres", adminUsername)

			delegatedDnsComponent := helper.NewAtmosComponent("dns-delegated", "default-test", map[string]interface{}{})
			delegatedDomainName := atm.Output(delegatedDnsComponent, "default_domain_name")
			delegatedDomainNZoneId := atm.Output(delegatedDnsComponent, "default_dns_zone_id")

			masterHostname := atm.Output(component, "master_hostname")
			expectedMasterHostname := fmt.Sprintf("%s-%s-writer.%s", inputs["name"], component.Vars["cluster_name"], delegatedDomainName)
			assert.Equal(t, expectedMasterHostname, masterHostname)

			replicasHostname := atm.Output(component, "replicas_hostname")
			expectedReplicasHostname := fmt.Sprintf("%s-%s-reader.%s", inputs["name"], component.Vars["cluster_name"], delegatedDomainName)
			assert.Equal(t, expectedReplicasHostname, replicasHostname)

			ssmKeyPaths := atm.OutputList(component, "ssm_key_paths")
			assert.Equal(t, 7, len(ssmKeyPaths))

			kmsKeyArn := atm.Output(component, "kms_key_arn")
			assert.NotEmpty(t, kmsKeyArn)

			allowedSecurtiyGroups := atm.OutputList(component, "allowed_security_groups")
			assert.Equal(t, 0, len(allowedSecurtiyGroups))

			clusterIdentifier := atm.Output(component, "cluster_identifier")

			configMap := map[string]interface{}{}
			atm.OutputStruct(component, "config_map", &configMap)

			assert.Equal(t, clusterIdentifier, configMap["cluster"])
			assert.Equal(t, databaseName, configMap["database"])
			assert.Equal(t, masterHostname, configMap["hostname"])
			assert.EqualValues(t, inputs["database_port"], configMap["port"])
			assert.Equal(t, adminUsername, configMap["username"])

			masterHostnameDNSRecord := aws.GetRoute53Record(t, delegatedDomainNZoneId, masterHostname, "CNAME", awsRegion)
			assert.Equal(t, *masterHostnameDNSRecord.ResourceRecords[0].Value, configMap["endpoint"])

			// Uncomment the following code block to validate the schema creation in the RDS instance
			// when `publicly_accessible=true`  will use public subnets

			passwordSSMKey, ok := configMap["password_ssm_key"].(string)
			assert.True(t, ok, "password_ssm_key should be a string")

			adminUserPassword := aws.GetParameter(t, awsRegion, passwordSSMKey)

			dbUrl, ok := configMap["endpoint"].(string)
			assert.True(t, ok, "endpoint should be a string")

			dbPort, ok := inputs["database_port"].(int)
			assert.True(t, ok, "database_port should be an int")

			schemaExistsInRdsInstance := aws.GetWhetherSchemaExistsInRdsPostgresInstance(t, dbUrl, int32(dbPort), adminUsername, adminUserPassword, databaseName)
			assert.True(t, schemaExistsInRdsInstance)

			schemaExistsInRdsInstance = aws.GetWhetherSchemaExistsInRdsPostgresInstance(t, masterHostname, int32(dbPort), adminUsername, adminUserPassword, databaseName)
			assert.True(t, schemaExistsInRdsInstance)

			schemaExistsInRdsInstance = aws.GetWhetherSchemaExistsInRdsPostgresInstance(t, replicasHostname, int32(dbPort), adminUsername, adminUserPassword, databaseName)
			assert.True(t, schemaExistsInRdsInstance)
		})

		// Test phase: Validate the functionality of the ALB component
		suite.Test(t, "serverless", func(t *testing.T, atm *helper.Atmos) {
			t.Parallel()
			inputs := map[string]interface{}{
				"name":                "db",
				"database_name":       "postgres",
				"admin_user":          "postgres",
				"database_port":       5432,
				"publicly_accessible": true,
				"allowed_cidr_blocks": []string{
					"0.0.0.0/0",
				},
			}

			component := helper.NewAtmosComponent("aurora-postgres/serverless", "default-test", inputs)
			component.Vars["cluster_name"] = component.GetRandomIdentifier()

			defer atm.Destroy(component)
			atm.Deploy(component)
			assert.NotNil(t, component)

			databaseName := atm.Output(component, "database_name")
			assert.Equal(t, "postgres", databaseName)

			adminUsername := atm.Output(component, "admin_username")
			assert.Equal(t, "postgres", adminUsername)

			delegatedDnsComponent := helper.NewAtmosComponent("dns-delegated", "default-test", map[string]interface{}{})
			delegatedDomainName := atm.Output(delegatedDnsComponent, "default_domain_name")
			delegatedDomainNZoneId := atm.Output(delegatedDnsComponent, "default_dns_zone_id")

			masterHostname := atm.Output(component, "master_hostname")
			expectedMasterHostname := fmt.Sprintf("%s-%s-writer.%s", inputs["name"], component.Vars["cluster_name"], delegatedDomainName)
			assert.Equal(t, expectedMasterHostname, masterHostname)

			ssmKeyPaths := atm.OutputList(component, "ssm_key_paths")
			assert.Equal(t, 7, len(ssmKeyPaths))

			kmsKeyArn := atm.Output(component, "kms_key_arn")
			assert.NotEmpty(t, kmsKeyArn)

			allowedSecurtiyGroups := atm.OutputList(component, "allowed_security_groups")
			assert.Equal(t, 0, len(allowedSecurtiyGroups))

			clusterIdentifier := atm.Output(component, "cluster_identifier")

			configMap := map[string]interface{}{}
			atm.OutputStruct(component, "config_map", &configMap)

			assert.Equal(t, clusterIdentifier, configMap["cluster"])
			assert.Equal(t, databaseName, configMap["database"])
			assert.Equal(t, masterHostname, configMap["hostname"])
			assert.EqualValues(t, inputs["database_port"], configMap["port"])
			assert.Equal(t, adminUsername, configMap["username"])

			masterHostnameDNSRecord := aws.GetRoute53Record(t, delegatedDomainNZoneId, masterHostname, "CNAME", awsRegion)
			assert.Equal(t, *masterHostnameDNSRecord.ResourceRecords[0].Value, configMap["endpoint"])

			passwordSSMKey, ok := configMap["password_ssm_key"].(string)
			assert.True(t, ok, "password_ssm_key should be a string")

			adminUserPassword := aws.GetParameter(t, awsRegion, passwordSSMKey)

			dbUrl, ok := configMap["endpoint"].(string)
			assert.True(t, ok, "endpoint should be a string")

			dbPort, ok := inputs["database_port"].(int)
			assert.True(t, ok, "database_port should be an int")

			schemaExistsInRdsInstance := aws.GetWhetherSchemaExistsInRdsPostgresInstance(t, dbUrl, int32(dbPort), adminUsername, adminUserPassword, databaseName)
			assert.True(t, schemaExistsInRdsInstance)

			schemaExistsInRdsInstance = aws.GetWhetherSchemaExistsInRdsPostgresInstance(t, masterHostname, int32(dbPort), adminUsername, adminUserPassword, databaseName)
			assert.True(t, schemaExistsInRdsInstance)
		})
	})
}
