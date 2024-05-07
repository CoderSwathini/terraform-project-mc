variable "vpc_CIDR" {
  default = "10.0.0.0/16"
}

variable "subnet1CIDR" {
  default = "10.0.1.0/24"
}
variable "subnet2CIDR" {
  default = "10.0.2.0/24"

}
variable "AMIid" {
  default = "ami-0a4f913c1801e18a2"
}


variable "InstType" {
  default = "t2.micro"
}
