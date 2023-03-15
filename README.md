# Building a Secure and Scalable Node.js Application on AWS with Terraform, Nginx Reverse Proxy, and Python Healthchecks

## Problem Statement
- Design and implement a secure and reliable public web service on AWS using Terraform and Nginx reverse proxy
- Configure the service to only allow external access on port 80 and 443
- Redirect traffic from port 80 to 443 while restricting access to paths starting with "/internal/..."
- Service must return the current time on "/now" and run behind an Nginx reverse proxy to proxy pass to port 3000
- The Nginx reverse proxy should be configured to redirect traffic from port 80 to 443
- Add autoscaling and loadbalancing to the service
- Utilize a Python healthcheck script to periodically check if the service is up and running

## Provisioning and Deploying the service on AWS using Terraform

### Tools Required
- AWS account
- Terraform: Infrastructure as a code tool for creating and managing infrastructure. You can download and install Terraform by following the instructions in the [Terraform documentation](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
- Visual Studio Code: Code editor with built-in support for Git and other tools. You can download and install Visual Studio Code by following the instructions in the [VS Code documentation](https://code.visualstudio.com/download)
- Terraform Extension in VS Code

### Instructions for Running the Terraform Script
- Clone this repository in VS Code
- In the `terraform.tfvars` file enter your AWS access and secret keys in double quote.
```
aws_access_key = "YOUR_AWS_ACCESS_KEYS"
aws_secret_key = "YOUR_AWS_SECRET_KEY"
```
- In the `deploy_service.tf` file change the `key_name` to your AWS account's key name on line 172 and save the file.
```
key_name = "AWS-KEY"
```
- To download the provider plugins and modules, run the following command in VS code terminal
```
terraform init 
```
- If the initialization is successful you will get the following message in terminal
![image](https://user-images.githubusercontent.com/56789226/225116381-dab31331-6427-4e46-ae2a-cff34ce6a1f1.png)
- To preview the changes that Terraform will make to your AWS infrastructure based on your current Terraform configuration use the following command
```
terraform plan
```
![image](https://user-images.githubusercontent.com/56789226/225116827-288ad3ef-06ea-451a-b9a7-b5b3c29fa712.png)
- To apply the changes defined in your terraform configuration files to your infrastructure use
```
terraform apply 
```
- Now you can see in your AWS `us-east-1` region, VPC, Subnets, Security Group, Load Balancer, Auto Scaling Groups and EC2 instance running our `Devops-Service` is successfully created
- Now to check whether our service is running according to the defined tasks copy the `public_ip` of EC2 instance named `Devops-service` and in the browser type `public_ip` and hit enter. You can see that `http://public_ip` has successfully redirected to `https://public_ip`  which can be seen by double pressing on URL. As we don't have SSL certificate it will show `ERR_SSL_PROTOCOL_ERROR`. But upon checking the URL we can see that we have successfully redirected from HTTP to HTTPS ( i.e from Port 80 to 443)

![image](https://user-images.githubusercontent.com/56789226/225118147-d1c59caf-a68d-4fcc-b7f7-8cb6108c3172.png)
![image](https://user-images.githubusercontent.com/56789226/225118198-3b704159-0597-486c-a476-dfa1e1a34ffc.png)
- We know that our Node-js application is running on port 3000 and using the `/now` path, we can access the current time. But we don't want to expose our port 3000 to public. Therefore we have used Nginx Reverse proxy to proxy pass. As soon as we type `http://public_ip:443/now` and hit enter it will proxy pass to our `http://public_ip:3000/now` and show us the current time.

![image](https://user-images.githubusercontent.com/56789226/225119843-464fd00b-5940-4859-84e7-340398196375.png)
- Access to the path starting `/internal/.../` is successfully denied access and returns an HTTP 403 Forbidden response to any requests that match the specified path pattern

![image](https://user-images.githubusercontent.com/56789226/225120245-84c94208-6e5b-4a01-be19-85339ace401c.png)

## Healthcheck script in Python to periodically check if the service is up
### Tools Required
- Python 3 
- VS Code
- Python Extension In VS Code

### Instructions for Running the Python Script
- Create a virtual python environment using 
```
python3 -m venv env
```
- Virtual environment with the name `env` will be created
- To activate the virtual environment use
```
source env/bin/activate
```
- To install the dependencies 
```
pip install -r requirements.txt
```
- To run the healthcheck script use the command
```
python3 healthcheck.py <public_ip_address>
```
- Once we enter the above command, the code sends a GET request to the URL `http://{args.ip.address}:443/healthz` using python requests library. If the response status code is not 200 the code prints that the service is down. If the status code is 200 it again sends a GET request to `http://{args.ip_address}:443/now` if the response status code is again 200 it prints `Service is healthy` and current time. The service keeps sending GET request to `/healthz` endpoint after every 30 seconds.

![image](https://user-images.githubusercontent.com/56789226/225127358-63738e96-8518-4b2e-b4e1-ce75e0ab36be.png)





















