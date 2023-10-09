# openai-api-lambda

このリポジトリはOpenAIのAPIキーを隠蔽するためのlambdaのリソースとそのソースコードが置かれています。

## terraform

terraformは他のAWSリソースに影響を与えないように、このリポジトリで使うためだけのIAM Roleを用意した。

tfstateもs3にtfstate-openai-api-lambdaを用意していて、他から独立している。

## デプロイ

アプリケーションの変更はtaskで行う。AWSのリソースを変更した場合はterraformを使う。

- task deploy
    - lambda用にソースコードをzipにかためてデプロイする
- terraform apply
    - AWSのリソースを変更した場合はterraformコマンドを使う

## secrets

Githubシークレットに必要なキーを登録してある。伝搬ルールは以下。

1. Github Secrets
2. Github Actions{{ seacrets.hogehoge }}でアクセスする
3. Taskfile taskコマンド実行前に環境変数として渡す
4. 各コマンド