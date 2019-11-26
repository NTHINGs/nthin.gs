terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "tecnoly"

    workspaces {
      name = "nthings-site"
    }
  }
}

provider "google" {
  credentials = file("./credentials.json")
  project     = var.gcp_project
  region      = var.gcp_region
}

data "google_compute_image" "ubuntu" {
  family  = "ubuntu-1604-lts"
  project = "ubuntu-os-cloud"
}

resource "google_compute_firewall" "firewall" {
  name    = "nginx-firewall"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  # These IP ranges are required for health checks
  source_ranges = ["0.0.0.0/0"]

  # Target tags define the instances to which the rule applies
  target_tags = ["nginx"]
}

resource "google_compute_instance" "nginx" {
  name         = "nthings-nginx"
  machine_type = var.machine_type
  zone         = var.gcp_zone

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Include this section to give the VM an external ip address
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_public_key)}"
  }

  metadata_startup_script = templatefile("${path.module}/templates/startup.tmpl", { user = var.ssh_user })

  tags = ["nginx"]
}

resource "google_dns_managed_zone" "dns-zone" {
  name        = "nthings"
  dns_name    = "nthin.gs."
}


resource "google_dns_record_set" "dns" {
  name = google_dns_managed_zone.dns-zone.dns_name
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.dns-zone.name

  rrdatas = [google_compute_instance.nginx.network_interface.0.access_config.0.nat_ip]
}

resource "null_resource" "godaddy_dns" {
  provisioner "local-exec" {
    command = "python3 ${path.module}/scripts/dns.py ${join(",", google_dns_managed_zone.dns-zone.name_servers)} ${google_dns_record_set.dns.name} ${var.godaddy_api_key}"
  }

  triggers = {
    dns_name = google_dns_record_set.dns.name
    script = filesha256("${path.module}/scripts/dns.py")
  }
}