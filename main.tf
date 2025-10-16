/**
 * # OCI Hub-and-Spoke Architecture
 * 
 * This Terraform project implements a hub-and-spoke architecture on Oracle Cloud Infrastructure.
 */

locals {
  # Parse YAML configuration file
  config = yamldecode(file(var.config_file_path))
  
  # Extract compartment configurations
  compartments = local.config.compartments
  
  # Extract hub VCN configurations
  hub_vcn = local.config.hub_vcn
  
  # Extract spoke VCN configurations
  spokes_vcn = local.config.spokes_vcn
  
  # Extract IAM configurations
  groups = local.config.groups
  policies = local.config.policies
  
  # Extract monitoring configurations
  cloud_guard = local.config.cloud_guard
  logging = local.config.logging
  notification = local.config.notification
}

# Create all compartments
module "compartments" {
  source = "./modules/compartments"
  
  compartments = local.compartments
  tenancy_ocid = var.tenancy_ocid
  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

# Create hub VCN and associated resources
module "hub_network" {
  source = "./modules/network"
  
  vcn_name = local.hub_vcn.name
  vcn_cidr = local.hub_vcn.cidr
  compartment_id = module.compartments.compartment_ids[local.hub_vcn.compartment]
  subnets = local.hub_vcn.subnets
  
  # This is the hub VCN
  is_hub = true
  is_spoke = false
  
  on_premis_cidr = var.on_premis_cidr

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
  
  depends_on = [module.compartments]

  virtual_circuit_bandwidth_shape_name        = var.virtual_circuit_bandwidth_shape_name
virtual_circuit_customer_asn                = var.virtual_circuit_customer_asn
virtual_circuit_display_name                = var.virtual_circuit_display_name
virtual_circuit_type                        = var.virtual_circuit_type
virtual_circuit_customer_bgp_peering_ip     = var.virtual_circuit_customer_bgp_peering_ip
virtual_circuit_oracle_bgp_peering_ip       = var.virtual_circuit_oracle_bgp_peering_ip
fc_provider_name                            = var.fc_provider_name
}

module "hub_security" {
  source = "./modules/security"
  
  compartment_id = module.compartments.compartment_ids[local.hub_vcn.compartment]
  vcn_id = module.hub_network.vcn_id
  vcn_name = local.hub_vcn.name
  vcn_cidr = local.hub_vcn.cidr
  subnets = local.hub_vcn.subnets
  
  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
  
  depends_on = [module.hub_network]
}

# Create hub compute instances
/*module "hub_compute" {
  source = "./modules/compute"
  
  compartment_id = module.compartments.compartment_ids[local.hub_vcn.compartment]
  vcn_id = module.hub_network.vcn_id
  subnet_ids = module.hub_network.subnet_ids
  prefix = local.hub_vcn.name
  
  # Process instances and map compartment names to IDs
  instances = [
    for instance in local.hub_vcn.instances : merge(
      instance,
      {
        compartment_id = lookup(module.compartments.compartment_ids, instance.compartment, module.compartments.compartment_ids[local.hub_vcn.compartment])
      }
    )
  ]
  
  ssh_public_key = var.ssh_public_key
  freeform_tags = var.freeform_tags
  defined_tags = var.defined_tags
  
  depends_on = [module.hub_security]
}
*/
/*
# Create hub firewall
module "hub_firewall" {
  source = "./modules/firewall"
  
  compartment_id = module.compartments.compartment_ids[local.hub_vcn.compartment]
  vcn_id = module.hub_network.vcn_id
  subnet_id = module.hub_network.subnet_ids[local.hub_vcn.firewall.subnet]
  
  depends_on = [module.hub_network]
}
*/
# Create spoke VCNs and associated resources
module "spoke_networks" {
  source = "./modules/network"
  count = length(local.spokes_vcn)
  
  vcn_name = local.spokes_vcn[count.index].name
  vcn_cidr = local.spokes_vcn[count.index].cidr
  compartment_id = module.compartments.compartment_ids[local.spokes_vcn[count.index].compartment]
  subnets = local.spokes_vcn[count.index].subnets
  
  # Set up DRG attachments and route tables for hub connectivity
  hub_vcn_id = module.hub_network.vcn_id
  hub_drg_id = module.hub_network.drg_id
  is_spoke = true
  is_hub = false
  
  on_premis_cidr = var.on_premis_cidr

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
   

