provider "aws" {
   access_key = "YOUR GENERATED ACCESS ID"
   secret_key = "YOUR GENERATED SECRET KEY"
   region     = "us-east-1"
}

variable "root_domain_name" {
   default = "frontend.domain.tld"
}

variable "application_subdomain" {
   default = "frontend.${var.root_domain_name}"
}

// Define S3

resource "aws_s3_bucket" "s3_bucket" {
   bucket = "${var.application_subdomain}"
   acl    = "public-read"
   policy = <<POLICY
{
  "Version":"2012-10-17",
  "Statement":[{
    "Sid":"AddPerm",
    "Effect":"Allow",
    "Principal": "*",
    "Action":["s3:GetObject"],
    "Resource":["arn:aws:s3:::${var.application_subdomain}/*"]
  }]
}
POLICY
  website {
    index_document = "index.html"
    error_document = "index.html"
  }
}

// Define CloudFront Distribution

resource "aws_cloudfront_distribution" "frontend_cloudfront_distribution" {
  origin {
    custom_origin_config {
      http_port              = "80"
      origin_protocol_policy = "http-only"
    }
    domain_name = "${aws_s3_bucket.s3_bucket.website_endpoint}"
    origin_id   = "${var.application_subdomain}"
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    viewer_protocol_policy = "http-only"
    compress               = true
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "${var.application_subdomain}"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  custom_error_response {
    error_caching_min_ttl = 3000
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
  }

  aliases = ["${var.application_subdomain}"]

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

//  Route53

data "aws_route53_zone" "zone" {
  name         = "${var.root_domain_name}"
  private_zone = false
  most_recent  = true
}

resource "aws_route53_record" "frontend_record" {
  zone_id = "${data.route53_zone.zone_id}"
  name    = "${var.application_subdomain}"
  type    = "A"
  alias = {
    name = "${aws_cloudfront_distribution.frontend_cloudfront_distribution.domain_name}"
    zone_id = "${aws_cloudfront_distribution.frontend_cloudfront_distribution.hosted_zone_id}"
    evaluate_target_health = false
  }
}
