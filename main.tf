provider "aws" {
  region = "${var.region}"
}

resource "aws_vpc" "clusterVpc" {
    cidr_block = "10.1.0.0/16"
    instance_tenancy = "default"
    enable_dns_support = "true"
    tags {
        Name = "ClusterVpc"
    }
}

resource "aws_subnet" "clusterVpc-public" {
    vpc_id = "${aws_vpc.clusterVpc.id}"
    cidr_block = "10.1.0.0/24"
    map_public_ip_on_launch = "true"
    availability_zone = "${var.availability-zone1}"

    tags {
        Name = "clusterVpc-public"
    }
}

resource "aws_key_pair" "clusterkeypair" {
  key_name = "clusterkey"
  public_key = "${file("${var.PUBLIC_KEY_PATH}")}"
}

resource "aws_internet_gateway" "cluster-gw" {
    vpc_id = "${aws_vpc.clusterVpc.id}"

    tags {
        Name = "ClusterIG"
    }
}

resource "aws_route_table" "cluster-rt" {
    vpc_id = "${aws_vpc.clusterVpc.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.cluster-gw.id}"
    }

    tags {
        Name = "cluster-rt"
    }
}

resource "aws_route_table_association" "cluster-rt-a" {
    subnet_id = "${aws_subnet.clusterVpc-public.id}"
    route_table_id = "${aws_route_table.cluster-rt.id}"
}

data "aws_availability_zones" "all" {}

resource "aws_autoscaling_group" "clustersample" {
  launch_configuration = "${aws_launch_configuration.clustersample.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  vpc_zone_identifier = ["${aws_subnet.clusterVpc-public.id}"]

  min_size = 2
  max_size = 6

  load_balancers = ["${aws_elb.clustersample.name}"]
  health_check_type = "ELB"

  tag {
    key = "Name"
    value = "clustersample"
    propagate_at_launch = true
  }
}

resource "aws_launch_configuration" "clustersample" {
  image_id = "ami-04681a1dbd79675a5"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.clustersample-instance.id}"]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "clustersample-instance" {
  vpc_id = "${aws_vpc.clusterVpc.id}"
  name = "clustersample-instance"

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 8
    to_port = 0
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elb" "clustersample" {
  name = "clustersample"
  security_groups = ["${aws_security_group.clustersample-elb.id}"]
  #availability_zones = ["${data.aws_availability_zones.all.names}"]
  subnets = ["${aws_subnet.clusterVpc-public.id}"]

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:8080/"
  }

  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = 8080
    instance_protocol = "http"
  }
}

resource "aws_security_group" "clustersample-elb" {
  name = "clustersample-elb"
  vpc_id = "${aws_vpc.clusterVpc.id}"

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 8
    to_port = 0
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}