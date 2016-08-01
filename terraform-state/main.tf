resource "aws_s3_bucket" "pds-tf-state" {
    bucket = "pds-tf-state"
    acl = "private"
    versioning {
        enabled = "true"
    }
}