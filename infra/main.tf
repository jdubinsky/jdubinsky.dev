provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "cloudfront-acm-certs"
  region = "us-east-1"
}

data "archive_file" "zip" {
  type        = "zip"
  source_dir  = "../src/build"
  output_path = "jdev-lambda.zip"
}

resource "aws_acm_certificate" "cert" {
  provider                  = aws.cloudfront-acm-certs
  domain_name               = "*.jdubinsky.dev"
  validation_method         = "EMAIL"
  subject_alternative_names = ["jdubinsky.dev"]
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn = aws_acm_certificate.cert.arn
}

resource "aws_route53_zone" "root_domain" {
  name = "jdubinsky.dev"
}

resource "aws_api_gateway_stage" "api_prod_stage" {
  stage_name    = "production"
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.prod_deploy.id
}

# The domain name to use with api-gateway
resource "aws_api_gateway_domain_name" "apigw_domain_name" {
  domain_name     = "jdubinsky.dev"
  certificate_arn = aws_acm_certificate.cert.arn
}

resource "aws_api_gateway_base_path_mapping" "apigw_path_map" {
  api_id      = aws_api_gateway_rest_api.api.id
  domain_name = aws_api_gateway_domain_name.apigw_domain_name.domain_name
  stage_name  = aws_api_gateway_stage.api_prod_stage.stage_name
}

resource "aws_route53_record" "r53rec" {
  name    = "jdubinsky.dev"
  type    = "A"
  zone_id = aws_route53_zone.root_domain.id

  alias {
    evaluate_target_health = true
    name                   = aws_cloudfront_distribution.apigw_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.apigw_distribution.hosted_zone_id
  }
}

resource "aws_route53_record" "r53rec-www" {
  name    = "www.jdubinsky.dev"
  type    = "A"
  zone_id = aws_route53_zone.root_domain.id

  alias {
    evaluate_target_health = true
    name                   = aws_cloudfront_distribution.apigw_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.apigw_distribution.hosted_zone_id
  }
}

data "aws_iam_policy_document" "policy" {
  statement {
    sid    = ""
    effect = "Allow"

    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.policy.json
}

resource "aws_api_gateway_rest_api" "api" {
  name        = "JDevAPI"
  description = "API GW for jdubinsky.dev personal site"

  binary_media_types = ["*/*"]
}

resource "aws_api_gateway_method" "proxy_root" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_deployment" "prod_deploy" {
  depends_on = [
    aws_api_gateway_integration.lambda,
    aws_api_gateway_integration.lambda_root,
  ]

  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "prod"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_method.proxy.resource_id
  http_method = aws_api_gateway_method.proxy.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda.invoke_arn
}

resource "aws_api_gateway_integration" "lambda_root" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_method.proxy_root.resource_id
  http_method = aws_api_gateway_method.proxy_root.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda.invoke_arn
}

# Lambda
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_lambda_function" "lambda" {
  function_name = "jdubinsky-dev"

  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256

  role    = aws_iam_role.iam_for_lambda.arn
  handler = "index.handler"
  runtime = "nodejs10.x"

  memory_size = 256
  timeout     = 60

  environment {
    variables = {
      APP_PORT = 8080
      NODE_ENV = "production"
      API_HOST = "https://www.jdubinsky.dev/"
    }
  }
}

resource "aws_s3_bucket" "tfstate" {
  bucket = "jdev-tfstate-prod"
}

resource "aws_s3_bucket_policy" "tfstate_policy" {
  bucket = aws_s3_bucket.tfstate.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.tfstate.bucket}"
    },
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::${aws_s3_bucket.tfstate.bucket}/terraform.tfstate"
    }
  ]
}
POLICY
}
