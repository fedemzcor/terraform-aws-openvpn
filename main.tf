

resource "aws_eip" "openvpn" {
  vpc        = true
}

/*
resource "aws_key_pair" "openvpn" {
  key_name   = "openvpn-key"
  public_key = "${file(var.public_key)}"
}

*/

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

resource "aws_route53_record" "vpn" {
  zone_id = "${data.aws_route53_zone.main.zone_id}"
  name    = "${var.subdomain_name}"
  type    = "A"
  ttl     = "${var.subdomain_ttl}"
  records = ["${aws_eip.openvpn.public_ip}"] // ["${aws_instance.openvpn.public_ip}"]
}


resource "aws_instance" "openvpn" {
  tags = {
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

resource "aws_eip_association" "eip_assoc" {

   depends_on = ["aws_instance.openvpn"]

  instance_id   = "${aws_instance.openvpn.id}"
  allocation_id = "${aws_eip.openvpn.id}"
}



resource "null_resource" "provision_openvpn" {

  depends_on = ["aws_instance.openvpn","aws_eip_association.eip_assoc"]

  triggers = {
    subdomain_id = "${aws_route53_record.vpn.id}"
    instance_id   = "${aws_instance.openvpn.id}"
  }
  
  connection {
    type        = "ssh"
    host        = "${aws_eip.openvpn.public_ip}"
    user        = "${var.ssh_user}"
    port        = "${var.ssh_port}"
    private_key = "${file(var.private_key)}"
    agent       = false
  }

  provisioner "file" {
    source      = "${path.module}/script.sh"
    destination = "/home/openvpnas/script.sh"
  }


  provisioner "remote-exec" {

    inline = [
      "sleep 440",
      "chmod +x /home/openvpnas/script.sh",
      "sh /home/openvpnas/script.sh ${var.certificate_email} ${var.subdomain_name}",
    ]
  }
  
}
