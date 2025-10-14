pipeline {
    agent any

    parameters {
        string(name: 'BACKEND_BUCKET', defaultValue: 'amin-terraform-s33', description: 'S3 bucket name for Terraform backend')
        string(name: 'TF_WORKDIR', defaultValue: '.', description: 'Directory containing Terraform files')
    }

    options {
        timestamps()
    }

    environment {
        AWS_CREDENTIALS_ID = 'aws-academy'
        PATH = "$HOME/bin:$PATH"
    }

    stages {

        stage('Checkout Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/AhmedAminIV/k8sCluster-AWS-IaaC.git'
            }
        }

        stage('Setup AWS Credentials') {
            steps {
                withCredentials([[ $class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}" ]]) {
                    sh '''
                        echo "AWS credentials configured."
                        aws sts get-caller-identity || true
                    '''
                }
            }
        }

        stage('Install Dependencies') {
            steps {
                script {
                    installTerraform()
                    installAnsible()
                }
            }
        }

        stage('Update Terraform Backend') {
            steps {
                script {
                    def s3Bucket = params.BACKEND_BUCKET ?: "default-terraform-backend-bucket"
                    sh """
                        echo "Updating backend.tf with S3 bucket: ${s3Bucket}"
                        if [ -f "${params.TF_WORKDIR}/backend.tf" ]; then
                          sed -i "s|bucket *= *\\\".*\\\"|bucket = \\\"${s3Bucket}\\\"|" ${params.TF_WORKDIR}/backend.tf
                        else
                          echo "backend.tf not found under ${params.TF_WORKDIR}/"
                        fi
                    """
                }
            }
        }

        stage('Terraform Init & Apply') {
            steps {
                withCredentials([[ $class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}" ]]) {
                    dir("${params.TF_WORKDIR}") {
                        sh '''
                            echo "Initializing Terraform..."
                            terraform init -input=false

                            echo "Validating Terraform configuration..."
                            terraform validate || true

                            echo "Planning infrastructure changes..."
                            terraform plan -out=tfplan -input=false

                            echo "Applying Terraform plan..."
                            terraform apply -auto-approve tfplan

                            echo "Saving Terraform output..."
                            terraform output -json > ../terraform-output.json || true
                        '''
                    }
                }
            }
        }

        stage('Run Ansible Playbook') {
            steps {
                script {
                    sh '''#!/bin/bash
                    
                    echo "Configuring SSH for Ansible..."
                    eval $(ssh-agent -s)
                    KEY_PATH="cluster_key.pem"

                    if [ -f "./${KEY_PATH}" ]; then
                        chmod 600 "./${KEY_PATH}"
                        ssh-add "./${KEY_PATH}"
                    elif [ -f "${params.TF_WORKDIR}/${KEY_PATH}" ]; then
                        chmod 600 "${params.TF_WORKDIR}/${KEY_PATH}"
                        ssh-add "${params.TF_WORKDIR}/${KEY_PATH}"
                    else
                        echo "SSH key not found. Terraform might not have created one."
                    fi
                    
                    echo "Running Ansible Playbook..."
                    source /var/lib/jenkins/ansible-env/bin/activate
                    
                    if [ -f "./ansible/k8s_setup.yml" ]; then
                        ansible-playbook -i ./ansible/inventory ./ansible/k8s_setup.yml
                    elif [ -f "./k8s_setup.yml" ]; then
                        ansible-playbook -i ./inventory ./k8s_setup.yml
                    else
                        echo "Ansible playbook not found!"
                        exit 1
                    fi
                    '''
                }
            }
        }
    }

    post {
        always {
            echo 'Pipeline execution finished.'
        }
        success {
            echo 'Infrastructure and Kubernetes cluster deployed successfully.'
        }
        failure {
            echo 'Pipeline failed. Check logs above for details.'
        }
    }
}
