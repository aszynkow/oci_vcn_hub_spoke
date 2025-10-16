/**
 * # Variables for Network Module
 */

variable "compartment_id" {
  description = "OCID of the compartment where the VCN will be created"
  type        = string
}

variable "vcn_name" {
  description = "Name of the VCN"
  type        = string
}

variable "vcn_cidr" {
  description = "CIDR block for the VCN"
  type        = string
}

variable "subnets" {
  description = "List of subnets to create in the VCN"
  type = list(object({
    name = string
    cidr = string
    security_list_rules = optional(list(object({
      type              = string
      protocol          = string
      port              = optional(number)
      source_cidr       = optional(string)
      destination_cidr  = optional(string)
      description       = string
    })))
  }))
}

variable "is_hub" {
  description = "Whether this VCN is the hub VCN"
  type        = bool
  default     = false
}

variable "is_spoke" {
  description = "Whether this VCN is a spoke VCN"
  type        = bool
  default     = false
}

variable "hub_drg_id" {
  description = "OCID of the hub DRG (required if is_spoke is true)"
  type        = string
  default     = null
}

variable "hub_vcn_id" {
  description = "OCID of the hub VCN (required if is_spoke is true)"
  type        = string
  default     = null
}

variable "freeform_tags" {
  description = "Freeform tags to apply to created resources"
  type        = map(string)
  default     = {}
}

variable "defined_tags" {
  description = "Defined tags to apply to created resources"
  type        = map(string)
  default     = {}
}

variable on_premis_cidr {
  description = "CIDR block for the on-prem"
  type        = string
}

variable "virtual_circuit_bandwidth_shape_name" {}
variable "virtual_circuit_customer_asn" {}
variable "virtual_circuit_display_name" {  }
variable "virtual_circuit_type" {}
variable "virtual_circuit_customer_bgp_peering_ip" {}
variable "virtual_circuit_oracle_bgp_peering_ip" {}
variable "fc_provider_name" {}