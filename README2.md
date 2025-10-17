# Automated Kubeadm Cluster Deployment on AWS

## Section I: Executive Summary and Deployment Architecture

This project establishes a resilient and secure Kubernetes cluster on the Amazon Web Services (AWS) cloud platform. The deployment adheres to the Infrastructure as Code (IaC) paradigm, utilizing **Terraform** for resource provisioning and **Ansible** for declarative configuration management. The workflow is designed for immutability, auditability, and minimal human intervention, progressing from raw infrastructure definition to application-ready Kubernetes nodes.
**Infrastructure Setup (Terraform):**

* **VPC Design:** Created a custom VPC with an Internet Gateway, NAT Gateway, and proper routing.
* **Subnets:** Configured one public subnet (for the Bastion host and NAT Gateway) and three private subnets across different Availability Zones for better resilience.
* **Instances:**

  * **Bastion Host:** Ubuntu-based `t2.micro` instance for secure SSH access.
  * **Master Node:** `t3.medium` instance hosting the Kubernetes control plane.
  * **Worker Nodes:** Two `t3.small` instances, each in a different private subnet.
* **Security Groups:**

  * Bastion SG allows SSH access from anywhere (IPv4).
  * Master and Worker SGs allow only internal communication and SSH access from the Bastion host.
* **Key Management:** Generated an RSA TLS private key using Terraform, pushed the public key to all instances, and stored the private key securely in the project directory.
* **Dynamic Inventory:** Used Terraform to render an Ansible dynamic inventory template automatically after instance IPs were created.

**Configuration & Orchestration (Ansible):**

* Used Ansible to configure all nodes and set up Kubernetes with **kubeadm**.
* Automated the deployment of Kubernetes control plane and worker node joining.
* Configured `kubectl` on the Bastion host to manage the cluster remotely.

This project demonstrates the full integration of **Infrastructure as Code (IaC)** and **Configuration Management** tools to create a scalable, secure, and production-ready Kubernetes environment.


## Section II: Infrastructure Provisioning (Terraform Responsibilities)

The Terraform layer is modularized to ensure separation of concerns and reusability, operating entirely within the `eu-west-1` region.

### 1. Network Module (`modules/vpc`)

The primary objective of this module is the establishment of a robust, three-tiered network topology, as evidenced in `modules/vpc/main.tf`:

| Component | Quantity | CIDR / Description | Functionality |
| :--- | :--- | :--- | :--- |
| **VPC** | 1 | `var.vpc_cidr_block` | Logical network isolation for the entire cluster. |
| **Public Subnet** | 1 | `cidrsubnet(..., 8, 0)` | Hosts the Bastion and NAT Gateway. Traffic is routed via the Internet Gateway (IGW). |
| **Private Subnets** | 3 (across 3 AZs) | `cidrsubnet(..., 8, 1-3)` | Host the Master and Worker nodes. Outbound traffic is routed exclusively through the NAT Gateway. |
| **NAT Gateway (NAT GW)** | 1 | | Provides all private resources with egress to the public internet for updates and image pulls. |

### 2. Compute Module (`modules/compute`)

This module provisions the requisite server infrastructure, managing instance type, placement, and network security:

| Node Role | Instance Type | Placement | Security Protocol |
| :--- | :--- | :--- | :--- |
| **Master Node** | `t3.medium` | Private Subnet 1 | Kubeadm control plane host. SSH access restricted to the Bastion SG. |
| **Worker Nodes** | 2 x `t3.small` | Private Subnets 2 & 3 | Application compute hosts. SSH access restricted to the Bastion SG. |
| **Bastion Host** | `t2.micro` | Public Subnet 1 | SSH jump box. Public access is limited by a dedicated Security Group (SG). |

### 3. Root Configuration (`root main.tf` and Outputs)

The root configuration orchestrates inter-module connectivity and security assets:

| Asset / Action | Mechanism | Security Justification |
| :--- | :--- | :--- |
| **SSH Key Management** | **`tls_private_key`** and **`local_file`** | Generates the cryptographic key pair and saves the private key directly to a local file (`cluster_key.pem`). This bypasses Secrets Manager permission issues, with the `local_file` resource applying strict `0400` file permissions for security. |
| **Security Group Hardening** | **CIDR Reference and Dependency Inference** | The Master/Worker Security Group utilizes `var.vpc_cidr_block` for internal communication and **explicitly references the Bastion Host's Security Group ID** for inbound SSH (Port 22), thereby strictly limiting administrative access. |
| **Ansible Inventory Generation** | **`local_file`** and **`templatefile`** | Dynamically renders the `inventory.tpl` template, substituting provisioned IP addresses from the compute module outputs (`module.compute_nodes.*_ip`) to create the executable `inventory` file for Ansible. |


## Section III: Configuration Management (Ansible Protocols)

The Ansible layer executes immediately following infrastructure provisioning, ensuring all EC2 instances meet the prerequisite state for Kubeadm initialization.

### 1. Dynamic Inventory (`inventory.tpl` and `inventory`)

The rendered `inventory` file facilitates seamless access to private cluster resources:

* **Proxy Jump Configuration:** The inventory defines the `ansible_ssh_common_args` with a `ProxyCommand`, instructing Ansible to use the Bastion Host's public IP to tunnel into the private Master and Worker nodes.
* **Target Groups:** Defines logical groups (`kube-master`, `kube-workers`, `kube-nodes`) for precise task targeting.

### 2. Kubeadm Prerequisites Playbook (`k8s_setup.yml`)

The playbook targets the `kube-nodes` group and performs critical system preparations:

| Task Category | Actions Performed (Example) | Kubeadm Requirement |
| :--- | :--- | :--- |
| **Kernel Hardening** | Disabling Swap; loading `overlay` and `br_netfilter` kernel modules. | Essential for Kubernetes memory management and networking (CNI). |
| **Networking Configuration** | Setting `net.bridge.bridge-nf-call-iptables = 1` via `sysctl`. | Required for correct network packet filtering and bridge functionality. |
| **Container Runtime** | Installation and configuration of **Containerd** (including enabling the `SystemdCgroup` driver). | Required by Kubelet to manage containers. |
| **K8s Packages** | Installation and version pinning of `kubelet`, `kubeadm`, and `kubectl`. | Provides the tools necessary to initialize and manage the cluster control plane. |


How to Run and Test

1. **Run Terraform:**
> make sure Terraform is installed.

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

2. **Run Ansible:**
> Execute the command, which will perform all four plays:
> make sure Ansible is installed.

```Bash
eval $(ssh-agent -s)
ssh-add cluster_key.pem
ansible-playbook -i ./inventory k8s_setup.yml
```

3.  **Test the Cluster:** Once the playbook finishes, you can SSH into the Bastion Host using your private key and confirm the cluster state:

```bash
# SSH into the Bastion Host
ssh -i ./cluster_key.pem ubuntu@<BASTION_PUBLIC_IP>

# On the Bastion Host, run:
kubectl get nodes
```  
>   You should see `master-node` and two `worker-node`s in the `Ready` state.


