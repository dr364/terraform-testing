FROM golang:1.15.8-alpine3.13

ENV PRE_COMMIT_TERRAFORM_VERSION v1.45.0
ENV TERRAFORM_VERSION 0.14.6
ENV TFLINT_VERSION v0.24.1
ENV TERRASCAN_VERSION 1.3.2
ENV TERRATEST_VERSION v0.32.5
ENV TESTIFY_VERSION v1.7.0
# Terraform validate pre-commit hook requires the AWS_DEFAULT_REGION env var for initialising AWS cloud provider config
# Without it then the validate command could fail because the AWS provider needs the region set
ENV AWS_DEFAULT_REGION us-east-1

ENV TF_IN_AUTOMATION 1
ENV GOPATH /opt/workdir

LABEL maintainer=dr364@github.com \
      name=terraform-testing \
      version=0.1.3

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

# Establish the runtime user (non-root, no sudo privileges)
RUN addgroup -g 1000 -S terraform && \
    adduser -u 1000 -S -D terraform -G terraform --shell /bin/bash && \
    mkdir -p $GOPATH/src && \
    chown -R terraform:terraform $GOPATH

# Tell docker that all future commands should run as the terraform user
USER terraform
WORKDIR $GOPATH/src

# Copy the git repo to test here, or attach a volume to $GOPATH

# Install go packages (Terratest and testify)
RUN go mod download github.com/gruntwork-io/terratest@$TERRATEST_VERSION && \
    go mod download github.com/stretchr/testify@$TESTIFY_VERSION
