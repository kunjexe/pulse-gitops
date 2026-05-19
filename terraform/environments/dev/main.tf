terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "pulse-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "pulse-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "pulse"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "db_password" {
  type      = string
  sensitive = true
}

# ---------- Networking ----------
module "networking" {
  source      = "../modules/networking"
  environment = "dev"
}

# ---------- EKS ----------
module "eks" {
  source             = "../modules/eks"
  environment        = "dev"
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  node_desired_size  = 2
  node_min_size      = 1
  node_max_size      = 3
}

# ---------- Databases ----------
module "databases" {
  source             = "../modules/databases"
  environment        = "dev"
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  db_password        = var.db_password
  db_instance_class  = "db.t3.micro"
  redis_node_type    = "cache.t3.micro"
}

# ---------- Storage ----------
module "storage" {
  source      = "../modules/storage"
  environment = "dev"
}

# ---------- Outputs ----------
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  value     = module.databases.rds_endpoint
  sensitive = true
}

output "redis_endpoint" {
  value = module.databases.redis_endpoint
}

output "media_bucket" {
  value = module.storage.media_bucket_name
}

output "ecr_repos" {
  value = module.storage.ecr_repository_urls
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}
