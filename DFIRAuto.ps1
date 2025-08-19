#title: AutoMaster.ps1
#Version: 1.4
#description: Forensic Tools Automation
#status: testing
#author: Lhakpa Tenzing Sherpa (lhakpa.t.sherpa005@gmail.com)
#modified: 2025/08/18

# Initial config setup
function Get-File {
    [CmdletBinding()]
    param()

    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.OpenFileDialog]$fileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $fileDialog.Filter = "All Files (*.*)|*.*"
    $fileDialog.Title = "Select a File"

    if ($fileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $fileDialog.FileName
    }
}

function Set-Initial {
    [CmdletBinding()]
    param()

    # Ensure config directory exists
    if (-not (Test-Path .\config)) {
        New-Item -Path .\config -ItemType Directory | Out-Null
    }

    [System.IO.FileInfo]$configFile = Get-ChildItem -Path .\config -Filter config.txt -Recurse -ErrorAction SilentlyContinue
    if (-not $configFile) {
        Write-Host "No config found" -ForegroundColor Cyan
        Write-Host "Select THOR exe path!"
        Get-File | Out-File .\config\config.txt

        Write-Host "Select THOR Util exe path!"
        Get-File | Out-File .\config\config.txt -Append

        Write-Host "Select Cyber Triage exe path!"
        Get-File | Out-File .\config\config.txt -Append

        Write-Host "Select KAPE exe path!"
        Write-Host "Make sure you select the KAPE (not GKAPE) version" -ForegroundColor Red
        Get-File | Out-File .\config\config.txt -Append

        Write-Host "Select Hayabusa exe path!"
        Get-File | Out-File .\config\config.txt -Append

        Write-Host "Select Arsenal Image Mounter exe path!"
        Write-Host "Make sure you select the CLI version" -ForegroundColor Red
        Get-File | Out-File .\config\config.txt -Append
    } else {
        Write-Host "Found previous configurations" -ForegroundColor Green
    }
}

Set-Initial

# Load configs safely
[string[]]$configs = Get-Content .\config\config.txt -ErrorAction SilentlyContinue
[string]$thorTool = if ($configs.Length -ge 1) { $configs[0].Trim() } else { '' }
[string]$thorUtilTool = if ($configs.Length -ge 2) { $configs[1].Trim() } else { '' }
[string]$cyberTriageTool = if ($configs.Length -ge 3) { $configs[2].Trim() } else { '' }
[string]$kapeTool = if ($configs.Length -ge 4) { $configs[3].Trim() } else { '' }
[string]$hayabusaTool = if ($configs.Length -ge 5) { $configs[4].Trim() } else { '' }
[string]$arsenalTool = if ($configs.Length -ge 6) { $configs[5].Trim() } else { '' }

Write-Host "1. THOR: $thorTool`n2. THOR Util: $thorUtilTool`n3. KAPE: $kapeTool`n4. Hayabusa: $hayabusaTool`n5. Cyber Triage: $cyberTriageTool`n6. Arsenal Image Mounter: $arsenalTool" -ForegroundColor Cyan

# User prompts
[string]$isKapeImage = Read-Host "Is this a KAPE image? (y/n)"
[string]$isLinuxMachine = Read-Host "Is this a Linux image? (y/n)"
[string]$clearOldOutputs = Read-Host "Want to clear old outputs? (y/n)"
[string]$bitlockered = Read-Host "Is this bitlockered? (y/n)"

# Ensure output and log directories exist
if (-not (Test-Path .\Outputs)) { New-Item -Path .\Outputs -ItemType Directory | Out-Null }
if (-not (Test-Path .\scriptErrorLogs)) { New-Item -Path .\scriptErrorLogs -ItemType Directory | Out-Null }

if ($clearOldOutputs -eq 'y') {
    Get-ChildItem .\Outputs -Directory | ForEach-Object {
        Write-Host "Clearing folder: $($_.FullName)" -ForegroundColor Cyan
        Get-ChildItem -Path $_.FullName -File -Recurse | Remove-Item -Force -Confirm:$false
    }
}

