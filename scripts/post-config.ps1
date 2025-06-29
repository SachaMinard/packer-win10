<#
.SYNOPSIS
    Optimized Windows post-configuration script for Packer

.DESCRIPTION
    This script automates the full configuration of a Windows VM after installation.
    It loads environment variables from Bitwarden, synchronizes PowerShell modules,
    and configures all essential system components.

.PARAMETER SourcePath
    Source path for files (default F:\)

.PARAMETER LogPath
    Path for log files (default C:\temp\logs)

.EXAMPLE
    .\post-config.ps1
    Runs the full configuration with default parameters

.NOTES
    Author: STA4CK Team
    Version: 2.0
    Last modified: $(Get-Date -Format 'yyyy-MM-dd')
    
    Prerequisites:
    - Run as administrator
    - secrets.env file present on F:\
    - init.ps1 script present on F:\
    - PowerShell modules present on F:\modules\

.LINK
    https://github.com/sta4ck/packer-windows
#>

param(
    [string]$SourcePath = "F:\",
    [string]$LogPath = "C:\temp\logs"
)

$ProgressPreference = 'SilentlyContinue'

# Set English culture for error messages
[System.Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'
[System.Threading.Thread]::CurrentThread.CurrentCulture = 'en-US'

# ============================================================================
# GLOBAL VARIABLES AND CONFIGURATION
# ============================================================================

$Global:StartTime = Get-Date
$Global:LogFile = Join-Path $LogPath "post-config-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$Global:TranscriptFile = Join-Path $LogPath "post-config-transcript-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$Global:StepResults = @()
$Global:ErrorCount = 0
$Global:WarningCount = 0

# Create log directory
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

# Start complete transcript
Start-Transcript -Path $Global:TranscriptFile -Append

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Write-StepHeader {
    param(
        [string]$StepNumber,
        [string]$Title
    )
    
    $header = @"

===============================================================================
 STEP $StepNumber - $($Title.ToUpper())
===============================================================================
"@
    
    Write-Host $header -ForegroundColor Cyan
}

function Write-Log {
    param(
        [string]$Level,
        [string]$Message
    )
    
    # Console output with colors (automatically captured by transcript)
    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "INFO" { "White" }
        default { "Gray" }
    }
    
    Write-Host "  [$Level] $Message" -ForegroundColor $color
    
    # Update counters
    if ($Level -eq "ERROR") { $Global:ErrorCount = $Global:ErrorCount + 1 }
    if ($Level -eq "WARN") { $Global:WarningCount = $Global:WarningCount + 1 }
}

function Add-StepResult {
    param(
        [string]$Step,
        [string]$Status,
        [string]$Details = ""
    )
    
    $Global:StepResults += [PSCustomObject]@{
        Step     = $Step
        Status   = $Status
        Details  = $Details
        Duration = ""
    }
}

function Test-CommandAvailable {
    param([string]$CommandName)
    return (Get-Command $CommandName -ErrorAction SilentlyContinue) -ne $null
}

function Pause-OnError {
    Write-Host "Press Enter to continue after fixing the issue..." -ForegroundColor Yellow
    Read-Host | Out-Null
}

# Function removed - no longer needed with optimized Enable-NAS

function Copy-LogToNAS {
    Write-Host "===============================================================================" -ForegroundColor Green
    Write-Host " COPY LOGS TO NAS" -ForegroundColor Green
    Write-Host "===============================================================================" -ForegroundColor Green
    
    # Check Z: drive availability
    if (Test-Path "Z:\") {
        try {
            $nasLogsPath = "Z:\logs"
            if (-not (Test-Path $nasLogsPath)) {
                New-Item -Path $nasLogsPath -ItemType Directory -Force | Out-Null
                Write-Host "[OK] Directory Z:\logs created" -ForegroundColor Green
            }
            
            # Copy transcript
            $nasTranscriptFile = Join-Path $nasLogsPath "post-config-transcript-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
            Copy-Item -Path $Global:TranscriptFile -Destination $nasTranscriptFile -Force
            Write-Host "[OK] Transcript copied to: $nasTranscriptFile" -ForegroundColor Green
            
            Write-Host "[SUCCESS] Logs saved successfully to NAS" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "[ERROR] Error copying to NAS: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Local transcript available: $Global:TranscriptFile" -ForegroundColor Yellow
            return $false
        }
    }
    else {
        Write-Host "[ERROR] Drive Z: not available" -ForegroundColor Red
        Write-Host "NAS is not mounted or accessible" -ForegroundColor Yellow
        Write-Host "Local transcript available: $Global:TranscriptFile" -ForegroundColor Yellow
        Write-Host "Press Enter after checking/mounting drive Z: or to continue without copy..." -ForegroundColor Yellow
        Read-Host | Out-Null
        return $false
    }
}

