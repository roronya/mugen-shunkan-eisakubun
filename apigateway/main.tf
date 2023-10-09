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
}
