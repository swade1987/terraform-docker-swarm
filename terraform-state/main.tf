resource "aws_s3_bucket" "example-tf-state" {
    bucket = "example-tf-state"
    acl = "private"
    versioning {
        enabled = "true"
    }
}