# locals{
#     ami_id = data.aws_ami.joindevops.id
#     vpc_id = data.aws_ssm_parameter.vpc_id.value
#     private_subnet_id = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
#     private_subnet_ids = element(split(",", data.aws_ssm_parameter.private_subnet_ids.value),0)

#     common_tags = {
#         Project = var.project
#         Environment = var.environment
#         Terraform = "true"
#     }
# }

locals {
  name           = "${var.project}-${var.environment}"
  current_time = formatdate("YYYY-MM-DD-hh-mm", timestamp())
}