# ============================================================================
# MAIN SCRIPT - START
# ============================================================================

Write-Host @"
===============================================================================
 WINDOWS POST-CONFIGURATION SCRIPT
 STA4CK AUTOMATION
===============================================================================
"@ -ForegroundColor Magenta

Write-Host "[INFO] Script started at $(Get-Date)" -ForegroundColor White
Write-Host "[INFO] Source path: $SourcePath" -ForegroundColor White
Write-Host "[INFO] Transcript file: $Global:TranscriptFile" -ForegroundColor White

# ============================================================================
# 1. LOAD ENVIRONMENT VARIABLES
# ============================================================================

Write-StepHeader "1" "Load Environment Variables"

$step1Start = Get-Date
try {
    $secretsFile = Join-Path $SourcePath "secrets.env"
    
    if (-not (Test-Path $secretsFile)) {
        throw "Secrets file not found: $secretsFile"
    }
    
    Write-Log "INFO" "Reading secrets file: $secretsFile"
    $encodedContent = Get-Content $secretsFile -Raw
    $decodedBytes = [System.Convert]::FromBase64String($encodedContent.Trim())
    $plainContent = [System.Text.Encoding]::UTF8.GetString($decodedBytes)
    
    $variableCount = 0
    $plainContent -split "`n" | ForEach-Object {
        $line = $_.Trim()
        if ($line -and $line -match '^([^=]+)="?([^"]*)"?$') {
            $varName = $matches[1]
            $varValue = $matches[2]
            [System.Environment]::SetEnvironmentVariable($varName, $varValue, [System.EnvironmentVariableTarget]::Process)
            $variableCount++
            
            if ($varName -match "PASSWORD|SECRET") {
                Write-Log "INFO" "Loaded variable: $varName = ***MASKED***"
            }
            else {
                Write-Log "INFO" "Loaded variable: $varName = $varValue"
            }
        }
    }
    
    Write-Log "SUCCESS" "Successfully loaded $variableCount environment variables"
    Add-StepResult "Environment Variables" "SUCCESS" "$variableCount variables loaded"
    
}
catch {
    Write-Log "ERROR" "Failed to load environment variables: $_"
    Add-StepResult "Environment Variables" "FAILED" $_.Message
    Pause-OnError
    exit 1
}

$step1Duration = (Get-Date) - $step1Start
$Global:StepResults[-1].Duration = "{0:F2}s" -f $step1Duration.TotalSeconds

# ============================================================================
# 2. EXECUTE INIT.PS1
# ============================================================================

Write-StepHeader "2" "Execute PowerShell Initialization"

$step2Start = Get-Date
try {
    $initScript = Join-Path $SourcePath "init.ps1"
    
    if (-not (Test-Path $initScript)) {
        throw "Init script not found: $initScript"
    }
    
    Write-Log "INFO" "Executing init.ps1 with Bitwarden credentials"
    & $initScript -Email $env:BW_EMAIL -Password $env:BW_PASSWORD -ClientId $env:BW_CLIENTID -ClientSecret $env:BW_CLIENTSECRET -EnvPassword $env:ENV_PASSWORD
    
    Write-Log "SUCCESS" "Init script executed successfully"
    Add-StepResult "PowerShell Init" "SUCCESS" "Bitwarden modules synchronized"
    
}
catch {
    Write-Log "ERROR" "Failed to execute init script: $_"
    Add-StepResult "PowerShell Init" "FAILED" $_.Message
    Pause-OnError
    exit 1
}

