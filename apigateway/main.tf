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
  rest_api_id   = aws_api_gateway_rest_api.mugen_shunkan_eisakubun_api.id
  resource_id   = aws_api_gateway_resource.mugen_shunkan_eisakubun_resource.id
  http_method   = "GET"
  authorization = "NONE"
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

# 出力: API GatewayのURL
output "mugen_shunkan_eisakubun_api_url" {
  value = "${aws_api_gateway_rest_api.mugen_shunkan_eisakubun_api.execution_arn}/*/${aws_api_gateway_method.mugen_shunkan_eisakubun_method.http_method}${aws_api_gateway_resource.mugen_shunkan_eisakubun_resource.path}"
}

# ステージとデプロイは手動もしくはaws cliから行う
## やったこと
## 1. 手動でステージとデプロイを作る
## 2. ステージの「ログとトレース」を編集しCloudWatchログを有効化する
