variable "region" {}
variable "gcp_project" {}
variable "credentials" {}
variable "vpc1_name" {}
variable "subnet1_cidr" {}
variable "subnet1_region" {}
variable "subnet1_source_ranges" {}
variable "firewall_protocol1" {}
variable "firewall_protocol2" {}
variable "firewall_ports" {
  type = list(string)
}
variable "wordpress_instance_name" {}
variable "sql_database_instance_name" {}
variable "sql_database_instance_region" {}
variable "sql_database_name" {}