# Terraform boilerplate configuration for a basic Apache web server on AWS within a VPC

## Preparation

Add the access key and secret key of the desired AWS user to the `terraform.tfvars` file. Make sure that the user has the necessary permissions to create resources such as VPCs and EC2s.

If you want to connect to the server via SSH, you can create a key pair in the AWS EC2 Console and specify the name of the key in the `ssh_key_name` variable.

## Usage

Initialize the project to download the AWS plugin:

```
terraform init
```

Provision the resources with `apply`. When Terraform asks you to confirm type `yes` and press `ENTER`.

```
terraform apply
```

The public IP of the created server will be logged to your console after the creation process has finished.
Go to this IP and you should see the message `"Hello World"`. You may have to wait a few seconds till Apache has been fully initialized.

Destroy the provisioned resources:

```
terraform destroy
```
