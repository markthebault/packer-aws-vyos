# VyOs instance on AWS
This project is about building a VyOS instance for AWS. In order to proceed you need [packer](https://www.packer.io/downloads.html) and [terraform](https://www.terraform.io/downloads.html) to run the project.

**Note this version will work only with the version 1.1.x**

## Create the AMI
### Define your region
When using the `Makefile` a parameter is used to declare the region where the AMI will be created. By default the region is `eu-west-1`. To customize the region by changing the parameter **AWS_REGION** of the Makefile like this:
`make AWS_REGION=eu-central-1 packer`

### Create the infrastructure for Packer
Packer needs a VPC and a Subnet to run an ec2 to create an AMI, by default, packer use the default VPC. I might happend that you have deleted the default VPC or your comapny does not allows Default VPC. That's why we need to run terraform before generating the AMI.

To run Terraform you can run the following command `make terraform-start`.

### Running packer
When the infrastructure is ready you can run `make packer` to execute packer to create the AMI.
You can personalize the version of VyOS ISO image by pasting the version and the link to the ISO (only verion 1.1.x) from the [VyOS ISO webpage](https://downloads.vyos.io/?dir=release/legacy/1.1.8) directly inside the `Makefile`


Running packer: `make packer`

When packer finishes you can run `make output-ami` to get the output AMI id. For instance: `ami_vyos="ami-0cbf39ec"`

### Cleaning up the environment
When you got the packer AMI id, you can clean up the environment created by terraform by running: `make terraform-down`

### Fast track, run everything
To speed you the process you can just the command `make` it will run all the steps above.

## Trouble shooting
* If terraform is not working, verify the versions of the modules used and your local version.
* To run an older version of VyOS, you need to update file `provision.sh` and restore the commented parameter `vyos_iso_url` and commned the new one, and ofcourse update the `packer.json`.

# TODO
* Build ISO from the version of VyOS 1.2.x
* Use the provision120.sh for next releases