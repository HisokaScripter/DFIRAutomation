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

function Get-InitialConfig(){ # This needs to run once to get user configs

}

class Mounter { # Class to handle image mounting
    Mounter() {
        $this.Mounter = Get-File -Title "Select the arsenal image mounter acli.exe" -InitialDirectory (Get-Location)
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
}

function main(){
    $mounter = [Mounter]::new()
    #[System.IO.FilePath[]]$Images = $()
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