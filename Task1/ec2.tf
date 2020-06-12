provider "aws"{
	region = "ap-south-1"
	profile = "default"

}

resource "aws_key_pair" "terraformKey" {
  key_name   = "myterrakey"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD3F6tyPEFEzV0LX3X8BsXdMsQz1x2cEikKDEY0aIj41qgxMCP/iteneqXSIFZBp5vizPvaoIR3Um9xK7PGoW8giupGn+EPuxIA4cDM4vzOqOkiMPhz5XK0whEjkVzTo4+S0puvDZuwIsdiW9mxhJc7tgBNL0cYlWSYVkz4G/fslNfRPW5mYAM49f4fhtxPb5ok4Q2Lg9dPKVHO/Bgeu5woMc7RY0p1ej6D4CKFE6lymSDJpW0YHX/wqE9+cfEauh7xZcG0q9t2ta6F6fmX0agvpFyZo8aFbXeUBr7osSCJNgvavWbM/06niWrOvYX2xwWdhXmXSrbX8ZbabVohBK41"

}


resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-d4e4f9bc"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "securityfromterraform"
  }
}

resource "aws_ebs_volume" "ebsfromterraform"{
	 availability_zone = "ap-south-1a"
         size              = 1

}


resource "aws_instance" "website"{
  ami = "ami-0447a12f28fddb066"
  availability_zone = "ap-south-1a"
  instance_type = "t2.micro"
  key_name ="keyforlogin_os"
  security_groups =["allow_tls"]

  depends_on = [
        aws_security_group.allow_tls,
				aws_key_pair.terraformKey
  ]
  connection{
      type = "ssh"
      user = "ec2-user"
      private_key = file("./keyforlogin_os.pem")
      host = aws_instance.website.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd"
    ]
}
  tags = {
    Name = "mywebsite"
  }
}


resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ebsfromterraform.id
  instance_id = aws_instance.website.id
	force_detach = true
}

resource "null_resource" "diskformat"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("./keyforlogin_os.pem")
    host     = aws_instance.website.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone  /var/www/html/"
    ]
  }
}


resource "aws_s3_bucket" "mybucket" {
	bucket = "mybucket"
	acl = "public-read"
	tags = {
		Name = "mybucket"
	}
}

resource "aws_s3_bucket_object" "image" {
	bucket = "mybucket"
	key = "linux.png"
	source = "./linux.png"
	acl = "public-read"
}

locals {
	s3_origin_id = "s3-origin"
}

resource "aws_cloudfront_distribution" "task1cloudfront" {
	enabled = true
	is_ipv6_enabled = true

	origin {
		domain_name = aws_s3_bucket.mybucket.bucket_regional_domain_name
		origin_id = local.s3_origin_id
	}

	restrictions {
		geo_restriction {
			restriction_type = "none"
		}
	}

	default_cache_behavior {
		target_origin_id = local.s3_origin_id
		allowed_methods = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    	cached_methods  = ["HEAD", "GET", "OPTIONS"]

    	forwarded_values {
      		query_string = false
      		cookies {
        		forward = "none"
      		}
		}

		viewer_protocol_policy = "redirect-to-https"
    	min_ttl                = 0
    	default_ttl            = 120
    	max_ttl                = 86400
	}

	viewer_certificate {
    	cloudfront_default_certificate = true
  	}
}
