# Copyright 2023-2024 Broadcom. All rights reserved.
# SPDX-License-Identifier: BSD-2
/*
    DESCRIPTION:
    VMware vSphere variables used for all builds.
    - Variables are use by the source blocks.
    - SÉCURITÉ: Toutes les valeurs sont récupérées depuis Bitwarden via le Makefile
*/
// vSphere Credentials - RÉCUPÉRÉES DEPUIS BITWARDEN
// vsphere_endpoint sera défini par la variable d'environnement PKR_VAR_vsphere_endpoint
// vsphere_username sera défini par la variable d'environnement PKR_VAR_vsphere_username
// vsphere_password sera défini par la variable d'environnement PKR_VAR_vsphere_password
vsphere_insecure_connection = true

// vSphere Settings - RÉCUPÉRÉES DEPUIS BITWARDEN
// vsphere_datacenter sera défini par la variable d'environnement PKR_VAR_vsphere_datacenter
// vsphere_host sera défini par la variable d'environnement PKR_VAR_vsphere_host
// vsphere_datastore sera défini par la variable d'environnement PKR_VAR_vsphere_datastore
// vsphere_network sera défini par la variable d'environnement PKR_VAR_vsphere_network
// vsphere_folder sera défini par la variable d'environnement PKR_VAR_vsphere_folder
//vsphere_cluster                        = "Cluster"
//vsphere_resource_pool                = "sfo-w01-rp01"
vsphere_set_host_for_datastore_uploads = false