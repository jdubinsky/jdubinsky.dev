provider "aws" {
  region = "${var.aws_region}"
}
data "archive_file" "zip" {
  type        = "zip"
  source_file = "index.js"
  output_path = "jdubinsky-dev-lambda.zip"
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

resource "aws_lambda_function" "lambda" {
  function_name = "jdubinsky-dev"

  filename         = "${data.archive_file.zip.output_path}"
  source_code_hash = "${data.archive_file.zip.output_base64sha256}"

  role    = "${aws_iam_role.iam_for_lambda.arn}"
  handler = "index.handler"
  runtime = "nodejs10.16.3"

  environment {
    variables = {
      APP_PORT = 8080
      NODE_ENV = "production"
    }
  }
}
