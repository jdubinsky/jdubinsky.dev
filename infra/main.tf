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
  provider          = "aws.cloudfront-acm-certs"
  domain_name       = "*.jdubinsky.dev"
  validation_method = "EMAIL"
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn = "${aws_acm_certificate.cert.arn}"
}

resource "aws_route53_zone" "root_domain" {
  name = "jdubinsky.dev"
}

# The domain name to use with api-gateway
resource "aws_api_gateway_domain_name" "apigw_domain_name" {
  domain_name     = "www.jdubinsky.dev"
  certificate_arn = "${aws_acm_certificate.cert.arn}"

}

resource "aws_api_gateway_base_path_mapping" "apigw_path_map" {
  api_id      = "${aws_api_gateway_rest_api.api.id}"
  domain_name = "${aws_api_gateway_domain_name.apigw_domain_name.domain_name}"
  stage_name  = "prod"
}

resource "aws_route53_record" "r53rec" {
  name    = "www.jdubinsky.dev"
  type    = "A"
  zone_id = "${aws_route53_zone.root_domain.id}"

  alias {
    evaluate_target_health = true
    name                   = "${aws_api_gateway_domain_name.apigw_domain_name.cloudfront_domain_name}"
    zone_id                = "${aws_api_gateway_domain_name.apigw_domain_name.cloudfront_zone_id}"
  }
}

resource "aws_route53_record" "r53rec2" {
  name    = "jdubinsky.dev"
  type    = "A"
  zone_id = "${aws_route53_zone.root_domain.id}"

  alias {
    evaluate_target_health = true
    name                   = "www.jdubinsky.dev"
    zone_id                = "${aws_route53_zone.root_domain.id}"
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
  assume_role_policy = "${data.aws_iam_policy_document.policy.json}"
}

resource "aws_api_gateway_rest_api" "api" {
  name        = "JDevAPI"
  description = "API GW for jdubinsky.dev personal site"
}

resource "aws_api_gateway_resource" "resource" {
  path_part   = "resource"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  resource_id   = "${aws_api_gateway_resource.resource.id}"
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_deployment" "apigw_prod_deploy" {
  depends_on  = ["aws_api_gateway_integration.integration"]
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  stage_name  = "prod"
}

resource "aws_api_gateway_stage" "api_prod_stage" {
  stage_name    = "prod"
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  deployment_id = "${aws_api_gateway_deployment.apigw_prod_deploy.id}"
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  resource_id             = "${aws_api_gateway_resource.resource.id}"
  http_method             = "${aws_api_gateway_method.method.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.lambda.arn}/invocations"
}

# Lambda
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda.function_name}"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.region}:${var.account_id}:${aws_api_gateway_rest_api.api.id}/*/${aws_api_gateway_method.method.http_method}${aws_api_gateway_resource.resource.path}"
}

resource "aws_lambda_function" "lambda" {
  function_name = "jdubinsky-dev"

  filename         = "${data.archive_file.zip.output_path}"
  source_code_hash = "${data.archive_file.zip.output_base64sha256}"

  role    = "${aws_iam_role.iam_for_lambda.arn}"
  handler = "index.handler"
  runtime = "nodejs10.x"

  environment {
    variables = {
      APP_PORT = 8080
      NODE_ENV = "production"
    }
  }
}
