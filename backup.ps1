# 1. Define Paths
$source = "C:\Users\AIIC\Documents\my_app_fixed"
$backupRoot = "C:\Users\AIIC\Documents\my_app_backups"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$dest = "$backupRoot\backup_$timestamp"

# 2. Create the main backup folder if it doesn't exist
if (!(Test-Path $backupRoot)) { New-Item -ItemType Directory -Path $backupRoot }

Write-Host "Starting backup to $dest..." -ForegroundColor Cyan

# 3. Copy files using Robocopy (Excludes build and temp folders)
# /E = copy subdirectories, /XD = exclude directories
robocopy $source $dest /E /XD build .dart_tool .gradle .idea .vscode /NFL /NDL /NJH /NJS /nc /ns /np

# 4. Git Backup (Saves to GitHub)
Set-Location $source
git add .
git commit -m "Automated backup on $timestamp"
git push

Write-Host "Backup completed successfully!" -ForegroundColor Green
Read-Host "Press Enter to exit"