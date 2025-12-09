resource "aws_lb_target_group" "component" {
  name     = "${var.project}-${var.environment}-component" #roboshop-dev-component
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  deregistration_delay = 120
  health_check {
    healthy_threshold = 2
    interval = 10
    matcher = "200-299"
    path = "/health"
    port = 8080
    timeout = 5
    unhealthy_threshold = 3
  }
}

module "component" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  ami           = data.aws_ami.joindevops.id
  name = "${local.name}-${var.tags.Component}-ami"
  instance_type = "t3.micro"
  vpc_security_group_ids = [var.component_sg_id]
  subnet_id = element(var.private_subnet_ids,0)
  #iam_instance_profile = var.iam_instance_profile
  tags = merge(
    var.common_tags,
    var.tags
  )
}

resource "null_resource" "component" {
  triggers = {
    instance_id = module.component.id
  }
  
  provisioner "file" {
    source      = "component.sh"
    destination = "/tmp/component.sh"
  }

  connection {
    type     = "ssh"
    user     = "ec2-user"
    password = "DevOps321"
    host     = module.component.private_ip
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/component.sh",
      "sudo sh /tmp/component.sh ${var.tags.Component} ${var.environment} ${var.app_version}"
    ]
  }
}

resource "aws_ec2_instance_state" "component" {
  instance_id = module.component.id
  state       = "stopped"
  depends_on = [null_resource.component]
}

resource "aws_ami_from_instance" "component" {
  name               = "${var.project}-${var.environment}-${local.current_time}"
  source_instance_id = aws_instance.component.id
  depends_on = [aws_ec2_instance_state.component]
}

resource "null_resource" "component_delete" {
  triggers = {

    instance_id = module.component.id

  }
  
  # make sure you have aws configure in your laptop
  provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${module.component.id}"
  }

  depends_on = [aws_ami_from_instance.component]
}

resource "aws_launch_template" "component" {
  name = "${local.name}-${var.tags.Component}"

  image_id = aws_ami_from_instance.component.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = "t3.micro"
  vpc_security_group_ids = [var.component_sg_id]
  update_default_version = true # each time you update, new version will become default
  tag_specifications {
    resource_type = "instance"
    # EC2 tags created by ASG
    tags = {
        Name = "${var.project}-${var.environment}-component"
      }
  }

}

resource "aws_autoscaling_group" "component" {
  name                 = "${var.project}-${var.environment}-component"
  desired_capacity   = 1
  max_size           = 10
  min_size           = 1
  target_group_arns = [aws_lb_target_group.component.arn]
  vpc_zone_identifier  = var.private_subnet_ids
  health_check_grace_period = 60
  health_check_type         = "ELB"

  launch_template {
    id      = aws_launch_template.component.id
    version = aws_launch_template.component.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }

  tag {
    key = "Name"
    value = "${local.name}-${var.tags.Component}"
    propagate_at_launch = true
  }

  timeouts{
    delete = "15m"
  }
}

resource "aws_autoscaling_policy" "component" {
  name                   = "${local.name}-${var.tags.Component}"
  autoscaling_group_name = aws_autoscaling_group.component.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 5.0
  }
}

resource "aws_lb_listener_rule" "component" {
  listener_arn = var.backend_alb_listener_arn
  priority     = var.rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.component.arn
  }

  condition {
    host_header {
      values = ["${var.tags.Component}.app-${var.environment}.${var.zone_name}"]
    }
  }
}