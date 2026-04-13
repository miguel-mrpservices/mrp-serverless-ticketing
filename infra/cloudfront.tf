# Auth config so CloudFront can pull from the private S3 bucket
resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "s3-cloudfront-oac"
  description                       = "OAC for CloudFront to access private S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# URI rewrite logic to handle subfolders and SPA routing
resource "aws_cloudfront_function" "rewrite_uri" {
  name    = "rewrite-index-requests"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = <<EOF
function handler(event) {
    var request = event.request;
    var uri = request.uri;
    
    // Add index.html to trailing slashes
    if (uri.endsWith('/')) {
        request.uri += 'index.html';
    } 
    // Map paths without extensions (clean URLs) to index.html
    else if (!uri.includes('.')) {
        request.uri += '/index.html';
    }
    
    return request;
}
EOF
}

# Main CDN distribution for the frontend
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
    origin_id                = "S3Origin"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  # Domain aliases
  aliases = ["mrpservices.tech", "www.mrpservices.tech"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3Origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    # Hook up the rewrite function to viewer requests
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.rewrite_uri.arn
    }
  }

  # SSL/TLS config with ACM cert
  viewer_certificate {
    acm_certificate_arn      = var.cert_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}