output "logstash_security_group" {
    value = "${aws_security_group.logstash_elb.id}"
}