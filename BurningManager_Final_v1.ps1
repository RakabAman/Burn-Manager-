<#
Blu-ray Burn Manager — Sequential burning + optional long-path skipping
- New UI checkbox: "Skip folders that contain files with long paths"
- Burn sequence: run .ibb projects one-by-one, waiting for ImgBurn to finish each before continuing
- Fallback strategy for launching ImgBurn:
   * Preferred: use ImgBurn.exe path (if provided) and start with .ibb as argument, waiting on that process
   * Fallback: shell-open the .ibb and poll for ImgBurn process start/exit to wait for completion
- Comments added for clarity
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ====================================================================
# UI: form and layout (improved)
# ====================================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Blu-ray Burn Manager - Sequential Burn (Rakab Aman)"
$form.Size = [System.Drawing.Size]::new(500,650)
$form.MinimumSize = [System.Drawing.Size]::new(700,550)
$form.StartPosition = "CenterScreen"

# Layout constants
$pad = 8
$labelW = 150
$browseW = 80
$spacing = 5
$rowH = 45

# Dynamic widths
$controlLeft = $pad + $labelW + $spacing
$controlW = $form.ClientSize.Width - ($controlLeft + $browseW + $pad + ($spacing*2))
$browseLeft = $controlLeft + $controlW + $spacing

# -------------------------
# Controls: Inputs
# -------------------------
$labels = @(
    "Source Folder",
    "Output Folder (IBB & lists)",
    "Single Compare CSV (optional)",
    "ImgBurn.exe (full path)"
)

$textBoxes = @()
$browseBtns = @()
for ($i=0; $i -lt $labels.Count; $i++) {
    $y = $pad + ($i * $rowH)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $labels[$i]
    $lbl.Location = [System.Drawing.Point]::new($pad, $y + 8)
    $lbl.Size = [System.Drawing.Size]::new($labelW, 25)
    $form.Controls.Add($lbl)

    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Location = [System.Drawing.Point]::new($controlLeft, $y + 6)
    $tb.Size = [System.Drawing.Size]::new($controlW, 26)
    $tb.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $form.Controls.Add($tb); $textBoxes += $tb

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "Browse"
    $btn.Location = [System.Drawing.Point]::new($browseLeft, $y + 2)
    $btn.Size = [System.Drawing.Size]::new($browseW, 28)
    $btn.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
    $form.Controls.Add($btn); $browseBtns += $btn
}

# Multi CSV selector and master option
$multiLabel = New-Object System.Windows.Forms.Label
$multiLabel.Text = "Compare CSVs (multi-select)"
$multiLabel.Location = [System.Drawing.Point]::new($pad, $pad + ($labels.Count * $rowH) + 4)
$multiLabel.Size = [System.Drawing.Size]::new($labelW, 35)
$form.Controls.Add($multiLabel)

$multiText = New-Object System.Windows.Forms.TextBox
$multiText.Location = [System.Drawing.Point]::new($controlLeft, $pad + ($labels.Count * $rowH) + 2)
$multiText.Size = [System.Drawing.Size]::new($controlW, 26)
$multiText.ReadOnly = $true
$multiText.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($multiText)

$multiBtn = New-Object System.Windows.Forms.Button
$multiBtn.Text = "Select CSVs"
$multiBtn.Location = [System.Drawing.Point]::new($browseLeft , $pad + ($labels.Count * $rowH) - 2)
$multiBtn.Size = [System.Drawing.Size]::new(80, 28)
$multiBtn.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($multiBtn)

# Master CSV checkbox (new)
$chkWriteMaster = New-Object System.Windows.Forms.CheckBox
$chkWriteMaster.Text = "Write/update Master_FileList.csv in Output"
$chkWriteMaster.Location = [System.Drawing.Point]::new($controlLeft -100, $pad + ($labels.Count * $rowH) + 36)
$chkWriteMaster.Size = [System.Drawing.Size]::new(250, 22)
$chkWriteMaster.Checked = $true
$form.Controls.Add($chkWriteMaster)

# Skip long path checkbox (new)
$chkSkipLongPaths = New-Object System.Windows.Forms.CheckBox
$chkSkipLongPaths.Text = "Skip folders that contain files with long paths (optional)"
$chkSkipLongPaths.Location = [System.Drawing.Point]::new($controlLeft + 200, $pad + ($labels.Count * $rowH) + 36)
$chkSkipLongPaths.Size = [System.Drawing.Size]::new(660, 22)
$chkSkipLongPaths.Checked = $true    # sensible default; user can uncheck
$form.Controls.Add($chkSkipLongPaths)

