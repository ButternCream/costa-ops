variable "postgres_user" {
  type = string
}

variable "postgres_db" {
  type = string
}

variable "postgres_password" {
  type      = string
  sensitive = true
}

variable "postgres_port" {
  type = string
}

variable "costa_api_port" {
  type = string
}

variable "region" {
  type = string
}

variable "repo" {
  type = string
}
