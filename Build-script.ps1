# Define Variables
$repoUrl = "git@github.com:EmperiaLtd/emperia-unreal.git"
$projectDir = "C:\Projects"
$fileToCopy = "$projectDir\global.json"
$BuildNumber = "Build_ci_cd_4"
$FolderPath = "$projectDir\test_build"
$buildDir = "$FolderPath\$BuildNumber"

# Variables for phase 2 
$phase2gitURL = "git@github.com:akash-emperiavr/walmart-build-deployment.git"
$workingDir = "$projectDir\walmart-build-deployment\.github\workflows"
$FilePath = "$workingDir\deploy_latest_build.yml"


# Ensure Git is available
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Git is not installed. Please install Git and try again."
    exit 1
}

# Create Folder Directory if it does not exist
if (-not (Test-Path $FolderPath)) {
    New-Item -ItemType Directory -Path $FolderPath | Out-Null
}

# Create Project Directory if it does not exist
if (-not (Test-Path $projectDir)) {
    New-Item -ItemType Directory -Path $projectDir | Out-Null
}

# Navigate to Project Directory
Set-Location -Path $projectDir

# Clone the Git Repository
Write-Host "Cloning repository..."
git clone $repoUrl
if ($LASTEXITCODE -ne 0) {
    Write-Host "Git clone failed!"
    exit 1
}

# Extract Repo Folder Name from URL
$repoName = ($repoUrl -split "/" | Select-Object -Last 1) -replace ".git$"
$repoPath = "$projectDir\$repoName"

# Ensure Repo Folder Exists
if (-not (Test-Path $repoPath)) {
    Write-Host "Repository folder not found!"
    exit 1
}

# Copy global.json into the cloned repository
Write-Host "Copying global.json into repository..."
Copy-Item -Path $fileToCopy -Destination $repoPath -Force

# Navigate into the cloned repository
Set-Location -Path $repoPath

# Run Git Submodule Command
Write-Host "Initializing Git submodules..."
git submodule update --init --recursive

# Run Custom Command (Replace with actual command)
Write-Host "Running custom command 1 to build sln file in the dir"
& "C:\Projects\UE_5.4\UnrealEngine\Engine\Build\BatchFiles\GenerateProjectFiles.bat" -project="C:\Projects\emperia-unreal\EmperiaUnreal.uproject" -game -engine

Write-Host "Running custom command 1.5 dotnet restore"
dotnet restore

Write-Host "Running custom command 2 to build from the sln file"
& "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" "C:\Projects\emperia-unreal\EmperiaUnreal.sln" /p:Configuration="Development Editor" /p:Platform=Win64

# Create Build Directory if it does not exist
if (-not (Test-Path $buildDir)) {
    New-Item -ItemType Directory -Path $buildDir | Out-Null
}

Write-Host "Running custom command 3 to build the package for Linux"
& "C:\Projects\UE_5.4\UnrealEngine\Engine\Build\BatchFiles\RunUAT.bat" BuildCookRun -project="C:\Projects\emperia-unreal\EmperiaUnreal.uproject" -noP4 -platform=Linux -clientconfig=Development -serverconfig=Development -cook -build -stage -pak -archive -archivedirectory="$buildDir"

# Navigate into the Build repository
Set-Location -Path $FolderPath

# Before running tag check if folder contain data
$files = Get-ChildItem -Path $buildDir
if ($files.Count -eq 0) {
    Write-Host "Error: No files found in $buildDir!"
    exit 1
}

Write-Host "Running custom command 4 to zip the package for Linux"
tar -a -c -f "$buildDir.zip" -C "$FolderPath" "$BuildNumber"

Write-Host "Running custom command 5 to upload the $BuildNumber.zip file to GCP bucket"
gcloud storage cp -r .\$BuildNumber.zip gs://ugc-data-dump-unreal-project/Unreal_project_Builds/

#Delete the Build dir
Set-Location -Path $projectDir
# Check if folder exists
if (Test-Path $FolderPath) {
    Remove-Item -Path $FolderPath -Recurse -Force
    Write-Host "Folder deleted: $FolderPath"
} else {
    Write-Host "test_build Folder does not exist: $FolderPath"
}

#Delete the unreal project dir
Set-Location -Path $projectDir
# Check if folder exists
if (Test-Path $repoPath) {
    Remove-Item -Path $repoPath -Recurse -Force
    Write-Host "Folder deleted: $repoPath"
} else {
    Write-Host "Unreal Project $repoName Folder does not exist: $repoPath"
}

#Phase 2 calling module 2  to build the image 

#Set working dir
Set-Location -Path $projectDir

# Clone the Git Repository
Write-Host "Cloning repository..."
git clone $phase2gitURL
if ($LASTEXITCODE -ne 0) {
    Write-Host "Git clone failed!"
    exit 1
}

# Extract Repo Folder Name from URL
$phase2repoName = ($phase2gitURL -split "/" | Select-Object -Last 1) -replace ".git$"
$phase2repoPath = "$projectDir\$phase2repoName"

# Ensure Repo Folder Exists
if (-not (Test-Path $phase2repoPath)) {
    Write-Host "Repository folder not found!"
    exit 1
}

# Read file content as a single string
$Content = Get-Content -Path $FilePath -Raw

# Replace BUILD_No value dynamically
$NewContent = $Content -replace "(?<=BUILD_No:\s)[^\r\n]+", $BuildNumber

# Save changes
$NewContent | Set-Content -Path $FilePath

Write-Host "Updated deploy_latest_build.yml: Build_No set to $BuildNumber"

Set-Location -Path $phase2repoPath
# Git commands to commit and push
git config --global user.email "akash@emperiavr.com"
git config --global user.name "Akash Rawat"
git add .
git commit -m "Updated Build_No to $BuildNumber Building Image"
git push origin main  # Change 'main' to your branch name if needed

Write-Host "Changes pushed to GitHub!"

#Delete the phase 2 dir
Set-Location -Path $projectDir
# Check if folder exists
if (Test-Path $phase2repoPath) {
    Remove-Item -Path $phase2repoPath -Recurse -Force
    Write-Host "Folder deleted: $phase2repoPath"
} else {
    Write-Host "$phase2repoName Folder does not exist: $phase2repoPath"
}

Write-Host "Script execution completed successfully!"
