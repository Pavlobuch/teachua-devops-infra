pipeline {
    agent any

    parameters {
        string(name: 'BACKEND_IMAGE_TAG', defaultValue: '', description: 'Backend Docker image tag from ECR (leave empty to deploy latest)')
        string(name: 'FRONTEND_IMAGE_TAG', defaultValue: '', description: 'Frontend Docker image tag from ECR (leave empty to deploy latest)')
    }

    environment {
        AWS_REGION = 'eu-north-1'
        NAMESPACE = 'teachua'

        ECR_REGISTRY = '441955873558.dkr.ecr.eu-north-1.amazonaws.com'
        BACKEND_IMAGE = '441955873558.dkr.ecr.eu-north-1.amazonaws.com/teachua-dev-backend'
        FRONTEND_IMAGE = '441955873558.dkr.ecr.eu-north-1.amazonaws.com/teachua-dev-frontend'

        EC2_USER = 'ubuntu'
        KUBECONFIG_PATH = '/home/ubuntu/.kube/config'
    }

    stages {
        stage('Checkout Infra Repo') {
            steps {
                checkout scm
            }
        }

        stage('Get EC2 Host') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'aws-jenkins-ecr',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    script {
                        env.EC2_HOST = sh(
                            script: '''
                                aws ec2 describe-instances \
                                --region $AWS_REGION \
                                --filters "Name=tag:Name,Values=teachua-dev-ec2-app" "Name=instance-state-name,Values=running" \
                                --query "Reservations[0].Instances[0].PublicIpAddress" \
                                --output text
                            ''',
                            returnStdout: true
                        ).trim()
                    }

                    echo "EC2 host: ${env.EC2_HOST}"
                }
            }
        }

        stage('Verify Tools') {
            steps {
                sh 'git --version'
                sh 'aws --version'
                sh 'kubectl version --client'
                sh 'ssh -V'
            }
        }

        stage('Prepare Image Tags') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'aws-jenkins-ecr',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    script {
                        env.BACKEND_DEPLOY_TAG = params.BACKEND_IMAGE_TAG?.trim()
                        env.FRONTEND_DEPLOY_TAG = params.FRONTEND_IMAGE_TAG?.trim()

                        if (!env.BACKEND_DEPLOY_TAG) {
                            env.BACKEND_DEPLOY_TAG = sh(
                                script: '''
                                    aws ecr describe-images \
                                      --repository-name teachua-dev-backend \
                                      --region $AWS_REGION \
                                      --query 'sort_by(imageDetails[?imageTags!=null], &imagePushedAt)[-1].imageTags[0]' \
                                      --output text
                                ''',
                                returnStdout: true
                            ).trim()
                        }

                        if (!env.FRONTEND_DEPLOY_TAG) {
                            env.FRONTEND_DEPLOY_TAG = sh(
                                script: '''
                                    aws ecr describe-images \
                                      --repository-name teachua-dev-frontend \
                                      --region $AWS_REGION \
                                      --query 'sort_by(imageDetails[?imageTags!=null], &imagePushedAt)[-1].imageTags[0]' \
                                      --output text
                                ''',
                                returnStdout: true
                            ).trim()
                        }

                        echo "Backend deploy tag: ${env.BACKEND_DEPLOY_TAG}"
                        echo "Frontend deploy tag: ${env.FRONTEND_DEPLOY_TAG}"
                    }
                }
            }
        }

        stage('Create Namespace') {
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'ec2-ssh-key',
                    keyFileVariable: 'EC2_SSH_KEY'
                )]) {
                    sh '''
                        ssh -i "$EC2_SSH_KEY" \
                            -o StrictHostKeyChecking=no \
                            "$EC2_USER@$EC2_HOST" \
                            "export KUBECONFIG=/home/ubuntu/.kube/config && kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -"
                    '''
                }
            }
        }

        stage('Create or Update ECR Pull Secret') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'aws-jenkins-ecr',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    ),
                    sshUserPrivateKey(
                        credentialsId: 'ec2-ssh-key',
                        keyFileVariable: 'EC2_SSH_KEY'
                    )
                ]) {
                    sh '''
                        set +x

                        ECR_PASSWORD=$(aws ecr get-login-password --region $AWS_REGION)

                        ssh -i "$EC2_SSH_KEY" \
                            -o StrictHostKeyChecking=no \
                            "$EC2_USER@$EC2_HOST" \
                            "export KUBECONFIG=/home/ubuntu/.kube/config && kubectl create secret docker-registry ecr-registry-secret \
                                --docker-server=$ECR_REGISTRY \
                                --docker-username=AWS \
                                --docker-password='$ECR_PASSWORD' \
                                -n $NAMESPACE \
                                --dry-run=client -o yaml | kubectl apply -f -"
                    '''
                }
            }
        }

        stage('Attach Pull Secret to Default Service Account') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'ec2-ssh-key',
                        keyFileVariable: 'EC2_SSH_KEY'
                    )
                ]) {
                    sh '''
                        ssh -i "$EC2_SSH_KEY" \
                            -o StrictHostKeyChecking=no \
                            "$EC2_USER@$EC2_HOST" \
                            "export KUBECONFIG=/home/ubuntu/.kube/config && kubectl patch serviceaccount default \
                                -n $NAMESPACE \
                                -p '{\"imagePullSecrets\":[{\"name\":\"ecr-registry-secret\"}]}'"
                    '''
                }
            }
        }

        stage('Apply Kubernetes Manifests') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'ec2-ssh-key',
                        keyFileVariable: 'EC2_SSH_KEY'
                    )
                ]) {
                    sh '''
                        ssh -i "$EC2_SSH_KEY" \
                            -o StrictHostKeyChecking=no \
                            "$EC2_USER@$EC2_HOST" \
                            "export KUBECONFIG=/home/ubuntu/.kube/config && cd ~/teachua-devops-infra && git pull && kubectl apply -R -f kubernetes/"
                    '''
                }
            }
        }

        stage('Update Images') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'ec2-ssh-key',
                        keyFileVariable: 'EC2_SSH_KEY'
                    )
                ]) {
                    sh '''
                        ssh -i "$EC2_SSH_KEY" \
                            -o StrictHostKeyChecking=no \
                            "$EC2_USER@$EC2_HOST" \
                            "export KUBECONFIG=/home/ubuntu/.kube/config && kubectl set image deployment/backend backend=$BACKEND_IMAGE:$BACKEND_DEPLOY_TAG -n $NAMESPACE && \
                             kubectl set image deployment/frontend frontend=$FRONTEND_IMAGE:$FRONTEND_DEPLOY_TAG -n $NAMESPACE"
                    '''
                }
            }
        }

        stage('Verify Rolling Update') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'ec2-ssh-key',
                        keyFileVariable: 'EC2_SSH_KEY'
                    )
                ]) {
                    sh '''
                        ssh -i "$EC2_SSH_KEY" \
                            -o StrictHostKeyChecking=no \
                            "$EC2_USER@$EC2_HOST" \
                            "export KUBECONFIG=/home/ubuntu/.kube/config && kubectl rollout status deployment/backend -n $NAMESPACE --timeout=180s && \
                             kubectl rollout status deployment/frontend -n $NAMESPACE --timeout=180s"
                    '''
                }
            }
        }

        stage('Post Deploy Status') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'ec2-ssh-key',
                        keyFileVariable: 'EC2_SSH_KEY'
                    )
                ]) {
                    sh '''
                        ssh -i "$EC2_SSH_KEY" \
                            -o StrictHostKeyChecking=no \
                            "$EC2_USER@$EC2_HOST" \
                            "export KUBECONFIG=/home/ubuntu/.kube/config && kubectl get pods -n $NAMESPACE && \
                             kubectl get svc -n $NAMESPACE && \
                             kubectl get ingress -n $NAMESPACE"
                    '''
                }
            }
        }
    }
}