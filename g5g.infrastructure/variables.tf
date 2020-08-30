variable "aws_region" {
  description = "The AWS region to create things in."
  default     = "af-south-1"
}

variable "az_count" {
  description = "Number of AZs to cover in a given AWS region"
  default     = "2"
}

variable "product-scraper_image" {
  description = "Docker image to run in the ECS cluster"
  default     = "139407860310.dkr.ecr.af-south-1.amazonaws.com/product-scraper:latest"
}

variable "product-scraper_port" {
  description = "Port exposed by the docker image to redirect traffic to"
  default     = 3003
}

variable "product-scraper_count" {
  description = "Number of docker containers to run"
  default     = 1
}

variable "fargate_cpu" {
  description = "Fargate instance CPU units to provision (1 vCPU = 1024 CPU units)"
  default     = "256"
}

variable "fargate_memory" {
  description = "Fargate instance memory to provision (in MiB)"
  default     = "512"
}
