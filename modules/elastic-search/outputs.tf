output "elasticsearch_security_group" {
    value = "${aws_security_group.elastic_search.id}"
}