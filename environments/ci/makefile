.PHONY: all configure plan apply

all:
	configure plan apply

configure:
	terraform remote config -backend=s3 -backend-config="bucket=example-tf-state" -backend-config="key=ci" -backend-config="region=eu-west-1"

plan:
	terraform get && terraform plan

apply:
	terraform get && terraform apply

destroy:
	terraform destroy
