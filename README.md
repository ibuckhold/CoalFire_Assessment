# CoalFire_Assessment
My Repo for CoalFire's Interview assessment

Documentation:

Terraform 
- Install Homebrew (a package manager) to install terraform:   https://brew.sh/
- Install HashiCorp tap using :    brew tap hashicorp/tap
- Install Terraform using :    brew install hashicorp/tap/terraform
- Ensure the download was successful by using :     terraform -help

AWS
- Install the AWS CLI :   https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
- Ensure your credentials are set to your AWS account under the "~/.aws/credentials folder"

Getting Started:

- Ensure that the "profile" on line 12 is set to your correct credentials
- Initialize the Project using :    terraform init
- Create an excecution plan and preview it using :    terraform plan 
- If the plan matches expection, excecute the actions using :   terraform apply

Resources Used:

https://learn.hashicorp.com/tutorials/terraform/infrastructure-as-code?in=terraform/aws-get-started
Started the Terraform tutorial after recieving the technical assessment

https://registry.terraform.io/providers/aaronfeng/aws/latest/docs  
Referred to the Docs for almost everything, using all the tabs for aws resources

https://www.youtube.com/watch?v=qePhmKyZfcM
This video helped me understand how to set up an auto-scaling group as well as an application load balancer in terraform with a great explanation

https://stackoverflow.com/questions/64818807/terraform-aws-route-table-association-add-multiple-subnet
This showed me how to create an association with my subnets and route tables 

https://stackoverflow.com/questions/69030719/how-to-add-a-load-balancer-to-an-ec2-instance-using-terraform
Was using aws_elb (classic) instead of aws_lb (application)

https://medium.com/@mehul20042001/aws-vpc-with-subnets-and-nat-gateway-using-terraform-11735ff67491
This showed me how to configure the NAT gateway and create an EIP 

https://www.reddit.com/r/Terraform/comments/bitrln/using_root_block_device_in_the_ec2_module/
This showed me to use root_block_device and not ebs_block_device

https://dev.to/chefgs/create-apache-web-server-in-aws-using-terraform-1fpj
This showed me how to script the installation of Apache onto my instances