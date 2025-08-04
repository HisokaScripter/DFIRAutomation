# DFIRAuto.ps1
# Creaded by: HisokaScripter
# Description: This script automates the process of mounting forensic images using Arsenal Image Mounter.
# Requirements: Arsenal Image Mounter (acli.exe) 

function Get-File { # Prompt user to select file
    [CmdletBinding()]
    param (
        [string]$Title = "Select a file",
        [string]$InitialDirectory = [Environment]::GetFolderPath("MyDocuments")
    )

    $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $fileDialog.Title = $Title
    $fileDialog.InitialDirectory = $InitialDirectory
    $fileDialog.Filter = "All files (*.*)|*.*"

    if ($fileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $fileDialog.FileName
    } else {
        return $null
    }
}

[boolean] function Set-InitialConfig() { # This needs to run once to get user configs
    $configFile = "$env:USERPROFILE\DFIRAutoConfig.json"
    if (Test-Path $configFile) { # Check if config file exists
        return "Already configured. Use the config file to change settings."
    }

    $config = @{
        ArsenalImageMounterPath = ""
        Tools = @()
    }
    $ContinueConfig = $true

    while ($ContinueConfig) { # Look until user selects all tools to work with
        $ToolPath = Get-File -Title "Select tool currentToolCount" -InitialDirectory (Get-Location)
        $config.Tools.Add($ToolPath)
        if (Get-Content $configFile){ # Check if config is not empty
            $ToolPath >> $configFile# Append config
        }
        else { # config file was empty
            $ToolPath > $configFile # Create new config file
        }

        write-host "Current tools: `n" -ForegroundColor Cyan
        foreach ($tool in $config.Tools) {
            write-host "#$($config.Tools.Count()): $tool `n" -ForegroundColor Green
        }

        if ($arsenalPath) {
            $config.ArsenalImageMounterPath = $arsenalPath
            $ContinueConfig = $false
        } else {
            Write-Host "No file selected. Please select a valid Arsenal Image Mounter path." -ForegroundColor Red
        }
    }
    return $true
}

[System.IO.File] function Get-ToolConfig(){
    $configFile = "$env:USERPROFILE\DFIRAutoConfig.json"
    if (Test-Path $configFile) {
        $config = Get-Content $configFile | ConvertFrom-Json
        return $config.Tools
    } else {
        Write-Host "Configuration file not found. Please run Set-InitialConfig first." -ForegroundColor Red
        return $null
    }
}

class Mounter { # Class to handle image mounting
    Mounter([System.IO.FilePath]$ToolOutputPath) {
        $this.OutPutDir = $ToolOutputPath
        $this.Mounter = Get-File -Title "Select the arsenal image mounter acli.exe" -InitialDirectory (Get-Location)
        $this.Date = Get-Date -Format "yyyyMMddHHmm"
    }
    [string] Get-ToolConfig([string]$ToolName) {
        $KnownToolArgs = @(
            Hayabusa = @(),
            Thor = @(),
            Kape = @(),
            Autopsy = @(),
            CyberTriage = @(),
            Plaso = @(),
            Sleuthkit = @(),
            Volatility = @(),
            Rekall = @(),
            X1 = @(),
            FTKImager = @(),
            Xplico = @(),
            BulkExtractor = @(),
            Binwalk = @(),
            Foremost = @(),
            Scalpel = @(),
            Sleuthkit = @(),
        )
        switch ($ToolName){
            "Hayabusa" {
                $KnownToolArgs.Hayabusa.Add("csv-timeline")
                $KnownToolArgs.Hayabusa.Add("-d")
                $KnownToolArgs.Hayabusa.Add($this.MountedDriveLetter)
                $KnownToolArgs.Hayabusa.Add("--output")
                #Define output directory for Hayabusa
                $HayabusaOutputDir = $this.OutPutDir + "/Hayabusa/$($this.MountedDrive.Name) $($this.Date).csv" # Create output directory with date
                Test-Path $HayabusaOutputDir # Check if output directory exists
                if (-not $?) { # If it does not exist, create it
                    New-Item -ItemType Directory -Path $HayabusaOutputDir -Force | Out-Null
                }
                $KnownToolArgs.Hayabusa.Add($HayabusaOutputDir)
                $KnownToolArgs.Hayabusa.Add("--profile")
                $KnownToolArgs.Hayabusa.Add("super-verbose")
                $KnownToolArgs.Hayabusa.Add("--UTC")
                $KnownToolArgs.Hayabusa.Add("-w")
                $KnownToolArgs.Hayabusa.Add("-A")
                $KnownToolArgs.Hayabusa.Add("-a")
                $KnownToolArgs.Hayabusa.Add("-D")
                $KnownToolArgs.Hayabusa.Add("-n")
                $KnownToolArgs.Hayabusa.Add("-u")
                $KnownToolArgs.Hayabusa.Add("-q")
            }
            "Thor" {
                $KnownToolArgs.Thor.Add("-a")
                $KnownToolArgs.Thor.Add("Filescan")
                $KnownToolArgs.Thor.Add("--nocpulimit")
                $KnownToolArgs.Thor.Add("--max-reasons 0")
                $KnownToolArgs.Thor.Add("--nothordb")
                $KnownToolArgs.Thor.Add("--utc")
                $KnownToolArgs.Thor.Add("-p")
                $KnownToolArgs.Thor.Add($this.MountedDriveLetter)
                $KnownToolArgs.Thor.Add("-e")
                $ThorOutputDir = $this.OutPutDir + "/Thor/$($this.MountedDrive.Name) $($this.Date).csv" # Create output directory with date
                Test-Path $ThorOutputDir # Check if output directory exists
                if (-not $?) { # If it does not exist, create it
                    New-Item -ItemType Directory -Path $ThorOutputDir -Force | Out-Null
                }
                $KnownToolArgs.Thor.Add($ThorOutputDir)
                $KnownToolArgs.Thor.Add("-NoNewWindow")
                $KnownToolArgs.Thor.Add("-PassThru")
                $KnownToolArgs.Thor.Add("-Wait")
            }
            "Kape" {
                $KnownToolArgs.Kape.Add("--msource")
                $KnownToolArgs.Kape.Add($this.MountedDriveLetter)
                $KnownToolArgs.Kape.Add("--mdest")
                $KapeOutputDir = $this.OutPutDir + "/Kape/$($this.MountedDrive.Name) $($this.Date)" # Create output directory with date
                Test-Path $KapeOutputDir # Check if output directory exists
                if (-not $?) { # If it does not exist, create it
                    New-Item -ItemType Directory -Path $KapeOutputDir -Force | Out-Null
                }
                $KnownToolArgs.Kape.Add($KapeOutputDir)
                $KnownToolArgs.Kape.Add("--module")
                $KnownToolArgs.Kape.Add("!EZParser")
                $KnownToolArgs.Kape.Add("-NoNewWindow")
                $KnownToolArgs.Kape.Add("-PassThru")
                $KnownToolArgs.Kape.Add("-Wait")
            }
            
        }

    }

