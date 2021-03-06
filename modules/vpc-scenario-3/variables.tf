variable "name_prefix" {
  description = "Name to prefix various resources with"
  type        = string
}

variable "region" {
  description = "Region were VPC will be created"
  type        = string
}

variable "cidr" {
  description = "CIDR range of VPC. eg: 172.16.0.0/16"
  type        = string
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "A list of public subnet CIDRs to deploy inside the VPC."
}

variable "private_subnet_cidrs" {
  description = "A list of private subnet CIDRs to deploy inside the VPC. Should not be higher than public subnets count"
  default     = []
  type        = list(string)
}

variable "azs" {
  type        = list(string)
  description = "A list of Availaiblity Zones in the region"
}

variable "extra_tags" {
  description = "Extra tags that will be added to VPC, DHCP Options, Internet Gateway, Subnets and Routing Table."
  default     = {}
  type        = map(string)
}

variable "enable_dns_hostnames" {
  default     = true
  description = "boolean, enable/disable VPC attribute, enable_dns_hostnames"
  type        = string
}

variable "enable_dns_support" {
  default     = true
  description = "boolean, enable/disable VPC attribute, enable_dns_support"
  type        = string
}

variable "dns_servers" {
  default     = ["AmazonProvidedDNS"]
  description = "list of DNS servers"
  type        = list(string)
}

variable "vpn_static_routes" {
  type        = list(string)
  description = "list of static routes to use with AWS customer gateway (VPN)"
}

variable "vpn_remote_ip" {
  description = "IP address of the remote VPN for AWS to associate with"
  type        = string
}

