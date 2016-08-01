output "security_group_id" {
    value = "${aws_security_group.gocd_server.id}"
}