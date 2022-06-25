resource "aws_vpc" "mco_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}


resource "aws_subnet" "mco_public_subnet" {
  vpc_id                  = aws_vpc.mco_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-2a"

  tags = {
    Name = "dev-public"
  }
}


resource "aws_internet_gateway" "mco_internet_gateway" {
  vpc_id = aws_vpc.mco_vpc.id

  tags = {
    Name = "dev-igw"
  }
}

resource "aws_route_table" "mco_public_rt" {
  vpc_id = aws_vpc.mco_vpc.id

  tags = {

    Name = "dev_public_rt"

  }

}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.mco_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.mco_internet_gateway.id
}


resource "aws_route_table_association" "mco_public_asso" {
  subnet_id      = aws_subnet.mco_public_subnet.id
  route_table_id = aws_route_table.mco_public_rt.id
}

resource "aws_security_group" "mco_sg" {
  name   = "dev_sg"
  vpc_id = aws_vpc.mco_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["82.76.153.174/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_key_pair" "mco_auth" {
  key_name   = "mcokey"
  public_key = file("~/.ssh/mco-key.pub")
}

resource "aws_instance" "dev_node" {
  instance_type          = "t2.micro"
  ami                    = data.aws_ami.server_ami.id
  key_name               = aws_key_pair.mco_auth.id
  vpc_security_group_ids = [aws_security_group.mco_sg.id]
  subnet_id              = aws_subnet.mco_public_subnet.id
  user_data              = file("userdata.tpl")

  root_block_device {
    volume_size = 10
  }
  tags = {
    Name = "dev-node"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-config.tpl", {
      hostname     = self.public_ip
      user         = "ubuntu"
      identityfile = "~/.ssh/mco-key"
    })
    interpreter = ["bash", "-c"]
  }

}