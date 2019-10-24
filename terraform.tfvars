region = "us-central1"
gcp_project = "cloudglobaldelivery-1000135575"
vpc1_name = "dev"
credentials= "credentials.json"
subnet1_cidr= "10.10.0.0/24"
subnet1_region = "us-east1"
subnet1_source_ranges =  ["0.0.0.0/0"]
firewall_protocol1 = "icmp"
firewall_protocol2 = "smtp"
firewall_ports = ["0-65535"]
wordpress_instance_name = "stacked-vmname-timestamp"
wordpress_instance_machine_type = "target_machine"
wordpress_instance_zone = "us-east1-b"

sql_database_instance_name = "wpsql-vmname-timestamp"
sql_database_instance_region = "us-east1"
sql_database_name = "wp-database"

elk_instance_name = "elk-vmname-stacked-timestamp"
elk_instance_machine_type = "target_machine"

elk_instance_zone = "us-east1-b"