$step2Duration = (Get-Date) - $step2Start
$Global:StepResults[-1].Duration = "{0:F2}s" -f $step2Duration.TotalSeconds

# ============================================================================
# 3. LOAD POWERSHELL MODULES
# ============================================================================

Write-StepHeader "3" "Load PowerShell Modules"

$step3Start = Get-Date
try {
    $modulesPath = Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Modules"
    
    if (Test-Path $modulesPath) {
        Write-Log "INFO" "Loading modules from: $modulesPath"
        
        $allScripts = Get-ChildItem -Path $modulesPath -Recurse -Filter "*.ps1" -ErrorAction SilentlyContinue
        $loadedCount = 0
        $failedCount = 0
        
        foreach ($scriptFile in $allScripts) {
            try {
                if ($scriptFile.Name -notmatch "(test|config|setup)" -and $scriptFile.Name -notlike "*template*") {
                    . $scriptFile.FullName
                    $loadedCount++
                }
            }
            catch {
                $failedCount++
                Write-Log "WARN" "Failed to load script: $($scriptFile.Name) - $_"
            }
        }
        
        $globalModule = Join-Path $modulesPath "GlobalModules.psm1"
        if (Test-Path $globalModule) {
            Import-Module $globalModule -Force -Global
            Write-Log "INFO" "GlobalModules.psm1 imported successfully"
        }
        
        Write-Log "SUCCESS" "Loaded $loadedCount modules ($failedCount failed)"
        Add-StepResult "PowerShell Modules" "SUCCESS" "$loadedCount loaded, $failedCount failed"
        
    }
    else {
        Write-Log "WARN" "Modules directory not found: $modulesPath"
        Add-StepResult "PowerShell Modules" "WARNING" "Directory not found"
    }
}
catch {
    Write-Log "ERROR" "Failed to load PowerShell modules: $_"
    Add-StepResult "PowerShell Modules" "FAILED" $_.Message
    Pause-OnError
    exit 1
}

$step3Duration = (Get-Date) - $step3Start
$Global:StepResults[-1].Duration = "{0:F2}s" -f $step3Duration.TotalSeconds

# ============================================================================
# 4. INSTALL VMWARE TOOLS
# ============================================================================

Write-StepHeader "4" "Install VMware Tools"

$step4Start = Get-Date
try {
    if (Test-CommandAvailable "Install-VMwareTools") {
        Write-Log "INFO" "Using Install-VMwareTools function from modules"
        Install-VMwareTools -Force $true
        Write-Log "SUCCESS" "VMware Tools processed by module function"
        Add-StepResult "VMware Tools" "SUCCESS" "Installed via module function"
    }
    else {
        $vmToolsPath = "C:\Program Files\VMware\VMware Tools\vmtoolsd.exe"
        if (Test-Path $vmToolsPath) {
            Write-Log "INFO" "VMware Tools already present"
            Add-StepResult "VMware Tools" "SUCCESS" "Already installed"
        }
        else {
            Write-Log "WARN" "Install-VMwareTools function and VMware Tools not available"
            Add-StepResult "VMware Tools" "WARNING" "Function and tools not available"
        }
    }
}
catch {
    Write-Log "ERROR" "Failed to install VMware Tools: $_"
    Add-StepResult "VMware Tools" "FAILED" $_.Message
    Pause-OnError
    exit 1
}

$step4Duration = (Get-Date) - $step4Start
$Global:StepResults[-1].Duration = "{0:F2}s" -f $step4Duration.TotalSeconds

# ============================================================================
# 5. DISABLE UAC
# ============================================================================

Write-StepHeader "5" "Disable User Account Control"

