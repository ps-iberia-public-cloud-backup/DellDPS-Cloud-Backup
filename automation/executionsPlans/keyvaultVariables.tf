variable "key_name" {
  description = "The SSH key name to use for the instance"
  type        = string
}

variable "container_type" {
  default     = "docker"
  description = "The container type"
}

variable "source_image" {
  default     = "your-source-image"
  description = "The source image"
}

variable "source_image_version" {
  default     = "latest"
  description = "The source image version"
}

variable "target_image" {
  default     = "your-target-image"
  description = "The target image"
}

variable "container_installation_folder" {
  default     = "/opt/container"
  description = "The container installation folder"
}

variable "proxy" {
  default     = ""
  description = "Proxy (optional)"
}

variable "az_resource_group" {
  default     = ""
  description = "Azure resource group (optional)"
}

variable "az_tenant_id" {
  default     = ""
  description = "Azure tenant ID (optional)"
}

variable "az_service_principal_client_id" {
  default     = ""
  description = "Azure service principal client ID (optional)"
}

variable "az_service_principal_client_secret" {
  default     = ""
  description = "Azure service principal client secret (optional)"
}

variable "az_secret_spn" {
  default     = ""
  description = "Azure secret SPN (optional)"
}

variable "az_subscription_id" {
  default     = ""
  description = "Azure subscription ID (optional)"
}

variable "avamar_server_name" {
  default     = ""
  description = "Avamar server name (optional)"
}

variable "datadomain_server_name" {
  default     = ""
  description = "Data Domain server name (optional)"
}

variable "container_name" {
  default     = ""
  description = "Container name (optional)"
}

variable "az_container_name" {
  default     = ""
  description = "Azure container name (optional)"
}
