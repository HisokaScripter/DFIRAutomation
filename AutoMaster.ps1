#title: AutoMaster.ps1
#Version: 1.3
#description: Forensic Tools Automation
#status: testing
#author: Lhakpa Tenzing Sherpa (lhakpa.t.sherpa005@gmail.com)
#modified: 2025/08/19

#Version 1.3 Notes:
#Added the ability to use different a mounted drive instead of needing to provide the image file (Due to issues with CLI)
#Initial config

function Get-File {
    [CmdletBinding()]
    param()

    Add-Type -AssemblyName System.Windows.Forms
    $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $fileDialog.Filter = "All Files (*.*)|*.*"
    $fileDialog.Title = "Select a File"

    if ($fileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $fileDialog.FileName
    }
}

function Set-Initial(){
    $file = (Get-ChildItem -Path .\config -Filter config.txt -Recurse -ErrorAction SilentlyContinue -Force)
    if(-not $file.Name -eq "config.txt"){
        write-host "No config found" -ForegroundColor Cyan
        write-host "select thor exe path!"
        Start-Sleep -Seconds 1
        Get-File > .\config\config.txt

        write-host "select thor util exe path!"
        Start-Sleep -Seconds 1
        Get-File >> .\config\config.txt

        write-host "select cyber exe triage path!"
        Start-Sleep -Seconds 1
        Get-File >> .\config\config.txt

        write-host "select kape exe path!"
        write-host "Make sure you select the kape and not gkape version" -ForegroundColor Red
        Start-Sleep -Seconds 1
        Get-File >> .\config\config.txt

        write-host "select hayabusa exe path!"
        Start-Sleep -Seconds 1
        Get-File >> .\config\config.txt

        write-host "select arsenal image mounter exe path!"
        write-host "Make sure you select the cli version" -ForegroundColor Red
        Start-Sleep -Seconds 1
        Get-File >> .\config\config.txt
    }
    else{
        write-host "Found previous configurations" -ForegroundColor Green
    }
}

Set-Initial
$configs = Get-Content ".\config\config.txt"
$thorTool=$configs[0]
$thorUtilTool=$configs[1]
$kapeTool=$configs[3]
$hayabusaTool=$configs[4]
$cyberTriageTool=$configs[2]
$arsenalTool=$configs[5]

Write-Host "1. Thor: $thorTool`n2. ThorUtil: $thorUtilTool`n3. Kape: $kapeTool`n4. Hayabysa: $hayabusaTool`n5. Cyber Triage: $cyberTriageTool`n6. Arsenal Image Mounter: $arsenalTool" -ForegroundColor Cyan
$useMountedDrive = read-host "use-Mounted drive? (y/n) leave blank for no"
[String]$driveToUse = ""
if ($useMountedDrive -eq "y") {
    $driveToUse = read-host "Provide mounted drive: "
}
$isKapeImage = read-host "is this a kape image?`n (y/n):"
$isLinuxMachine = read-host "Is this a linux image?`n (y/n)"
$clearOldOutputs = read-host "Want to clear old outputs?`n (y/n)"
$bitlockered = read-host "Is this bitlockered?`n (y/n)"
if ($clearOldOutputs -eq 'y') {
    foreach ($folder in Get-ChildItem ./Outputs -Directory) {
        write-host "Clearing folder: $($folder.FullName)" -ForegroundColor "Cyan"
        Get-ChildItem -Path $folder.FullName -File -Recurse | ForEach-Object {
            write-host "Removing file: $($_.FullName)" -ForegroundColor "Cyan"
            Remove-Item -Path $_.FullName -Force -Confirm:$true
        }
    }
}

if($isLinuxMachine -eq 'y'){
    write-host "Hey this is a linux image... you can't use windows tools for a linux machine."
    return
}

$arguments | Format-Table OriginalLine, SortedLine

[String]$MountedDrive = $null


[Boolean]$mounted = $false
if ($useMountedDrive -eq "y"){
    $MountedDrive = $driveToUse
}
else{
    Write-Host "Select target image:"

    $imagePath = get-file

    $imageFile = Get-Item -Path $imagePath

    function Get-DriveSize {
        param ($driveLetter)
        return (Get-PSDrive -Name $driveLetter.substring(0,1)).Used
    }

    $drivesBefore = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root

    $extension = [System.IO.Path]::GetExtension($imageFile.Name).ToLower()

    switch ($extension) {
        ".e01" {
            $provider = "libewf"
        }
        ".vmdk" {
            $provider = "DiscUtils"
        }
        ".vhd" {
            $provider = "DiscUtils"
        }
        ".vhdx" {
            $provider = "DiscUtils"
        }
        ".aff4" {
            $provider = "LibAFF4"
        }
        default {
            throw "Unsupported file format: $extension"
        }
    }
    write-host $extension -ForegroundColor Red
    if ($imageFile) {
        write-host $provider
        $arsenalTool
        $mountCommand = "$arsenalTool --mount --fakesig --readonly --online --filename='$($imagePath)' --provider=$provider --writeoverlay='$($imagePath).diff' --autodelete"
        $powerShellProcess = Start-Process -FilePath "powershell.exe" -ArgumentList $mountCommand -PassThru
        Write-Host $powerShellProcess
        $drivesAfter = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
        $newDrives = Compare-Object -ReferenceObject $drivesBefore -DifferenceObject $drivesAfter |
            Where-Object { $_.SideIndicator -eq '=>' } |
                Select-Object -ExpandProperty InputObject
        $maxSize = 0
        if($bitlockered -eq 'y'){
            write-host "Please decrypt the drive waiting 30 seconds"
            Start-Sleep -Seconds 30
        }
        foreach ($drive in $newDrives) {
            $size = Get-DriveSize -driveLetter $drive
            if ($size -gt $maxSize) {
                $maxSize = $size
                $MountedDrive = $drive
                $mounted = $true
            }
        }
    }
    else {
        Write-Host "No image files were found in the directory."
    }
    while (-not $mounted){
    write-host "Waiting for drive letter..."
    Start-Sleep -Seconds 2
    $drivesAfter = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
    $newDrives = Compare-Object -ReferenceObject $drivesBefore -DifferenceObject $drivesAfter |
    Where-Object { $_.SideIndicator -eq '=>' } |
    Select-Object -ExpandProperty InputObject
    foreach ($drive in $newDrives) {
        write-host $drive
        $size = Get-DriveSize -driveLetter $drive
        if ($size -gt $maxSize) {
            $maxSize = $size
            $MountedDrive = $drive
            $mounted = $true
        }
    }
}
}

