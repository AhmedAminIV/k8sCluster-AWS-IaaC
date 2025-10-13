# 🧩 Prerequisites for Kubernetes Cluster Deployment (AWS + Terraform + Ansible)

This document provides all the steps required to prepare your local environment to deploy a fully automated Kubernetes cluster on AWS using **Terraform** and **Ansible**.

---

## 📁 1. Clone the Repository

Clone this project to your local machine:

```bash
git clone https://github.com/AhmedAminIV/k8sCluster-AWS-IaaC.git
cd k8sCluster-AWS-IaaC
```

---

## ☁️ 2. Install and Configure AWS CLI

Terraform and Ansible require access to your AWS account via the AWS CLI.

### Install AWS CLI

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install unzip curl -y

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### Verify Installation

```bash
aws --version
```

### Configure AWS Credentials

Run the following and enter your **Access Key**, **Secret Key**, **Region**, and **Output format**:

```bash
aws configure
```

This creates the file `~/.aws/credentials`, used by Terraform and Ansible to authenticate to AWS.

---

## ⚙️ 3. Install Terraform

Terraform is used to provision the infrastructure (VPC, EC2 instances, etc.) on AWS.

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y gnupg software-properties-common curl

curl -fsSL https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update
sudo apt install terraform -y
terraform -version
```

---

## 🧱 4. Install Ansible

Ansible is used to configure the provisioned EC2 instances and set up the Kubernetes cluster.

```bash
sudo apt update
sudo apt install software-properties-common -y
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install ansible -y
ansible --version
```

---

## 🧰 5. Prepare Terraform Backend (Optional but Recommended)

Create an **S3 bucket** in AWS for remote Terraform state storage.
Then update your Terraform backend configuration in your `.tf` files:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "k8s-cluster/terraform.tfstate"
    region         = "your-region"
  }
}
```
[![backend-screenshot.png](https://i.postimg.cc/7YnVKJxf/backend-screenshot.png)](https://postimg.cc/SJjCssYh)
