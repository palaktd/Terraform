resource "aws_instance" "first-vm" {
  tags = {
    name = "first-vm" 
    role = "learning"
    app = "httpd"
  }
  subnet_id = var.subnet_id
  security_groups = var.sg
  ami = var.ami
  availability_zone = var.az
  instance_type = var.instance_type
  associate_public_ip_address = var.associate_public_ip_address
  ebs_block_device {
    delete_on_termination = false
    tags = {
      name = "secondary volume"
    }
    volume_size = var.ebs_volume_size
    device_name = var.ebs_device_name
  }
  root_block_device {
    delete_on_termination = true
    tags = {
      name = "root volume of ${aws_instance.first-vm.tags.name}"
    }
  }
}