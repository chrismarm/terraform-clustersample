output "elb_dns_name" {
  value = "${aws_elb.clustersample.dns_name}"
}