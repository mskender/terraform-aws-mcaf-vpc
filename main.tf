locals {
  az_ids              = [for zone in var.availability_zones : substr(zone, length(zone) - 1, 1)]
  zones               = length(var.availability_zones)
  lambda_subnet_count = var.lambda_subnet ? local.zones : 0
  vpc_cidr_suffix     = regex("\\/(\\d{1,2})$", var.cidr_block)[0]

  # Calculate the newbits as used by the cidrsubnet function. 
  # https://www.terraform.io/docs/configuration/functions/cidrsubnet.html
  private_subnet_newbits = var.private_subnet_suffix - local.vpc_cidr_suffix
  public_subnet_newbits  = var.public_subnet_suffix - local.vpc_cidr_suffix
  lambda_subnet_newbits  = var.lambda_subnet_suffix - local.vpc_cidr_suffix
}

resource "aws_vpc" "default" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"
  tags                 = merge(var.tags, { "Name" = "${var.stack}-vpc" })
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id
  tags   = merge(var.tags, { "Name" = "${var.stack}-igw" })
}

resource "aws_eip" "nat" {
  count = local.zones
  vpc   = true

  tags = merge(
    var.tags, { "Name" = "${var.stack}-nat-${local.az_ids[count.index]}" }
  )

  depends_on = [aws_internet_gateway.default]
}

resource "aws_nat_gateway" "default" {
  count         = local.zones
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.tags, { "Name" = "${var.stack}-nat-${local.az_ids[count.index]}" }
  )
}

resource "aws_subnet" "public" {
  count                   = local.zones
  cidr_block              = cidrsubnet(var.cidr_block, local.public_subnet_newbits, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.default.id

  tags = merge(
    var.tags, { "Name" = "${var.stack}-public-${local.az_ids[count.index]}" }
  )
}

resource "aws_subnet" "private" {
  count                   = local.zones
  cidr_block              = cidrsubnet(var.cidr_block, local.private_subnet_newbits, count.index + local.zones)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false
  vpc_id                  = aws_vpc.default.id

  tags = merge(
    var.tags, { "Name" = "${var.stack}-private-${local.az_ids[count.index]}" }
  )
}

resource "aws_subnet" "lambda" {
  count                   = local.lambda_subnet_count
  cidr_block              = cidrsubnet(var.cidr_block, local.lambda_subnet_newbits, count.index + local.zones)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false
  vpc_id                  = aws_vpc.default.id

  tags = merge(
    var.tags, { "Name" = "${var.stack}-lambda-${local.az_ids[count.index]}" }
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.default.id
  tags   = merge(var.tags, { "Name" = "${var.stack}-public" })
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default.id
}

resource "aws_route_table_association" "public" {
  count          = local.zones
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = local.zones
  vpc_id = aws_vpc.default.id

  tags = merge(
    var.tags, { "Name" = "${var.stack}-private-${local.az_ids[count.index]}" }
  )
}

resource "aws_route" "private" {
  count                  = local.zones
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.default[count.index].id
}

resource "aws_route_table_association" "private" {
  count          = local.zones
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table" "lambda" {
  count  = local.lambda_subnet_count
  vpc_id = aws_vpc.default.id

  tags = merge(
    var.tags, { "Name" = "${var.stack}-lambda-${local.az_ids[count.index]}" }
  )
}

resource "aws_route" "lambda" {
  count                  = local.lambda_subnet_count
  route_table_id         = aws_route_table.lambda[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.default[count.index].id
}

resource "aws_route_table_association" "lambda" {
  count          = local.lambda_subnet_count
  subnet_id      = aws_subnet.lambda[count.index].id
  route_table_id = aws_route_table.lambda[count.index].id
}
