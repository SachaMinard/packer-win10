# Copyright 2023-2024 Broadcom. All rights reserved.
# SPDX-License-Identifier: BSD-2

/*
    DESCRIPTION:
    Microsoft Windows 10 build variables.
    Packer Plugin for VMware vSphere: 'vsphere-iso' builder.
*/

// Installation Operating System Metadata
vm_inst_os_language            = "fr-FR"
vm_inst_os_keyboard            = "fr-FR"
vm_guest_os_language           = "fr-FR"
vm_guest_os_keyboard           = "fr-FR"
vm_guest_os_timezone           = "UTC+1"
vm_inst_os_image               = "Windows 10 Pro"
vm_inst_os_kms_key_standard    = "W269N-WFGWX-YVC9B-4J6C9-T83GX"
vm_guest_os_edition_standard   = "pro"
vm_guest_os_experience         = ""
// Virtual Machine Guest Operating System Setting
vm_guest_os_type = "windows9_64Guest"
// Virtual Machine Hardware Settings
vm_firmware              = "efi-secure"
vm_cdrom_type            = "sata"
vm_cpu_count             = 2
vm_cpu_cores             = 1
vm_cpu_hot_add           = false
vm_mem_size              = 8192
vm_mem_hot_add           = false
vm_disk_size             = 102400
vm_disk_controller_type  = ["pvscsi"]
vm_disk_thin_provisioned = true
vm_network_card          = "vmxnet3"
// Removable Media Settings
iso_path = "microsoft/Windows 10"
iso_file = "fr-fr_windows_10_business_editions_version_22h2_updated_oct_2024_x64_dvd_2582115c.iso"
// Boot Settings
vm_boot_order       = "disk,cdrom"
vm_boot_wait        = "2s"
vm_boot_command     = ["<spacebar>"]
vm_shutdown_command = "shutdown /s /t 10 /f /d p:4:1 /c \"Shutdown by Packer\""
// Communicator Settings
communicator_port    = 5986
communicator_timeout = "12h"
// Computer Name
vm_computer_name  = "template-win10"