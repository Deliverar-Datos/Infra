resource "random_id" "bucket_suffix" {
  byte_length = 8
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "${var.bucket_name_prefix}${random_id.bucket_suffix.hex}"

  tags = {
    Environment = "Dev"
    Project     = "TerraformS3Upload"
  }
}

# Recorre los archivos en el directorio 'files' y sube cada uno
resource "aws_s3_object" "object_upload" {
  for_each = fileset(var.source_files_directory, "*")

  bucket = aws_s3_bucket.my_bucket.id
  key    = each.value
  source = "${var.source_files_directory}/${each.value}"
  etag   = filemd5("${var.source_files_directory}/${each.value}") # Para detectar cambios en el archivo
}