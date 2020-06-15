
provider "aws" {
  
  region = "ap-south-1"
  profile = "pushkar1"
}

variable "mykey" {
	type = string
	default = "mykey121"
}


resource "aws_instance" "inst" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name      = var.mykey
  security_groups = [ "security_group1" ]
  


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file    ("C:/Users/Lenovo/Desktop/mykey121.pem")
    host     = aws_instance.inst.public_ip
  }

  
  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
  
  tags = {
    Name = "pushkar"
  }
}

output "avail_zone" {
	value = aws_instance.inst.availability_zone
}

output "Vol_id" {
	value = aws_ebs_volume.myvol1.id
}

output "inst_id" {
	value = aws_instance.inst.id
}

resource "aws_ebs_volume" "myvol1" {
  availability_zone = aws_instance.inst.availability_zone
  size              = 1

 tags = {
    Name = "Pushkar_volume"
  }
}


resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.myvol1.id}"
  instance_id = "${aws_instance.inst.id}"
  force_detach = true
}

resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]

 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file    ("C:/Users/Lenovo/Desktop/mykey121.pem")
    host     = aws_instance.inst.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/pushkar02-op/multicloudtest1.git /var/www/html/"
    ]
  }
}
resource "null_resource" "nullremote2"  {

depends_on = [
    null_resource.nullremote3,
  ]

provisioner "local-exec" {
	    command = "start chrome  ${aws_instance.inst.public_ip}"
  	}
}

resource "aws_s3_bucket" "bucket" {
  bucket = "my-website-test-bucket"
  acl    = "public-read"

  tags = {
    Name        = "My bucket"
    
  }
  force_destroy = true

provisioner "local-exec" {
        command     = "git clone https://github.com/pushkar02-op/Mytaskimages  images"
    }
provisioner "local-exec" {
        when        =   destroy
        command     =   "echo Y | rmdir /s images"
    }
}
resource "aws_s3_bucket_object" "image-upload" {
    bucket  = aws_s3_bucket.bucket.bucket
    key     = "mypic1"
    source  = "images/mapbutton.jpg"
    acl     = "public-read"
}





locals {
  s3_origin_id = "mys3origin"
 image_url = "${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.image-upload.key}"
}





resource "aws_cloudfront_distribution" "s3_distribution" {

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

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
 enabled             = true

  origin {
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

   
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }


  viewer_certificate {
    cloudfront_default_certificate = true
  }


connection {
        type    = "ssh"
        user    = "ec2-user"
        host    = aws_instance.inst.public_ip
        port    = 22
        private_key = file    ("C:/Users/Lenovo/Desktop/mykey121.pem")
    }
provisioner "remote-exec" {
        inline  = [
            # "sudo su << \"EOF\" \n echo \"<img src='${self.domain_name}'>\" >> /var/www/html/test.html \n \"EOF\""
            "sudo su << EOF",
            "echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.image-upload.key}'>\" >> /var/www/html/test.html",
            "EOF"
        ]
    }
}