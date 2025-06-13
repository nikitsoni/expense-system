output "dynamodb_users_table" {
  value = aws_dynamodb_table.users.name
}

output "dynamodb_expenses_table" {
  value = aws_dynamodb_table.expenses.name
}

output "dynamodb_debts_table" {
  value = aws_dynamodb_table.debts.name
}

output "api_url" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}