$step5Start = Get-Date
try {
    if (Test-CommandAvailable "Disable-UAC") {
        Disable-UAC
        Write-Log "SUCCESS" "UAC disabled via module function"
        Add-StepResult "UAC Disable" "SUCCESS" "Disabled via module function"
    }
    else {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name EnableLUA -Value 0 -Force
        Write-Log "SUCCESS" "UAC disabled via registry (fallback)"
        Add-StepResult "UAC Disable" "SUCCESS" "Disabled via registry fallback"
    }
}
catch {
    Write-Log "ERROR" "Failed to disable UAC: $_"
    Add-StepResult "UAC Disable" "FAILED" $_.Message
    Pause-OnError
    exit 1
}

$step5Duration = (Get-Date) - $step5Start
$Global:StepResults[-1].Duration = "{0:F2}s" -f $step5Duration.TotalSeconds

# ============================================================================
# 6. ENABLE REMOTE DESKTOP
# ============================================================================

Write-StepHeader "6" "Enable Remote Desktop Protocol"

$step6Start = Get-Date
try {
    if (Test-CommandAvailable "Enable-RDP") {
        Enable-RDP
        Write-Log "SUCCESS" "RDP enabled via module function"
        Add-StepResult "RDP Enable" "SUCCESS" "Enabled via module function"
    }
    else {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections -Value 0 -Force
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
        Write-Log "SUCCESS" "RDP enabled via registry and firewall (fallback)"
        Add-StepResult "RDP Enable" "SUCCESS" "Enabled via registry fallback"
    }
}
catch {
    Write-Log "ERROR" "Failed to enable RDP: $_"
    Add-StepResult "RDP Enable" "FAILED" $_.Message
    Pause-OnError
    exit 1
}

$step6Duration = (Get-Date) - $step6Start
$Global:StepResults[-1].Duration = "{0:F2}s" -f $step6Duration.TotalSeconds

# ============================================================================
# 7. INSTALL CHOCOLATEY
# ============================================================================

Write-StepHeader "7" "Install Chocolatey Package Manager"

$step7Start = Get-Date
try {
    if (Test-CommandAvailable "Install-Chocolatey") {
        Install-Chocolatey
        Write-Log "SUCCESS" "Chocolatey installed via module function"
        Add-StepResult "Chocolatey Install" "SUCCESS" "Installed via module function"
    }
    else {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Log "SUCCESS" "Chocolatey installed via web installer (fallback)"
        Add-StepResult "Chocolatey Install" "SUCCESS" "Installed via web fallback"
    }
}
catch {
    Write-Log "ERROR" "Failed to install Chocolatey: $_"
    Add-StepResult "Chocolatey Install" "FAILED" $_.Message
    Pause-OnError
    exit 1
}

$step7Duration = (Get-Date) - $step7Start
$Global:StepResults[-1].Duration = "{0:F2}s" -f $step7Duration.TotalSeconds

# ============================================================================
# 8. INSTALL BITWARDEN CLI
# ============================================================================

Write-StepHeader "8" "Install Bitwarden CLI"

$step8Start = Get-Date
try {
    if (Test-CommandAvailable "Install-BitwardenCLI") {
        Install-BitwardenCLI
        if (Test-CommandAvailable "bw") {
            Write-Log "SUCCESS" "Bitwarden CLI installed via Install-BitwardenCLI function"
            Add-StepResult "Bitwarden CLI" "SUCCESS" "Installed via function"
        }
        else {
            Write-Log "ERROR" "Install-BitwardenCLI executed but 'bw' not found in PATH"
            Add-StepResult "Bitwarden CLI" "FAILED" "'bw' not found after installation"
        }
    }
    else {
        Write-Log "ERROR" "Install-BitwardenCLI function not available in loaded modules"
        Add-StepResult "Bitwarden CLI" "FAILED" "Function not available"
    }
}
catch {
    Write-Log "ERROR" "Error installing Bitwarden CLI: $($_.Exception.Message)"
    Write-Log "ERROR" "Exception details: $($_ | Out-String)"
    Add-StepResult "Bitwarden CLI" "FAILED" $_.Exception.Message
    Pause-OnError
    exit 1
}
$step8Duration = (Get-Date) - $step8Start
$Global:StepResults[-1].Duration = "{0:F2}s" -f $step8Duration.TotalSeconds

