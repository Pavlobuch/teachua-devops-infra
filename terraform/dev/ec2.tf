data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "ec2_key" {
  key_name   = "cheap-fullstack"
  public_key = file(pathexpand(var.public_key_path))
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ec2-key"
  })
}

resource "aws_instance" "app" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  subnet_id                   = aws_subnet.public.id
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  key_name                    = aws_key_pair.ec2_key.key_name
  associate_public_ip_address = true
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ec2-app"
  })
}

resource "aws_instance" "monitoring" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }
  vpc_security_group_ids      = [aws_security_group.monitoring_sg.id]
  subnet_id                   = aws_subnet.public.id
  private_ip                  = "10.20.1.100"
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  key_name                    = aws_key_pair.ec2_key.key_name
  associate_public_ip_address = true
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ec2-monitoring"
  })
}