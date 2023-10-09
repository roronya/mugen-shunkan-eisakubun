terraform {
  required_version = "1.5.6"
  backend "s3" {
    bucket = "tfstate-apigateway-mugen-shunkan-eisakubun"
    key    = "terraform.tfstate"
    region = "ap-northeast-1"
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

# Lambdaで定義した情報を参照するための設定
data "terraform_remote_state" "lambda_state" {
  backend = "s3"

  config = {
    bucket = "tfstate-lambda-mugen-shunkan-eisakubun"
    key    = "terraform.tfstate"
    region = "ap-northeast-1"
  }
}

locals {
  lambda_arn           = data.terraform_remote_state.lambda_state.outputs.mugen_shunkan_eisakubun_lambda_arn
  lambda_function_name = data.terraform_remote_state.lambda_state.outputs.mugen_shunkan_eisakubun_lambda_function_name
}

# API GatewayのREST APIの作成
resource "aws_api_gateway_rest_api" "mugen_shunkan_eisakubun_api" {
  name        = "mugen-shunkan-eisakubun-api"
  description = "API for mugen-shunkan-eisakubun Lambda function"
}

# API Gatewayのリソースの作成
resource "aws_api_gateway_resource" "mugen_shunkan_eisakubun_resource" {
  rest_api_id = aws_api_gateway_rest_api.mugen_shunkan_eisakubun_api.id
  parent_id   = aws_api_gateway_rest_api.mugen_shunkan_eisakubun_api.root_resource_id
  path_part   = "invoke"
}

# API GatewayのHTTPメソッドの設定
resource "aws_api_gateway_method" "mugen_shunkan_eisakubun_method" {
  rest_api_id      = aws_api_gateway_rest_api.mugen_shunkan_eisakubun_api.id
  resource_id      = aws_api_gateway_resource.mugen_shunkan_eisakubun_resource.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = true
}

# Lambda関数との統合
resource "aws_api_gateway_integration" "mugen_shunkan_eisakubun_lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.mugen_shunkan_eisakubun_api.id
  resource_id = aws_api_gateway_resource.mugen_shunkan_eisakubun_resource.id
  http_method = aws_api_gateway_method.mugen_shunkan_eisakubun_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:ap-northeast-1:lambda:path/2015-03-31/functions/${data.terraform_remote_state.lambda_state.outputs.mugen_shunkan_eisakubun_lambda_arn}/invocations"

}

# Lambda関数がAPI Gatewayからのリクエストを受け入れるように権限を付与
resource "aws_lambda_permission" "mugen_shunkan_eisakubun_api_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = data.terraform_remote_state.lambda_state.outputs.mugen_shunkan_eisakubun_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.mugen_shunkan_eisakubun_api.execution_arn}/*/${aws_api_gateway_method.mugen_shunkan_eisakubun_method.http_method}${aws_api_gateway_resource.mugen_shunkan_eisakubun_resource.path}"
}

# ステージを作るのにデプロイが必要なので作る
# 変更があるたび毎回作られてしまうので、適用タイミングは気をつける
# TODO: 毎回作られると意図せずデプロイされてしまうので、あとでterraform管理下から外す
resource "aws_api_gateway_deployment" "mugen_shunkan_eisakubun_deployment" {
  depends_on = [aws_api_gateway_integration.mugen_shunkan_eisakubun_lambda_integration]

  rest_api_id = aws_api_gateway_rest_api.mugen_shunkan_eisakubun_api.id

  lifecycle {
    create_before_destroy = true
  }
}

# API Gatewayのステージの作成
# ↑で作ったデプロイと紐付ける
resource "aws_api_gateway_stage" "mugen_shunkan_eisakubun_stage" {
  deployment_id = aws_api_gateway_deployment.mugen_shunkan_eisakubun_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.mugen_shunkan_eisakubun_api.id
  stage_name    = "prd"
  description   = "Production environment"

  # ロギング設定の追加
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.mugen_shunkan_eisakubun_log_group.arn
    format          = "$context.identity.sourceIp - - [$context.requestTime] \"$context.httpMethod $context.resourcePath $context.protocol\" $context.status $context.responseLength $context.requestId"
  }
}

# CloudWatchロググループの作成
resource "aws_cloudwatch_log_group" "mugen_shunkan_eisakubun_log_group" {
  name = "/aws/apigateway/mugen-shunkan-eisakubun"
}

# API Gatewayアカウントのロギング設定
resource "aws_api_gateway_account" "logging" {
  cloudwatch_role_arn = aws_iam_role.apigateway_cloudwatch_role.arn
}

resource "aws_iam_role" "apigateway_cloudwatch_role" {
  name = "APIGatewayCloudWatchRole"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Principal = {
          Service = "apigateway.amazonaws.com"
        },
        Effect = "Allow",
      }
    ]
  })
}

resource "aws_iam_role_policy" "apigateway_cloudwatch_policy" {
  name = "APIGatewayCloudWatchPolicy"
  role = aws_iam_role.apigateway_cloudwatch_role.id

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# APIキーの作成
resource "aws_api_gateway_api_key" "mugen_shunkan_eisakubun_api_key" {
  name        = "mugen-shunkan-eisakubun-api-key"
  description = "API key for mugen-shunkan-eisakubun"
  enabled     = true
}

# 使用プランの作成
resource "aws_api_gateway_usage_plan" "mugen_shunkan_eisakubun_usage_plan" {
  name        = "mugen-shunkan-eisakubun-usage-plan"
  description = "Usage plan for mugen-shunkan-eisakubun API"

  api_stages {
    api_id = aws_api_gateway_rest_api.mugen_shunkan_eisakubun_api.id
    stage  = aws_api_gateway_stage.mugen_shunkan_eisakubun_stage.stage_name
  }
}

# APIキーと使用プランの関連付け
resource "aws_api_gateway_usage_plan_key" "mugen_shunkan_eisakubun_usage_plan_key" {
  key_id        = aws_api_gateway_api_key.mugen_shunkan_eisakubun_api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.mugen_shunkan_eisakubun_usage_plan.id
}
