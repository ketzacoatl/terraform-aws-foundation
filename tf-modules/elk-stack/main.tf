/**
 *## ELK stack (ELasticsearch + Logstash + Kibana)
 *
 * This module takes care of deployment of the full ELK stack. Which entails:
 *
 * * Creation of VPC with private and private subnets across many
 *   Availability Zones (AZs). At most one NAT gateway per private subnet,
 *   actual number of gateways is calculated automatically.
 * * Deploying Elasticsearch cluster across a private subnets with specified number
 *   of master and data nodes across all AZs, thus promoting high availability.
 *   See `../elasticsearch` module for more information.
 * * Deploys multiple load balanced servers running Kibana+Logstash each. See
 *   `../logstash+kibana` module for more information, as well as individual modules
 *   `../logstash` and `../kibana`.
 * * It also deploys a control EC2 instance that can be used to manage all instances
 *    in the stack
 */

provider "aws" {
  region = "${var.region}"
}


data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

data "aws_vpc" "current" {
  id = "${var.vpc_id}"
}

# Temporary SSH sg
resource "aws_security_group" "ssh" {
  name = "${var.name_prefix}-ssh"
  vpc_id = "${var.vpc_id}"
  tags {
    Name = "${var.name_prefix}-ssh"
    Description = "Allow SSH to hosts in ${var.name_prefix}"
  }
  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.public_cidrs}"]
  }
}


resource "aws_key_pair" "elk-key" {
  key_name = "${var.name_prefix}-key"
  public_key = "${file("${path.module}/${var.pub_key_file}")}"
}


module "elasticsearch" {
  source = "../elasticsearch"

  name_prefix               = "${var.name_prefix}"
  region                    = "${var.region}"
  vpc_id                    = "${var.vpc_id}"
  vpc_azs                   = ["${var.vpc_azs}"]
  route53_zone_id           = "${var.route53_zone_id}"
  key_name                  = "${aws_key_pair.elk-key.key_name}"
  public_subnet_ids         = ["${var.private_subnet_ids}"]
  private_subnet_ids        = ["${var.private_subnet_ids}"]
  extra_sg_ids              = ["${aws_security_group.ssh.id}"]
  node_ami                  = "${data.aws_ami.ubuntu.id}"
  data_node_count           = "${var.elasticsearch_data_node_count}"
  data_node_ebs_size        = "${var.elasticsearch_data_node_ebs_size}"
  data_node_snapshot_ids    = ["${var.elasticsearch_data_node_snapshot_ids}"]
  data_node_instance_type   = "${var.elasticsearch_data_node_instance_type}"
  master_node_count         = "${var.elasticsearch_master_node_count}"
  master_node_ebs_size      = "${var.elasticsearch_master_node_ebs_size}"
  master_node_snapshot_ids  = ["${var.elasticsearch_master_node_snapshot_ids}"]
  master_node_instance_type = "${var.elasticsearch_master_node_instance_type}"
}


module "kibana" {
  source = "../kibana"

  name_prefix          = "${var.name_prefix}"
  vpc_id               = "${var.vpc_id}"
  vpc_azs              = ["${var.vpc_azs}"]
  route53_zone_id      = "${var.route53_zone_id}"
  kibana_dns_name      = "${var.kibana_dns_name}"
  public_subnet_ids    = ["${var.public_subnet_ids}"]
  private_subnet_ids   = ["${var.private_subnet_ids}"]
  key_name             = ""
  ami                  = ""
  instance_type        = ""
  elasticsearch_url    = "http://${module.elasticsearch.elb_dns}:9200"
  min_server_count     = 0
  max_server_count     = 0
  desired_server_count = 0
  elb_ingress_cidrs    = ["${var.public_cidrs}"]
}

module "logstash-kibana" {
  source = "../logstash"

  name_prefix              = "${var.name_prefix}"
  name_suffix              = "-kibana"
  vpc_id                   = "${var.vpc_id}"
  public_subnet_ids        = ["${var.public_subnet_ids}"]
  private_subnet_ids       = ["${var.private_subnet_ids}"]
  vpc_azs                  = ["${var.vpc_azs}"]
  route53_zone_id          = "${var.route53_zone_id}"
  logstash_dns_name        = "${var.logstash_dns_name}"
  ami                      = "${data.aws_ami.ubuntu.id}"
  instance_type            = "${var.logstash_kibana_instance_type}"
  key_name                 = "${aws_key_pair.elk-key.key_name}"
  elasticsearch_url        = "http://${module.elasticsearch.elb_dns}:9200"
  min_server_count         = "${var.logstash_kibana_min_server_count}"
  max_server_count         = "${var.logstash_kibana_max_server_count}"
  desired_server_count     = "${var.logstash_kibana_desired_server_count}"
  extra_sg_ids             = ["${module.kibana.security_group_id}", "${aws_security_group.ssh.id}"]
  extra_setup_snippet      = "${module.kibana.setup_snippet}"
  extra_elb_ingress_cidrs  = ["${concat(list(data.aws_vpc.current.cidr_block), var.logstash_extra_cidrs)}"]
  extra_elbs               = ["${module.kibana.elb_name}"]
  certstrap_depot_path     = "${var.certstrap_depot_path}"
  certstrap_ca_common_name = "${var.certstrap_ca_common_name}"
  certstrap_ca_passphrase  = "${var.certstrap_ca_passphrase}"
  credstash_table_name     = "${var.credstash_table_name}"
  credstash_kms_key_arn    = "${var.credstash_kms_key_arn}"
  credstash_prefix         = "${var.name_prefix}-"
}

