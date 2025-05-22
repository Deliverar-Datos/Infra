variable "bucket_name_prefix" {
  description = "Prefijo para el nombre del bucket S3."
  type        = string
  default     = "deliver-ar-s3-app-" # Puedes cambiar este prefijo
}

variable "source_files_directory" {
  description = "Ruta al directorio que contiene los archivos a subir."
  type        = string
  default     = "./files"
}