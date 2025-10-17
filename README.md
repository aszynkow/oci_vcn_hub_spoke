# oci_poc
Deploys OCI basic VCN Hub and Spoke infrastructure

This guide helps you install and use **OCI POC Infrastructure**.

![OCI POC Infrastructure](images/ocipoc_architecture_infra.png)


1. Recommended to be executed by a member of Tenancy Administrator group. 
2. Deploy a dedicated **OCI POC Infrastructure** stack.
   - this stack imports a cusotm image so first time may run ~10min longer
3. Clean up resources when you’re done.

---

## Step 1: Ask your Your Tenancy Administrator for assisntance.

 If you **are** a tenancy administrator, Resource Manager will typically deploy the minimal required policies automatically, but you can reference the same IAM policies, groups and dynamic-groups. No users are created.

---

## Step 2: Deploy the OCI POC infrastructure

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?region=home&zipUrl=https://github.com/aszynkow/oci_vcn_hub_spoke/raw/main/releases/download/v1.0.0/ocipoc.zip)

1. Click **Deploy to Oracle Cloud** above.
2. In **Create Stack**:
   - Give your stack a **name** (e.g. _aipoc-stack_).
   - Select the **compartment** where you want OCI OCI POC deployed.
   - Provide any additional parameters (such as VCN CIDR and providing public ssh key and ADB/OpenSearch cluster user credentials) according to your preferences.
3. Click **Next**, then **Create**, and finally choose **Run apply** to provision your cluster.
4. Monitor the progress in **Resource Manager → Stacks**. Once the status is **Succeeded**, you have a A10 GPU VM, WAF/Load Balancer, PostgreSQl DB, Object Store bucket and Bastion Service to host and work with OCI OCI POC.

## Cleanup

When you are finished, you can remove the resources you created in **two steps**, in this order:

1. **Destroy the OCI OCI POCs Stack**

   - Go to **Resource Manager → Stacks** in the OCI Console.
   - Select the stack you used to install **OCI OCI POC** (from Step 3).
   - Choose **Terraform Actions → Destroy**, confirm, and wait until the job succeeds.

Following this order ensures you do not have leftover services or dependencies in your tenancy. Once both stacks are destroyed, your tenancy will be free of any OCI OCI POC-related resources.

---

## Need Help?

- For questions or additional support, contact [adam.szynkowski@oracle.com](mailto:adam.szynkowski@oracle.com).