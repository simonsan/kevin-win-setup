﻿# Import BITS for file transfers
#Import-Module BitsTransfer

# IMPORTANT NOTE!
# Need to set the following command manually, to run this script on a standard Win10 machine
# don't close the Powershell afterwards because for security reasons scripts are just allowed
# for the current powershell process
# >>> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process

# Dependencies to be downloaded
# GitHub-Files can be referenced with their RepoName and the Flag "isGit"
# that will Download automatically the newest Release-Version
# Search for #ADD NEW SOFTWARE LINK GENERATION HERE and add a new case for the Link generation
$deps = @(
    [PSCustomObject]@{Name = "cmake"; isGit=$true; isZip=$true; isInstaller=$false; LatestRelease =""; RepoName = "Kitware/CMake"; DownloadLink = ""; HashFile = ""; HomeDir = ""; FileName = ""}
    [PSCustomObject]@{Name = "mingit"; isGit=$true; isZip=$true; isInstaller=$false; LatestRelease = ""; RepoName = "git-for-windows/git"; DownloadLink = ""; HashFile = ""; HomeDir = ""; FileName = ""}
    [PSCustomObject]@{Name = "python3"; isGit=$false; isZip=$false; isInstaller=$true; LatestRelease = ""; RepoName = ""; DownloadLink = "https://www.python.org/ftp/python/3.7.3/python-3.7.3-amd64.exe"; HashFile = ""; HomeDir = ""; FileName = ""}
  
  
   # Preset New Download (Search for #ADD NEW SOFTWARE LINK GENERATION HERE and add a new case)
   # [PSCustomObject]@{Name = ""; isGit=""; RepoName = ""; DownloadLink = ""; HashFile = ""; HomeDir = ""; FileName = ""}
   
    )

# Change to preferred download path
$dependency_dl_path="$env:HOMEDRIVE\openage-deps\";


# Flag for DRY RUN -> TODO
#$dry_run=false;