  depends_on = [module.compartments, module.hub_network]

virtual_circuit_bandwidth_shape_name        = var.virtual_circuit_bandwidth_shape_name
virtual_circuit_customer_asn                = var.virtual_circuit_customer_asn
virtual_circuit_display_name                = var.virtual_circuit_display_name
virtual_circuit_type                        = var.virtual_circuit_type
virtual_circuit_customer_bgp_peering_ip     = var.virtual_circuit_customer_bgp_peering_ip
virtual_circuit_oracle_bgp_peering_ip       = var.virtual_circuit_oracle_bgp_peering_ip
fc_provider_name                            = var.fc_provider_name

}

# Create spoke security lists
module "spoke_security" {
  source = "./modules/security"
  count = length(local.spokes_vcn)
  
  compartment_id = module.compartments.compartment_ids[local.spokes_vcn[count.index].compartment]
  vcn_id = module.spoke_networks[count.index].vcn_id
  vcn_name = local.spokes_vcn[count.index].name
  vcn_cidr = local.spokes_vcn[count.index].cidr
  subnets = local.spokes_vcn[count.index].subnets
  
  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
  
  depends_on = [module.spoke_networks]
}

/*
# Create spoke compute instances (including jump servers)
module "spoke_compute" {
  source = "./modules/compute"
  count = length(local.spokes_vcn)
  
  compartment_id = module.compartments.compartment_ids[local.spokes_vcn[count.index].compartment]
  vcn_id = module.spoke_networks[count.index].vcn_id
  subnet_ids = module.spoke_networks[count.index].subnet_ids
  prefix = local.spokes_vcn[count.index].name
  
  # Process instances and map compartment names to IDs
  instances = [
    for instance in lookup(local.spokes_vcn[count.index], "instances", []) : merge(
      instance,
      {
        compartment_id = lookup(module.compartments.compartment_ids, instance.compartment, module.compartments.compartment_ids[local.spokes_vcn[count.index].compartment])
      }
    )
  ]
  
  ssh_public_key = var.ssh_public_key
  freeform_tags = var.freeform_tags
  defined_tags = var.defined_tags
  
  depends_on = [module.spoke_security]
}
*/
/*
# Create spoke databases
module "spoke_databases" {
  source = "./modules/database"
  count = length(local.spokes_vcn)
  
  compartment_id = module.compartments.compartment_ids[local.spokes_vcn[count.index].compartment]
  vcn_id = module.spoke_networks[count.index].vcn_id
  
  # Try to find a database subnet using different naming patterns
  subnet_id = lookup(module.spoke_networks[count.index].subnet_ids, "db", lookup(module.spoke_networks[count.index].subnet_ids, "${local.spokes_vcn[count.index].name}-db", null))
  
  # Provide a default subnet in case no db subnet is found
  default_subnet_id = values(module.spoke_networks[count.index].subnet_ids)[0]
  
  prefix = local.spokes_vcn[count.index].name
  dbcs_config = local.spokes_vcn[count.index].dbcs
  
  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
  
  depends_on = [module.spoke_networks]
}
*/
/*
# Create spoke load balancers
module "spoke_loadbalancers" {
  source = "./modules/loadbalancer"
  count = length(local.spokes_vcn)
  
  compartment_id = module.compartments.compartment_ids[local.spokes_vcn[count.index].compartment]
  vcn_id = module.spoke_networks[count.index].vcn_id
  subnet_ids = module.spoke_networks[count.index].subnet_ids
  lb_configs = local.spokes_vcn[count.index].loadbalancers
  
  depends_on = [module.spoke_networks]
}
*/
# Create IAM groups
module "iam_groups" {
  source = "./modules/iam/groups"
  
  groups = local.groups
  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

# Create IAM policies
module "iam_policies" {
  source = "./modules/iam/policies"
  
  tenancy_ocid = var.tenancy_ocid
  policies = local.policies
  compartment_ids = module.compartments.compartment_ids
  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
  
  depends_on = [module.iam_groups]
}
/*
# Set up monitoring and notifications
module "monitoring" {
  source = "./modules/monitoring"
  
  tenancy_ocid = var.tenancy_ocid
  compartment_id = var.compartment_id
  region = var.region
  vcn_id = module.hub_network.vcn_id
  prefix = "hub-spoke"
  
  cloud_guard_enabled = local.cloud_guard.enable
  logging_enabled = local.logging.enable
  notification_enabled = local.notification.enable
  notification_email = local.notification.email
  
  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
  
  depends_on = [
    module.hub_network,
    module.spoke_networks,
    module.hub_compute,
    module.spoke_compute,
    module.spoke_databases,
    module.spoke_loadbalancers
  ]
}
*/