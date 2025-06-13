provider "aws" {
  region = var.aws_region
}

resource "aws_dynamodb_table" "users" {
  name = "users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "expenses" {
  name         = "expenses"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "expense_id"

  attribute {
    name = "expense_id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "debts" {
  name         = "debts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "from"

  attribute {
    name = "from"
    type = "S"
  }

  attribute {
    name = "to"
    type = "S"
  }

  global_secondary_index {
    name            = "to-index"
    hash_key        = "to"
    projection_type = "ALL"
  }
}

# Lambda Execution Role
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach AWS managed policy for:
# 1. Writing to CloudWatch Logs
# 2. Basic Lambda execution permissions
resource "aws_iam_role_policy_attachment" "lambda_basic_exec_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Allow full access to DynamoDB for now (you can scope it down later)
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_access" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_lambda_function" "register_user" {
  function_name = "register_user"
  filename         = "${path.module}/../register_user.zip"
  source_code_hash = filebase64sha256("${path.module}/../register_user.zip")
  runtime          = "python3.11"
  handler          = "handler.lambda_handler"
  role             = aws_iam_role.lambda_exec_role.arn
}

# HTTP API Gateway
resource "aws_apigatewayv2_api" "http_api" {
  name          = "expense-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "register_user_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.register_user.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_user" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /users"
  target    = "integrations/${aws_apigatewayv2_integration.register_user_integration.id}"
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_apigw_invoke_register_user" {
  statement_id  = "AllowAPIGatewayInvokeRegisterUser"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.register_user.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_lambda_function" "add_expense" {
  function_name    = "add_expense"
  filename         = "${path.module}/../add_expense.zip"
  source_code_hash = filebase64sha256("${path.module}/../add_expense.zip")
  runtime          = "python3.11"
  handler          = "handler.lambda_handler"
  role             = aws_iam_role.lambda_exec_role.arn
}

resource "aws_apigatewayv2_integration" "add_expense_integration" {
  api_id                = aws_apigatewayv2_api.http_api.id
  integration_type      = "AWS_PROXY"
  integration_uri       = aws_lambda_function.add_expense.invoke_arn
  integration_method    = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_expense" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /expenses"
  target    = "integrations/${aws_apigatewayv2_integration.add_expense_integration.id}"
}

resource "aws_lambda_permission" "allow_apigw_invoke_add_expense" {
  statement_id  = "AllowAPIGatewayInvokeAddExpense"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.add_expense.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_lambda_function" "get_user" {
  function_name    = "get_user"
  filename         = "${path.module}/../get_user.zip"
  source_code_hash = filebase64sha256("${path.module}/../get_user.zip")
  runtime          = "python3.11"
  handler          = "handler.lambda_handler"
  role             = aws_iam_role.lambda_exec_role.arn
}

resource "aws_apigatewayv2_integration" "get_user_integration" {
  api_id                = aws_apigatewayv2_api.http_api.id
  integration_type      = "AWS_PROXY"
  integration_uri       = aws_lambda_function.get_user.invoke_arn
  integration_method    = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_user_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /users/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.get_user_integration.id}"
}

resource "aws_lambda_permission" "allow_apigw_invoke_get_user" {
  statement_id  = "AllowInvokeGetUser"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_user.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_lambda_function" "get_expenses_by_user" {
  function_name    = "get_expenses_by_user"
  filename         = "${path.module}/../get_expenses_by_user.zip"
  source_code_hash = filebase64sha256("${path.module}/../get_expenses_by_user.zip")
  runtime          = "python3.11"
  handler          = "handler.lambda_handler"
  role             = aws_iam_role.lambda_exec_role.arn
}

resource "aws_apigatewayv2_integration" "get_expenses_by_user_integration" {
  api_id                = aws_apigatewayv2_api.http_api.id
  integration_type      = "AWS_PROXY"
  integration_uri       = aws_lambda_function.get_expenses_by_user.invoke_arn
  integration_method    = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_expenses_by_user_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /expenses/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.get_expenses_by_user_integration.id}"
}

resource "aws_lambda_permission" "allow_apigw_invoke_get_expenses_by_user" {
  statement_id  = "AllowInvokeGetExpensesByUser"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_expenses_by_user.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
