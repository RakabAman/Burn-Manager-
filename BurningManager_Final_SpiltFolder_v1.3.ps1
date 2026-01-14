Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Add Win32 helper to get 8.3 short paths
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class ShortPathUtil {
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern uint GetShortPathName(string lpszLongPath, StringBuilder lpszShortPath, uint cchBuffer);

    public static string GetShortPath(string path) {
        if (string.IsNullOrEmpty(path)) return path;
        StringBuilder sb = new StringBuilder(260);
        uint ret = GetShortPathName(path, sb, (uint)sb.Capacity);
        if (ret == 0) return path;
        return sb.ToString();
    }
}
"@ -Language CSharpVersion3


# ====================================================================
# Burn Manager (complete, patched to support short paths + ANSI .ibb)
# ====================================================================

$form = New-Object System.Windows.Forms.Form
$form.Text = "Burn Manager - Sequential Burn (GiB + Settings + ShortPath)"
$form.Size = [System.Drawing.Size]::new(920,720)
$form.MinimumSize = [System.Drawing.Size]::new(760,520)
$form.StartPosition = "CenterScreen"

$pad = 8; $labelW = 180; $browseW = 90; $spacing = 6; $rowH = 44

# Input labels
$labels = @("Source Folder","Output Folder (IBB & lists)","Single Compare CSV (optional)","ImgBurn.exe (full path)")
$textBoxes = @(); $browseBtns = @()
for ($i=0; $i -lt $labels.Count; $i++) {
    $y = $pad + ($i * $rowH)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $labels[$i]; $lbl.Location = [System.Drawing.Point]::new($pad, $y + 10); $lbl.Size = [System.Drawing.Size]::new($labelW, 24)
    $form.Controls.Add($lbl)

    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Location = [System.Drawing.Point]::new($labelW + $pad + $spacing, $y + 6)
    $tb.Size = [System.Drawing.Size]::new(520, 26)
    $tb.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $form.Controls.Add($tb); $textBoxes += $tb

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "Browse"
    $btn.Location = [System.Drawing.Point]::new($labelW + $pad + $spacing + 530, $y + 4)
    $btn.Size = [System.Drawing.Size]::new($browseW, 28)
    $btn.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
    $form.Controls.Add($btn); $browseBtns += $btn
}

# Multi CSV selector
$multiLabel = New-Object System.Windows.Forms.Label
$multiLabel.Text = "Compare CSVs (multi-select)"; $multiLabel.Location = [System.Drawing.Point]::new($pad, $pad + ($labels.Count * $rowH) + 4); $multiLabel.Size = [System.Drawing.Size]::new($labelW, 28)
$form.Controls.Add($multiLabel)

$multiText = New-Object System.Windows.Forms.TextBox
$multiText.Location = [System.Drawing.Point]::new($labelW + $pad + $spacing, $pad + ($labels.Count * $rowH) + 2)
$multiText.Size = [System.Drawing.Size]::new(520, 26); $multiText.ReadOnly = $true
$multiText.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($multiText)

$multiBtn = New-Object System.Windows.Forms.Button
$multiBtn.Text = "Select CSVs"
$multiBtn.Location = [System.Drawing.Point]::new($labelW + $pad + $spacing + 530, $pad + ($labels.Count * $rowH) - 2)
$multiBtn.Size = [System.Drawing.Size]::new($browseW, 28)
$form.Controls.Add($multiBtn)

# Checkboxes
$chkWriteMaster = New-Object System.Windows.Forms.CheckBox
$chkWriteMaster.Text = "Write/update Master_FileList.csv in Output"
$chkWriteMaster.Location = [System.Drawing.Point]::new($labelW + $pad - 30, $pad + ($labels.Count * $rowH) + 36)
$chkWriteMaster.Size = [System.Drawing.Size]::new(360, 22); $chkWriteMaster.Checked = $true
$form.Controls.Add($chkWriteMaster)

$chkSkipLongPaths = New-Object System.Windows.Forms.CheckBox
$chkSkipLongPaths.Text = "Skip folders that contain files with long paths (optional)"
$chkSkipLongPaths.Location = [System.Drawing.Point]::new($labelW + $pad + 340, $pad + ($labels.Count * $rowH) + 36)
$chkSkipLongPaths.Size = [System.Drawing.Size]::new(420, 22); $chkSkipLongPaths.Checked = $true
$form.Controls.Add($chkSkipLongPaths)

# Disc size combo (silence returned indices)
$discY = $pad + ($labels.Count * $rowH) + 70
$lblDisc = New-Object System.Windows.Forms.Label
$lblDisc.Text = "Disc Size"; $lblDisc.Location = [System.Drawing.Point]::new($pad, $discY + 6); $lblDisc.Size = [System.Drawing.Size]::new($labelW - 80, 20)
$form.Controls.Add($lblDisc)

$comboDisc = New-Object System.Windows.Forms.ComboBox
$comboDisc.Location = [System.Drawing.Point]::new($labelW + $pad - 80, $discY + 4)
$comboDisc.Size = [System.Drawing.Size]::new(260, 26)
$comboDisc.DropDownStyle = "DropDownList"
[void]$comboDisc.Items.Add("BD-50 (50 GiB)")
[void]$comboDisc.Items.Add("BD-25 (25 GiB)")
[void]$comboDisc.Items.Add("BD-20 (20 GiB)")
[void]$comboDisc.Items.Add("DVD-4.37GiB (single-layer)")
[void]$comboDisc.Items.Add("DVD-DL ~7.90GiB (dual-layer)")
[void]$comboDisc.Items.Add("CD-700MB (700 MB)")
$comboDisc.SelectedIndex = 0
$form.Controls.Add($comboDisc)

# Other controls
$chkDryRun = New-Object System.Windows.Forms.CheckBox; $chkDryRun.Text = "Dry-Run (do not execute ImgBurn)"; $chkDryRun.Location = [System.Drawing.Point]::new($labelW + $pad + 10 , $discY + 6); $chkDryRun.Size = [System.Drawing.Size]::new(220, 22); $form.Controls.Add($chkDryRun)
$chkSplitOversize = New-Object System.Windows.Forms.CheckBox; $chkSplitOversize.Text = "Split oversize folders into file-level batches"; $chkSplitOversize.Location = [System.Drawing.Point]::new($labelW + $pad + 240, $discY + 6); $chkSplitOversize.Size = [System.Drawing.Size]::new(420, 22); $chkSplitOversize.Checked = $false; $form.Controls.Add($chkSplitOversize)