# Disc size and dry-run
$discY = $pad + ($labels.Count * $rowH) + 60
$lblDisc = New-Object System.Windows.Forms.Label
$lblDisc.Text = "Disc Size"
$lblDisc.Location = [System.Drawing.Point]::new($pad, $discY + 8)
$lblDisc.Size = [System.Drawing.Size]::new($labelW, 20)
$form.Controls.Add($lblDisc)

$comboDisc = New-Object System.Windows.Forms.ComboBox
$comboDisc.Location = [System.Drawing.Point]::new($controlLeft, $discY + 6)
$comboDisc.Size = [System.Drawing.Size]::new(160, 26)
$comboDisc.DropDownStyle = "DropDownList"
$comboDisc.Items.Add("50 GB"); $comboDisc.Items.Add("20 GB")
$comboDisc.SelectedIndex = 0
$form.Controls.Add($comboDisc)

$chkDryRun = New-Object System.Windows.Forms.CheckBox
$chkDryRun.Text = "Dry-Run (do not execute ImgBurn; print actions)"
$chkDryRun.Location = [System.Drawing.Point]::new($controlLeft + 180, $discY + 8)
$chkDryRun.Size = [System.Drawing.Size]::new(420, 22)
$form.Controls.Add($chkDryRun)

# Output box and three action buttons
$btnW = 200; $btnH = 44; $btnSpace = 18
$buttonsY = 290

$btnGenerate = New-Object System.Windows.Forms.Button
$btnGenerate.Text = "Generate Burn Lists (Disc_*.txt)"
$btnGenerate.Size = [System.Drawing.Size]::new($btnW, $btnH)
$btnGenerate.Location = [System.Drawing.Point]::new($pad + 20, $buttonsY)
# $btnGenerate.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($btnGenerate)

$btnCreateIbb = New-Object System.Windows.Forms.Button
$btnCreateIbb.Text = "Create IBB Projects (no burn)"
$btnCreateIbb.Size = [System.Drawing.Size]::new($btnW, $btnH)
$btnCreateIbb.Location = [System.Drawing.Point]::new($pad + 30 + $btnW, $buttonsY)
# $btnCreateIbb.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($btnCreateIbb)

$btnBurnIbb = New-Object System.Windows.Forms.Button
$btnBurnIbb.Text = "Burn IBB Projects (sequential)"
$btnBurnIbb.Size = [System.Drawing.Size]::new($btnW, $btnH)
$btnBurnIbb.Location = [System.Drawing.Point]::new($pad + 40 + $btnW + $btnW, $buttonsY)
# $btnBurnIbb.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($btnBurnIbb)

$outputTop = $discY + 100
$outputH = $form.ClientSize.Height - $outputTop - 10
if ($outputH -lt 220) { $outputH = 220 }

$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Multiline = $true
$outputBox.ScrollBars = "Vertical"
$outputBox.Location = [System.Drawing.Point]::new($pad, $outputTop)
$outputBox.Size = [System.Drawing.Size]::new($form.ClientSize.Width - ($pad*2), $outputH)
$outputBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$outputBox.ReadOnly = $true
$form.Controls.Add($outputBox)



# -------------------------
# Logging helper
# -------------------------
function Append-Output {
    param([string]$txt)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $outputBox.AppendText("[$ts] $txt`r`n")
    $outputBox.SelectionStart = $outputBox.Text.Length
    $outputBox.ScrollToCaret()
}

# -------------------------
# Browse handlers
# -------------------------
$browseBtns[0].Add_Click({
    $f = New-Object Windows.Forms.FolderBrowserDialog
    if ($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $textBoxes[0].Text = $f.SelectedPath }
})
$browseBtns[1].Add_Click({
    $f = New-Object Windows.Forms.FolderBrowserDialog
    if ($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $textBoxes[1].Text = $f.SelectedPath }
})
$browseBtns[2].Add_Click({
    $ofd = New-Object Windows.Forms.OpenFileDialog
    $ofd.Filter = "CSV Files (*.csv)|*.csv"
    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $textBoxes[2].Text = $ofd.FileName }
})
$browseBtns[3].Add_Click({
    $ofd = New-Object Windows.Forms.OpenFileDialog
    $ofd.Filter = "Executable Files (*.exe)|*.exe"
    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $textBoxes[3].Text = $ofd.FileName }
})

# Multi CSV selector
$multiCsvPaths = @()
$multiBtn.Add_Click({
    $ofd = New-Object Windows.Forms.OpenFileDialog
    $ofd.Filter = "CSV Files (*.csv)|*.csv"
    $ofd.Multiselect = $true
    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $multiCsvPaths = $ofd.FileNames
        $multiText.Text = ($multiCsvPaths -join "; ")
        Append-Output ("Selected {0} CSV(s) for compare." -f $multiCsvPaths.Count)
    }
})

# ====================================================================
# Core functions (Create IBB project + run ImgBurn sequentially)
# ====================================================================

