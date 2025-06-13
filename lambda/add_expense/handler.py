import json
import uuid
import boto3
from datetime import datetime
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
expenses_table = dynamodb.Table('expenses')
users_table = dynamodb.Table('users')

def lambda_handler(event, context):
    try:
        body = json.loads(event.get("body", "{}"))

        required_fields = ["payer_id", "amount", "participants", "splits", "description"]
        for field in required_fields:
            if field not in body:
                return {
                    "statusCode": 400,
                    "body": json.dumps({"error": f"{field} is required"})
                }

        # Validate user exists
        user_resp = users_table.get_item(Key={"user_id": body["payer_id"]})
        if "Item" not in user_resp:
            return {
                "statusCode": 404,
                "body": json.dumps({"error": "Invalid payer_id. User does not exist."})
            }

        # Convert amount and splits to Decimal
        amount = Decimal(str(body["amount"]))
        splits = {uid: Decimal(str(val)) for uid, val in body["splits"].items()}

        total_split = sum(splits.get(user_id, Decimal("0")) for user_id in body["participants"])
        if total_split != amount:
            return {
                "statusCode": 400,
                "body": json.dumps({"error": "Split amounts do not add up to total"})
            }

        expense_id = str(uuid.uuid4())
        item = {
            "expense_id": expense_id,
            "payer_id": body["payer_id"],
            "amount": amount,
            "participants": body["participants"],
            "splits": splits,
            "description": body["description"],
            "created_at": datetime.utcnow().isoformat()
        }

        expenses_table.put_item(Item=item)

        return {
            "statusCode": 201,
            "body": json.dumps({"message": "Expense added", "expense_id": expense_id})
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
