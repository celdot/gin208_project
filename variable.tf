variable "region" {
  type = string
}
variable "vpc_name" {
  type = list
}
variable "cidr_block_public" {
  type = string
}
variable "public_subnet" {
  type = string
}
variable "cidr_block_private" {
  type = string
}
variable "private_subnet" {
  type = string
}
variable "gw_name" {
  type = string
}
variable "rtb_name" {
  type = string
}
variable "group" {
  type = string
}
variable "sg_name" {
  type = string
}
variable "key_name_fe" {
  type = string
}
variable "key_name_be" {
  type = string
}
variable "key_path_fe" {
  type = string
}
variable "key_path_be" {
  type = string
}
variable "ami_name" {
  type = list
}
variable "instance_type" {
  type = string
}
variable "backend_instance" {
  type = string
}
variable "frontend_instance" {
  type = string
}