function Create-IbbProjectIni {
    param(
        [Parameter(Mandatory=$true)][string[]]$SourcePaths,
        [Parameter(Mandatory=$true)][string]$ProjectPath,
        [string]$DestinationIso = "",
        [int]$FileSystem = 3,
        [switch]$PreserveFullPathnames = $false,
        [switch]$RecurseSubdirectories = $true,
        [switch]$IncludeHiddenFiles = $false,
        [switch]$IncludeSystemFiles = $false,
        [switch]$AddToWriteQueueWhenDone = $false,
        [string]$VolumeLabelUdf = ""
    )
    try {
        if (-not $SourcePaths -or $SourcePaths.Count -eq 0) { throw "No source paths provided." }
        if ([string]::IsNullOrWhiteSpace($ProjectPath)) { throw "ProjectPath empty." }

        $projParent = Split-Path -Path $ProjectPath -Parent
        if (-not (Test-Path -LiteralPath $projParent)) { New-Item -ItemType Directory -Path $projParent -Force | Out-Null }

        $clean = @()
        foreach ($p in $SourcePaths) {
            if ([string]::IsNullOrWhiteSpace($p)) { continue }
            $pp = $p.Trim()
            if (Test-Path -LiteralPath $pp -PathType Container) {
                if (-not $pp.EndsWith("\") -and -not $pp.EndsWith("/")) { $pp += "\" }
                $clean += $pp; continue
            }
            if (Test-Path -LiteralPath $pp -PathType Leaf) { $clean += $pp; continue }
            $pp2 = $pp.TrimEnd('\','/')
            if (Test-Path -LiteralPath $pp2 -PathType Container) { if (-not $pp2.EndsWith("\") -and -not $pp2.EndsWith("/")) { $pp2 += "\" }; $clean += $pp2; continue }
            throw "Source path not found: $pp"
        }
        if ($clean.Count -eq 0) { throw "No valid source paths found." }

        $preserveVal = if ($PreserveFullPathnames.IsPresent) { 1 } else { 0 }
        $recurseVal  = if ($RecurseSubdirectories.IsPresent)   { 1 } else { 0 }
        $hiddenVal   = if ($IncludeHiddenFiles.IsPresent)     { 1 } else { 0 }
        $systemVal   = if ($IncludeSystemFiles.IsPresent)     { 1 } else { 0 }
        $queueVal    = if ($AddToWriteQueueWhenDone.IsPresent) { 1 } else { 0 }

        $lines = @()
        $lines += "IBB"; $lines += ""; $lines += "[START_BACKUP_OPTIONS]"
        $lines += "BuildInputMode=1"; $lines += "BuildOutputMode=2"
        $lines += ("Destination={0}" -f $DestinationIso); $lines += "DataType=0"
        $lines += ("FileSystem={0}" -f $FileSystem); $lines += "UDFRevision=0"
        $lines += ("PreserveFullPathnames={0}" -f $preserveVal); $lines += ("RecurseSubdirectories={0}" -f $recurseVal)
        $lines += "IncludeHiddenFiles=1" ; $lines += ("IncludeSystemFiles={0}" -f $systemVal)
        $lines += "IncludeArchiveFilesOnly=0"; $lines += ("AddToWriteQueueWhenDone={0}" -f $queueVal)
        $lines += "ClearArchiveAttribute=0"; $lines += "VolumeLabel_ISO9660="; $lines += "VolumeLabel_Joliet="
        $lines += ("VolumeLabel_UDF={0}" -f $VolumeLabelUdf)
        $lines += "Identifier_System="; $lines += "Identifier_VolumeSet="; $lines += "Identifier_Publisher="
        $lines += "Identifier_Preparer="; $lines += "Identifier_Application="; $lines += "Dates_FolderFileType=0"
        $lines += "Restrictions_ISO9660_InterchangeLevel=0"; $lines += "Restrictions_ISO9660_CharacterSet=0"
        $lines += "Restrictions_ISO9660_AllowMoreThan8DirectoryLevels=0"; $lines += "Restrictions_ISO9660_AllowMoreThan255CharactersInPath=0"
        $lines += "Restrictions_ISO9660_AllowFilesWithoutExtensions=0"; $lines += "Restrictions_ISO9660_AllowFilesExceedingSizeLimit=0"
        $lines += "Restrictions_ISO9660_DontAddVersionNumberToFiles=0"; $lines += "Restrictions_Joliet_InterchangeLevel=0"
        $lines += "Restrictions_Joliet_AllowFilesWithoutExtensions=0"; $lines += "Restrictions_Joliet_AddVersionNumberToFiles=0"
        $lines += "Restrictions_UDF_DisableUnicodeSupport=0"; $lines += "Restrictions_UDF_DVDVideoDontDisableUnicodeSupport=0"
        $lines += "Restrictions_UDF_DVDVideoDontDisableUnicodeSupport_SF=0"; $lines += "Restrictions_UDF_HDDVDVideoDontDisableUnicodeSupport=0"
        $lines += "Restrictions_UDF_HDDVDVideoDontDisableUnicodeSupport_SF=0"; $lines += "Restrictions_UDF_BDVideoDontDisableUnicodeSupport=0"
        $lines += "Restrictions_UDF_BDVideoDontDisableUnicodeSupport_SF=0"; $lines += "Restrictions_UDF_DVDVideoAllowUnicodeVolumeLabel=0"
        $lines += "Restrictions_UDF_HDDVDVideoAllowUnicodeVolumeLabel=0"; $lines += "Restrictions_UDF_BDVideoAllowUnicodeVolumeLabel=0"
        $lines += "Restrictions_UDF_AllowNonCompliantFileCreationDates=0"; $lines += "BootableDisc_MakeImageBootable=0"
        $lines += "[END_BACKUP_OPTIONS]"; $lines += ""; $lines += "[START_BACKUP_LIST]"

        foreach ($s in $clean) { $lines += $s }

        $lines += "[END_BACKUP_LIST]"; $lines += ""
        $encoding = [System.Text.Encoding]::GetEncoding([System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage)
        [System.IO.File]::WriteAllLines($ProjectPath, $lines, $encoding)

        Append-Output ("Wrote .ibb project: {0} (entries: {1})" -f $ProjectPath, $clean.Count)
        return $true
    } catch {
        Append-Output ("❌ Create-IbbProjectIni failed: {0}" -f $_.Exception.ToString())
        return $false
    }
}

# --------------------------------------------------------------------
# Run-ImgBurnProjectSequential: open one .ibb and wait for ImgBurn to finish
# - If ImgBurn.exe available -> start it with the .ibb arg and wait on process
# - Else -> shell-open .ibb and poll for ImgBurn process; wait until it exits
# Returns $true on success, $false on failure
# --------------------------------------------------------------------
function Run-ImgBurnProjectSequential {
    param(
        [string]$ImgBurnExe,    # optional path to ImgBurn.exe
        [string]$ProjectPath,
        [switch]$DryRun,
        [int]$PollIntervalSeconds = 2,   # how often to poll for ImgBurn process
        [int]$WaitTimeoutSeconds = 3600  # fallback max wait (1 hour default)
    )

    try {
        if ([string]::IsNullOrWhiteSpace($ProjectPath) -or -not (Test-Path -LiteralPath $ProjectPath)) { throw "Project file not found: $ProjectPath" }

        if ($DryRun) {
            Append-Output ("DRY-RUN -> Would open project: {0}" -f $ProjectPath)
            return $true
        }

        # Preferred: if a valid ImgBurn.exe was provided, start ImgBurn with the project path as an argument and wait for that specific process
        if (-not [string]::IsNullOrWhiteSpace($ImgBurnExe) -and (Test-Path -LiteralPath $ImgBurnExe)) {
            Append-Output ("Launching ImgBurn.exe with project: {0}" -f $ProjectPath)
            # Build argument safely with quotes
            $quoted = '"' + ($ProjectPath -replace '"','\"') + '"'
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $ImgBurnExe
            $psi.Arguments = $quoted
            $psi.WorkingDirectory = (Split-Path -Path $ProjectPath -Parent)
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            $proc = [System.Diagnostics.Process]::Start($psi)
            if (-not $proc) { Append-Output "❌ Failed to start ImgBurn.exe"; return $false }
            # Wait up to timeout seconds for process to exit
            $finished = $proc.WaitForExit($WaitTimeoutSeconds * 1000)
            if (-not $finished) {
                Append-Output ("⚠️ ImgBurn did not exit within {0} seconds for project {1}" -f $WaitTimeoutSeconds, $ProjectPath)
                return $false
            }
            Append-Output ("ImgBurn process exited (code {0}) for project {1}" -f $proc.ExitCode, $ProjectPath)
            return $true
        }

        # Fallback: use shell open on the .ibb file (replicates double-click). Then poll for ImgBurn.exe processes to start and exit.
        Append-Output ("Shell-opening .ibb (fallback): {0}" -f $ProjectPath)
        Start-Process -FilePath $ProjectPath -WorkingDirectory (Split-Path -Path $ProjectPath -Parent) -ErrorAction Stop

        # Wait for ImgBurn process to appear
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $found = $false
        while ($stopwatch.Elapsed.TotalSeconds -lt $WaitTimeoutSeconds) {
            $procs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'ImgBurn' }
            if ($procs.Count -gt 0) { $found = $true; break }
            Start-Sleep -Seconds $PollIntervalSeconds
        }
        if (-not $found) {
            Append-Output ("⚠️ ImgBurn process did not start within {0} seconds after opening {1}" -f $WaitTimeoutSeconds, $ProjectPath)
            return $false
        }

        # Now wait for all ImgBurn processes to finish (they may spawn children)
        Append-Output "ImgBurn started; waiting for it to finish..."
        $stopwatch.Restart()
        while ($stopwatch.Elapsed.TotalSeconds -lt $WaitTimeoutSeconds) {
            $procs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'ImgBurn' }
            if ($procs.Count -eq 0) { Append-Output "ImgBurn processes no longer present."; return $true }
            Start-Sleep -Seconds $PollIntervalSeconds
        }
        Append-Output ("⚠️ ImgBurn did not exit within {0} seconds after starting for project {1}" -f $WaitTimeoutSeconds, $ProjectPath)
        return $false
    } catch {
        Append-Output ("❌ Run-ImgBurnProjectSequential failed: {0}" -f $_.Exception.ToString())
        return $false
    }
}

# ====================================================================
# Relative-path compare utilities (same as before)
# ====================================================================
function Build-CompareFolderSet {
    param([string[]]$paths, [string]$singlePath, [string]$SourceRoot)

    function Normalize-ToRelative { param([string]$p)
        if ([string]::IsNullOrWhiteSpace($p)) { return $null }
        try {
            if ($SourceRoot -and ($p -match '^[a-zA-Z]:\\' -or $p -like '\\\*')) {
                try { $rel = [IO.Path]::GetRelativePath($SourceRoot, $p); if ($rel) { return $rel.TrimStart('\','/') } } catch {}
            }
            if (-not ($p -match '^[a-zA-Z]:\\' -or $p -like '\\\*')) { return $p.TrimStart('\','/').Trim() }
            $full = $p.TrimEnd('\','/'); return $full
        } catch { return $null }
    }

    $relFolderSet = New-Object System.Collections.Generic.HashSet[string]
    $relFileSet   = New-Object System.Collections.Generic.HashSet[string]

    function Add-RelativeFolder { param([string]$r) if ($r) { [void]$relFolderSet.Add(($r.TrimEnd('\','/').ToLowerInvariant())) } }
    function Add-RelativeFile { param([string]$r) if (-not $r) { return } $norm = $r.TrimStart('\','/').ToLowerInvariant(); [void]$relFileSet.Add($norm); try { $parent = [System.IO.Path]::GetDirectoryName($norm); if ($parent) { [void]$relFolderSet.Add($parent) } } catch {} }

    if ($paths -and $paths.Count -gt 0) {
        foreach ($csv in $paths) {
            try {
                $rows = Import-Csv -Path $csv -ErrorAction Stop
                foreach ($r in $rows) {
                    if ($r.PSObject.Properties.Match('RelativePath').Count -gt 0 -and $r.RelativePath) { Add-RelativeFile -r $r.RelativePath.Trim(); continue }
                    if ($r.PSObject.Properties.Match('FullName').Count -gt 0 -and $r.FullName) { $rel = Normalize-ToRelative -p $r.FullName.Trim(); Add-RelativeFile -r $rel; continue }
                    foreach ($prop in $r.PSObject.Properties) {
                        $val = $prop.Value
                        if (-not [string]::IsNullOrWhiteSpace($val)) {
                            $rel = Normalize-ToRelative -p $val.Trim()
                            if ($rel) { Add-RelativeFile -r $rel; break }
                        }
                    }
                }
                Append-Output ("Loaded compare CSV: {0} ({1} rows)" -f (Split-Path $csv -Leaf), $rows.Count)
            } catch { Append-Output ("❌ Failed to load CSV {0}: {1}" -f (Split-Path $csv -Leaf), $_.Exception.Message) }
        }
    } elseif ($singlePath -and (Test-Path -LiteralPath $singlePath)) {
        try {
            $rows = Import-Csv -Path $singlePath -ErrorAction Stop
            foreach ($r in $rows) {
                if ($r.PSObject.Properties.Match('RelativePath').Count -gt 0 -and $r.RelativePath) { Add-RelativeFile -r $r.RelativePath.Trim(); continue }
                if ($r.PSObject.Properties.Match('FullName').Count -gt 0 -and $r.FullName) { $rel = Normalize-ToRelative -p $r.FullName.Trim(); Add-RelativeFile -r $rel; continue }
                foreach ($prop in $r.PSObject.Properties) {
                    $val = $prop.Value
                    if (-not [string]::IsNullOrWhiteSpace($val)) { $rel = Normalize-ToRelative -p $val.Trim(); if ($rel) { Add-RelativeFile -r $rel; break } }
                }
            }
            Append-Output ("Loaded single compare CSV: {0} ({1} rows)" -f (Split-Path $singlePath -Leaf), $rows.Count)
        } catch { Append-Output ("❌ Failed to load single CSV: {0}" -f $_.Exception.Message) }
    } else { Append-Output "No compare CSV(s) provided." }

    return @{ RelativeFolders = $relFolderSet; RelativeFiles = $relFileSet }
}

function Is-FolderConsideredBurned {
    param([string]$folderPathAbsolute, [System.Collections.Generic.HashSet[string]]$relFolderSet, [System.Collections.Generic.HashSet[string]]$relFileSet, [string]$SourceRoot)
    if (-not $folderPathAbsolute) { return $false }
    try {
        $rel = $null
        try { $rel = [IO.Path]::GetRelativePath($SourceRoot, $folderPathAbsolute) } catch {
            if ($folderPathAbsolute.StartsWith($SourceRoot, [System.StringComparison]::OrdinalIgnoreCase)) { $rel = $folderPathAbsolute.Substring($SourceRoot.Length).TrimStart('\','/') } else { $rel = $folderPathAbsolute }
        }
        if (-not $rel) { return $false }
        $norm = $rel.TrimStart('\','/').TrimEnd('\','/').ToLowerInvariant()
    } catch { return $false }

    if ($relFolderSet.Contains($norm)) { return $true }
    $prefix = $norm + "\"
    foreach ($rf in $relFileSet) { if ($rf.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) { return $true } }
    return $false
}

# ====================================================================
# Generate button: create Disc_*.txt & per-disc CSV with RelativePath
# - Honors SkipLongPaths checkbox
# ====================================================================
$btnGenerate.Add_Click({
    Start-Sleep -Milliseconds 50
    $source = $textBoxes[0].Text.Trim(); $output = $textBoxes[1].Text.Trim(); $singleCompare = $textBoxes[2].Text.Trim()
    if ([string]::IsNullOrWhiteSpace($source) -or -not (Test-Path -LiteralPath $source)) { Append-Output "❌ Source folder not valid."; return }
    if ([string]::IsNullOrWhiteSpace($output) -or -not (Test-Path -LiteralPath $output)) { Append-Output "❌ Output folder not valid."; return }

    $discSizeGB = if ($comboDisc.SelectedItem -like "50*") {50} else {20}
    $discSizeBytes = [int64]$discSizeGB * 1GB
    $maxPath = 240

    $skipLongPaths = $chkSkipLongPaths.Checked
    Append-Output ("Starting Generate (disc size: {0} GB) - SkipLongPaths={1}" -f $discSizeGB, $skipLongPaths)

    # Build compare sets relative to the provided source root
    $compareData = Build-CompareFolderSet -paths $multiCsvPaths -singlePath $singleCompare -SourceRoot $source
    $compareFolders = $compareData.RelativeFolders; $compareFiles = $compareData.RelativeFiles

    try {
        $subfolders = Get-ChildItem -Path $source -Directory -ErrorAction Stop
        $batchIdx = 1; $currentSize = 0; $currentBatch = @(); $skipped = @(); $longPaths = @(); $discCount = 0

        foreach ($fd in $subfolders) {
            if (Is-FolderConsideredBurned -folderPathAbsolute $fd.FullName -relFolderSet $compareFolders -relFileSet $compareFiles -SourceRoot $source) {
                $skipped += $fd.FullName; Append-Output ("Skipping (already burned): {0}" -f $fd.FullName); continue
            }

            # Check for long paths only if user asked to skip them
            if ($skipLongPaths) {
                $tooLong = Get-ChildItem -Path $fd.FullName -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName.Length -gt $maxPath }
                if ($tooLong.Count -gt 0) {
                    $longPaths += $fd.FullName
                    Append-Output ("Skipping (long path detected): {0}" -f $fd.FullName)
                    continue
                }
            }

            $size = (Get-ChildItem -Path $fd.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Prop Length -Sum).Sum
            if (-not $size) { $size = 0 }

            if (($currentSize + $size) -gt $discSizeBytes -and $currentBatch.Count -gt 0) {
                $ts = Get-Date -Format "yyyyMMdd_HHmmss"; $name = "Disc_$batchIdx"; $listPath = Join-Path $output "$name`_$ts.txt"; $csvPath = Join-Path $output "$name`_FileList`_$ts.csv"
                $currentBatch | ForEach-Object { $_.FullName } | Set-Content -Path $listPath -Encoding UTF8
                Append-Output ("Created burn list: {0}" -f $listPath)

                # Build per-disc CSV with RelativePath
                $inv = @()
                foreach ($b in $currentBatch) {
                    $files = Get-ChildItem -Path $b.FullName -Recurse -File -ErrorAction SilentlyContinue
                    foreach ($f in $files) {
                        try { $rel = [IO.Path]::GetRelativePath($source, $f.FullName) } catch {
                            if ($f.FullName.StartsWith($source, [System.StringComparison]::OrdinalIgnoreCase)) { $rel = $f.FullName.Substring($source.Length).TrimStart('\','/') } else { $rel = $f.FullName }
                        }
                        $inv += [pscustomobject]@{ FullName = $f.FullName; RelativePath = $rel; Length = $f.Length; LastWriteTime = $f.LastWriteTime.ToString("o") }
                    }
                }
                if ($inv.Count -gt 0) { $inv | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8; Append-Output ("Created CSV inventory: {0} ({1} files)" -f $csvPath, $inv.Count) } else { Append-Output ("CSV inventory empty: {0}" -f $name) }

                $batchIdx++; $discCount++; $currentBatch = @(); $currentSize = 0
            }

            $currentBatch += $fd; $currentSize += $size
        }

        # Final batch flush
        if ($currentBatch.Count -gt 0) {
            $ts = Get-Date -Format "yyyyMMdd_HHmmss"; $name = "Disc_$batchIdx"; $listPath = Join-Path $output "$name`_$ts.txt"; $csvPath = Join-Path $output "$name`_FileList`_$ts.csv"
            $currentBatch | ForEach-Object { $_.FullName } | Set-Content -Path $listPath -Encoding UTF8
            Append-Output ("Created burn list: {0}" -f $listPath)

            $inv = @()
            foreach ($b in $currentBatch) {
                $files = Get-ChildItem -Path $b.FullName -Recurse -File -ErrorAction SilentlyContinue
                foreach ($f in $files) {
                    try { $rel = [IO.Path]::GetRelativePath($source, $f.FullName) } catch {
                        if ($f.FullName.StartsWith($source, [System.StringComparison]::OrdinalIgnoreCase)) { $rel = $f.FullName.Substring($source.Length).TrimStart('\','/') } else { $rel = $f.FullName }
                    }
                    $inv += [pscustomobject]@{ FullName = $f.FullName; RelativePath = $rel; Length = $f.Length; LastWriteTime = $f.LastWriteTime.ToString("o") }
                }
            }
            if ($inv.Count -gt 0) { $inv | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8; Append-Output ("Created CSV inventory: {0} ({1} files)" -f $csvPath, $inv.Count) } else { Append-Output ("CSV inventory empty: {0}" -f $name) }
            $discCount++
        }

        # Update Master_FileList.csv if enabled (stores RelativePath)
        if ($chkWriteMaster.Checked) {
            $masterPath = Join-Path $output "Master_FileList.csv"; $masterMap = @{}
            $filelistCsvs = Get-ChildItem -Path $output -Filter "*_FileList_*.csv" -File -ErrorAction SilentlyContinue
            foreach ($f in $filelistCsvs) {
                try {
                    $rows = Import-Csv -Path $f.FullName -ErrorAction Stop
                    foreach ($r in $rows) {
                        if (-not $r.RelativePath) { continue }
                        if (-not $masterMap.ContainsKey($r.RelativePath)) { $masterMap[$r.RelativePath] = @{ Length = if ($r.Length) { [int64]$r.Length } else { 0 }; LastWrite = $r.LastWriteTime } }
                    }
                    Append-Output ("Merged: {0} ({1} rows)" -f $f.Name, $rows.Count)
                } catch { Append-Output ("❌ Failed to merge {0}: {1}" -f $f.Name, $_.Exception.Message) }
            }
            try {
                $outRows = foreach ($k in $masterMap.Keys) { [pscustomobject]@{ RelativePath = $k; Length = $masterMap[$k].Length; LastWriteTime = $masterMap[$k].LastWrite } }
                if ($outRows) { $outRows | Export-Csv -Path $masterPath -NoTypeInformation -Encoding UTF8; Append-Output ("Master_FileList.csv updated: {0} ({1} unique files)" -f $masterPath, $outRows.Count) } else { Append-Output "Master_FileList.csv update skipped (no rows)." }
            } catch { Append-Output ("❌ Failed writing master: {0}" -f $_.Exception.Message) }
        }

        $summary = @(); $summary += "Total new discs created: $discCount"; $summary += "Skipped (already burned): $($skipped.Count)"; $summary += "Skipped (long paths): $($longPaths.Count)"
        $sPath = Join-Path $output ("Burn_Summary_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
        $summary | Set-Content -Path $sPath -Encoding UTF8
        Append-Output ("Summary saved: {0}" -f $sPath)
        Append-Output "Generate complete."
    } catch { Append-Output ("❌ Error during Generate: {0}" -f $_.Exception.Message) }
})

# ====================================================================
# Create IBB Projects button: write .ibb files for each Disc_*.txt (no launch)
# ====================================================================
$btnCreateIbb.Add_Click({
    Start-Sleep -Milliseconds 50
    $output = $textBoxes[1].Text.Trim()
    if ([string]::IsNullOrWhiteSpace($output) -or -not (Test-Path -LiteralPath $output)) { Append-Output "❌ Output folder not valid."; return }

    Append-Output "Starting Create IBB Projects (no burn)."
    $lists = Get-ChildItem -Path $output -Filter "Disc_*.txt" -File -ErrorAction SilentlyContinue | Sort-Object Name
    if ($lists.Count -eq 0) { Append-Output "No Disc_*.txt files found in output."; return }

    foreach ($list in $lists) {
        Append-Output ("Processing {0}" -f $list.Name)
        try {
            $raw = Get-Content -Path $list.FullName -ErrorAction Stop
            $folders = @()
            foreach ($line in $raw) {
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                $s = $line.Trim()
                if (Test-Path -LiteralPath $s -PathType Container) { $folders += (Get-Item -LiteralPath $s).FullName }
                elseif (Test-Path -LiteralPath $s -PathType Leaf) { $parent = Split-Path -LiteralPath $s -Parent; if ($parent -and (Test-Path -LiteralPath $parent -PathType Container)) { $folders += (Get-Item -LiteralPath $parent).FullName } }
                else { Append-Output ("  ❗ Source entry not found and skipped: {0}" -f $s) }
            }
            $folders = $folders | Select-Object -Unique
            if ($folders.Count -eq 0) { Append-Output ("Skipping {0} (no valid folders resolved)" -f $list.Name); continue }

            $base = [IO.Path]::GetFileNameWithoutExtension($list.Name)
            $projPath = Join-Path $output ("{0}.ibb" -f $base)
            $isoPath = Join-Path $output ("{0}.iso" -f $base)

            # Use folder entries only for project (no explicit root-file lines)
            $sourceEntries = $folders

            $created = Create-IbbProjectIni -SourcePaths $sourceEntries -ProjectPath $projPath -DestinationIso $isoPath -FileSystem 3 -PreserveFullPathnames:$false -RecurseSubdirectories:$true -VolumeLabelUdf $base
            if (-not $created) { Append-Output ("❌ Failed to create project for {0}" -f $list.Name); continue }
            Append-Output ("Project written: {0}" -f $projPath)
        } catch { Append-Output ("❌ Error processing {0}: {1}" -f $list.Name, $_.Exception.Message) }
    }
    Append-Output "Create IBB Projects complete."
})

# ====================================================================
# Burn IBB Projects button: sequential processing using Run-ImgBurnProjectSequential
# ====================================================================
$btnBurnIbb.Add_Click({
    Start-Sleep -Milliseconds 50
    $output = $textBoxes[1].Text.Trim(); $imgburn = $textBoxes[3].Text.Trim(); $dry = $chkDryRun.Checked
    if ([string]::IsNullOrWhiteSpace($output) -or -not (Test-Path -LiteralPath $output)) { Append-Output "❌ Output folder not valid."; return }

    Append-Output ("Starting Sequential Burn IBB Projects. DryRun={0}" -f $dry)
    $ibbs = Get-ChildItem -Path $output -Filter "*.ibb" -File -ErrorAction SilentlyContinue | Sort-Object Name
    if ($ibbs.Count -eq 0) { Append-Output "No .ibb project files found in output."; return }

    foreach ($p in $ibbs) {
        Append-Output ("Processing project: {0}" -f $p.Name)
        try {
            # Launch and wait for completion (sequential)
            $ok = Run-ImgBurnProjectSequential -ImgBurnExe $imgburn -ProjectPath $p.FullName -DryRun:$dry -PollIntervalSeconds 2 -WaitTimeoutSeconds 7200
            if (-not $ok) {
                Append-Output ("❌ Project failed or timed out: {0}. Aborting remaining projects." -f $p.FullName)
                break
            }
            Append-Output ("✅ Project completed: {0}" -f $p.Name)
            Start-Sleep -Seconds 1
        } catch { Append-Output ("❌ Error processing {0}: {1}" -f $p.Name, $_.Exception.Message); break }
    }
    Append-Output "Sequential Burn IBB Projects finished."
})

# Resize handler: keep controls responsive
# Replace existing Resize handler with this
$form.Add_Resize({
    # only resize textboxes and output area, do not reposition buttons
    $controlW = $form.ClientSize.Width - ($controlLeft + $browseW + $pad + ($spacing*2))
    if ($controlW -lt 300) { $controlW = 300 }
    foreach ($tb in $textBoxes) { $tb.Width = $controlW }
    $multiText.Width = $controlW - 220
    $outputBox.Width = $form.ClientSize.Width - ($pad*2)
    $outputBox.Height = $form.ClientSize.Height - $outputTop - 10

})


# Show UI
[void]$form.ShowDialog()