write-host "mounted: $MountedDrive"

function Start-Kape {
    $mdest = ".\Outputs\Kape"
    Start-Process -FilePath $kapeTool -ArgumentList "--msource $MountedDrive --mdest $mdest --module !EZParser" -NoNewWindow  -PassThru -Wait;
}

function Start-Hayabusa {
    $destination = ".\Outputs\Hayabusa"
    $date = Get-Date -Format "yyyyMMddHHmm"
    Write-Host "Updating Hayabusa rules" -ForegroundColor Cyan
    Start-Process -FilePath $hayabusaTool -ArgumentList "update-rules" -Wait
    write-host "Finished updating hayabusa" -ForegroundColor Cyan
    $hayabusaArguments = "csv-timeline -d $MountedDrive --multiline --output $destination\csv_results_$date.csv --profile super-verbose --UTC -w -A -a -D -n -u -q"
    Start-Process -FilePath $hayabusaTool -ArgumentList $hayabusaArguments -NoNewWindow -PassThru -Wait;
}

function Start-Thor {
    Write-Host "Updating Thor Lite" -ForegroundColor Cyan
    Start-Process -FilePath $thorUtilTool -ArgumentList "upgrade" -NoNewWindow -PassThru -Wait;
    write-host "Updated thor" -ForegroundColor "Green"
    $ThorOutputPath = ".\Outputs\Thor"
    Start-Process -FilePath $thorTool -ArgumentList "-a Filescan --nocpulimit --intense --max-reasons 0 --nothordb --utc -p $MountedDrive -e $ThorOutputPath" -NoNewWindow -PassThru -Wait
}

function start-CTriage {
    $baseIncidentName = "Incident"
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $IncidentName = "${baseIncidentName}_${timestamp}"
    $currentPwd = (Get-Location).path
    $destinationPath = "$currentPwd\Outputs\CyberTriage"
    
    start-Process -FilePath $cyberTriageTool -ArgumentList "--createIncident=$IncidentName --nogui --nosplash" -Wait
    if($isKapeImage -eq 'y'){
        start-Process -FilePath $cyberTriageTool -ArgumentList "--openIncident=$IncidentName --addHost=$IncidentName --addHostType=KAPE --addHostPath=$imageFile --addHostMalware=Hash --generateHostReport --reportType=csv --reportPath=$destinationPath --nogui --nosplash" -NoNewWindow -PassThru -Wait
    }
    else{
        start-Process -FilePath $cyberTriageTool -ArgumentList "--openIncident=$IncidentName --addHost=$IncidentName --addHostType=DiskImage --addHostPath=$imageFile --addHostMalware=Hash --generateHostReport --reportType=csv --reportPath=$destinationPath --nogui --nosplash" -Wait
    }
    Write-Output "Host added and report generated."
}

$thorTool=$configs[0]
$thorUtilTool=$configs[1]
$kapeTool=$configs[3]
$hayabusaTool=$configs[4]
$cyberTriageTool=$configs[2]
$arsenalTool=$configs[5]

write-host "Updating KAPE with KAPE-EZToolsAncillaryUpdater.ps1" -ForegroundColor Cyan
$curd = (Get-Location).Path
cd C:\Users\SANSDFIR\Desktop\AutomateToolsScriptv1_2\AutomateToolsScript\Tools\Tools\KAPE
C:\Users\SANSDFIR\Desktop\AutomateToolsScriptv1_2\AutomateToolsScript\Tools\Tools\KAPE\KAPE-EZToolsAncillaryUpdater.ps1
cd $curd
write-host "Back to original directory"
write-host "Running Kape: $kapeTool" -ForegroundColor Cyan
Start-Kape
write-host "Kape Finished!" -Background "Green"

write-host "Running Hayabusa: $hayabusaTool" -ForegroundColor Cyan
Start-Hayabusa
write-host "Hayabusa Finished!" -Background "Green"

write-host "Running Thor: $thorTool : $thorUtilTool" -ForegroundColor Cyan
Start-Thor
write-host "Thor Finished!" -Background "Green"
write-host "Dismounting..."

$process = Start-Process -FilePath $arsenalTool -ArgumentList "--dismount" -Wait -PassThru
if ($process.ExitCode -eq 0) {
    Write-Host "Dismount successful!" -ForegroundColor Green
} else {
    Write-Host "Dismount failed with exit code $($process.ExitCode)" -ForegroundColor Red
}

write-host "Running Cyber Triage: $cyberTriageTool" -ForegroundColor Cyan
Start-CTriage
write-host "Cyber Triage Finished!" -Background "Green"
Write-Host "Finished Automation Script!" -Background Green
write-host "Finished successfully!" >> .\Finished.txt
