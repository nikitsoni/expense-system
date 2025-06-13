import json
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('users')

def lambda_handler(event, context):
    user_id = event["pathParameters"]["id"]

    try:
        response = table.get_item(Key={"user_id": user_id})
        item = response.get("Item")

        if not item:
            return {
                "statusCode": 404,
                "body": json.dumps({"error": "User not found"})
            }

        return {
            "statusCode": 200,
            "body": json.dumps(item)
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
