import boto3
import json
import csv
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')
glue_client = boto3.client('glue')

def handler(event, context):
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    job_name = 'data-processing-glue-job'
    response = glue_client.start_job_run(
        JobName=job_name,
        Arguments={
            '--input_bucket': bucket,
            '--input_key': key,
        }
    )
    glue_job_run_id = response['JobRunId']
    glue_job_status = 'RUNNING'
    while glue_job_status == 'RUNNING':
        response = glue_client.get_job_run(JobName=job_name, RunId=glue_job_run_id)
        glue_job_status = response['JobRun']['JobRunState']

    if glue_job_status == 'SUCCEEDED':
        report_bucket = 'report_bucket'
        report_key = 'report.csv'
        send_notification('Report is saved to S3')

    return {
        'statusCode': 200,
        'body': json.dumps('Workflow complete.')
    }

def send_notification(message):
    pass
