output "swarm_manager_security_group" {
    value = "${aws_security_group.swarm_manager.id}"
}