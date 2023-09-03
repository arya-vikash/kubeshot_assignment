import sys
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

sc = SparkContext()
glueContext = GlueContext(sc)

args = getResolvedOptions(sys.argv, ['JOB_NAME', 'input_bucket', 'input_key'])

job = Job(glueContext)
job.init(args['JOB_NAME'], args)

datasource0 = glueContext.create_dynamic_frame.from_catalog(database = "your-database-name", table_name = "your-table-name", transformation_ctx = "datasource0")

from pyspark.sql.functions import col, upper
df = datasource0.toDF()
df = df.withColumn("your_column_name", upper(col("your_column_name")))
processed_data = glueContext.create_dynamic_frame.fromDF(df, glueContext, "processed_data")

output_bucket = "processing-report-bucket"
output_key = "processed_data/"
output_path = f"s3://{output_bucket}/{output_key}"
glueContext.write_dynamic_frame.from_options(
    frame = processed_data,
    connection_type = "s3",
    connection_options = {"path": output_path},
    format = "parquet"
)

job.commit()