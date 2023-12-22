===========================================================================================

Terraform - GIT - SonarQube - Trivy - DockerHub - EKS
------------------------------------------------------

===========================================================================================

1. Create EC2 instance using Terraform

   main.tf 
	- t2.large
	- keyname: Linux-VM-Key7
	- Vol Size: 40G
	- Ingress: [22, 80, 443, 8080, 9000, 3000]

   provider.tf   
	- aws ~>5.0
	- region: us-east-1 or ap-south-1

   install.sh
	- jdk temurin-17-jdk
	- jenkins (Ex: jenkins --version 2.426.2)
	- install docker (docker version Ex: 24.0.5) 
	- sonarqube (from Dockerhub) as a container in the EC2 (Ex: http://54.213.190.162:9000/api/server/version Ex: Version: 9.9.3.79811) 
	- install trivy (trivy --version Ex: Version: 0.48.1)

===========================================================================================

2. Create a user
	- user: clouduser
	- grant Admin access
	- Security creds: Create Access Key: clouduser

===========================================================================================

3. Terminal
	- aws configure 
	- access key/secret key
	- Download the CSV file

===========================================================================================

4. Terraform
	- init, plan, apply

===========================================================================================

5. Configure Jenkins
	- ssh to the EC2: ssh -i key ubuntu@<<Public IP>>
  	
  	- http://<<Public IP>>:8080
	  	- install suggested plugins
	  	- create an admin user/password

  	- Jenkins => plugins: Install   
	  	- Eclipse Temurin installer
	  	- SonarQube Scanner
	  	- Sonar Quality Gates
	  	- Quality Gates
	  	- NodeJS 1.6.1
	  	- Docker 
	  	- Docker Commons
	  	- Docker Pipeline
	  	- Docker API
	  	- docker-build-step

  	- Tools:
	  	- Manage Jenkins => Tools
	  	- Add NodeJS => node16

  	- JDK installation
  		- jdk17 => Add installer => install from adoptium.net => jdk-17.0.8.1+1

  	- Docker: Add docker
  		- docker => Install automatically => Add installer => latest => Download from docker

  	- SonarQube:
  		- sonarqube-scanner => Install automatically => Install from Maven Central : 5.0.1.3006
      
    - Apply => Save
  
    - Note: If you wante to remove the warnings on:
	    - 	Quality Gates Plugin 2.5
	    - 	Sonar Quality Gates Plugin 1.3.1
         - => Configure which of these warnings are shown => Hidden security warnings => Remove checkboxes

===========================================================================================

6. Configure SonarQube and Integrate with Jenkins
 	- SonarQube is running as a container in the EC2 instance
 		- http://<<Public IP>>:9000
 		- Set new admin pw

 	- Generate the Token on SonarQube
 		- Use the token to integrate the SonarQube with Jenkins
 		- Administration => Security => Click on Tokens (Update Tokens) => jenkins-sonarqube-token (Ex: token-for-jenkins) => Copy Token
   		- Ex: squ_cd96a91b6f3260f12872d8c353682de05245df00	

 	- Jenkins => Manage Jenkins => Credentials (Global credentials (unrestricted))
 		- => Add Credentials => Secret Text => ID:SonarQube-Token => Secret: Paste Token => Create

 	- Jenkins => Manage Jenkins => System => SonarQube servers 
	 	- => Name: SonarQube-Server => URL: http://<<privateEC2IP>>:9000
	 	- => Server authentication token: Select the token (Ex: jenkins-sonarqube-token) => Apply => Save	

 	- SonarQube UI:
  		- => http://<<Public IP>>:9000 => Quality Gates (Menu option) => Create 
 		- => SonarQube-Quality-Gate => Save

    	- Create Webhook via SonarQube UI (to integrate with the Jenkins)
     		- http://<<Public IP>>:9000 => Adminstration => Configuration => Webhooks => Create
    		- => jenkins => URL: http://<<privateEC2IP>>:8080/sonarqube-webhook => Create
      		- Ex: http://172.31.27.171:8080/sonarqube-webhook/ 	
   		- => Verify

===========================================================================================    

7. Create Jenkins Pipeline to Build and Push Docker Image to DockerHub
	
 	- Jenkins => New Item => Name: Swiggy-CICD => Pipeline => Ok
		- => Discard old builds: Max # of builds: 2 	

	- Pipeline Script: Copy the steps until Trivy first
		- => (
  		- => tools:
    		- => jdk, nodejs in jenkins, 
		- => environment: Scanner_Home: 'sonarqube-scanner',  
		- => clean the workspace
		- => checkout from github => privide the git repo url with .git
		- => Sonarqube-Analysis => Provide project name: Swiggy-CICD && project key: Swiggy-CICD
		- => Quality Gate: Cred Token: 'SonarQube-Token' to connect SonarQube to Jenkins
		- => Install Dependencies
		- => Trivy FS Scan
		- => )
		- => Apply => Save
		- => => Build Now

	- Example:

			pipeline{
			     agent any
			     
			     tools{
				 jdk 'jdk17'
				 nodejs 'node16'
			     }
			     environment {
				 SCANNER_HOME=tool 'sonarqube-scanner'
			     }
			     
			     stages {
				 stage('Clean Workspace'){
				     steps{
					 cleanWs()
				     }
				 }
				 stage('Checkout from Git'){
				     steps{
					 git branch: 'main', url: 'https://github.com/cubejar/a-swiggy-clone'
				     }
				 }
				 stage("Sonarqube Analysis "){
				     steps{
					 withSonarQubeEnv('SonarQube-Server') {
					     sh ''' $SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=Swiggy-CI \
					     -Dsonar.projectKey=Swiggy-CI '''
					 }
				     }
				 }
				 stage("Quality Gate"){
				    steps {
					 script {
					     waitForQualityGate abortPipeline: false, credentialsId: 'SonarQube-Token' 
					 }
				     } 
				 }
				 stage('Install Dependencies') {
				     steps {
					 sh "npm install"
				     }
				 }
				 stage('TRIVY FS SCAN') {
				     steps {
					 sh "trivy fs . > trivyfs.txt"
				     }
				 }
			   }
			}		   

   

===========================================================================================

8. Verify the SonarQube dashboard
   - http://<<privateEC2IP>>:9000 => Projects => Swiggy-CICD

===========================================================================================

9. Configure pipeline to build the docker image and Push into DockerHub
   - Integrate the DockerHub to Jenkins
   - hub.docker.com => Account Settings => Security => Create Access Token
   - http://<<privateEC2IP>>:8080 => Manage Jenkins => Credentails => Security 
   - => Add Credentails => Username with Password => Username: DockerHub username
   - => Password: DockerHub Access Token
   - => ID: dockerhub 
   - => Create
   - => Verify 
   - (The dockerhub access credentials has added to the Jenkins using the DockerHub Token)

===========================================================================================

10. Add stage for the Docker Build and Push
   - Jenkins => Pipeline => Configure => Add the stage/step
   - => credid: dockerhub, toolname: docker
   - => build image
   - => tag: Tag the image name: dockerhub user/<<IMAGE>>:latest
   - => docker push

   - => Note: Add the following stages:
     
				stage("Docker Build & Push"){
			             steps{
			                 script{
			                    withDockerRegistry(credentialsId: 'dockerhub', toolName: 'docker'){   
			                        sh "docker build -t swiggy-clone ."
			                        sh "docker tag swiggy-clone cubejar/swiggy-clone:latest"
			                        sh "docker push cubejar/swiggy-clone:latest "
			                     }
			                 }
			             }
			         }

  
===========================================================================================

11. Add stage to scan the DockerHub image
   - Jenkins => Pipeline => Configure => Add the stage/step
   - => Trivy
   - => Apply
   - => Save


			         stage("TRIVY"){
			             steps{
			                 sh "trivy image cubejar/swiggy-clone:latest > trivyimage.txt" 
			             }
			         }


Note: trivy scan results
   - => Login to EC2 instance 
   - => You can find the trivy scan results here: /var/lib/jenkins/workspace/Swiggy-CICD/trivyimage.txt

===========================================================================================

12. Build and verify the docker image in DockerHub

===========================================================================================

13. Setup to create AWS EKS cluster and Download the Config/Secret file for the EKS cluster
   - Install the kubectl in the EC2   
   - => apt update
   - => install curl
   - => kubectl version --client

   - Install AWS CLI
   - => unzip
   - => sudo ./aws/install
   - => aws --version

   - Install EKSCTL
   - => eksctl version: 0.164.0

   - Create and add IAM role to the EC2 instance
   - => IAM => Roles => Create Role => AWS Service => EC2 => Admin => name: "eksctl_role" => Create

   - EC2 => Actions => Security => Modify IAM => Select the IAM role: "eksctl_role" => Update
     
   - Example:

		# 1--Install kubectl on Jenkins

			 sudo apt update
			 sudo apt install curl
			 curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl
			 sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
			 kubectl version --client
		
		# 2--Install AWS Cli
		
			curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
			sudo apt install unzip
			unzip awscliv2.zip
			sudo ./aws/install
			aws --version
			
		# 3--Installing  eksctl
		
			curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
			cd /tmp
			sudo mv /tmp/eksctl /bin
			eksctl version
		
		# 4--Setup Kubernetes using eksctl
			Refer--https://github.com/aws-samples/eks-workshop/issues/734
			eksctl create cluster --name virtualtechbox-cluster \
			--region ap-south-1 \
			--node-type t2.small \
			--nodes 3 \
			5-- Verify Cluster with below command
			$ kubectl get nodes
			$ kubectl get svc

===========================================================================================

14. Create EKS cluster
    - => eksctl create cluster --name <<NAME>> --region <<REGION>> --node-type t2.small --nodes 3

===========================================================================================

15. Copy and rename the KubeConfig file 
   - kubeconfig file location => /home/ubuntu/.kube/config 
   - => Save a copy from /home/ubuntu/.kube/config /home/ubuntu/secret.txt => Copy out this file
   - => This file will be used to integrate the Jenkins with EKS cluster

   - => kubectl get nodes
   - => kubectl get svc

===========================================================================================

16. Configure the Jenkins Pipeline to Deploy Application on EKS
   - Integrate the Jenkins with AWS EKS cluster, we need to update the jenkins pipeline
   - Jenkins => Deploy 4 plugins => Available plugins => Kubernetes 
   - => Kubernetes
   - => Kubernetes Credentials
   - => Kubernetes Client API
   - => Kubernetes CLI
   - => Install
     
===========================================================================================

17. Add the Kubernetes Credentials in Jenkins
   - Manage Jenkins => Credentials => Add Cred => Kind: Secret File => ID: kubernetes
   - => Choose File => Select the secret.txt => Create

===========================================================================================

18. Update the Jenkins pipeline
   - Steps: Deploy to Kubernetes
   - Pipeline Syntaz: Select: WithKubeConfig: Configure Kubernetes CLI (kubectl) 
   - => Cred Name: kubernetes(secret.txt)            
   - => Generate pipeline script
   - => Apply => Save

===========================================================================================

19. Git hub repo:
   - It has the kubernetes manifest file
   - Deploy.yaml: selector name and svc name to be matched
   - image: name to be matched the dockerhub image name
   - Svc.yaml: Type: LoadBalancer
   - App name to be matched the selector

===========================================================================================

20. Set the Trigger and verify the CICD pipeline
   - Jenkins => Configure => GitHub Project: GITPROJECTURL
   - => Build Trigger => GitHub hook trigger for GITScm polling

   - GitHub: Select the project => Settings => Webhooks => Add Webhooks => Payload URL
   - => <<Enter the Jenkins URL>>/github-webhook/
   - => Add Webhooks
   - => Refresh
   - => Verify

===========================================================================================

21. Verify the CICD trigger functionality by modifying any of the file and commit the changes
   - Edit the ReadMe.md file
     push into the GIT

   - Veify the Jenkins pipeline

   - Veify the DockerHub and refresh

   - EC2 => kubectl get pods
   - kubectl get svc
   - Select the DNS name from the service to access via the browser

   - Edit the file. Example /src/Components/OffersBanner file
   - push into the GIT     
   - Verify

===========================================================================================
