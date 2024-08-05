provider "aws" {
  region = "us-west-2"
}

# External data source to fetch GitHub IP ranges
data "external" "github_hooks_ips" {
  program = ["bash", "${path.module}/fetch_github_ips.sh"]
}

locals {
  github_ips = [for k, v in data.external.github_hooks_ips.result : v]
}

# Get the current IP address
data "http" "my_ip" {
  url = "https://ipinfo.io/ip"
}

# Extract and validate the IP address
locals {
  my_ip = chomp(data.http.my_ip.response_body)
}

resource "aws_instance" "jenkins_server" {
  ami           = "ami-0440fa9465661a496" # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  key_name = "jenkins_key_pair"

  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]

  # Provisioner to run a script after the EC2 instance is created
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y docker",
      "sudo systemctl start docker",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "sudo useradd -m jenkins",
      "sudo usermod -aG docker jenkins",
      "sudo -u jenkins docker run -d -p 8080:8080 -p 50000:50000 --name jenkins jenkins/jenkins:lts",
      "sudo chown ec2-user:docker /var/run/docker.sock",
      "sudo chmod 660 /var/run/docker.sock"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/jenkins_key_pair.pem")  # Path to your private key file
      host        = self.public_ip
    }
  }

  tags = {
    Name = "JenkinsServer"
  }
}

resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins_sg"
  description = "Allow SSH and HTTP traffic from my IP"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${local.my_ip}/32"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["${local.my_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "instance_public_ip" {
  value = aws_instance.jenkins_server.public_ip
}

output "instance_public_dns" {
  value = aws_instance.jenkins_server.public_dns
}


output "github_hooks_ips" {
  value = data.external.github_hooks_ips
}