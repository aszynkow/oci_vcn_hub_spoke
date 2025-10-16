/**
 * # OCI Network Module
 * 
 * This module creates VCNs, subnets, and related network resources.
 */

# Create the VCN
resource "oci_core_vcn" "vcn" {
  cidr_block     = var.vcn_cidr
  compartment_id = var.compartment_id
  display_name   = var.vcn_name
  dns_label      = replace(var.vcn_name, "-", "")
  
  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

# Create Internet Gateway for the VCN
resource "oci_core_internet_gateway" "internet_gateway" {
  count = var.is_hub ? 1 : 0
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${var.vcn_name}-igw"
  enabled        = true
  
  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

# Create NAT Gateway for private subnets
resource "oci_core_nat_gateway" "nat_gateway" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${var.vcn_name}-natgw"
  
  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

# Create Service Gateway for OCI Services
resource "oci_core_service_gateway" "service_gateway" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${var.vcn_name}-sgw"
  
  services {
    service_id = data.oci_core_services.all_oci_services.services[0].id
  }
  
  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

# Get all OCI Services
data "oci_core_services" "all_oci_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

# Create Dynamic Routing Gateway if this is the hub VCN
resource "oci_core_drg" "drg" {
  count = var.is_hub ? 1 : 0
  
  compartment_id = var.compartment_id
  display_name   = "${var.vcn_name}-drg"
  
  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

# Attach DRG to the VCN
resource "oci_core_drg_attachment" "drg_attachment" {
  count = var.is_hub || var.is_spoke ? 1 : 0
  
  # For hub, use the created DRG. For spoke, use the provided hub DRG ID
  drg_id       = var.is_hub ? oci_core_drg.drg[0].id : var.hub_drg_id != null ? var.hub_drg_id : ""
  vcn_id       = oci_core_vcn.vcn.id
  display_name = "${var.vcn_name}-drg-attachment"
  
  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}


# Create default route table for the VCN
resource "oci_core_default_route_table" "default_route_table" {
  count = var.is_hub ? 1 : 0
  manage_default_resource_id = oci_core_vcn.vcn.default_route_table_id
  display_name               = "${var.vcn_name}-default-rt"
  
  # Route traffic to the internet through the Internet Gateway
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.internet_gateway[0].id
  }
  
  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

# Create a route table for private subnets
resource "oci_core_route_table" "private_route_table" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${var.vcn_name}-private-rt"
  
  # Route traffic to the internet through the NAT Gateway
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.nat_gateway.id
  }
  
  # Route traffic to OCI services through the Service Gateway
  route_rules {
    destination       = data.oci_core_services.all_oci_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.service_gateway.id
  }
  
  dynamic "route_rules" {
    for_each = var.is_hub ? [1] : []
    content {
      destination       = var.on_premis_cidr  # replace with your hub-specific destination
      destination_type  = "CIDR_BLOCK"
      network_entity_id = oci_core_drg.drg[0].id  # replace with the hub network entity
    }
  }

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

# Create a separate route table for DRG routes to avoid circular dependencies
resource "oci_core_route_table" "drg_route_table" {
  count = var.is_spoke ? 1 : 0
  
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${var.vcn_name}-drg-rt"
  
  # For spoke VCNs, route traffic to other spokes through the hub DRG
  /*route_rules {
    destination       = var.on_premis_cidr # This covers all VCNs in our design
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_drg.drg[0].id#oci_core_drg_attachment.drg_attachment[0].id
  }*/
  
  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

# Create subnets based on provided configuration
resource "oci_core_subnet" "subnets" {
  for_each = {
    for subnet in var.subnets : subnet.name => subnet
  }
  
  cidr_block     = each.value.cidr
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = each.value.name
  dns_label      = replace(each.value.name, "-", "")
  
  # Determine if the subnet is public or private based on name pattern
  # If the subnet contains "public" or "hub-access", it's public
  prohibit_public_ip_on_vnic = ! (contains(["public", "hub-access"], lower(each.value.name)) || contains(["hub-public", "hub-access"], each.value.name))
  
  # Use the appropriate route table
  # For spoke VCNs, use the DRG route table for private subnets
  route_table_id = contains(["public", "hub-access"], lower(each.value.name)) || contains(["hub-public", "hub-access"], each.value.name) ? oci_core_default_route_table.default_route_table[0].id : var.is_spoke ? oci_core_route_table.drg_route_table[0].id : oci_core_route_table.private_route_table.id
  
  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

# Create DRG route distribution for the hub DRG (if this is the hub)
resource "oci_core_drg_route_distribution" "hub_drg_route_distribution" {
  count = var.is_hub ? 1 : 0
  
  drg_id      = oci_core_drg.drg[0].id
  display_name = "${var.vcn_name}-drg-route-distribution"
  distribution_type = "IMPORT"
}

# Create a route distribution statement for the hub DRG
resource "oci_core_drg_route_distribution_statement" "hub_drg_route_distribution_statement" {
  count = var.is_hub ? 1 : 0
  
  drg_route_distribution_id = oci_core_drg_route_distribution.hub_drg_route_distribution[0].id
  action = "ACCEPT"
  priority = 1
  
  match_criteria {
    match_type = "DRG_ATTACHMENT_TYPE"
    attachment_type = "VCN"
  }
}

# Create DRG route table for hub-to-spoke routing
resource "oci_core_drg_route_table" "hub_drg_route_table" {
  count = var.is_hub ? 1 : 0
  
  drg_id       = oci_core_drg.drg[0].id
  display_name = "${var.vcn_name}-drg-rt"
  
  import_drg_route_distribution_id = oci_core_drg_route_distribution.hub_drg_route_distribution[0].id
}

# Break the circular dependency by removing the direct references
# Instead, use local variables to refer to the network entities
locals {
  drg_attachment_id = var.is_hub || var.is_spoke ? oci_core_drg_attachment.drg_attachment[0].id : null
  #drg_id       = var.is_hub ? oci_core_drg.drg[0].id : oci_core_drg.drg[0].id #var.hub_drg_id != null ? var.hub_drg_id : ""
}

/*resource "oci_core_virtual_circuit" "generated_oci_core_virtual_circuit" {
	
  bandwidth_shape_name = "1 Gbps"
	compartment_id = var.compartment_id
	cross_connect_mappings {
		customer_bgp_peering_ip = "10.10.101.33/30"
		oracle_bgp_peering_ip = "10.10.101.34/30"
	}
	customer_asn = "133937"
	display_name = "shared_demo_fc1"
	freeform_tags = var.freeform_tags
	gateway_id = oci_core_drg.drg.id
	ip_mtu = "MTU_1500"
	is_bfd_enabled = "false"
	provider_service_id = "ocid1.providerservice.oc1.ap-sydney-1.aaaaaaaaejfl3464godhy52ft6toy7x6pm5ci3eb3k4xmpvjxv5fql7sgiya"
	type = "PRIVATE"
}
*/
resource oci_core_virtual_circuit "poc_oci_fs1" {
  count = var.is_hub ? 1 : 0

  bandwidth_shape_name = var.virtual_circuit_bandwidth_shape_name
  compartment_id       = var.compartment_id
  cross_connect_mappings {
    #bgp_md5auth_key = <<Optional value not found in discovery>>
    #cross_connect_or_cross_connect_group_id = <<Optional value not found in discovery>>
    customer_bgp_peering_ip = var.virtual_circuit_customer_bgp_peering_ip
    #customer_bgp_peering_ipv6 = <<Optional value not found in discovery>>
    oracle_bgp_peering_ip = var.virtual_circuit_oracle_bgp_peering_ip
    #oracle_bgp_peering_ipv6 = <<Optional value not found in discovery>>
    #vlan = <<Optional value not found in discovery>>
  }
  customer_asn = var.virtual_circuit_customer_asn
  display_name = var.virtual_circuit_display_name
  freeform_tags  = var.freeform_tags
  gateway_id          = oci_core_drg.drg[0].id
  provider_service_id = local.fc_provider_id
  type = var.virtual_circuit_type
}

locals {
#fc_provider_id = data.oci_core_fast_connect_provider_services.ps1.fast_connect_provider_services.3.id
fc_provider_service = var.is_hub ? [for x in data.oci_core_fast_connect_provider_services.ps1[0].fast_connect_provider_services: x if x.provider_name == var.fc_provider_name] : []
fc_provider_id = var.is_hub ? local.fc_provider_service.0.id : 0
}
data oci_core_fast_connect_provider_services ps1 {
    count = var.is_hub ? 1 : 0
    compartment_id = var.compartment_id
}