# ============================================================================
# 9. CONFIGURE NAS
# ============================================================================

Write-StepHeader "9" "Configure Network Attached Storage"

$step9Start = Get-Date
try {
    if (Test-CommandAvailable "New-TaskMountNASAtLogon") {
        New-TaskMountNASAtLogon -ItemId "nas-sacha" -MasterPassword $env:ENV_PASSWORD
        Write-Log "SUCCESS" "NAS scheduled task created"
        # Explicit verification of scheduled task
        $taskName = "MountNASAtLogon"
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($null -eq $task) {
            Write-Log "ERROR" "Scheduled task '$taskName' was not created"
            Add-StepResult "NAS Task" "FAILED" "Task not found"
        }
        else {
            Write-Log "SUCCESS" "Scheduled task '$taskName' found"
            Add-StepResult "NAS Task" "SUCCESS" "Task found"
        }
        if (Test-CommandAvailable "Enable-NAS") {
            # First attempt immediate mounting with robust error handling
            Write-Log "INFO" "Attempting immediate NAS mount during provisioning"
            
            try {
                # Wait for network stabilization
                Write-Log "INFO" "Waiting for network stabilization..."
                Start-Sleep -Seconds 5
                
                # Test network connectivity with retries
                $nasServer = "synology-sacha"
                $networkReady = $false
                
                for ($i = 1; $i -le 3; $i++) {
                    Write-Log "INFO" "Network connectivity test $i/3 to $nasServer"
                    try {
                        $pingResult = Test-Connection -ComputerName $nasServer -Count 1 -Quiet -ErrorAction Stop
                        if ($pingResult) {
                            Write-Log "SUCCESS" "Network connectivity verified to $nasServer"
                            $networkReady = $true
                            break
                        }
                    }
                    catch {
                        Write-Log "WARN" "Connectivity test $i failed: $($_.Exception.Message)"
                    }
                    
                    if ($i -lt 3) {
                        Write-Log "INFO" "Waiting 3 seconds before next connectivity test"
                        Start-Sleep -Seconds 3
                    }
                }
                
                if ($networkReady) {
                    # Attempt immediate mount
                    Write-Log "INFO" "Network ready - attempting immediate NAS mount"
                    
                    # Suppress error output but capture result
                    $nasResult = Enable-NAS -ItemId "nas-sacha" -MasterPassword $env:ENV_PASSWORD 2>$null
                    
                    if ($nasResult -and ($nasResult.Status -eq "OK" -or $nasResult.Status -eq "AlreadyMounted")) {
                        if (Test-Path "Z:\") {
                            Write-Log "SUCCESS" "NAS mounted immediately during provisioning on Z:"
                            Add-StepResult "NAS Configuration" "SUCCESS" "Mounted immediately + task created"
                        }
                        else {
                            Write-Log "INFO" "Mount command succeeded but drive not yet visible"
                            Add-StepResult "NAS Configuration" "SUCCESS" "Mount attempted + task created"
                        }
                    }
                    else {
                        Write-Log "WARN" "Immediate mount failed - will rely on scheduled task"
                        Add-StepResult "NAS Configuration" "SUCCESS" "Task created (immediate mount failed)"
                    }
                }
                else {
                    Write-Log "WARN" "Network not ready for immediate mount - relying on scheduled task"
                    Add-StepResult "NAS Configuration" "SUCCESS" "Task created (network not ready)"
                }
            }
            catch {
                Write-Log "WARN" "Immediate mount attempt failed: $($_.Exception.Message)"
                Write-Log "INFO" "NAS will be mounted via scheduled task at next logon"
                Add-StepResult "NAS Configuration" "SUCCESS" "Task created (immediate mount error)"
            }
        }
        else {
            Write-Log "WARN" "Enable-NAS function not available"
            Add-StepResult "NAS Configuration" "WARNING" "Enable function not available"
        }
    }
    else {
        Write-Log "WARN" "NAS functions not available"
        Add-StepResult "NAS Configuration" "WARNING" "Functions not available"
    }
}
catch {
    Write-Log "ERROR" "Error configuring NAS: $($_.Exception.Message)"
    Write-Log "ERROR" "Exception details: $($_ | Out-String)"
    Add-StepResult "NAS Configuration" "FAILED" $_.Exception.Message
    Pause-OnError
    exit 1
}
$step9Duration = (Get-Date) - $step9Start
$Global:StepResults[-1].Duration = "{0:F2}s" -f $step9Duration.TotalSeconds

