# Copyright 2023-2024 Broadcom. All rights reserved.
# SPDX-License-Identifier: BSD-2
/*
    DESCRIPTION:
    Common variables used for all builds.
    - Variables are use by the source blocks.
    - SÉCURITÉ: Certaines valeurs sont récupérées depuis Bitwarden via le Makefile
*/
// Virtual Machine Settings
common_vm_version           = 20
common_tools_upgrade_policy = true
common_remove_cdrom         = true
// Template and Content Library Settings
common_template_conversion         = true
# common_content_library_name        = "PACKER_WINDOWS_TEST"
# common_content_library_ovf         = true
# common_content_library_destroy     = true
# common_content_library_skip_export = false
// OVF Export Settings
common_ovf_export_enabled   = false
common_ovf_export_overwrite = true
// Removable Media Settings - RÉCUPÉRÉE DEPUIS BITWARDEN
// common_iso_datastore sera défini par la variable d'environnement PKR_VAR_common_iso_datastore
// Boot and Provisioning Settings
common_data_source       = "disk"
common_http_ip           = null
common_http_port_min     = 8000
common_http_port_max     = 8099
common_ip_wait_timeout   = "180m"
common_ip_settle_timeout = "5s"
common_shutdown_timeout  = "15m"
// HCP Packer
common_hcp_packer_registry_enabled = false

// Guest OS Metadata - utilisé pour naming et HCP Packer
vm_guest_os_family  = "windows"
vm_guest_os_name    = "desktop"
vm_guest_os_version = "10"