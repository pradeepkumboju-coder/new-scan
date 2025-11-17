terraform {
  required_version = ">=1.3.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

# Optional: VPC network settings should be set according to org policy.
# Create a Memorystore Redis instance for debounce queue (replace with managed Redis if desired)
resource "google_redis_instance" "dispatcher_redis" {
  name           = "dispatcher-redis"
  tier           = "STANDARD_HA"
  memory_size_gb = 1
  region         = var.region
  location_id    = var.zone
}

# DNS record for dispatcher fronting IP (requires you to supply dispatcher_ip)
resource "google_dns_record_set" "dispatcher" {
  managed_zone = var.dns_zone
  name         = "${var.dispatcher_hostname}."
  type         = "A"
  ttl          = 300
  rrdatas      = [var.dispatcher_ip]
}
