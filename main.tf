provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "script_bucket" {
  bucket = "your-script-bucket-name"
}

resource "aws_s3_object" "script_object" {
  bucket       = aws_s3_bucket.script_bucket.id
  key          = "app.py"
  source       = "./app.py"
}

resource "aws_s3_bucket" "json_bucket" {
  bucket = "job-processing-bucket"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket" "report_bucket" {
  bucket = "processing-report-bucket"

  tags = {
    Name        = "Report bucket"
    Environment = "Dev"
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "lambda_policy" {
    name = "test-role"
    policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
    roles       = [aws_iam_role.lambda_role.id]
}

resource "aws_lambda_function" "data_processing_lambda" {
  function_name = "data-processing-lambda"
  handler      = "index.handler"
  runtime      = "python3.10"
  role         = aws_iam_role.lambda_role.arn

  filename     = "./lambda_function.zip"
  source_code_hash = filebase64sha256("./lambda_function.zip")

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.json_bucket.id
    }
  }
  depends_on = [aws_iam_policy_attachment.lambda_policy]
}

resource "aws_cloudwatch_log_group" "function_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.data_processing_lambda.function_name}"
  retention_in_days = 7
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_iam_policy" "function_logging_policy" {
  name   = "function-logging-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Action : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect : "Allow",
        Resource : "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "function_logging_policy_attachment" {
  role = aws_iam_role.lambda_role.id
  policy_arn = aws_iam_policy.function_logging_policy.arn
}

resource "aws_iam_policy" "glue_job_policy" {
  name        = "GlueJobPolicy"
  description = "IAM policy for Glue job permissions"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "glue:StartJobRun",
        Effect = "Allow",
        Resource = "*",
      },
      {
        Action = "glue:GetJobRun",
        Effect = "Allow",
        Resource = "*",
      },
    ],
  })
}

resource "aws_iam_policy_attachment" "glue_job_policy_attachment" {
  name       = "glue-job-policy-attachment"
  policy_arn = aws_iam_policy.glue_job_policy.arn
  roles      = [aws_iam_role.lambda_role.name]
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_processing_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.json_bucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.json_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.data_processing_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

resource "aws_glue_job" "data_processing_glue_job" {
  name     = "data-processing-glue-job"
  role_arn = aws_iam_role.lambda_role.arn
  command {
    name = "pythonshell"
    python_version = "3"
    script_location = "s3://${aws_s3_bucket.script_bucket.bucket}/app.py"
  }

  default_arguments = {
    "--input_bucket" = aws_s3_bucket.json_bucket.id
  }
}

resource "aws_quicksight_data_set" "dataset" {
  name      = "your-quick-sight-dataset-name"
  aws_account_id = var.aws_account_id
  import_mode = "SPICE"
  data_set_id = "dataset-id"

  physical_table_map {
    physical_table_map_id = "DataSet"
    
    s3_source {
      data_source_arn = aws_s3_bucket.json_bucket.arn
    input_columns {
    name    = "customer_name"
    type    = "STRING"
}

    input_columns {
        name    = "product_name"
        type    = "STRING"
    }

    input_columns {
        name    = "quantity"
        type    = "INTEGER"
    }
      upload_settings {
        format = "CSV"
        start_from_row = 1
        delimiter = ","
        text_qualifier = "DOUBLE_QUOTE"
      }
    }
  }
}