if ($isLinuxMachine -eq 'y') {
    Write-Host "This is a Linux image—exiting." -ForegroundColor Yellow
    return
}

# Select image
Write-Host "Select target image:"
[string]$imagePath = Get-File
[System.IO.FileInfo]$imageFile = Get-Item -Path $imagePath -ErrorAction SilentlyContinue

if (-not $imageFile) {
    Write-Host "No image selected—exiting." -ForegroundColor Red
    return
}

# Function to get drive size
function Get-DriveSize {
    [CmdletBinding()]
    param ([string]$driveLetter)
    return (Get-PSDrive -Name $driveLetter.Substring(0,1) -ErrorAction SilentlyContinue).Used
}

[bool]$canMount = ($arsenalTool -and (Test-Path $arsenalTool))
[string]$MountedDrive = $null

if ($canMount) {
    # Get drives before mounting
    [string[]]$drivesBefore = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root

    # Determine provider based on extension
    [string]$extension = $imageFile.Extension.ToLower()
    [string]$provider = switch ($extension) {
        ".e01" { "libewf" }
        ".vmdk" { "DiscUtils" }
        ".vhd" { "DiscUtils" }
        ".vhdx" { "DiscUtils" }
        ".aff4" { "LibAFF4" }
        default { throw "Unsupported file format: $extension" }
    }

    # Mount image
    Write-Host "Mounting image with provider: $provider" -ForegroundColor Cyan
    [string]$mountArgs = "--mount --fakesig --readonly --online --filename='$imagePath' --provider=$provider --writeoverlay='$imagePath.diff' --autodelete"
    Start-Process -FilePath $arsenalTool -ArgumentList $mountArgs -NoNewWindow -Wait

    if ($bitlockered -eq 'y') {
        Write-Host "Decrypt the drive—waiting 30 seconds..." -ForegroundColor Yellow
        Start-Sleep -Seconds 30
    }

    # Find mounted drive
    [bool]$mounted = $false
    [long]$maxSize = 0

    while (-not $mounted) {
        Write-Host "Waiting for mount..." -ForegroundColor Cyan
        Start-Sleep -Seconds 1
        [string[]]$drivesAfter = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
        [string[]]$newDrives = Compare-Object -ReferenceObject $drivesBefore -DifferenceObject $drivesAfter |
            Where-Object { $_.SideIndicator -eq '=>' } |
            Select-Object -ExpandProperty InputObject

        foreach ($drive in $newDrives) {
            [long]$size = Get-DriveSize -driveLetter $drive
            if ($size -gt $maxSize) {
                $maxSize = $size
                $MountedDrive = $drive
                $mounted = $true
            }
        }
    }

    Write-Host "Mounted at: $MountedDrive" -ForegroundColor Green
} else {
    Write-Host "Skipping mount: Arsenal tool not configured or missing." -ForegroundColor Yellow
}

# Run KAPE
function Start-Kape {
    [string]$mdest = ".\Outputs\Kape"
    Start-Process -FilePath $kapeTool -ArgumentList "--msource $MountedDrive --mdest $mdest --module !EZParser" -NoNewWindow -Wait 2> .\scriptErrorLogs\KapeErrors.txt
}

# Run Hayabusa
function Start-Hayabusa {
    [string]$destination = ".\Outputs\Hayabusa"
    [string]$date = Get-Date -Format "yyyyMMddHHmm"
    Write-Host "Updating Hayabusa rules..." -ForegroundColor Cyan
    Start-Process -FilePath $hayabusaTool -ArgumentList "update-rules" -NoNewWindow -Wait
    Write-Host "Hayabusa updated." -ForegroundColor Green
    [string]$hayabusaArgs = "csv-timeline -d $MountedDrive --multiline --output $destination\csv_results_$date.csv --profile super-verbose --UTC -w -A -a -D -n -u -q"
    Start-Process -FilePath $hayabusaTool -ArgumentList $hayabusaArgs -NoNewWindow -Wait 2> .\scriptErrorLogs\HayabusaErrors.txt
}

