/**
 * # Variables for OCI Hub-and-Spoke Architecture
 * 
 * This file defines the variables used in the Terraform configuration.
 */

variable "config_file_path" {
  description = "Path to the YAML configuration file"
  type        = string
  default     = "input.yaml"
}

variable "tenancy_ocid" {
  description = "OCID of your tenancy"
  type        = string
  default = ""
}

variable "user_ocid" {
  description = "OCID of the user calling the API"
  type        = string
  default = ""
}

variable "fingerprint" {
  description = "Fingerprint of the API private key"
  type        = string
  default = ""
}

variable "private_key_path" {
  description = "Path to the private key used for OCI API calls"
  type        = string
  default = ""
}

variable "region" {
  description = "OCI region to deploy resources"
  type        = string
}

variable "compartment_id" {
  description = "OCID of the root compartment"
  type        = string
}

variable "freeform_tags" {
  description = "Freeform tags to apply to all resources"
  type        = map(string)
  default     = {
    "project" = "hub-spoke-architecture"
  }
}

variable "defined_tags" {
  description = "Defined tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable on_premis_cidr {
  description = "CIDR block for the on-prem"
  type        = string
}


variable "virtual_circuit_customer_asn" {default = "65203"}
variable "fc_provider_name" { default = "Megaport"}
variable "virtual_circuit_bandwidth_shape_name" {default = "1 Gbps"}
variable "virtual_circuit_display_name" { default = "oci-poc-fs1" }
variable "virtual_circuit_type" { default =  "PRIVATE"}
variable "virtual_circuit_customer_bgp_peering_ip" {}
variable "virtual_circuit_oracle_bgp_peering_ip" {}

