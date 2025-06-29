# Copyright 2023-2024 Broadcom. All rights reserved.
# SPDX-License-Identifier: BSD-2
/*
    DESCRIPTION:
    Build account variables used for all builds.
    - Variables are passed to and used by guest operating system configuration files (e.g., ks.cfg, autounattend.xml).
    - Variables are passed to and used by configuration scripts.
    - SÉCURITÉ: Toutes les valeurs sont récupérées depuis Bitwarden via le Makefile
*/
// Default Account Credentials - RÉCUPÉRÉES DEPUIS BITWARDEN
// build_username sera défini par la variable d'environnement PKR_VAR_build_username
// build_password sera défini par la variable d'environnement PKR_VAR_build_password