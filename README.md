# Terraform

The repository contains the Terraform configuration for running Docker Swarm in AWS.

# IMPORTANT

## The following command must be ran from within EACH "environment directory" to make sure your state file gets upload to S3.

1. From the directory "environments/globals" execute the command "make configure".

1. From the directory "environments/core-services" execute the command "make configure".

1. From the directory "environments/ci" execute the command "make configure".