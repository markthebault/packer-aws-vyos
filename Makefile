AWS_REGION=eu-west-1
VYOS_ISO_URL=https://downloads.vyos.io/release/legacy/1.1.8/vyos-1.1.8-amd64.iso
VYOS_VERSION=1.1.8-$(shell date +"%s")


all: terraform-start packer terraform-down output-ami

terraform-start:
	@cd terraform && terraform init && terraform apply -var 'aws_region=$(AWS_REGION)' -auto-approve

packer:
	@VYOS_ISO_URL=$(VYOS_ISO_URL) VYOS_VERSION=$(VYOS_VERSION) sh run-packer

terraform-down:
	@cd terraform && terraform destroy -force -var 'aws_region=$(AWS_REGION)'

output-ami:
	@echo ami_vyos=\"$(shell sh extract-ami-ids)\"
