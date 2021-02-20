# Terraform Testing Pipeline

A Dockerfile and Concourse CI pipeline to run a series of test stages on your Terraform definitions in AWS.

The test types that the pipeline run are:
- Static IaC code analysis and quality checks (through pre-commit hooks - validate Terraform definitions, perform linting and static security checks)
- Unit tests (using Terratest) - static analysis of a `terraform plan`
- Integration tests (using Terratest) - dynamic analysis of deployed Terraform definitions

## Testing apps

The Docker image uses the following open source projects -

- Pre-Commit Terraform hooks - https://github.com/antonbabenko/pre-commit-terraform
- TFLint - https://github.com/terraform-linters/tflint
- Terrascan - https://github.com/accurics/terrascan
- Terratest - https://github.com/gruntwork-io/terratest
  - Testify for test assertions - https://github.com/stretchr/testify

## Prerequisites

- The pipeline assumes that the Terraform defintions you are running are in a public git repository. If they are in a private repo, you will need to add the `private_key` to the `git` resource type. See https://github.com/concourse/git-resource for details on how to implement.

- The pipeline assumes that you are using Terratest to perform your unit and integration tests. To separate unit and integration tests into the appropriate pipeline stages, Terratest requires that you tag your test files with either `unit` or `integration` on the first line of the file, like so:

```
// +build integration

package test

import (
    ...
```

- The pipeline assumes that you have your tests configured in a folder called `test` at the root of your Terraform repo, similar to below:

```
terraform-code
| ---- vars
| ---- modules
|      | ---- module-1
|             | ---- main.tf
|             | ---- outputs.tf
|             | ---- variables.tf
| ---- test
|      | ---- fixtures
|      |      | ---- integration-test
|      |      |      | ---- integration-test.tf
|      |      | ---- unit-test
|      |             | ---- unit-test.tf
|      | ---- integration-test.go
|      | ---- unit-test.go
| ---- main.tf
| ---- provider.tf
| ---- outputs.tf
| ---- variables.tf
```

- The pipeline assumes that you will pass your AWS credentials as variables to the pipeline. **Run in a separate AWS account, or ensure that you have variables in your integration tests set to not destroy existing production infrastructure. Put simply, do not use AWS credentials for your production environment!!!**

- You don't need to have a `.pre-commit-config.yaml` configured with the Terraform pre-commit hooks in your target repository, as it will create a temporary one for you. However if you do already have a `.pre-commit-config.yaml`, you should leverage some form of pre-commit hooks for checking your Terraform definitions in your repo - doesn't have to be from the hook repo that is part of the Docker image, but it is highly recommended you perform some form of quality checking or linting!

## Test Stages

The Concourse pipeline runs through a number of test stages, performing quality checks and fixes. If using the pipeline's inbuilt `pre-commit-config.yaml`, this will perform the following:

1) Pre-commit hooks for validating the Terraform plan and running TFLint to find common syntax and naming errors.
2) Terrascan for static security analysis
3) Terratest for unit tests, if any defined (static analysis of a Terraform plan)
4) Terratest for integration tests (tests on deployed Terraform code)

## How to deploy pipeline

The pipeline has a number of variables you will need to declare when you submit it to Concourse:
1) `((terraform-git-uri))` - The Git URI of the Terraform definitions you wish to test.
2) `((terraform-branch-name))` - The branch of code you wish to track within the aforementioned Git repo.
3) `((pre-commit-repo-version))` - The tag of `pre-commit-terraform` to use for pre-commit checks. If you are not using `pre-commit-terraform` then just place an arbitrary value here (Concourse currently doesn't support optional parameters or default values). Ensure that this aligns with the `PRE_COMMIT_TERRAFORM_VERSION` in the Dockerfile.
4) `(aws-region))` - Your AWS region specified in your `AWS_DEFAULT_REGION` environment variable or cred file.
5) `((aws-access-key-id))` - Your AWS access key specified in your `AWS_ACCESS_KEY_ID` environment variable or cred file.
6) `((aws-secret-access-key))` - Your AWS region specified in your `AWS_SECRET_ACCESS_KEY` environment variable or cred file.

Presuming you have `fly` (the CLI tool for interacting with Concourse) talking to your Concourse instance, run the following command:
```
fly -t <target> set-pipeline -p <your-pipeline-name> -c pipeline.yml -v terraform-git-uri=<terraform-git-uri> -v terraform-branch-name=<branch-name> -v pre-commit-repo-version=<pre-commit-release-version> -v aws-region=<aws-region> -v aws-access-key-id=<aws-access-key-id> -v aws-secret-access-key=<aws-secret-access-key>
```
