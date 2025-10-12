# k8sCluster-AWS-IaaC
Provision K8s cluster (kubeadm) using Terraform for infrastructure and Ansible for configuration on AWS 

# Kubernetes Cluster Deployment with Terraform and Ansible

This project automates the deployment of a Kubernetes cluster (1 master + 2 workers) on AWS, using Terraform to provision VMs and Ansible to configure the cluster. A Bastion host is used for secure SSH access.

---

## **Architecture**

- **Bastion Host**: Publicly accessible, used for SSH into internal nodes.
- **Master Node**: Kubernetes control plane.
- **Worker Nodes**: Kubernetes nodes (2 nodes in separate AZs).
- **Network**: Nodes in private subnets, accessed through Bastion.

---

## **Prerequisites**

- AWS account with programmatic access (access key + secret key)
- Terraform installed
- Ansible >= 2.14
- Python 3 installed on all target VMs
- `cluster_key.pem` (created automatically by Terraform)

---

## **Deployment Workflow**

### **1. Configure Terraform Backend**

1. Create an **S3 bucket** to store Terraform state.  
2. Update `backend.tf` in Terraform code with your S3 bucket and region.

Example:

```hcl
terraform {
  backend "s3" {
    bucket = "my-terraform-state-bucket"
    key    = "k8s-cluster/terraform.tfstate"
    region = "us-east-1"
  }
}
````

---

### **2. Configure AWS CLI**

```bash
aws configure
# Enter Access Key ID, Secret Access Key, default region, output format
```

---

### **3. Provision Infrastructure with Terraform**

```bash
terraform init
terraform apply -auto-approve
```

* Terraform creates:

  * Bastion host (public)
  * Master node (private)
  * 2 Worker nodes (private)
  * `cluster_key.pem` for SSH

---

### **4. Configure SSH Agent for Ansible**

```bash
eval $(ssh-agent -s)
ssh-add cluster_key.pem
```

---

### **5. Run Ansible Playbook**

```bash
ansible-playbook -i ./inventory k8s_setup.yml
```

* **Inventory** uses bastion as SSH proxy.
* Playbook:

  * Installs Docker, kubeadm, kubelet, kubectl
  * Initializes master node
  * Joins worker nodes
  * Configures CNI (Calico)
  * Installs kubectl on Bastion and configures kubeconfig

---

### **6. Verify Cluster**

On the Bastion host:

```bash
kubectl get nodes
kubectl get pods -A
```

* Ensure all nodes are `Ready`.

---

## **Ansible Inventory Notes**

* Bastion host has **no ProxyCommand**.
* Internal nodes use **ProxyCommand through Bastion**.
* Host key checking is disabled for first-time SSH:

Example:

```ini
[kube-master]
master-node ansible_host=10.0.1.244 ansible_ssh_common_args=-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p -q ubuntu@<BASTION_PUBLIC_IP>"
```

---

## **Tips**

* Do **not commit `cluster_key.pem`** — add it to `.gitignore`.
* For first-time runs, **ensure `host_key_checking = False`** in `ansible.cfg`.
* Nodes are deployed in separate AZs — adjust Terraform if you want different network topology.

---

## **Troubleshooting**

* **SSH fails first time**: Ensure `ansible.cfg` and `ansible_ssh_common_args` have StrictHostKeyChecking disabled.
* **kubectl fails on Bastion**: Make sure kubeconfig is copied from master and points to correct API server (`https://<MASTER_PRIVATE_IP>:6443`).
* **Terraform apply hangs**: Check security groups allow SSH from Bastion to internal nodes.

---

## **Security Notes**

* All private keys should be managed securely.
* Bastion is the only publicly accessible node.
* Consider Ansible Vault for storing secrets.
