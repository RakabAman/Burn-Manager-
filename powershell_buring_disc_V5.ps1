# === LOAD UI COMPONENTS ===
Add-Type -AssemblyName System.Windows.Forms

function Select-Folder($description) {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = $description
    $dialog.ShowNewFolderButton = $true
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.SelectedPath
    } else {
        throw "Folder selection cancelled."
    }
}

function Select-File($description, $filter) {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = $description
    $dialog.Filter = $filter
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.FileName
    } else {
        throw "File selection cancelled."
    }
}

# === USER INPUT ===
$sourceFolder = Select-Folder "Select the SOURCE folder containing folders to burn"
$csvPath = Select-File "Select a previously burned FileList CSV (to skip duplicates)" "CSV Files (*.csv)|*.csv"
$outputFolder = Select-Folder "Select the OUTPUT folder for new burn lists"

# === CONFIGURATION ===
$discSizeGB = 50
$maxPathLength = 240
$discSizeBytes = $discSizeGB * 1GB
$subfolders = Get-ChildItem -Path $sourceFolder -Directory
$batchIndex = 1
$currentBatchSize = 0
$currentBatch = @()
$skippedFolders = @()
$longPaths = @()
$discCount = 0

# === LOAD PREVIOUS FILE LIST ===
$previousFiles = Import-Csv -Path $csvPath
$previousFolders = $previousFiles.FullName | ForEach-Object {
    Split-Path $_ -Parent
} | Select-Object -Unique

# === MAIN LOOP: FILTER AND BATCH ===
foreach ($folder in $subfolders) {
    # Skip if folder already burned
    if ($previousFolders -contains $folder.FullName) {
        $skippedFolders += $folder.FullName
        continue
    }

    # Skip if folder contains long paths
    $tooLong = Get-ChildItem -Path $folder.FullName -Recurse -File | Where-Object {
        $_.FullName.Length -gt $maxPathLength
    }
    if ($tooLong.Count -gt 0) {
        $longPaths += $folder.FullName
        continue
    }

    # Check size and batch
    $folderSize = (Get-ChildItem -Path $folder.FullName -Recurse | Measure-Object -Property Length -Sum).Sum
    if (($currentBatchSize + $folderSize) -gt $discSizeBytes) {
        Save-Batch
    }

    $currentBatchSize += $folderSize
    $currentBatch += $folder
}

# === FINAL BATCH ===
if ($currentBatch.Count -gt 0) {
    Save-Batch
}

# === FUNCTION: SAVE BATCH TO FILE ===
function Save-Batch {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $baseName = "Disc_$batchIndex"
    $listPath = Join-Path $outputFolder "$baseName_$timestamp.txt"

    $currentBatch | ForEach-Object { $_.FullName } | Set-Content $listPath
    Write-Host "✅ Created burn list: $listPath"

    $global:discCount++
    $global:batchIndex++
    $global:currentBatchSize = 0
    $global:currentBatch = @()
}

# === SUMMARY REPORT ===
$summary = @()
$summary += "Total new discs created: $discCount"
$summary += "Folders skipped (already burned): $($skippedFolders.Count)"
$summary += "Folders skipped (long paths): $($longPaths.Count)"
$summary += ""
if ($skippedFolders.Count -gt 0) {
    $summary += "Already burned folders:"
    $summary += $skippedFolders
}
if ($longPaths.Count -gt 0) {
    $summary += ""
    $summary += "Folders with long paths:"
    $summary += $longPaths
}
$reportPath = Join-Path $outputFolder "Burn_Summary_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$summary | Set-Content $reportPath
Write-Host "📄 Summary saved to: $reportPath"
