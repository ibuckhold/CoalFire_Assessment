# USER DATA
locals {
  instance_userdata = <<USERDATA
#!/bin/bash
sudo dnf install -y httpd
sudo systemctl enable httpd
sudo systemctl start httpd
USERDATA
}