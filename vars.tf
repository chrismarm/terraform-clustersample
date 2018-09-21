variable "region" {
  type = "string"
  description = "Chosen region. As a newbie, only N.Virginia is allowed for me"
  default = "us-east-1"
}

variable "availability-zone1" {
  type = "string"
  default = "us-east-1a"
}

variable "PUBLIC_KEY_PATH" {
  type = "string"
  default = "./cluster.pub"
}