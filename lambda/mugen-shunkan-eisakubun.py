import boto3
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    pass


def main():
    # Lambdaクライアントの初期化
    lambda_client = boto3.client('lambda')

    # 呼び出すLambda関数の名前
    function_name = 'openai-forwarder'

    # ペイロードの設定
    prompt = [
        {"role": "user", "content": "英語に訳してください。 'これはペンです。'"}
    ]
    payload = {"body": prompt}

    # 別のLambda関数の呼び出し
    response = lambda_client.invoke(
        FunctionName=function_name,
        InvocationType='RequestResponse',  # 同期的に実行. 'Event' を使用すると非同期実行
        Payload=json.dumps(payload)
    )

    # レスポンスの取得
    response_payload = json.loads(response['Payload'].read().decode('utf-8'))
    logger.info(response_payload)

    result = {
        'statusCode': 200,
        'body': response_payload['choices'][0]['message']['content']
    }
    logger.info(result)
    return result


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    main()
