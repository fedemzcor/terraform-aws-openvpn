

resource "aws_eip" "openvpn_eip" {
  vpc        = true
}

variable "vpc_id" {}

variable "subnet_id" {}

variable "public_key" {}

variable "private_key" {}

resource "aws_key_pair" "openvpn" {
  key_name   = "openvpn-key"
  public_key = "${file(var.public_key)}"
}

variable "ssh_user" {
  default = "openvpnas"
}

variable "ssh_port" {
  default = 22
}

variable "ssh_cidr" {
  default = "0.0.0.0/0"
}

variable "https_port" {
  default = 443
}

variable "http_port" {
  default = 80
}
variable "https_cidr" {
  default = "0.0.0.0/0"
}

variable "http_cidr" {
  default = "0.0.0.0/0"
}
variable "tcp_port" {
  default = 943
}

variable "tcp_cidr" {
  default = "0.0.0.0/0"
}

variable "udp_port" {
  default = 1194
}

variable "udp_cidr" {
  default = "0.0.0.0/0"
}

resource "aws_security_group" "openvpn" {
  name        = "openvpn_sg"
  description = "Allow traffic needed by openvpn"
  vpc_id      = "${var.vpc_id}"

  // ssh
  ingress {
    from_port   = "${var.ssh_port}"
    to_port     = "${var.ssh_port}"
    protocol    = "tcp"
    cidr_blocks = ["${var.ssh_cidr}"]
  }

  // http
  ingress {
    from_port   = "${var.http_port}"
    to_port     = "${var.http_port}"
    protocol    = "tcp"
    cidr_blocks = ["${var.http_cidr}"]
  }

  // https
  ingress {
    from_port   = "${var.https_port}"
    to_port     = "${var.https_port}"
    protocol    = "tcp"
    cidr_blocks = ["${var.https_cidr}"]
  }

  // open vpn tcp
  ingress {
    from_port   = "${var.tcp_port}"
    to_port     = "${var.tcp_port}"
    protocol    = "tcp"
    cidr_blocks = ["${var.tcp_cidr}"]
  }

  // open vpn udp
  ingress {
    from_port   = "${var.udp_port}"
    to_port     = "${var.udp_port}"
    protocol    = "udp"
    cidr_blocks = ["${var.udp_cidr}"]
  }

  // all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

variable "route53_zone_name" {}
variable "subdomain_name" {}

variable "subdomain_ttl" {
  default = "60"
}

data "aws_route53_zone" "main" {
  name = "${var.route53_zone_name}"
}

resource "aws_route53_record" "vpn" {
  zone_id = "${data.aws_route53_zone.main.zone_id}"
  name    = "${var.subdomain_name}"
  type    = "A"
  ttl     = "${var.subdomain_ttl}"
  records = ["${aws_instance.openvpn.public_ip}"]
}

variable "ami" {
  default = "ami-f53d7386" // ubuntu xenial openvpn ami in eu-west-1
}

variable "instance_type" {
  default = "t2.micro"
}

variable "admin_user" {
  default = "openvpn"
}

variable "admin_password" {
  default = "openvpn"
}

resource "aws_instance" "openvpn" {
  tags {
    Name = "openvpn"
  }

  ami                         = "${var.ami}"
  instance_type               = "${var.instance_type}"
  key_name                    = "${aws_key_pair.openvpn.key_name}"
  subnet_id                   = "${var.subnet_id}"
  vpc_security_group_ids      = ["${aws_security_group.openvpn.id}"]
  associate_public_ip_address = true

  # `admin_user` and `admin_pw` need to be passed in to the appliance through `user_data`, see docs -->
  # https://docs.openvpn.net/how-to-tutorialsguides/virtual-platforms/amazon-ec2-appliance-ami-quick-start-guide/
  user_data = <<USERDATA
admin_user=${var.admin_user}
admin_pw=${var.admin_password}
USERDATA
}

variable "certificate_email" {}

resource "null_resource" "provision_openvpn" {
  triggers {
    subdomain_id = "${aws_route53_record.vpn.id}"
  }

  connection {
    type        = "ssh"
    host        = "${aws_instance.openvpn.public_ip}"
    user        = "${var.ssh_user}"
    port        = "${var.ssh_port}"
    private_key = "${file(var.private_key)}"
    agent       = false
  }

  provisioner "file" {
    source      = "script.sh"
    destination = "/home/openvpnas/script.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/openvpnas/script.sh",
      "sh /home/openvpnas/script.sh ${var.certificate_email} ${var.subdomain_name}",
    ]
  }
  
}
