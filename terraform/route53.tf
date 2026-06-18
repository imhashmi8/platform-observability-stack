# Public hosted zone for the platform's DNS records (grafana.<domain>, etc.).
# external-dns (Phase 3+) writes records here using the IRSA role in irsa.tf.
#
# Created only when var.domain_name is set AND var.create_route53_zone is true.
# If the zone already exists in this account, set create_route53_zone = false and
# this will look it up instead.

resource "aws_route53_zone" "this" {
  count = local.enable_dns && var.create_route53_zone ? 1 : 0

  name = var.domain_name
  tags = local.tags
}

data "aws_route53_zone" "existing" {
  count = local.enable_dns && !var.create_route53_zone ? 1 : 0

  name         = var.domain_name
  private_zone = false
}

locals {
  hosted_zone_id = local.enable_dns ? (
    var.create_route53_zone ? aws_route53_zone.this[0].zone_id : data.aws_route53_zone.existing[0].zone_id
  ) : null

  hosted_zone_arn = local.enable_dns ? (
    var.create_route53_zone ? aws_route53_zone.this[0].arn : data.aws_route53_zone.existing[0].arn
  ) : null

  hosted_zone_name_servers = local.enable_dns && var.create_route53_zone ? aws_route53_zone.this[0].name_servers : []
}