$chkAutoSaveLog = New-Object System.Windows.Forms.CheckBox
$chkAutoSaveLog.Text = "Auto-append log to output after actions"
$chkAutoSaveLog.Location = [System.Drawing.Point]::new($labelW + $pad + 240, $discY + 30)
$chkAutoSaveLog.Size = [System.Drawing.Size]::new(300, 22); $chkAutoSaveLog.Checked = $true
$form.Controls.Add($chkAutoSaveLog)

# NEW: Use 8.3 short paths option for ImgBurn compatibility
$chkUseShortPaths = New-Object System.Windows.Forms.CheckBox
$chkUseShortPaths.Text = "Use 8.3 short paths for ImgBurn (fallback for non-ANSI filenames)"
$chkUseShortPaths.Location = [System.Drawing.Point]::new($labelW + $pad - 30, $discY + 54)
$chkUseShortPaths.Size = [System.Drawing.Size]::new(520, 22)
$chkUseShortPaths.Checked = $false
$form.Controls.Add($chkUseShortPaths)

# Action buttons and output box
$btnW = 240; $btnH = 44
$buttonsY = $discY + 70

$btnGenerate = New-Object System.Windows.Forms.Button; $btnGenerate.Text = "Generate Burn Lists (Disc_*.txt)"; $btnGenerate.Size = [System.Drawing.Size]::new($btnW, $btnH); $btnGenerate.Location = [System.Drawing.Point]::new($pad + 20, $buttonsY); $form.Controls.Add($btnGenerate)
$btnCreateIbb = New-Object System.Windows.Forms.Button; $btnCreateIbb.Text = "Create IBB Projects (no burn)"; $btnCreateIbb.Size = [System.Drawing.Size]::new($btnW, $btnH); $btnCreateIbb.Location = [System.Drawing.Point]::new($pad + 40 + $btnW, $buttonsY); $form.Controls.Add($btnCreateIbb)
$btnBurnIbb = New-Object System.Windows.Forms.Button; $btnBurnIbb.Text = "Burn IBB Projects (sequential)"; $btnBurnIbb.Size = [System.Drawing.Size]::new($btnW, $btnH); $btnBurnIbb.Location = [System.Drawing.Point]::new($pad + 60 + ($btnW*2), $buttonsY); $form.Controls.Add($btnBurnIbb)

$outputTop = $buttonsY + $btnH + 12
$outputH = $form.ClientSize.Height - $outputTop - 20
if ($outputH -lt 220) { $outputH = 220 }

$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Multiline = $true; $outputBox.ScrollBars = "Vertical"
$outputBox.Location = [System.Drawing.Point]::new($pad, $outputTop)
$outputBox.Size = [System.Drawing.Size]::new($form.ClientSize.Width - ($pad*2), $outputH)
$outputBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$outputBox.ReadOnly = $true
$form.Controls.Add($outputBox)

# -------------------------
# Settings persistence (per output folder)
# -------------------------
function Get-SettingsPathForOutput { param([string]$OutputFolder) if (-not $OutputFolder) { return $null } return Join-Path $OutputFolder 'Settings.json' }
function Load-SettingsForOutput { param([string]$OutputFolder) $p = Get-SettingsPathForOutput -OutputFolder $OutputFolder; if (-not $p -or -not (Test-Path -LiteralPath $p)) { return @{} } try { return (Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return @{} } }
function Save-SettingsForOutput { param([string]$OutputFolder, [hashtable]$Settings) try { if (-not (Test-Path -LiteralPath $OutputFolder)) { New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null } $path = Get-SettingsPathForOutput -OutputFolder $OutputFolder; $Settings | ConvertTo-Json -Depth 4 | Set-Content -Path $path -Encoding UTF8 -Force; return $true } catch { return $false } }

# -------------------------
# Safe UI logging
# -------------------------
function Append-Output {
    param([Parameter(Mandatory=$true)][object]$Message)
    try {
        $s = [string]$Message
        $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $line = "[$now] $s"
        if ($global:outputBox -and $global:outputBox -is [System.Windows.Forms.TextBox]) {
            if ($global:outputBox.InvokeRequired) {
                $action = [System.Action]{ $global:outputBox.AppendText("$line`r`n") }
                $null = $global:outputBox.BeginInvoke($action)
            } else {
                $global:outputBox.AppendText("$line`r`n")
            }
        } else {
            Write-Host $line
        }
    } catch {
        Write-Host $Message
    }
}

function Save-LogAppend {
    param([System.Windows.Forms.TextBox]$OutputTextBox, [string]$OutputFolder, [string]$FileName = "BurnManager.log")
    try {
        if (-not $OutputTextBox) { throw "OutputTextBox required." }
        $folder = $OutputFolder
        if (-not $folder -or [string]::IsNullOrWhiteSpace($folder)) {
            if ($script:textBoxes -and $script:textBoxes.Count -ge 2 -and (Test-Path $script:textBoxes[1].Text)) { $folder = $script:textBoxes[1].Text.Trim() } else { $folder = [Environment]::GetFolderPath("Desktop") }
        }
        if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
        $path = Join-Path $folder $FileName
        $text = $OutputTextBox.Text; if ($null -eq $text) { $text = "" }
        $enc = [System.Text.Encoding]::UTF8
        [System.IO.File]::AppendAllText($path, $text + "`r`n", $enc)
        $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $OutputTextBox.AppendText("[$now] Log appended: $path`r`n")
        return $path
    } catch {
        $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        if ($OutputTextBox) { $OutputTextBox.AppendText("[$now] ❌ Failed to append log: $($_.Exception.Message)`r`n") }
        return $null
    }
}

# -------------------------
# Browse handlers & multi CSV
# -------------------------
$browseBtns[0].Add_Click({
    $f = New-Object Windows.Forms.FolderBrowserDialog
    if ($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $textBoxes[0].Text = $f.SelectedPath }
})
$browseBtns[1].Add_Click({
    $f = New-Object Windows.Forms.FolderBrowserDialog
    if ($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $textBoxes[1].Text = $f.SelectedPath
        # Load settings for this output folder (if present)
        $s = Load-SettingsForOutput -OutputFolder $textBoxes[1].Text.Trim()
        if ($s -and $s.LastDiscSelection) {
            for ($i=0; $i -lt $comboDisc.Items.Count; $i++) { if ($comboDisc.Items[$i] -like "$($s.LastDiscSelection)*") { $comboDisc.SelectedIndex = $i; break } }
            Append-Output ("Loaded settings from: {0}" -f (Get-SettingsPathForOutput -OutputFolder $textBoxes[1].Text.Trim()))
        }
    }
})
$browseBtns[2].Add_Click({
    $ofd = New-Object Windows.Forms.OpenFileDialog; $ofd.Filter = "CSV Files (*.csv)|*.csv"
    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $textBoxes[2].Text = $ofd.FileName }
})
$browseBtns[3].Add_Click({
    $ofd = New-Object Windows.Forms.OpenFileDialog; $ofd.Filter = "Executable Files (*.exe)|*.exe"
    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $textBoxes[3].Text = $ofd.FileName }
})
$multiCsvPaths = @()
$multiBtn.Add_Click({
    $ofd = New-Object Windows.Forms.OpenFileDialog; $ofd.Filter = "CSV Files (*.csv)|*.csv"; $ofd.Multiselect = $true
    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $multiCsvPaths = $ofd.FileNames; $multiText.Text = ($multiCsvPaths -join "; "); Append-Output ("Selected {0} CSV(s) for compare." -f $multiCsvPaths.Count) }
})

