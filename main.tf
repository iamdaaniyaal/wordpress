// Configure the Google Cloud provider
provider "google" {
  credentials = "${file("${var.credentials}")}"
  project     = "${var.gcp_project}"
  region      = "${var.region}"
}

// Create VPC 1
resource "google_compute_network" "vpc1" {
  name                    = "${var.vpc1_name}-vpc"
  auto_create_subnetworks = "false"
}

// Create VPC1 Subnet
resource "google_compute_subnetwork" "subnet1" {
  name          = "${var.vpc1_name}-subnet"
  ip_cidr_range = "${var.subnet1_cidr}"
  network       = "${var.vpc1_name}-vpc"
  depends_on    = ["google_compute_network.vpc1"]
  region        = "${var.subnet1_region}"
}

// VPC 1 INGRESS firewall configuration
resource "google_compute_firewall" "firewall1" {
  name      = "${var.vpc1_name}-ingress-firewall"
  network   = "${google_compute_network.vpc1.name}"
  direction = "INGRESS"

  allow {
    protocol = "${var.firewall_protocol1}"
  }



  allow {
    protocol = "tcp"
    ports    = "${var.firewall_ports}"
  }

  //Giving source ranges as this is a INGRESS Firewall Rule
  source_ranges = "${var.subnet1_source_ranges}"
}

// VPC 1  EGRESS firewall configuration
resource "google_compute_firewall" "firewall2" {
  name               = "${var.vpc1_name}-egress-firewall"
  network            = "${google_compute_network.vpc1.name}"
  direction          = "EGRESS"
  destination_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "${var.firewall_protocol1}"
  }



  allow {
    protocol = "tcp"
    ports    = "${var.firewall_ports}"
  }

  //Not giving source ranges as this is a EGRESS Firewall Rule
  //source_ranges = "${var.subnet1_source_ranges}"
}



// Wordpress & CloudSQL starts here
resource "google_compute_address" "wordpressip" {
  name   = "${var.wordpress_instance_ip_name}"
  region = "us-east1"
}



resource "google_compute_instance" "wordpress" {
  name         = "${var.wordpress_instance_name}"
  machine_type = "${var.wordpress_instance_machine_type}"
  zone         = "${var.wordpress_instance_zone}"

    tags = ["http-server"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  // Local SSD disk
  # scratch_disk {
  # }

  network_interface {
    network    = "${google_compute_network.vpc1.self_link}"
    subnetwork = "${google_compute_subnetwork.subnet1.self_link}"

    access_config {
      // Ephemeral IP

      nat_ip = "${google_compute_address.wordpressip.address}"
    }
  }

  provisioner "file" {
    content     = "${data.template_file.phpconfig.rendered}"
    destination = "/wp-config.php"

    connection {
      type     = "ssh"
      user     = "root"
      password = "root123"
      # host     = "${google_compute_instance.default.network_interface[0].access_config[0].nat_ip}"
      host = "${google_compute_address.wordpressip.address}"
    }
  }



  provisioner "file" {
    content     = "${data.template_file.filebeat.rendered}"
    destination = "/filebeat.yml"

    connection {
      type     = "ssh"
      user     = "root"
      password = "root123"
      # host     = "${google_compute_instance.default.network_interface[0].access_config[0].nat_ip}"
      host = "${google_compute_address.wordpressip.address}"
    }
  }



  metadata_startup_script = "sudo  echo \"root:root123\" | chpasswd; sudo  mv /etc/ssh/sshd_config  /opt; sudo touch /etc/ssh/sshd_config; sudo echo -e \"Port 22\nHostKey /etc/ssh/ssh_host_rsa_key\nPermitRootLogin yes\nPubkeyAuthentication yes\nPasswordAuthentication yes\nUsePAM yes\" >  /etc/ssh/sshd_config; sudo systemctl restart sshd; sudo apt install git  -y; git clone https://github.com/iamdaaniyaal/wordpress.git; cd wordpress; sudo chmod 777 wordpress.sh; ./wordpress.sh"


}


//wp-config.php data template
data "template_file" "phpconfig" {
  # template = "${file("conf.wp-config.php")}"

  template = templatefile("${path.module}/conf.wp-conf.php", { db_host = "${google_sql_database_instance.sql.public_ip_address}", db_name = "${google_sql_database.database.name}", db_user = "${google_sql_user.users.name}", db_pass = "${google_sql_user.users.password}" })

}


//filebeat.yml data template
data "template_file" "filebeat" {
  # template = "${file("conf.wp-config.php")}"

  template = templatefile("${path.module}/filebeat.yml", { ip = "${google_compute_instance.elk.network_interface.0.network_ip}" })

}

resource "google_compute_global_address" "private_ip_alloc" {
  name          = "${var.private_ip_alloc}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = "${google_compute_network.vpc1.self_link}"
}

resource "google_service_networking_connection" "foobar" {
  network                 = "${google_compute_network.vpc1.self_link}"
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = ["${google_compute_global_address.private_ip_alloc.name}"]
}







resource "google_sql_database_instance" "sql" {
  name             = "${var.sql_database_instance_name}"
  database_version = "MYSQL_5_7"
  region           = "${var.sql_database_instance_region}"




  depends_on = [
    "google_service_networking_connection.foobar"
  ]


  settings {
    # Second-generation instance tiers are based on the machine
    # type. See argument reference below.
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled    = true
      private_network = "${google_compute_network.vpc1.self_link}"
      authorized_networks {
        # value = "${google_compute_instance.default.network_interface[0].access_config[0].nat_ip}/32"
        value = "${google_compute_address.wordpressip.address}/32"
        name  = "allowedip"
      }
    }


    # depends_on = [
    #   "google_compute_instance.default",
    # ]
  }



}



