provider "aws" {
  region = "ap-south-1"
  profile = "Shashank"
}


resource "tls_private_key" "tls_key" {
  algorithm = "RSA"
}


//Generating Key-Value Pair

resource "aws_key_pair" "generated_key" {
  key_name   = "shank_key"
  public_key = tls_private_key.tls_key.public_key_openssh


  depends_on = [
    tls_private_key.tls_key
  ]
}

//Saving keyfile locally

resource "local_file" "key-file" {
  content  = tls_private_key.tls_key.private_key_pem
  filename = "shank_key.pem"


  depends_on = [
    tls_private_key.tls_key
  ]
}

resource "aws_security_group" "allow_80" {
  name        = "allow_80"
  description = "Allow port 80"
ingress {
    description = "incoming http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    description = "incoming ssh"
    from_port   = 22
    to_port     = 22
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
    Name = "allow_80"
  }
}

resource "aws_instance" "web" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "shank_key"
  security_groups = [ "allow_80" ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.tls_key.private_key_pem
    host     = aws_instance.web.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "lwos1"
  }

}


resource "aws_ebs_volume" "esb1" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1
  tags = {
    Name = "lwebs"
  }
}


resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.esb1.id}"
  instance_id = "${aws_instance.web.id}"
  force_detach = true
}

resource "aws_s3_bucket" "mybucket" {
  bucket = "my-tf-test-bucketsdjte12"
  acl    = "public-read"

  tags = {
    Name        = "My bucket11sdj"
    Environment = "Dev"
  }
}


resource "aws_s3_bucket_object" "web-object1" {
  bucket = "${aws_s3_bucket.mybucket.bucket}"
  key    = "What-is-Hybrid-Cloud.jpg"
  source = "What-is-Hybrid-Cloud.jpg"
  acl    = "public-read"
}

output "myout"{
  value=aws_s3_bucket_object.web-object1
}

//Creating CloutFront with S3 Bucket Origin
resource "aws_cloudfront_distribution" "s3-web-distribution" {
  origin {
    domain_name = "${aws_s3_bucket.mybucket.bucket_regional_domain_name}"
    origin_id   = "${aws_s3_bucket.mybucket.id}"
  }


  enabled             = true
  is_ipv6_enabled     = true
  comment             = "S3 Web Distribution"


  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.mybucket.id}"


    forwarded_values {
      query_string = false


      cookies {
        forward = "none"
      }
    }


    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }


  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IN"]
    }
  }


  tags = {
    Name        = "Web-CF-Distribution"
    Environment = "Production"
  }


  viewer_certificate {
    cloudfront_default_certificate = true
  }


  depends_on = [
    aws_s3_bucket.mybucket
  ]
}


output "myos_ip" {
  value = aws_instance.web.public_ip
}


resource "null_resource" "nulllocal2"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.web.public_ip} > publicip.txt"
  	}
}



resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att,aws_cloudfront_distribution.s3-web-distribution
  ]
  
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.tls_key.private_key_pem
    host     = aws_instance.web.public_ip
  }


provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/shank2512/hybrid_task1.git /var/www/html/",
      "sudo sed -i -e 's/cloud-front/${aws_cloudfront_distribution.s3-web-distribution.domain_name}/g' /var/www/html/index.html"
    ]
  }
}



resource "null_resource" "nulllocal1"  {


depends_on = [
    null_resource.nullremote3,
  ]

	provisioner "local-exec" {
	    command = "chrome  ${aws_instance.web.public_ip}"
  	}
}