# Run THOR
function Start-Thor {
    Write-Host "Updating THOR Lite..." -ForegroundColor Cyan
    Start-Process -FilePath $thorUtilTool -ArgumentList "upgrade" -NoNewWindow -Wait
    Write-Host "THOR updated." -ForegroundColor Green
    [string]$thorOutputPath = ".\Outputs\Thor"
    [string]$thorArgs = "-a Filescan --nocpulimit --intense --max-reasons 0 --nothordb --utc -p $MountedDrive -e $thorOutputPath"
    Start-Process -FilePath $thorTool -ArgumentList $thorArgs -NoNewWindow -Wait 2> .\scriptErrorLogs\ThorErrors.txt
}

# Run Cyber Triage
function Start-CTriage {
    [string]$baseIncidentName = "Incident"
    [string]$timestamp = Get-Date -Format "yyyyMMddHHmmss"
    [string]$incidentName = "${baseIncidentName}_${timestamp}"
    [string]$destinationPath = ".\Outputs\CyberTriage"

    Start-Process -FilePath $cyberTriageTool -ArgumentList "--createIncident=$incidentName --nogui --nosplash" -NoNewWindow -Wait
    [string]$addHostArgsBase = "--openIncident=$incidentName --addHost=$incidentName --addHostMalware=Hash --generateHostReport --reportType=csv --reportPath=$destinationPath --nogui --nosplash"
    if ($isKapeImage -eq 'y') {
        [string]$addHostArgs = "$addHostArgsBase --addHostType=KAPE --addHostPath=$imagePath"
    } else {
        [string]$addHostArgs = "$addHostArgsBase --addHostType=DiskImage --addHostPath=$imagePath"
    }
    Start-Process -FilePath $cyberTriageTool -ArgumentList $addHostArgs -NoNewWindow -Wait 2> .\scriptErrorLogs\CyberTriageErrors.txt
    Write-Host "Host added and report generated." -ForegroundColor Green
}

# Execute tools if configured and mount available where needed
if ($canMount -and $MountedDrive -and $kapeTool -and (Test-Path $kapeTool)) {
    Write-Host "Running KAPE..." -ForegroundColor Cyan
    Start-Kape
    Write-Host "KAPE finished!" -ForegroundColor Green
} else {
    Write-Host "Skipping KAPE: Tool not configured, missing, or no mount." -ForegroundColor Yellow
}

if ($canMount -and $MountedDrive -and $hayabusaTool -and (Test-Path $hayabusaTool)) {
    Write-Host "Running Hayabusa..." -ForegroundColor Cyan
    Start-Hayabusa
    Write-Host "Hayabusa finished!" -ForegroundColor Green
} else {
    Write-Host "Skipping Hayabusa: Tool not configured, missing, or no mount." -ForegroundColor Yellow
}

if ($canMount -and $MountedDrive -and $thorTool -and $thorUtilTool -and (Test-Path $thorTool) -and (Test-Path $thorUtilTool)) {
    Write-Host "Running THOR..." -ForegroundColor Cyan
    Start-Thor
    Write-Host "THOR finished!" -ForegroundColor Green
} else {
    Write-Host "Skipping THOR: Tool/Util not configured, missing, or no mount." -ForegroundColor Yellow
}

# Dismount if mounted
if ($canMount -and $MountedDrive) {
    Write-Host "Dismounting..." -ForegroundColor Cyan
    Start-Process -FilePath $arsenalTool -ArgumentList "--dismount" -NoNewWindow -Wait
    Write-Host "Dismounted." -ForegroundColor Green
}

# Run Cyber Triage (doesn't need mount)
if ($cyberTriageTool -and (Test-Path $cyberTriageTool)) {
    Write-Host "Running Cyber Triage..." -ForegroundColor Cyan
    Start-CTriage
    Write-Host "Cyber Triage finished!" -ForegroundColor Green
} else {
    Write-Host "Skipping Cyber Triage: Tool not configured or missing." -ForegroundColor Yellow
}

Write-Host "Automation complete—ready for your next forensic breakthrough!" -ForegroundColor Green