# Function to create folderstructure
Function GenerateFolders($path){
    $global:foldPath=$null
    
    foreach($foldername in $path.split("\")){
          $global:foldPath+=($foldername+"\")

          if(!(Test-Path $global:foldPath)){
              New-Item -ItemType Directory -Path $global:foldPath
              Write-Host "$global:foldPath Folder created successfully!"
          }elseif((Test-Path $global:foldPath)){
              Write-Host "$global:foldPath Folder already exists!"
          }
#elseif($dry_run){
#            Write-Host "DRYRUN: $global:foldPath folder was not created!"
#          }
    }   
}

# Create subfolder for each dependency and save in $deps
Function GenerateDepFolders{
    Param($arr, [string]$path)

        $arr | ForEach-Object { 
            GenerateFolders "$($path)$($_.Name)"
            $_.HomeDir = "$($path)$($_.Name)\"
        }    
    
}

# Function to download dependency setups
Function DownloadDependencies($arr){
    
     $arr | ForEach-Object {
            # Start-BitsTransfer -Source $_.HashFile -Destination $_.HomeDir -Asynchronous
            $source = "$($_.DownloadLink)"
            $output = "$($_.HomeDir)$($_.FileName)"

            Write-Host "Downloading $($_.Name) ..."
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $job = Invoke-WebRequest $source -Out $output
  
            While ($job.JobState -eq "Transferring") {
                 Sleep -Seconds 3
            }
    }

}

# Function to generate FileName and FilePath from DownloadLink
Function GenerateFileNames($arr){

    $arr | ForEach-Object {
           $_.FileName = "$($_.DownloadLink.SubString($_.DownloadLink.LastIndexOf('/') + 1))"
    }
}

# Get the link for the latest version of a github repo
# Inspired by https://gist.github.com/f3l3gy/0e89dde158dde024959e36e915abf6bd
Function GetLatestVersionLink($arr){
    
    $arr | ForEach-Object {

           # Github
           if(($_.isGit) -eq $true){
               $releases = "https://api.github.com/repos/$($_.RepoName)/releases"
           
               Write-Host "Determining latest release for $($_.Name)"
               [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
           
               $versionRequest = ((ConvertFrom-Json -InputObject (Invoke-WebRequest -Uri  $releases -UseBasicParsing)) | Where {$_.prerelease -eq $false})[0]

               $_.LatestRelease = $versionRequest[0].tag_name
         
               #$_.DownloadLink = ($versionRequest | Where {$_.content_type -eq "application/zip"})
           

               #ADD NEW SOFTWARE LINK GENERATION HERE
               # >>>
          
               if(($_.Name) -eq "mingit"){
                   #MinGit-2.21.0-64-bit.zip
                   $name = "$($_.Name)-"
                   $version=($_.LatestRelease.Substring(1))
                   $version= $version.Substring(0,$version.Length-10)
                   $arch="-64-bit"
                   $type=".zip"

               }elseif(($_.Name) -eq "cmake"){
                   #cmake-3.14.5-win64-x64.zip 
                   $name = "$($_.Name)-"  
                   $version=$_.LatestRelease.Split("v")[1]
                   $arch="-win64-x64"
                   $type=".zip"
           
               }
          

               $file="$name$version$arch$type"

               #ADD NEW SOFTWARE LINK GENERATION HERE
               # >>> <<<
           
               Write-Host $_.LatestRelease

               # Debug
               # Write-Host "DownloadLink for $($_.RepoName) is"
               $_.DownloadLink="https://github.com/$($_.RepoName)/releases/download/$($_.LatestRelease)/$($file)"

               # Debug
               # Write-Host $_.DownloadLink

 

          }

    }
   
}


# Extract Zip-Files and delete archives afterwards
# Sets the HomeDir to the extracted new Folder structure
Function ExtractDependencies($arr){

    $arr | ForEach-Object {
    
        if(($_.isZip) -eq $true){
            
            Set-Location -Path $_.HomeDir
            $zip = "$($_.HomeDir)$($_.FileName)"

            Write-Host "Extracting $($_.Name) files"
            Expand-Archive $zip -Force
            Remove-Item $zip -Force

            $_.HomeDir = $zip.Substring(0,$zip.Length-4)
            
            # Debug
            # Write-Host $_.HomeDir 

        }
        
    }

}


# Install the dependencies
# TODO Testing
Function InstallDependencies($arr){
    
    $arr | ForEach-Object {
         if(($_.isInstaller) -eq $true){


           if(($_.Name) -eq "python3"){
             # Installer Routine for Python

             $setup = Start-Process "$($_.HomeDir)$($_.FileName)" -ArgumentList "/s /passive Include_debug=1 Include_dev=1 Include_lib=1 Include_pip=1 PrependPath=1 CompileAll=1 InstallAllUsers=1 TargetDir=$($_.HomeDir)" -Wait
             if ($setup.exitcode -eq 0){
                write-host "$($_.Name) installed succesfully."
             }
           }

         


         }


    }


   

   

   
    


}




# Create Directory for dependency downloads
GenerateDepFolders -arr $deps -path $dependency_dl_path

# Get Latest from Github
GetLatestVersionLink $deps

# Generate FileNames from Link
GenerateFileNames $deps

# Download all Dependencies
#DownloadDependencies $deps

# Extract Dependencies
#ExtractDependencies $deps

# Install Dependencies
#InstallDependencies $deps

# Python should be in PATH from here
# -> PIP
# git and cmake still missing in PATH


# Set Environment variables
# Install paths
# VCPKG_DEFAULT_TRIPLET=x64-windows
# cmake
# git
# Python (automatically)

# Alternative to Invoke-Webrequest
# Start-BitsTransfer -Source $_.HashFile -Destination $_.HomeDir -Asynchronous
# Start-BitsTransfer -Source $_.DownloadLink -Destination $_.HomeDir -Asynchronous -DisplayName "Downloading $_.Name ..." 


# Installer still do DL
# Visual Studio 17 CE (advanced options)


# pip install modules

# Prereq. MSVC17
# clone vcpkg and build to higher directory (e.g. C:\windows)
# vcpkg integrate, build and install packages
# 

# TODO Verification
# pgp for windows
# sha256