# -------------------------
# Run ImgBurn sequential helper
# -------------------------
function Run-ImgBurnProjectSequential {
    param([string]$ImgBurnExe,[string]$ProjectPath,[switch]$DryRun,[int]$PollIntervalSeconds=2,[int]$WaitTimeoutSeconds=3600)
    try {
        if ([string]::IsNullOrWhiteSpace($ProjectPath) -or -not (Test-Path -LiteralPath $ProjectPath)) { Append-Output ("❌ Project file not found: {0}" -f $ProjectPath); return $false }
        if ($DryRun) { Append-Output ("DRY-RUN -> Would open project: {0}" -f $ProjectPath); return $true }

        if (-not [string]::IsNullOrWhiteSpace($ImgBurnExe) -and (Test-Path -LiteralPath $ImgBurnExe)) {
            Append-Output ("Launching ImgBurn.exe with project: {0}" -f $ProjectPath)
            $quoted = '"' + ($ProjectPath -replace '"','\"') + '"'
            $psi = New-Object System.Diagnostics.ProcessStartInfo; $psi.FileName = $ImgBurnExe; $psi.Arguments = $quoted; $psi.WorkingDirectory = (Split-Path -Path $ProjectPath -Parent); $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
            $proc = [System.Diagnostics.Process]::Start($psi)
            if (-not $proc) { Append-Output "❌ Failed to start ImgBurn.exe"; return $false }
            $finished = $proc.WaitForExit($WaitTimeoutSeconds * 1000)
            if (-not $finished) { Append-Output ("⚠️ ImgBurn did not exit within {0} seconds for project {1}" -f $WaitTimeoutSeconds, $ProjectPath); try { $proc.Kill() } catch {}; return $false }
            Append-Output ("ImgBurn process exited (code {0}) for project {1}" -f $proc.ExitCode, $ProjectPath); return $true
        }

        Append-Output ("Shell-opening .ibb (fallback): {0}" -f $ProjectPath)
        Start-Process -FilePath $ProjectPath -WorkingDirectory (Split-Path -Path $ProjectPath -Parent) -ErrorAction Stop

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew(); $found = $false
        while ($stopwatch.Elapsed.TotalSeconds -lt $WaitTimeoutSeconds) { $procs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'ImgBurn' }; if ($procs -and $procs.Count -gt 0) { $found = $true; break } ; Start-Sleep -Seconds $PollIntervalSeconds }
        if (-not $found) { Append-Output ("⚠️ ImgBurn process did not start within {0} seconds after opening {1}" -f $WaitTimeoutSeconds, $ProjectPath); return $false }

        Append-Output "ImgBurn started; waiting for it to finish..."; $stopwatch.Restart()
        while ($stopwatch.Elapsed.TotalSeconds -lt $WaitTimeoutSeconds) { $procs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'ImgBurn' }; if (-not $procs -or $procs.Count -eq 0) { Append-Output "ImgBurn processes no longer present."; return $true } ; Start-Sleep -Seconds $PollIntervalSeconds }
        Append-Output ("⚠️ ImgBurn did not exit within {0} seconds after starting for project {1}" -f $WaitTimeoutSeconds, $ProjectPath); return $false
    } catch { Append-Output ("❌ Run-ImgBurnProjectSequential failed: {0}" -f $_.Exception.ToString()); return $false }
}

