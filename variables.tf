variable "project" {
    default = "roboshop"
}

variable "environment" {
    default = "dev"
}

variable "zone_name" {
    #default = "opsora.space"
}

variable "vpc_id" {
  
}

variable "component_sg_id" {
  
}

variable "private_subnet_ids" {
  
}

variable "iam_instance_profile" {
  
}

variable "backend_alb_listener_arn" {
  
}

variable "rule_priority" {
  
}

variable "app_version" {

}

variable "common_tags" {
#   default = {
#     Project     = "roboshop"
#     Environment = "dev"
#     Terraform   = "true"
#   }
}

variable "tags" {
  
}