# ============================================================================
# 10. ACTIVATE WINDOWS LICENSE
# ============================================================================

Write-StepHeader "10" "Activate Windows License"

$step10Start = Get-Date
try {
    if ($env:LICENCE_KEY_WINDOWS11_1 -and (Test-CommandAvailable "Set-WindowsActivation")) {
        Set-WindowsActivation -LicenseKey $env:LICENCE_KEY_WINDOWS11_1
        Write-Log "SUCCESS" "Windows license activated"
        Add-StepResult "Windows Activation" "SUCCESS" "License activated"
    }
    else {
        Write-Log "WARN" "License key or activation function not available"
        Add-StepResult "Windows Activation" "WARNING" "Key or function not available"
    }
}
catch {
    Write-Log "ERROR" "Failed to activate Windows license: $_"
    Add-StepResult "Windows Activation" "FAILED" $_.Message
    Pause-OnError
    exit 1
}

$step10Duration = (Get-Date) - $step10Start
$Global:StepResults[-1].Duration = "{0:F2}s" -f $step10Duration.TotalSeconds

# ============================================================================
# 11. CONFIGURE NTP AND TIMEZONE
# ============================================================================

Write-StepHeader "11" "Configure NTP and Timezone"

$step11Start = Get-Date
try {
    Start-Service W32Time -ErrorAction SilentlyContinue
    
    $ntpConfigured = $false
    $timezoneConfigured = $false
    
    if (Test-CommandAvailable "Set-WindowsNtpServer") {
        Set-WindowsNtpServer -UseDefaultNtp -Sync
        Write-Log "SUCCESS" "NTP server configured"
        $ntpConfigured = $true
    }
    
    if ($env:TZ -and (Test-CommandAvailable "Set-WindowsTimeZone")) {
        Set-WindowsTimeZone -TimeZone $env:TZ
        Write-Log "SUCCESS" "Timezone configured: $env:TZ"
        $timezoneConfigured = $true
    }
    
    if ($ntpConfigured -and $timezoneConfigured) {
        Add-StepResult "NTP/Timezone" "SUCCESS" "Both NTP and timezone configured"
    }
    elseif ($ntpConfigured -or $timezoneConfigured) {
        Add-StepResult "NTP/Timezone" "SUCCESS" "Partially configured"
    }
    else {
        Add-StepResult "NTP/Timezone" "WARNING" "Functions not available"
    }
    
}
catch {
    Write-Log "ERROR" "Failed to configure NTP/Timezone: $_"
    Add-StepResult "NTP/Timezone" "FAILED" $_.Message
    Pause-OnError
    exit 1
}

$step11Duration = (Get-Date) - $step11Start
$Global:StepResults[-1].Duration = "{0:F2}s" -f $step11Duration.TotalSeconds

# ============================================================================
# 12. ENABLE WINRM
# ============================================================================

Write-StepHeader "12" "Enable Windows Remote Management"

$step12Start = Get-Date
try {
    if (Test-CommandAvailable "Enable-WinRM") {
        Enable-WinRM
        Write-Log "SUCCESS" "WinRM enabled via module function"
        Add-StepResult "WinRM Enable" "SUCCESS" "Enabled via module function"
    }
    else {
        Enable-PSRemoting -Force
        Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
        Write-Log "SUCCESS" "WinRM enabled via PowerShell remoting (fallback)"
        Add-StepResult "WinRM Enable" "SUCCESS" "Enabled via PS remoting fallback"
    }
}
catch {
    Write-Log "ERROR" "Failed to enable WinRM: $_"
    Add-StepResult "WinRM Enable" "FAILED" $_.Message
    Pause-OnError
    exit 1
}