# -------------------------
# Compare & helper utilities
# -------------------------
function Build-CompareFolderSet {
    param([string[]]$paths,[string]$singlePath,[string]$SourceRoot)
    function Normalize-ToRelative { param([string]$p) if ([string]::IsNullOrWhiteSpace($p)) { return $null } try { if ($SourceRoot -and ($p -match '^[a-zA-Z]:\\' -or $p -like '\\*')) { try { $rel = [IO.Path]::GetRelativePath($SourceRoot,$p); if ($rel) { return $rel.TrimStart('\','/') } } catch {} } if (-not ($p -match '^[a-zA-Z]:\\' -or $p -like '\\*')) { return $p.TrimStart('\','/').Trim() } $full = $p.TrimEnd('\','/'); return $full } catch { return $null } }
    $relFolderSet = New-Object System.Collections.Generic.HashSet[string]; $relFileSet = New-Object System.Collections.Generic.HashSet[string]
    function Add-RelativeFolder { param([string]$r) if ($r) { [void]$relFolderSet.Add(($r.TrimEnd('\','/').ToLowerInvariant())) } }
    function Add-RelativeFile { param([string]$r) if (-not $r) { return } $norm = $r.TrimStart('\','/').ToLowerInvariant(); [void]$relFileSet.Add($norm); try { $parent = [System.IO.Path]::GetDirectoryName($norm); if ($parent) { [void]$relFolderSet.Add($parent) } } catch {} }
    if ($paths -and $paths.Count -gt 0) {
        foreach ($csv in $paths) {
            try {
                $rows = Import-Csv -Path $csv -ErrorAction Stop
                foreach ($r in $rows) {
                    if ($r.PSObject.Properties.Match('RelativePath').Count -gt 0 -and $r.RelativePath) { Add-RelativeFile -r $r.RelativePath.Trim(); continue }
                    if ($r.PSObject.Properties.Match('FullName').Count -gt 0 -and $r.FullName) { $rel = Normalize-ToRelative -p $r.FullName.Trim(); Add-RelativeFile -r $rel; continue }
                    foreach ($prop in $r.PSObject.Properties) { $val = $prop.Value; if (-not [string]::IsNullOrWhiteSpace($val)) { $rel = Normalize-ToRelative -p $val.Trim(); if ($rel) { Add-RelativeFile -r $rel; break } } }
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
                foreach ($prop in $r.PSObject.Properties) { $val = $prop.Value; if (-not [string]::IsNullOrWhiteSpace($val)) { $rel = Normalize-ToRelative -p $val.Trim(); if ($rel) { Add-RelativeFile -r $rel; break } } }
            }
            Append-Output ("Loaded single compare CSV: {0} ({1} rows)" -f (Split-Path $singlePath -Leaf), $rows.Count)
        } catch { Append-Output ("❌ Failed to load single CSV: {0}" -f $_.Exception.Message) }
    } else { Append-Output "No compare CSV(s) provided." }
    return @{ RelativeFolders = $relFolderSet; RelativeFiles = $relFileSet }
}

function Is-FolderConsideredBurned {
    param(
        [string]$folderPathAbsolute,
        [System.Collections.Generic.HashSet[string]]$relFolderSet,
        [System.Collections.Generic.HashSet[string]]$relFileSet,
        [string]$SourceRoot
    )

    if (-not $folderPathAbsolute) { return $false }

    try {
        $rel = $null
        try {
            $rel = [IO.Path]::GetRelativePath($SourceRoot, $folderPathAbsolute)
        } catch {
            if ($folderPathAbsolute.StartsWith($SourceRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                $rel = $folderPathAbsolute.Substring($SourceRoot.Length).TrimStart('\','/')
            } else {
                $rel = $folderPathAbsolute
            }
        }

        if (-not $rel) { return $false }

        $norm = $rel.TrimStart('\','/').TrimEnd('\','/').ToLowerInvariant()
    } catch {
        return $false
    }

    if ($relFolderSet.Contains($norm)) { return $true }

    $prefix = $norm + "\"

    foreach ($rf in $relFileSet) {
        if ($rf.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

# ---------------------------
# Safe list sanitization and .ibb creation (patched to optionally convert entries to short paths and write ANSI .ibb)
# ---------------------------
function Get-SafeListLines {
    param([Parameter(Mandatory=$true)][string]$ListFilePath,[int]$MaxSample=0)
    try { $raw = Get-Content -LiteralPath $ListFilePath -Raw -ErrorAction Stop -Encoding UTF8 } catch { try { $lines = Get-Content -LiteralPath $ListFilePath -ErrorAction Stop } catch { return @() } return $lines | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' } }
    if ($null -ne $raw -and $raw.Length -gt 0 -and $raw[0] -eq [char]65279) { $raw = $raw.Substring(1) }
    $lines = $raw -split "`r?`n"
    $out = @()
    foreach ($l in $lines) {
        if ($null -eq $l) { continue }
        $s = $l.Trim(); if ($s.Length -eq 0) { continue }
        if ($s.StartsWith('"') -and $s.EndsWith('"')) { $s = $s.Substring(1, $s.Length - 2) }
        if ($s.StartsWith("'") -and $s.EndsWith("'")) { $s = $s.Substring(1, $s.Length - 2) }
        $sb = New-Object System.Text.StringBuilder
        foreach ($ch in $s.ToCharArray()) { $code=[int][char]$ch; if (($code -ge 9 -and $code -le 126) -or $code -ge 160) { [void]$sb.Append($ch) } }
        $s2 = $sb.ToString().Trim(); if ($s2.Length -gt 0) { $out += $s2 }
    }
    if ($MaxSample -gt 0) { return $out | Select-Object -First $MaxSample }
    return $out
}

function Create-IBBProject {
    param([Parameter(Mandatory=$true)][string]$TxtPath,[Parameter(Mandatory=$true)][string]$SourceRoot,[Parameter(Mandatory=$true)][string]$OutputFolder)
    function SafeLog { param([string]$m) Append-Output $m }

    if (-not (Test-Path -LiteralPath $TxtPath)) { SafeLog "ERROR: list not found: $TxtPath"; return @{ Success = $false; Error = "TXT not found" } }

    try { $raw = Get-Content -LiteralPath $TxtPath -Raw -Encoding UTF8 -ErrorAction Stop } catch { try { $raw = (Get-Content -LiteralPath $TxtPath -Encoding Default -ErrorAction Stop) -join "`r`n" } catch { SafeLog "ERROR: cannot read $TxtPath"; return @{ Success = $false; Error = "Read failed" } } }
    if ($raw.Length -gt 0 -and $raw[0] -eq [char]65279) { $raw = $raw.Substring(1) }
    $lines = $raw -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    if (-not $lines -or $lines.Count -eq 0) { SafeLog "ERROR: empty list"; return @{ Success = $false; Error = "Empty list" } }

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($TxtPath)
    if (-not (Test-Path -LiteralPath $OutputFolder)) { New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null }
    $ibbPath = Join-Path $OutputFolder ("{0}.ibb" -f $baseName)

    $opts = @(
        "IBB","",
        "[START_BACKUP_OPTIONS]",
        "BuildInputMode=1","BuildOutputMode=1","Destination=0","TestMode=0","Verify=1","WriteSpeed=0","Copies=0","DataType=0","FileSystem=3",
        "UDFRevision=0","PreserveFullPathnames=0","RecurseSubdirectories=1","IncludeHiddenFiles=1","IncludeSystemFiles=0","IncludeArchiveFilesOnly=0",
        "AddToWriteQueueWhenDone=0","ClearArchiveAttribute=0","VolumeLabel_ISO9660=","VolumeLabel_Joliet=",("VolumeLabel_UDF={0}" -f $baseName),
        "Identifier_System=","Identifier_VolumeSet=","Identifier_Publisher=","Identifier_Preparer=","Identifier_Application=",
        "Dates_FolderFileType=0","Restrictions_ISO9660_InterchangeLevel=0","Restrictions_ISO9660_CharacterSet=0",
        "Restrictions_ISO9660_AllowMoreThan8DirectoryLevels=0","Restrictions_ISO9660_AllowMoreThan255CharactersInPath=0",
        "Restrictions_ISO9660_AllowFilesWithoutExtensions=0","Restrictions_ISO9660_AllowFilesExceedingSizeLimit=0","Restrictions_ISO9660_DontAddVersionNumberToFiles=0",
        "Restrictions_Joliet_InterchangeLevel=0","Restrictions_Joliet_AllowFilesWithoutExtensions=0","Restrictions_Joliet_AddVersionNumberToFiles=0",
        "Restrictions_UDF_DisableUnicodeSupport=0","Restrictions_UDF_DVDVideoDontDisableUnicodeSupport=0","Restrictions_UDF_DVDVideoDontDisableUnicodeSupport_SF=0",
        "Restrictions_UDF_HDDVDVideoDontDisableUnicodeSupport=0","Restrictions_UDF_HDDVDVideoDontDisableUnicodeSupport_SF=0",
        "Restrictions_UDF_BDVideoDontDisableUnicodeSupport=0","Restrictions_UDF_BDVideoDontDisableUnicodeSupport_SF=0",
        "Restrictions_UDF_DVDVideoAllowUnicodeVolumeLabel=0","Restrictions_UDF_HDDVDVideoAllowUnicodeVolumeLabel=0","Restrictions_UDF_BDVideoAllowUnicodeVolumeLabel=0",
        "Restrictions_UDF_AllowNonCompliantFileCreationDates=0","BootableDisc_MakeImageBootable=0",
        "[END_BACKUP_OPTIONS]","", "[START_BACKUP_LIST]"
    )

    $listEntries = New-Object System.Collections.Generic.List[string]
    foreach ($rawLine in $lines) {
        $p = $rawLine.Trim()
        if (-not ($p -match '^[A-Za-z]:\\' -or $p -match '^\\\\') -and $SourceRoot) { $p = Join-Path $SourceRoot $p }
        if (Test-Path -LiteralPath $p -PathType Container) { if ($p[-1] -ne '\') { $p = $p + '\' } }
        $listEntries.Add($p)
    }

    # Optionally convert list entries to 8.3 short paths for ImgBurn compatibility
    $useShort = $false
    try { $useShort = ($global:chkUseShortPaths -and $global:chkUseShortPaths.Checked) } catch { $useShort = $false }

    $listEntriesFinal = New-Object System.Collections.Generic.List[string]
    foreach ($entry in $listEntries) {
        $ent = $entry
        if ($useShort) {
            try {
                $short = [Win32.ShortPathUtil]::GetShortPath($ent)
                if ($short -and $short.Length -gt 0) {
                    if ($short -ne $ent) { Append-Output ("Converted to short path: {0} -> {1}" -f $ent, $short) }
                    $ent = $short
                }
            } catch {
                Append-Output ("⚠️ Short-path conversion failed for: {0} ; using original path." -f $ent)
            }
        }
        $listEntriesFinal.Add($ent)
    }

    $footer = @("[END_BACKUP_LIST]")

    $all = @(); $all += $opts; $all += $listEntriesFinal; $all += $footer

    try {
        # Write .ibb using system ANSI encoding (Encoding.Default) so legacy ImgBurn interprets bytes in local codepage
        $enc = [System.Text.Encoding]::Default
        [System.IO.File]::WriteAllLines($ibbPath, $all, $enc)
        SafeLog ("Wrote legacy .ibb: {0} (entries: {1})" -f $ibbPath, $listEntriesFinal.Count)
        return @{ Success = $true; IbbPath = $ibbPath; ItemCount = $listEntriesFinal.Count }
    } catch {
        SafeLog ("ERROR writing legacy .ibb: $($_.Exception.Message)")
        return @{ Success = $false; Error = $_.Exception.Message; Exception = $_.Exception }
    }
}

# -------------------------
# Create IBB Projects handler
# -------------------------
$btnCreateIbb.Add_Click({
    Start-Sleep -Milliseconds 50
    $output = $textBoxes[1].Text.Trim(); $source = $textBoxes[0].Text.Trim()
    if ([string]::IsNullOrWhiteSpace($output) -or -not (Test-Path -LiteralPath $output)) { Append-Output "❌ Output folder not valid for Create IBB Projects."; return }
    if ([string]::IsNullOrWhiteSpace($source) -or -not (Test-Path -LiteralPath $source)) { Append-Output "❌ Source folder not valid for Create IBB Projects."; return }
    Append-Output ("Starting Create IBB Projects (safe mode).")
    try {
        $lists = Get-ChildItem -LiteralPath $output -Filter "Disc_*_*.txt" -File -ErrorAction SilentlyContinue | Sort-Object Name
        if (-not $lists -or $lists.Count -eq 0) { Append-Output "No Disc_*.txt lists found to process."; return }
        foreach ($list in $lists) {
            Append-Output ("Processing {0}" -f $list.Name)
            $sample = Get-SafeListLines -ListFilePath $list.FullName -MaxSample 20
            foreach ($s in $sample) { if ($s -match '^\s*(if|for|while|switch|function|param|exit)\b') { Append-Output ("⚠️ Sample line starts with script keyword (treated as data): {0}" -f $s) } }
            try {
                $res = Create-IBBProject -TxtPath $list.FullName -SourceRoot $source -OutputFolder $output
                if ($null -eq $res) { Append-Output ("❌ Error processing {0}: Create-IBBProject returned null." -f $list.Name); continue }
                if ($res.Success -eq $true) { Append-Output ("Project written: {0}" -f $res.IbbPath) }
                else { $err = $res.Error; Append-Output ("❌ Error processing {0}: {1}" -f $list.Name, $err); if ($res.Exception) { Append-Output ("Exception Type: {0}" -f $res.Exception.GetType().FullName); Append-Output ("StackTrace: {0}" -f $res.Exception.StackTrace) } }
            } catch {
                Append-Output ("❌ Exception while processing {0}: {1}" -f $list.Name, $_.Exception.Message)
            }
        }
        Append-Output "Create IBB Projects complete."
        # Save LastDiscSelection into Settings.json
        try {
            $settings = @{ LastDiscSelection = $comboDisc.SelectedItem; LastUsedTimestamp = (Get-Date).ToString("o") }
            Save-SettingsForOutput -OutputFolder $output -Settings $settings | Out-Null
            Append-Output ("Saved settings to {0}" -f (Get-SettingsPathForOutput -OutputFolder $output))
        } catch { Append-Output ("Failed to save settings: {0}" -f $_.Exception.Message) }
    } catch { Append-Output ("❌ Error in Create IBB Projects handler: {0}" -f $_.Exception.Message) } finally { if ($chkAutoSaveLog -and $chkAutoSaveLog.Checked) { Save-LogAppend -OutputTextBox $outputBox -OutputFolder $output -FileName "BurnManager.log" } }
})

# -------------------------
# Generate handler (robust)
# -------------------------
$btnGenerate.Add_Click({
    Start-Sleep -Milliseconds 50
    $source = $textBoxes[0].Text.Trim(); $output = $textBoxes[1].Text.Trim(); $singleCompare = $textBoxes[2].Text.Trim()
    if ([string]::IsNullOrWhiteSpace($source) -or -not (Test-Path -LiteralPath $source)) { Append-Output "❌ Source folder not valid."; return }
    if ([string]::IsNullOrWhiteSpace($output) -or -not (Test-Path -LiteralPath $output)) { Append-Output "❌ Output folder not valid."; return }
    if (-not $comboDisc.SelectedItem) { Append-Output "❌ No disc size selected. Choose a disc size."; return }

    $selected = $comboDisc.SelectedItem -as [string]; $sel = if ($selected) { $selected.ToLowerInvariant() } else { '' }
    switch ($true) {
        { $sel -like '*bd-50*' } { $discSizeLabel = 'BD-50'; $discSizeBytes = [int64](50 * 1GB); break }
        { $sel -like '*bd-25*' } { $discSizeLabel = 'BD-25'; $discSizeBytes = [int64](25 * 1GB); break }
        { $sel -like '*bd-20*' } { $discSizeLabel = 'BD-20'; $discSizeBytes = [int64](20 * 1GB); break }
        { $sel -like '*dvd-4.37*' -or $sel -like '*single-layer*' -or $sel -like '*4.37*' } { $discSizeLabel = 'DVD-4.37GiB'; $discSizeBytes = [int64](4.37 * 1GB); break }
        { $sel -like '*dvd-dl*' -or $sel -like '*dual-layer*' -or $sel -like '*7.90*' } { $discSizeLabel = 'DVD-DL-~7.90GiB'; $discSizeBytes = [int64](7.90 * 1GB); break }
        { $sel -like '*cd-700*' -or $sel -like '*700mb*' } { $discSizeLabel = 'CD-700MB'; $discSizeBytes = [int64](700 * 1MB); break }
        default { Append-Output ("⚠️ Unknown disc selection '{0}' — defaulting to BD-50" -f $selected); $discSizeLabel = 'BD-50'; $discSizeBytes = [int64](50 * 1GB); break }
    }

    if (-not $discSizeBytes -or ([int64]$discSizeBytes -le 0)) { Append-Output ("❌ Disc size mapping failed for selection '{0}'. Aborting Generate." -f $selected); return }
    if ($discSizeBytes -ge 1GB) { $discSizeHuman = "{0} GiB" -f [math]::Round($discSizeBytes / 1GB, 2) } elseif ($discSizeBytes -ge 1MB) { $discSizeHuman = "{0} MB" -f [math]::Round($discSizeBytes / 1MB, 1) } else { $discSizeHuman = "{0} bytes" -f $discSizeBytes }
    Append-Output ("Starting Generate (disc size: {0} - {1}) - Output: {2}" -f $discSizeLabel, $discSizeHuman, $output)

    $compareData = Build-CompareFolderSet -paths $multiCsvPaths -singlePath $singleCompare -SourceRoot $source
    $compareFolders = $compareData.RelativeFolders; $compareFiles = $compareData.RelativeFiles

    $maxPath = 240; $skipLongPaths = $chkSkipLongPaths.Checked; $splitOversize = $chkSplitOversize.Checked
    $maxAllowedDiscs = 500; $createdDiscs = 0

    try {
        $existingLists = Get-ChildItem -Path $output -Filter "Disc_*_*.txt" -File -ErrorAction SilentlyContinue
        $lastDiscNum = 0
        foreach ($f in $existingLists) { if ($f.BaseName -match '^Disc_(\d+)') { try { $n = [int]$matches[1] } catch { $n = 0 }; if ($n -gt $lastDiscNum) { $lastDiscNum = $n } } }
        $batchIdx = $lastDiscNum + 1
        $currentSize = 0; $currentBatch = @(); $skipped = @(); $longPaths = @(); $discCount = 0

        $subfolders = Get-ChildItem -Path $source -Directory -ErrorAction Stop | Sort-Object Name

        foreach ($fd in $subfolders) {
            if ($createdDiscs -ge $maxAllowedDiscs) { Append-Output ("❌ Created discs would exceed safety cap ({0}). Aborting." -f $maxAllowedDiscs); break }

            if (Is-FolderConsideredBurned -folderPathAbsolute $fd.FullName -relFolderSet $compareFolders -relFileSet $compareFiles -SourceRoot $source) {
                $skipped += $fd.FullName; Append-Output ("Skipping (already burned): {0}" -f $fd.FullName); continue
            }

            if ($skipLongPaths) {
                $tooLong = Get-ChildItem -Path $fd.FullName -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName.Length -gt $maxPath }
                if ($tooLong -and $tooLong.Count -gt 0) { $longPaths += $fd.FullName; Append-Output ("Skipping (long path detected): {0}" -f $fd.FullName); continue }
            }

            $size = 0
            try { $size = (Get-ChildItem -Path $fd.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Prop Length -Sum).Sum } catch { $size = 0 }
            if (-not $size) { $size = 0 }

            if ($splitOversize -and $size -gt $discSizeBytes) {
                # ---- Robust file-level splitting loop (drop-in replacement) ----
Append-Output ("Oversize folder detected, splitting into file-level batches: {0}" -f $fd.FullName)
$files = Get-ChildItem -Path $fd.FullName -Recurse -File -ErrorAction SilentlyContinue | Sort-Object FullName
$fileBatch = New-Object System.Collections.Generic.List[object]
$fileSize = 0L

foreach ($f in $files) {
    $fLen = 0L
    try { $fLen = [int64]$f.Length } catch { $fLen = 0L }

    # If the single file is larger than the disc capacity, write it alone (warn)
    if ($fLen -ge $discSizeBytes) {
        Append-Output ("⚠️ File larger than disc capacity; writing as single-disc item: {0} ({1} bytes)" -f $f.FullName, $fLen)

        # Flush any existing batch first
        if ($fileBatch.Count -gt 0) {
            $ts = Get-Date -Format "yyyyMMdd_HHmmss"
            $listName = "Disc_{0}_{1}.txt" -f $batchIdx, $ts
            $csvName  = "Disc_{0}_FileList_{1}.csv" -f $batchIdx, $ts
            $listPath = Join-Path $output $listName
            $csvPath  = Join-Path $output $csvName

            $fileBatch | ForEach-Object { $_.FullName } | Set-Content -Path $listPath -Encoding UTF8

            $inv = foreach ($fb in $fileBatch) {
                try { $rel = [IO.Path]::GetRelativePath($source, $fb.FullName) } catch { if ($fb.FullName.StartsWith($source,[System.StringComparison]::OrdinalIgnoreCase)) { $rel = $fb.FullName.Substring($source.Length).TrimStart('\','/') } else { $rel = $fb.FullName } }
                [pscustomobject]@{ FullName = $fb.FullName; RelativePath = $rel; Length = $fb.Length; LastWriteTime = $fb.LastWriteTime.ToString("o") }
            }
            if ($inv.Count -gt 0) { $inv | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 }

            Append-Output ("Created oversize split burn list + CSV (flush): {0}, {1}" -f $listName, $csvName)
            $batchIdx++; $discCount++; $createdDiscs++
            $fileBatch.Clear(); $fileSize = 0L

            if ($createdDiscs -ge $maxAllowedDiscs) { break }
        }

        # Now write the large file as its own disc entry
        $ts = Get-Date -Format "yyyyMMdd_HHmmss"
        $listName = "Disc_{0}_{1}.txt" -f $batchIdx, $ts
        $csvName  = "Disc_{0}_FileList_{1}.csv" -f $batchIdx, $ts
        $listPath = Join-Path $output $listName
        $csvPath  = Join-Path $output $csvName

        @($f.FullName) | Set-Content -Path $listPath -Encoding UTF8

        $inv = [pscustomobject]@{
            FullName     = $f.FullName
            RelativePath = (try { [IO.Path]::GetRelativePath($source, $f.FullName) } catch { if ($f.FullName.StartsWith($source,[System.StringComparison]::OrdinalIgnoreCase)) { $f.FullName.Substring($source.Length).TrimStart('\','/') } else { $f.FullName } })
            Length       = $f.Length
            LastWriteTime= $f.LastWriteTime.ToString("o")
        }
        $inv | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

        Append-Output ("Created single-file oversized burn list + CSV: {0}, {1}" -f $listName, $csvName)
        $batchIdx++; $discCount++; $createdDiscs++

        if ($createdDiscs -ge $maxAllowedDiscs) { break }
        continue
    }

    # Normal add: check if adding this file would exceed capacity.
    # We allow equality (fileSize + fLen) -le discSizeBytes to include files that exactly fill a disc.
    if (($fileSize + $fLen) -gt $discSizeBytes -and $fileBatch.Count -gt 0) {
        # flush current file batch
        $ts = Get-Date -Format "yyyyMMdd_HHmmss"
        $listName = "Disc_{0}_{1}.txt" -f $batchIdx, $ts
        $csvName  = "Disc_{0}_FileList_{1}.csv" -f $batchIdx, $ts
        $listPath = Join-Path $output $listName
        $csvPath  = Join-Path $output $csvName

        $fileBatch | ForEach-Object { $_.FullName } | Set-Content -Path $listPath -Encoding UTF8

        $inv = foreach ($fb in $fileBatch) {
            try { $rel = [IO.Path]::GetRelativePath($source, $fb.FullName) } catch { if ($fb.FullName.StartsWith($source,[System.StringComparison]::OrdinalIgnoreCase)) { $rel = $fb.FullName.Substring($source.Length).TrimStart('\','/') } else { $rel = $fb.FullName } }
            [pscustomobject]@{ FullName = $fb.FullName; RelativePath = $rel; Length = $fb.Length; LastWriteTime = $fb.LastWriteTime.ToString("o") }
        }
        if ($inv.Count -gt 0) { $inv | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 }

        Append-Output ("Created oversize split burn list + CSV: {0}, {1}" -f $listName, $csvName)
        $batchIdx++; $discCount++; $createdDiscs++; $fileBatch.Clear(); $fileSize = 0L

        if ($createdDiscs -ge $maxAllowedDiscs) { break }
    }

    # Add current file into batch
    $fileBatch.Add($f)
    $fileSize += $fLen
}

# After loop: flush remaining files in fileBatch if any
if ($fileBatch.Count -gt 0 -and $createdDiscs -lt $maxAllowedDiscs) {
    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $listName = "Disc_{0}_{1}.txt" -f $batchIdx, $ts
    $csvName  = "Disc_{0}_FileList_{1}.csv" -f $batchIdx, $ts
    $listPath = Join-Path $output $listName
    $csvPath  = Join-Path $output $csvName

    $fileBatch | ForEach-Object { $_.FullName } | Set-Content -Path $listPath -Encoding UTF8

    $inv = foreach ($fb in $fileBatch) {
        try { $rel = [IO.Path]::GetRelativePath($source, $fb.FullName) } catch { if ($fb.FullName.StartsWith($source,[System.StringComparison]::OrdinalIgnoreCase)) { $rel = $fb.FullName.Substring($source.Length).TrimStart('\','/') } else { $rel = $fb.FullName } }
        [pscustomobject]@{ FullName = $fb.FullName; RelativePath = $rel; Length = $fb.Length; LastWriteTime = $fb.LastWriteTime.ToString("o") }
    }
    if ($inv.Count -gt 0) { $inv | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 }

    Append-Output ("Created oversize split burn list + CSV: {0}, {1}" -f $listName, $csvName)
    $batchIdx++; $discCount++; $createdDiscs++
    $fileBatch.Clear(); $fileSize = 0L
}
# ---- End replacement ----

            }

            if (($currentSize + $size) -gt $discSizeBytes -and $currentBatch.Count -gt 0) {
                $ts = Get-Date -Format "yyyyMMdd_HHmmss"
                $listName = "Disc_{0}_{1}.txt" -f $batchIdx, $ts; $csvName = "Disc_{0}_FileList_{1}.csv" -f $batchIdx, $ts
                $listPath = Join-Path $output $listName; $csvPath = Join-Path $output $csvName

                $currentBatch | ForEach-Object { $_.FullName } | Set-Content -Path $listPath -Encoding UTF8
                $inv = @()
                foreach ($b in $currentBatch) {
                    $files = Get-ChildItem -Path $b.FullName -Recurse -File -ErrorAction SilentlyContinue
                    foreach ($f in $files) {
                        try { $rel = [IO.Path]::GetRelativePath($source, $f.FullName) } catch { if ($f.FullName.StartsWith($source,[System.StringComparison]::OrdinalIgnoreCase)) { $rel = $f.FullName.Substring($source.Length).TrimStart('\','/') } else { $rel = $f.FullName } }
                        $inv += [pscustomobject]@{ FullName = $f.FullName; RelativePath = $rel; Length = $f.Length; LastWriteTime = $f.LastWriteTime.ToString("o") }
                    }
                }
                if ($inv.Count -gt 0) { $inv | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 }
                Append-Output ("Created burn list + CSV: {0}, {1}" -f $listName, $csvName)
                $batchIdx++; $discCount++; $createdDiscs++; $currentBatch = @(); $currentSize = 0
                if ($createdDiscs -ge $maxAllowedDiscs) { break }
            }

            $currentBatch += $fd; $currentSize += $size
        }

        if ($currentBatch.Count -gt 0 -and $createdDiscs -lt $maxAllowedDiscs) {
            $ts = Get-Date -Format "yyyyMMdd_HHmmss"
            $listName = "Disc_{0}_{1}.txt" -f $batchIdx, $ts; $csvName = "Disc_{0}_FileList_{1}.csv" -f $batchIdx, $ts
            $listPath = Join-Path $output $listName; $csvPath = Join-Path $output $csvName
            $currentBatch | ForEach-Object { $_.FullName } | Set-Content -Path $listPath -Encoding UTF8
            $inv = @()
            foreach ($b in $currentBatch) {
                $files = Get-ChildItem -Path $b.FullName -Recurse -File -ErrorAction SilentlyContinue
                foreach ($f in $files) {
                    try { $rel = [IO.Path]::GetRelativePath($source, $f.FullName) } catch { if ($f.FullName.StartsWith($source,[System.StringComparison]::OrdinalIgnoreCase)) { $rel = $f.FullName.Substring($source.Length).TrimStart('\','/') } else { $rel = $f.FullName } }
                    $inv += [pscustomobject]@{ FullName = $f.FullName; RelativePath = $rel; Length = $f.Length; LastWriteTime = $f.LastWriteTime.ToString("o") }
                }
            }
            if ($inv.Count -gt 0) { $inv | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 }
            Append-Output ("Created burn list + CSV: {0}, {1}" -f $listName, $csvName)
            $discCount++; $createdDiscs++
        }

        try {
            if ($chkWriteMaster.Checked) {
                $masterPath = Join-Path $output "Master_FileList.csv"
                $filelistCsvs = Get-ChildItem -Path $output -Filter "*_FileList_*.csv" -File -ErrorAction SilentlyContinue
                if ($filelistCsvs -and $filelistCsvs.Count -gt 0) {
                    $masterMap = @{}
                    foreach ($f in $filelistCsvs) {
                        try {
                            Import-Csv -Path $f.FullName -ErrorAction Stop | ForEach-Object {
                                $rel = $_.RelativePath; if (-not $rel) { return }
                                if (-not $masterMap.ContainsKey($rel)) {
                                    $len = 0; if ($_.Length) { try { $len = [int64]$_.Length } catch { $len = 0 } }
                                    $masterMap[$rel] = @{ Length = $len; LastWrite = $_.LastWriteTime }
                                }
                            }
                            Append-Output ("Merged CSV: {0}" -f $f.Name)
                        } catch { Append-Output ("⚠️ Failed to read CSV {0}: {1}" -f $f.Name, $_.Exception.Message) }
                    }
                    $outRows = foreach ($k in $masterMap.Keys) { [pscustomobject]@{ RelativePath = $k; Length = $masterMap[$k].Length; LastWriteTime = $masterMap[$k].LastWrite } }
                    if ($outRows) { $outRows | Export-Csv -Path $masterPath -NoTypeInformation -Encoding UTF8; Append-Output ("Master_FileList.csv written: {0} ({1} entries)" -f $masterPath, $outRows.Count) } else { Append-Output "Master_FileList.csv not written (no rows collected)." }
                } else { Append-Output "No per-disc filelist CSVs found; Master_FileList.csv not created." }
            } else { Append-Output "Master_FileList.csv creation skipped (checkbox unchecked)." }
        } catch { Append-Output ("❌ Error creating Master_FileList.csv: {0}" -f $_.Exception.Message) }

        Append-Output ("Generate complete. New discs created: {0}. Skipped (already burned): {1}. Skipped (long paths): {2}" -f $discCount, $skipped.Count, $longPaths.Count)
    } catch { Append-Output ("❌ Error during Generate: {0}" -f $_.Exception.Message) }

    if ($chkAutoSaveLog -and $chkAutoSaveLog.Checked) { Save-LogAppend -OutputTextBox $outputBox -OutputFolder $output -FileName "BurnManager.log" }
})

# -------------------------
# Burn handler (sequential)
# -------------------------
$btnBurnIbb.Add_Click({
    Start-Sleep -Milliseconds 50
    $output = $textBoxes[1].Text.Trim(); $imgburn = $textBoxes[3].Text.Trim(); $dry = $chkDryRun.Checked
    if ([string]::IsNullOrWhiteSpace($output) -or -not (Test-Path -LiteralPath $output)) { Append-Output "❌ Output folder not valid."; return }
    Append-Output ("Starting Sequential Burn IBB Projects. DryRun={0}" -f $dry)
    $ibbs = Get-ChildItem -Path $output -Filter "*.ibb" -File -ErrorAction SilentlyContinue | Sort-Object Name
    if (-not $ibbs -or $ibbs.Count -eq 0) { Append-Output "No .ibb project files found in output."; return }
    foreach ($p in $ibbs) {
        Append-Output ("Processing project: {0}" -f $p.Name)
        try {
            $ok = Run-ImgBurnProjectSequential -ImgBurnExe $imgburn -ProjectPath $p.FullName -DryRun:$dry -PollIntervalSeconds 2 -WaitTimeoutSeconds 7200
            if (-not $ok) { Append-Output ("❌ Project failed or timed out: {0}. Aborting remaining projects." -f $p.FullName); break }
            Append-Output ("✅ Project completed: {0}" -f $p.Name); Start-Sleep -Seconds 1
        } catch { Append-Output ("❌ Error processing {0}: {1}" -f $p.Name, $_.Exception.Message); break }
    }
    Append-Output "Sequential Burn IBB Projects finished."
    if ($chkAutoSaveLog -and $chkAutoSaveLog.Checked) { Save-LogAppend -OutputTextBox $outputBox -OutputFolder $textBoxes[1].Text.Trim() -FileName "BurnManager.log" }
})

# Persist selection on form closing
$form.Add_FormClosing({
    try {
        $output = $textBoxes[1].Text.Trim()
        if ($output -and (Test-Path -LiteralPath $output)) {
            $settings = @{ LastDiscSelection = $comboDisc.SelectedItem; LastUsedTimestamp = (Get-Date).ToString("o") }
            Save-SettingsForOutput -OutputFolder $output -Settings $settings | Out-Null
            Append-Output ("Saved settings to {0}" -f (Get-SettingsPathForOutput -OutputFolder $output))
        }
    } catch { }
})

# Resize handler
$form.Add_Resize({
    $controlLeft = $labelW + $pad + $spacing
    $controlW = $form.ClientSize.Width - ($controlLeft + $browseW + $pad + ($spacing*2))
    if ($controlW -lt 360) { $controlW = 360 }
    foreach ($tb in $textBoxes) { $tb.Width = $controlW }
    $multiText.Width = $controlW
    $outputBox.Width = $form.ClientSize.Width - ($pad*2)
    $outputBox.Height = $form.ClientSize.Height - $outputTop - 20
})

# Show UI
[void]$form.ShowDialog()