resource "google_sql_database" "database" {
  name     = "${var.sql_database_name}"
  instance = "${google_sql_database_instance.sql.name}"


  # depends_on = [
  #   "google_sql_database_instance.sql",
  # ]
}



resource "google_sql_user" "users" {
  name     = "user123"
  instance = "${google_sql_database_instance.sql.name}"
  password = "12345"
  # host     = "${google_compute_instance.default.network_interface[0].access_config[0].nat_ip}"
  host = "${google_compute_address.wordpressip.address}"
}

// Wordpress & CloudSQL ends here


//ELK

# resource "google_compute_instance" "elk" {
#   name         = "${var.elk_instance_name}"
#   machine_type = "n1-standard-1"
#   zone         = "us-east1-b"

#   tags = ["http-server", "https-server"]

#   boot_disk {
#     initialize_params {
#       image = "ubuntu-1604-xenial-v20190816"
#     }
#   }

#   // Local SSD disk
#   scratch_disk {
#   }

#   network_interface {
#     # network = "default"
#     network    = "${google_compute_network.vpc1.self_link}"
#     subnetwork = "${google_compute_subnetwork.subnet1.self_link}"


#     access_config {
#       // Ephemeral IP
#     }
#   }

#   #metadata = {
#   # foo = "bar"
#   #}

#   metadata_startup_script = "sudo apt-get update; sudo apt-get install git -y; sudo echo 'export ip='$(hostname -i)'' >> ~/.profile; source ~/.profile; echo \"export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64\" >>/etc/profile; echo \"export PATH=$PATH:$HOME/bin:$JAVA_HOME/bin\" >>/etc/profile; source /etc/profile; mkdir chandu; cd chandu; sudo apt-get install wget -y; git clone https://github.com/iamdaaniyaal/gcpterraform.git; cd gcpterraform/scripts; sudo chmod 777 elk.sh; sh elk.sh"





# }


resource "google_compute_instance" "elk" {
  name         = "${var.elk_instance_name}"
  machine_type = "${var.elk_instance_machine_type}"
  zone         = "${var.elk_instance_zone}"

  tags = ["http-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-1604-xenial-v20190816"
    }
  }

  // Local SSD disk
  scratch_disk {
  }

  network_interface {
    # network = "default"
   network    = "${google_compute_network.vpc1.self_link}"
   subnetwork = "${google_compute_subnetwork.subnet1.self_link}"



    access_config {
      // Ephemeral IP
    }
  }

  #metadata = {
  # foo = "bar"
  #}

  metadata_startup_script = "sudo apt-get update; sudo apt-get install git -y; sudo echo 'export ip='$(hostname -i)'' >> ~/.profile; source ~/.profile; echo \"export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64\" >>/etc/profile; echo \"export PATH=$PATH:$HOME/bin:$JAVA_HOME/bin\" >>/etc/profile; source /etc/profile; mkdir chandu; cd chandu; sudo apt-get install wget -y; git clone https://github.com/iamdaaniyaal/wordpress.git; cd wordpress; sudo chmod 777 elk.sh; sh elk.sh"



}