$step12Duration = (Get-Date) - $step12Start
$Global:StepResults[-1].Duration = "{0:F2}s" -f $step12Duration.TotalSeconds

# ============================================================================
# FINAL REPORT
# ============================================================================

$totalDuration = (Get-Date) - $Global:StartTime

Write-Host @"
===============================================================================
 EXECUTION REPORT
===============================================================================
"@ -ForegroundColor Green

Write-Host "Execution Summary:" -ForegroundColor Cyan
Write-Host "   Start Time: $($Global:StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
Write-Host "   End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host "   Total Duration: $("{0:F2}" -f $totalDuration.TotalSeconds) seconds" -ForegroundColor White
Write-Host "   Transcript File: $Global:TranscriptFile" -ForegroundColor White

# Stop transcript before copy
Stop-Transcript

Write-Host "Statistics:" -ForegroundColor Cyan
$successCount = ($Global:StepResults | Where-Object { $_.Status -eq "SUCCESS" }).Count
$warningCount = ($Global:StepResults | Where-Object { $_.Status -eq "WARNING" }).Count
$failedCount = ($Global:StepResults | Where-Object { $_.Status -eq "FAILED" }).Count

Write-Host "   Successful Steps: $successCount" -ForegroundColor Green
Write-Host "   Warning Steps: $warningCount" -ForegroundColor Yellow
Write-Host "   Failed Steps: $failedCount" -ForegroundColor Red
Write-Host "   Total Log Errors: $Global:ErrorCount" -ForegroundColor Red
Write-Host "   Total Log Warnings: $Global:WarningCount" -ForegroundColor Yellow

Write-Host "Detailed Results:" -ForegroundColor Cyan
$Global:StepResults | ForEach-Object {
    $statusIcon = switch ($_.Status) {
        "SUCCESS" { "[OK]" }
        "WARNING" { "[WARN]" }
        "FAILED" { "[FAIL]" }
        default { "[?]" }
    }
    
    $statusColor = switch ($_.Status) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "FAILED" { "Red" }
        default { "Gray" }
    }
    
    Write-Host "   $statusIcon $($_.Step.PadRight(25)) " -NoNewline
    Write-Host "$($_.Status.PadRight(10)) " -ForegroundColor $statusColor -NoNewline
    Write-Host "$($_.Duration.PadRight(8)) " -ForegroundColor Gray -NoNewline
    Write-Host "$($_.Details)" -ForegroundColor Gray
}

# Determine overall status
$overallStatus = if ($failedCount -gt 0) {
    "FAILED"
}
elseif ($warningCount -gt 0) {
    "SUCCESS_WITH_WARNINGS"
}
else {
    "SUCCESS"
}

Write-Host "Overall Status: " -NoNewline -ForegroundColor Cyan
switch ($overallStatus) {
    "SUCCESS" {
        Write-Host "COMPLETE SUCCESS" -ForegroundColor Green
        Write-Log "SUCCESS" "Post-configuration completed successfully"
    }
    "SUCCESS_WITH_WARNINGS" {
        Write-Host "SUCCESS WITH WARNINGS" -ForegroundColor Yellow
        Write-Log "WARN" "Post-configuration completed with warnings"
    }
    "FAILED" {
        Write-Host "FAILED" -ForegroundColor Red
        Write-Log "ERROR" "Post-configuration completed with failures"
    }
}

# Copy logs to NAS
Copy-LogToNAS

Write-Host @"
===============================================================================
 POST-CONFIGURATION COMPLETED
===============================================================================
"@ -ForegroundColor Magenta

Write-Host "[INFO] Script completed at $(Get-Date)" -ForegroundColor White
Write-Host "[INFO] Total execution time: $("{0:F2}" -f $totalDuration.TotalSeconds) seconds" -ForegroundColor White

if ($overallStatus -eq "FAILED") {
    exit 1
}
else {
    exit 0
}
