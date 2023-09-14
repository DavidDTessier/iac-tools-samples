package main

import (
	"github.com/pulumi/pulumi-gcp/sdk/v6/go/gcp/compute"
	"github.com/pulumi/pulumi-gcp/sdk/v6/go/gcp/serviceaccount"
	"github.com/pulumi/pulumi-gcp/sdk/v6/go/gcp/storage"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

func main() {
	pulumi.Run(func(ctx *pulumi.Context) error {
		// Create a GCP resource (Storage Bucket)
		bucket, err := storage.NewBucket(ctx, "my-bucket", &storage.BucketArgs{
			Location: pulumi.String("US"),
		})

		defaultAccount, err := serviceaccount.NewAccount(ctx, "defaultAccount", &serviceaccount.AccountArgs{
			AccountId:   pulumi.String("service-account-id"),
			DisplayName: pulumi.String("Service Account"),
		})

		computeNetwork, err := compute.NewNetwork(ctx, "my-network",
			&compute.NetworkArgs{
				AutoCreateSubnetworks: pulumi.Bool(true),
			},
		)

		if err != nil {
			return err
		}

		computeFirewall, err := compute.NewFirewall(ctx, "firewall",
			&compute.FirewallArgs{
				Network: computeNetwork.SelfLink,
				Allows: &compute.FirewallAllowArray{
					&compute.FirewallAllowArgs{
						Protocol: pulumi.String("tcp"),
						Ports: pulumi.StringArray{
							pulumi.String("22"),
							pulumi.String("80"),
						},
					},
				},
				SourceRanges: pulumi.StringArray{
					pulumi.String("0.0.0.0/0"),
				},
				SourceTags: pulumi.StringArray{
					pulumi.String("web"),
				},
			},
		)
		if err != nil {
			return err
		}

		// (optional) create a simple web server using the startup script for the instance
		startupScript := `#!/bin/bash
		echo "Hello, World!" > index.html
		nohup python -m SimpleHTTPServer 80 &`

		computeInstance, err := compute.NewInstance(ctx, "instance",
			&compute.InstanceArgs{
				MachineType:           pulumi.String("f1-micro"),
				Zone:                  pulumi.String("us-central1-a"),
				MetadataStartupScript: pulumi.String(startupScript),
				Tags: pulumi.StringArray{
					pulumi.String("foo"),
					pulumi.String("bar"),
				},
				BootDisk: &compute.InstanceBootDiskArgs{
					InitializeParams: &compute.InstanceBootDiskInitializeParamsArgs{
						Image: pulumi.String("debian-cloud/debian-9-stretch-v20181210"),
					},
				},
				NetworkInterfaces: compute.InstanceNetworkInterfaceArray{
					&compute.InstanceNetworkInterfaceArgs{
						Network: computeNetwork.SelfLink,
						// Must be empty to request an ephemeral IP
						AccessConfigs: compute.InstanceNetworkInterfaceAccessConfigArray{
							&compute.InstanceNetworkInterfaceAccessConfigArgs{},
						},
					},
				},
				Metadata: pulumi.StringMap{
					"foo": pulumi.String("bar"),
				},
				ServiceAccount: &compute.InstanceServiceAccountArgs{
					Email: defaultAccount.Email,
					Scopes: pulumi.StringArray{
						pulumi.String("https://www.googleapis.com/auth/cloud-platform"),
					},
				},
			},
			pulumi.DependsOn([]pulumi.Resource{computeFirewall}),
		)
		if err != nil {
			return err
		}

		ctx.Export("instanceName", computeInstance.Name)
		ctx.Export("instanceIP", computeInstance.NetworkInterfaces.Index(pulumi.Int(0)).AccessConfigs().Index(pulumi.Int(0)).NatIp())
		ctx.Export("bucketName", bucket.Url)
		return nil
	})
}
