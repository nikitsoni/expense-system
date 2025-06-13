import json
import boto3
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('expenses')

# Custom encoder to handle Decimal
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)  # or str(obj) if precision matters
        return super(DecimalEncoder, self).default(obj)

def lambda_handler(event, context):
    user_id = event["pathParameters"]["id"]

    try:
        response = table.scan(
            FilterExpression="contains(participants, :uid)",
            ExpressionAttributeValues={":uid": user_id}
        )
        items = response.get("Items", [])

        return {
            "statusCode": 200,
            "body": json.dumps(items, cls=DecimalEncoder)
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
