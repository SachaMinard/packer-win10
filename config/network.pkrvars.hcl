# Copyright 2023-2024 Broadcom. All rights reserved.
# SPDX-License-Identifier: BSD-2
/*
    DESCRIPTION:
    Network variables used for all builds.
    - Variables are passed to and used by guest operating system configuration files (e.g., ks.cfg).
    - SÉCURITÉ: Les valeurs réseau peuvent être récupérées depuis Bitwarden via le Makefile
*/
// VM Network Settings (default DHCP) - RÉCUPÉRÉES DEPUIS BITWARDEN SI NÉCESSAIRE
// vm_ip_address sera défini par la variable d'environnement PKR_VAR_vm_ip_address (si configuré)
// vm_ip_gateway sera défini par la variable d'environnement PKR_VAR_vm_ip_gateway (si configuré)
// vm_dns_primary sera défini par la variable d'environnement PKR_VAR_vm_dns_primary (si configuré)
// vm_dns_secondary sera défini par la variable d'environnement PKR_VAR_vm_dns_secondary (si configuré)
# vm_ip_address     = "10.248.0.24/20"
# vm_ip_metric      = 10
# vm_ip_prefix      = "0.0.0.0/0"
# vm_ip_gateway     = "10.248.0.1"
# vm_dns_primary    = "10.232.42.14"
# vm_dns_secondary  = "10.232.42.15"