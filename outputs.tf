output "id" {
  value       = aws_vpc.default.id
  description = "ID of the VPC"
}

output "igw_id" {
  value       = aws_internet_gateway.default.id
  description = "ID of the Internet Gateway"
}

output "nat_gateway_ids" {
  value       = aws_nat_gateway.default[*].id
  description = "IDs of the NAT gateways"
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "IDs of the public subnets"
}

output "public_route_table_id" {
  value       = aws_route_table.public.id
  description = "ID of the public route table"
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "IDs of the private subnets"
}

output "private_route_table_ids" {
  value       = aws_route_table.public[*].id
  description = "IDs of the private route tables"
}
