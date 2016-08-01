# Terraform

The repository contains the Terraform configuration for running Docker Swarm in AWS.

# Usage

Browse to environments/ci

## Configure Remote State to sync with S3

```bash
$ make configure
```

## Plan infrastructure changes

```bash
$ make plan
```

## Apply infrastructure changes

```bash
$ make apply
```