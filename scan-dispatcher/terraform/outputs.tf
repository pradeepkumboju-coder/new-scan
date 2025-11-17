output "redis_host" {
  description = "Redis host address"
  value       = google_redis_instance.dispatcher_redis.host
}

output "redis_port" {
  description = "Redis port"
  value       = google_redis_instance.dispatcher_redis.port
}
