variable "ami" {
  type = string
  description = "Enter the ami to be used for ec2 creation"
}
variable "subnet_id" {
  type = string
  description = "Enter the subnet ID"
}
variable "sg" {
  type = list(string)
  description = "Enter the security groups to be added in EC2"
}
variable "az" {
  type = string
  description = "Enter the availibity zone"
}
variable "instance_type" {
  type = string
  description = "Enter the configitation of instance"
}
variable "associate_public_ip_address" {
  type = bool
  default = false
}
variable "ebs_volume_size" {
  type = number
  description = "Enter the size of secondary volume"
}
variable "ebs_device_name" {
  type = string
  default = "/dev/sda1"
}