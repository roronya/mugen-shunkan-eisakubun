terraform {
  required_version = "1.5.6"
  backend "s3" {
    bucket = "tfstate-mugen-shunkan-eisakubun"
    key = "terraform.tfstate"
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
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Effect = "Allow",
    }]
  })
}

# ↑のIAMロールにCloudWatchへの書き込み権限を付けてロギングできるようにしている
resource "aws_iam_role_policy" "lambda_logging_policy" {
  name   = "lambda-logging"
  role   = aws_iam_role.lambda_role.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      Effect   = "Allow",
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}

resource "aws_lambda_function" "mugen-shunkan-eisakubun" {
  filename      = "function.zip"
  function_name = "mugen-shunkan-eisakubun"
  role          = aws_iam_role.lambda_role.arn
  handler       = "mugen-shunkan-eisakubun.lambda_handler"
  runtime       = "python3.11"
}
