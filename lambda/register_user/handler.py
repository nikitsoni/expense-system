import json
import uuid
import boto3
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('users')

def lambda_handler(event, context):
    try:
        body = json.loads(event.get("body", "{}"))

        # Simple validation
        if "name" not in body or "email" not in body:
            return {
                "statusCode": 400,
                "body": json.dumps({"error": "name and email are required"})
            }

        user_id = str(uuid.uuid4())

        item = {
            "user_id": user_id,
            "name": body["name"],
            "email": body["email"],
            "created_at": datetime.utcnow().isoformat()
        }

        table.put_item(Item=item)

        return {
            "statusCode": 201,
            "body": json.dumps({"message": "User registered", "user_id": user_id})
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
