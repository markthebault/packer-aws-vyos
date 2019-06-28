# Generate file

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "template_file" "packer_script" {
  template = "${file("${path.module}/templates/run-packer.tmpl")}"


  vars = {
    aws_region    = "${var.aws_region}"
    vpc_id        = "${module.vpc_vyos.vpc_id}"
    public_sub_id = "${module.vpc_vyos.public_subnets[0]}"
    vyos_base_ami = "${data.aws_ami.ubuntu.id}"
  }
}
resource "null_resource" "packer_script" {
  triggers = {
    template_rendered = "${data.template_file.packer_script.rendered}"
  }
  provisioner "local-exec" {
    command = "echo '${data.template_file.packer_script.rendered}' > ../run-packer"
  }
}
