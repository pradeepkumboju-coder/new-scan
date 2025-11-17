variable "project" {
  description = "GCP project id"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone (for redis location_id)"
  type        = string
  default     = "us-central1-a"
}

variable "dns_zone" {
  description = "Managed zone name in Cloud DNS"
  type        = string
}

variable "dispatcher_hostname" {
  description = "Fully qualified hostname for dispatcher ingress (e.g. dispatcher.company.com)"
  type        = string
}

variable "dispatcher_ip" {
  description = "External IP address for DNS record (LB IP). Provide after LB created or use blank for dynamic)"
  type        = string
  default     = ""
}
