output "allow_bastion_security_group_id" {
    value = "${aws_security_group.allow_bastion.id}"
}