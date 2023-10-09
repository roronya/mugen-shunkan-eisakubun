terraform {
  required_version = "1.5.6"
  backend "s3" {
    bucket = "tfstate-lambda-mugen-shunkan-eisakubun"
    key    = "terraform.tfstate"
    region = "ap-northeast-1"
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

# mugen-shunkan-eisakubunを実行するためのIAMロール
resource "aws_iam_role" "lambda_role" {
  name = "mugen-shunkan-eisakubun-lambda-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Effect = "Allow",
      }
    ]
  })
}

# ↑のIAMロールにCloudWatchへの書き込み権限を付けてロギングできるようにしている
resource "aws_iam_role_policy" "lambda_logging_policy" {
  name   = "lambda-logging"
  role   = aws_iam_role.lambda_role.name
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# openai-forwarderを呼び出すためのポリシー
resource "aws_iam_role_policy" "invoke_openai_forwarder" {
  name   = "InvokeOpenAIForwarder"
  role   = aws_iam_role.lambda_role.name
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "lambda:InvokeFunction",
        Resource = "arn:aws:lambda:ap-northeast-1:381106009995:function:openai-forwarder"
      }
    ]
  })
}


resource "aws_lambda_function" "mugen_shunkan_eisakubun" {
  filename      = "function.zip"
  function_name = "mugen-shunkan-eisakubun"
  role          = aws_iam_role.lambda_role.arn
  handler       = "mugen-shunkan-eisakubun.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30
}

# API Gatewayで参照したいのでoutputしておく
# also see: apigateway/main.tf
output "mugen_shunkan_eisakubun_lambda_arn" {
  description = "ARN of the mugen-shunkan-eisakubun lambda function"
  value       = aws_lambda_function.mugen_shunkan_eisakubun.arn
}

output "mugen_shunkan_eisakubun_lambda_function_name" {
  description = "ARN of the mugen-shunkan-eisakubun lambda function"
  value       = aws_lambda_function.mugen_shunkan_eisakubun.function_name
}

