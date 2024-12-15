output "ec2_id" {
  value = aws_instance.first-vm.id
}
output "secondary_vol" {
  value = aws_instance.first-vm.ebs_block_device.id
}
output "root_device_name" {
  value = aws_instance.first-vm.root_block_device.id
}