    [boolean] Mount-Image([System.IO.FilePath]$ImagePath, [string]$Provider) {
        $MountArgs_HashTable = @(
            "--mount", 
            $ImagePath, 
            "--fakesig", 
            "--readonly", 
            "--online", 
            "--filename=$($ImagePath)", 
            "--provider=$($Provider)", 
            "--writeoverlay=$($ImagePath)", 
            "--autodelete"
        )

        $MountArgs = " "
        foreach ($arg in $MountArgs_HashTable) {
            $MountArgs += "$arg "
        }
        $this.Mounter $MountArgs# Running Mounter acli.exe with arguments
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to mount image: $ImagePath" -ForegroundColor Red
            return $false
        }
    }


    [boolean] Get-MountedDriveLetter(){
        $DrivesBefore = Get-PSDrive -PSProvider FileSystem

        write-host "Mounting image with arguments: $MountArgs"

        $DrivesAfter = Get-PSDrive -PSProvider FileSystem
        $MaxDriverSize = 0
        [System.IO.Drive]$MountedDrive = $null

        foreach ($Drive in $DrivesAfter) {
            if ($Drive.Used -gt $MaxDriverSize) {
                $MaxDriverSize = $Drive.Used
                $MountedDrive = $Drive.Name
            }
        }

        write-host "Mounted Drive: $($MountedDrive.Name)"
    }
}

function ProcessImages([System.IO.File]$ImageFile, [string]$Provider) {
    param (
        [System.IO.FilePath]$ImageFile
        [string]$Provider
    )
    $mounter = [Mounter]::new()
    $DrivesBefore = Get-PSDrive -PSProvider FileSystem
    $mounter.Mount-Image($ImageFile, $Provider)
    $DrivesAfter = Get-PSDrive -PSProvider FileSystem

    # Get largest diffed drive
    $MaxDriveSize = 0
    [System.IO.Drive]$MountedDrive = $null
    foreach ($Drive in $DrivesAfter) {
        if ($Drive.Used -gt $MaxDriveSize) {
            $MaxDriveSize = $Drive.Used
            $MountedDrive = $Drive
        }
    }

    write-host $MountedDrive

    #Run tools on the mounted drive

}

function main(){
    $mounter = [Mounter]::new()
    $Created = Set-InitialConfig()

    if ($Created) {
        wite-host "New Config Created" -ForegroundColor Green
    }
    else{
        write-host $Created -ForegroundColor Cyan # Already configured message
    }
    $NumberOfImages = Read-Host "How many images do you want to mount? (Default: 1)" or 1

    [Int]$MountableImages = 1..Int($NumberOfImages)
    write-Host "Provide file or folder"
    #Provided data is the folder of file(Image) provided by user
    [System.IO.FilePath]$Provided_Data = Get-File -Title "Select image file or folder containing images" -InitialDirectory (Get-Location)
    [boolean]$IsFolder = (Get-Item $Provided_Data).PSIsContainer #Check if the provided path is a folder

    if ($IsFolder) {# File provided was a folder so lets recurse through it.
        $MountableImages | foreach-object -Paralell { #Run parallel for each image -Default 2 parallel threads
        
        $ImageFiles = Get-ChildItem -Path $using:Provided_Data -Recurse -File | Where-Object {#look inside the folder for image files
        -or $_.Extension -eq ".vhd"
        -or $_.Extension -eq ".e01"
        -or $_.Extension -eq ".aff4"
        -or $_.Extension -eq ".vmdk"
        -or $_.Extension -eq ".vhdx"}

        $ImageFiles | ForEach-Object {
            [System.IO.File]$ImageFile = $_
            $Extension = $ImageFile.Extension.ToLower()
            $Provider = ""

            switch ($Extension) { # Determine provider based on file extension
                ".vhd" { $Provider = "DiskUtils" }
                ".e01" { $Provider = "libewf" }
                ".aff4" { $Provider = "LibAFF4" }
                ".vmdk" { $Provider = "DiskUtils" }
                ".vhdx" { $Provider = "DiskUtils" }
                default {
                    Write-Host "Unsupported image format: $Extension" -ForegroundColor Red
                    return
                }
            }
            ProcessImages -ImageFile $_.FilePath -Provider $Provider
        }
    } -ThrottleLimit 2 #Test with 2 images parallel adjust based on local disk space 
    } else {
        ProcessImages -ImageFile $ImageFile
    }
}

main()