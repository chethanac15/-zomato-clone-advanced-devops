# Advanced Infrastructure as Code for Zomato Project
# This demonstrates multi-cloud infrastructure provisioning with advanced features

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
  
  backend "s3" {
    bucket = "zomato-terraform-state"
    key    = "zomato-clone/terraform.tfstate"
    region = "us-west-2"
    encrypt = true
    dynamodb_table = "terraform-locks"
  }
}

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "zomato-clone"
      Environment = var.environment
      Team        = "devops"
      ManagedBy   = "terraform"
    }
  }
}

# Google Cloud Provider Configuration
provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

# Azure Provider Configuration
provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
}

# Kubernetes Provider Configuration
provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Helm Provider Configuration
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# Data Sources
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

data "google_compute_zones" "available" {
  project = var.gcp_project
  region  = var.gcp_region
}

# VPC and Networking
module "aws_vpc" {
  source = "./modules/vpc"
  
  name                 = "zomato-vpc"
  cidr                 = var.vpc_cidr
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = var.private_subnets
  public_subnets       = var.public_subnets
  enable_nat_gateway   = true
  single_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Environment = var.environment
    Project     = "zomato-clone"
  }
}

# EKS Cluster
module "eks" {
  source = "./modules/eks"
  
  cluster_name                   = "zomato-cluster"
  cluster_version               = "1.28"
  cluster_endpoint_public_access = true
  
  vpc_id     = module.aws_vpc.vpc_id
  subnet_ids = module.aws_vpc.private_subnets
  
  eks_managed_node_groups = {
    general = {
      desired_capacity = 3
      max_capacity     = 10
      min_capacity     = 1
      
      instance_types = ["t3.medium", "t3.large"]
      capacity_type  = "ON_DEMAND"
      
      labels = {
        Environment = var.environment
        Project     = "zomato-clone"
        NodeGroup   = "general"
      }
      
      tags = {
        ExtraTag = "eks-node-group"
      }
    }
    
    monitoring = {
      desired_capacity = 2
      max_capacity     = 5
      min_capacity     = 1
      
      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"
      
      labels = {
        Environment = var.environment
        Project     = "zomato-clone"
        NodeGroup   = "monitoring"
      }
      
      taints = [{
        key    = "dedicated"
        value  = "monitoring"
        effect = "NO_SCHEDULE"
      }]
    }
  }
  
  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
  }
  
  tags = {
    Environment = var.environment
    Project     = "zomato-clone"
  }
}

# GKE Cluster
module "gke" {
  source = "./modules/gke"
  
  name               = "zomato-gke"
  project_id         = var.gcp_project
  region             = var.gcp_region
  zones              = data.google_compute_zones.available.names
  
  network            = module.gcp_vpc.network_name
  subnetwork        = module.gcp_vpc.subnets_names[0]
  
  node_pools = [
    {
      name               = "default-node-pool"
      machine_type       = "e2-medium"
      node_locations     = data.google_compute_zones.available.names
      initial_node_count = 1
      min_count          = 1
      max_count          = 5
      disk_size_gb       = 100
      disk_type          = "pd-standard"
      image_type         = "COS_CONTAINERD"
      auto_repair        = true
      auto_upgrade       = true
      service_account    = "default"
      preemptible        = false
      
      labels = {
        Environment = var.environment
        Project     = "zomato-clone"
      }
    }
  ]
  
  tags = {
    Environment = var.environment
    Project     = "zomato-clone"
  }
}

# Azure AKS Cluster
module "aks" {
  source = "./modules/aks"
  
  name                = "zomato-aks"
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.main.name
  
  kubernetes_version = "1.28.0"
  
  default_node_pool = {
    name                = "default"
    vm_size             = "Standard_DS2_v2"
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 5
    os_disk_size_gb     = 100
    type                = "VirtualMachineScaleSets"
  }
  
  tags = {
    Environment = var.environment
    Project     = "zomato-clone"
  }
}

# GCP VPC
module "gcp_vpc" {
  source = "./modules/gcp-vpc"
  
  name        = "zomato-vpc"
  project_id  = var.gcp_project
  region      = var.gcp_region
  
  subnets = [
    {
      subnet_name   = "zomato-subnet"
      subnet_ip     = "10.0.0.0/24"
      subnet_region = var.gcp_region
    }
  ]
  
  secondary_ranges = {
    "zomato-subnet" = [
      {
        range_name    = "pods"
        ip_cidr_range = "10.1.0.0/16"
      },
      {
        range_name    = "services"
        ip_cidr_range = "10.2.0.0/16"
      }
    ]
  }
}

# Azure Resource Group
resource "azurerm_resource_group" "main" {
  name     = "zomato-rg"
  location = var.azure_location
  
  tags = {
    Environment = var.environment
    Project     = "zomato-clone"
  }
}

# Azure VNet
resource "azurerm_virtual_network" "main" {
  name                = "zomato-vnet"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.0.0.0/16"]
  
  tags = {
    Environment = var.environment
    Project     = "zomato-clone"
  }
}

# Azure Subnet
resource "azurerm_subnet" "main" {
  name                 = "zomato-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
  
  service_endpoints = ["Microsoft.ContainerRegistry"]
}

# Security Groups and Firewall Rules
resource "aws_security_group" "eks_cluster" {
  name_prefix = "eks-cluster-"
  vpc_id      = module.aws_vpc.vpc_id
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "eks-cluster-sg"
  }
}

resource "aws_security_group" "eks_nodes" {
  name_prefix = "eks-nodes-"
  vpc_id      = module.aws_vpc.vpc_id
  
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "eks-nodes-sg"
  }
}

# IAM Roles and Policies
resource "aws_iam_role" "eks_cluster" {
  name = "eks-cluster-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = "zomato-terraform-state-${random_string.bucket_suffix.result}"
  
  tags = {
    Name        = "Terraform State"
    Environment = var.environment
    Project     = "zomato-clone"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table for Terraform Locks
resource "aws_dynamodb_table" "terraform_locks" {
  name           = "terraform-locks-${random_string.bucket_suffix.result}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
  
  tags = {
    Name        = "Terraform Locks"
    Environment = var.environment
    Project     = "zomato-clone"
  }
}

# Random String for Unique Names
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Outputs
output "aws_eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "aws_eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "gke_cluster_endpoint" {
  description = "Endpoint for GKE control plane"
  value       = module.gke.endpoint
}

output "gke_cluster_name" {
  description = "Name of the GKE cluster"
  value       = module.gke.name
}

output "aks_cluster_endpoint" {
  description = "Endpoint for AKS control plane"
  value       = module.aks.kube_config.0.host
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.name
}

output "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "terraform_locks_table" {
  description = "DynamoDB table for Terraform locks"
  value       = aws_dynamodb_table.terraform_locks.name
}
