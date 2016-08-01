output "subdomain_hosted_zone" {
    value = "${aws_route53_zone.public_hosted_zone.zone_id}"
}