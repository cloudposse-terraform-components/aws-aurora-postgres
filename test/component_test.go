package test

import (
	"testing"

	awssdk "github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/cloudposse/test-helpers/pkg/atmos"
	helper "github.com/cloudposse/test-helpers/pkg/atmos/aws-component-helper"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/stretchr/testify/require"
)

func TestComponent(t *testing.T) {
	awsRegion := "us-east-2"

	fixture := helper.NewFixture(t, "../", awsRegion, "test/fixtures")

	defer fixture.TearDown()
	fixture.SetUp(&atmos.Options{})

	fixture.Suite("default", func(t *testing.T, suite *helper.Suite) {
		suite.AddDependency("vpc", "default-test")

		suite.Setup(t, func(t *testing.T, atm *helper.Atmos) {
			randomID := suite.GetRandomIdentifier()
			inputs := map[string]interface{}{
				"zone_config": []map[string]string{
					{
						"subdomain": randomID,
						"zone_name": "example.net",
					},
				},
			}
			atm.GetAndDeploy("dns-delegated", "default-test", inputs)
		})

		suite.TearDown(t, func(t *testing.T, atm *helper.Atmos) {
			atm.GetAndDestroy("dns-delegated", "default-test", map[string]interface{}{})
		})

		suite.Test(t, "single-cluster", func(t *testing.T, atm *helper.Atmos) {
			inputs := map[string]interface{}{
				"name":                             "shared",
				"deletion_protection":              false,
				"storage_encrypted":                true,
				"engine":                           "aurora-postgresql",
				"engine_mode":                      "provisioned",
				"engine_version":                   "15.3",
				"cluster_family":                   "aurora-postgresql15",
				"cluster_size":                     2,
				"admin_user":                       "postgres",
				"admin_password":                   "",
				"database_name":                    "postgres",
				"database_port":                    5432,
				"enhanced_monitoring_role_enabled": true,
				"instance_type":                    "db.t3.medium",
				"skip_final_snapshot":              true,
				"rds_monitoring_enabled":           true,
				"rds_monitoring_interval":          15,
				"allow_ingress_from_vpc_accounts": []map[string]string{
					{
						"tenant": "core",
						"stage":  "auto",
					},
				},
			}

			defer atm.GetAndDestroy("aurora-postgres/cluster", "default-test", inputs)
			component := atm.GetAndDeploy("aurora-postgres/cluster", "default-test", inputs)

			clusterARN := atm.Output(component, "aurora_postgres_cluster_arn")
			require.Equal(t, clusterARN, "")
		})
	})
}
