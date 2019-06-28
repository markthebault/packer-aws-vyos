AWS_REGION=eu-west-1

all: terraform-start packer terraform-down output-ami

terraform-start:
	@cd terraform && terraform init && terraform apply -var 'aws_region=$(AWS_REGION)' -auto-approve

packer:
	@sh run-packer

terraform-down:
	@cd terraform && terraform destroy -force -var 'aws_region=$(AWS_REGION)'

output-ami:
	@echo ami_vyos=\"$(shell sh extract-ami-ids)\"
