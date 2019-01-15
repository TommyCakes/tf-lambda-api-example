# Provider

provider "aws" {
    region = "eu-west-1"
}

# Dynamo DB

resource "aws_dynamodb_table" "names" {
  name = "names"
  read_capacity = 2
  write_capacity = 2
  hash_key = "name"

  attribute {
      name = "name"
      type = "S"
  }
}


# Lambda 

resource "aws_iam_role" "lambda" {
  name =  "tommyGreeterRole"
  assume_role_policy = "${data.aws_iam_policy_document.lambda-assume-role.json}"  
}

data "aws_iam_policy_document" "lambda-assume-role" {
    statement {
        actions = ["sts:AssumeRole"]

        principals {
            type = "Service"
            identifiers = ["lambda.amazonaws.com"]
        }
    }
}

resource "aws_iam_role_policy_attachment" "dynamoDBAccess" {
    role = "${aws_iam_role.lambda.name}"
    policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy" "lambda-cloudwatch-log-group" {
  name = "tommy-cloudwatch-log-group"
  role = "${aws_iam_role.lambda.name}"
  policy = "${data.aws_iam_policy_document.cloudwatch-log-group-lambda.json}"  
}

data "aws_iam_policy_document" "cloudwatch-log-group-lambda" {
  statement {

      actions = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
      ]

      resources = [
          "arn:aws:logs:::*",
      ]
  }
}

data "archive_file" "lambda" {
  type = "zip"
  source_file = "lambda.js"
  output_path = "lambda.zip"
}

resource "aws_lambda_function" "greeter-lambda" {
  filename = "${data.archive_file.lambda.output_path}"
  function_name = "tommyGreeterLamda"
  role = "${aws_iam_role.lambda.arn}"
  handler = "lambda.handler"
  runtime = "nodejs6.10"
  source_code_hash = "{$base64sha256(file(data.archive_file.lambda.output_path))}"
}

resource "aws_lambda_function" "get-all-names" {
  filename = "${data.archive_file.lambda.output_path}"
  function_name = "getAllNamesLambda"
  role = "${aws_iam_role.lambda.arn}"
  handler = "lambda.getAllNames"
  runtime = "nodejs6.10"
  source_code_hash = "{$base64sha256(file(data.archive_file.lambda.output_path))}"
}

resource "aws_api_gateway_rest_api" "api" {
  name = "tommyGreeterApi"
}

resource "aws_api_gateway_resource" "api-resource-greeting" {
  path_part = "greetings"
  parent_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
}

resource "aws_api_gateway_resource" "api-resource-names" {
  path_part = "names"
  parent_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
}

resource "aws_api_gateway_method" "greeting" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.api-resource-greeting.id}"
  http_method = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "get-names" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.api-resource-names.id}"
  http_method = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "integration-greet" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.api-resource-greeting.id}"
  http_method = "${aws_api_gateway_method.greeting.http_method}"
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = "arn:aws:apigateway:eu-west-1:lambda:path/2015-03-31/functions/${aws_lambda_function.greeter-lambda.arn}/invocations"
}

resource "aws_api_gateway_integration" "integration-names" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.api-resource-names.id}"
  http_method = "${aws_api_gateway_method.get-names.http_method}"
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = "arn:aws:apigateway:eu-west-1:lambda:path/2015-03-31/functions/${aws_lambda_function.get-all-names.arn}/invocations"
}

resource "aws_lambda_permission" "greeter-permissions" {
  statement_id = "AllowExecutionFromAPIGateway"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.greeter-lambda.arn}"
  principal = "apigateway.amazonaws.com"
}

resource "aws_lambda_permission" "get-names-permissions" {
  statement_id = "AllowExecutionFromAPIGateway"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.get-all-names.arn}"
  principal = "apigateway.amazonaws.com"
}




