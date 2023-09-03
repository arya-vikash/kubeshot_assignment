import sys
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
import pandas as pd
import boto3
from io import StringIO

# Initialize Glue context
glueContext = GlueContext(SparkContext.getOrCreate())

# Get job arguments
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'input_bucket', 'input_key'])

# Create a Glue job
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Initialize S3 client
s3_client = boto3.client('s3')

# Read data from S3
bucket = args['input_bucket']
key = args['input_key']
response = s3_client.get_object(Bucket=bucket, Key=key)
data = response['Body'].read().decode('utf-8')

# Convert data to a pandas DataFrame
df = pd.read_csv(StringIO(data))

# Perform data processing using pandas
# Example: Convert a column to uppercase
df['your_column_name'] = df['your_column_name'].str.upper()

# Convert DataFrame back to CSV format
processed_data = df.to_csv(index=False)

# Write processed data back to S3
output_bucket = "report_bucket"
output_key = "processed_data/output.csv"
s3_client.put_object(Bucket=output_bucket, Key=output_key, Body=processed_data)

# Commit the job
job.commit()
