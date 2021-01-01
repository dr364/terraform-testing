FROM golang:1.15.6-alpine3.12

ENV PRE_COMMIT_TERRAFORM_VERSION v1.45.0
ENV TERRAFORM_VERSION 0.13.5
ENV TFLINT_VERSION v0.22.0
ENV TERRASCAN_VERSION 1.2.0
ENV TERRATEST_VERSION v0.31.2
ENV TESTIFY_VERSION v1.6.1
# Terraform validate pre-commit hook requires the AWS_DEFAULT_REGION env var for initialising AWS cloud provider config
# Without it then the validate command could fail because the AWS provider needs the region set
ENV AWS_DEFAULT_REGION us-east-1 

ENV TF_IN_AUTOMATION 1
ENV GOPATH /opt/workdir

LABEL maintainer=dr364@github.com \
      name=terraform-testing \
      version=0.1.2

# Update all packages, also install Python and pre-commit
RUN apk update && \
    apk upgrade && \
    apk add --no-cache unzip \
    bash \
    git \
    build-base \
    python3 \
    py3-pip && \
    pip3 install --ignore-installed pre-commit

# Download terraform pre-commit hooks so they can be used locally (i.e. via 'pre-commit try-repo', or writing a .pre-commit-config.yaml in your Terraform root folder to use the local repo)
WORKDIR /opt
RUN git clone https://github.com/antonbabenko/pre-commit-terraform && \
    cd pre-commit-terraform && \
    git checkout -b tags/${PRE_COMMIT_TERRAFORM_VERSION}

# Install Terraform, TFLint and Terrascan from binaries
WORKDIR /tmp
RUN wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    unzip -d /usr/local/bin terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    wget https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VERSION}/tflint_linux_amd64.zip && \
    unzip -d /usr/local/bin tflint_linux_amd64.zip && \
    wget https://github.com/accurics/terrascan/releases/download/v${TERRASCAN_VERSION}/terrascan_${TERRASCAN_VERSION}_Linux_x86_64.tar.gz && \
    tar -xzvf terrascan_${TERRASCAN_VERSION}_Linux_x86_64.tar.gz && \
    mv terrascan /usr/local/bin/

# Clean up temp files
RUN rm /tmp/*

# Install uncompiled go packages (Terratest and testify)
RUN mkdir -p $GOPATH/src
WORKDIR $GOPATH/src

# Copy the git repo to test here, or attach a volume to $GOPATH

# Initialise the go modules
RUN go mod download github.com/gruntwork-io/terratest@$TERRATEST_VERSION && \
    go mod download github.com/stretchr/testify@$TESTIFY_VERSION
