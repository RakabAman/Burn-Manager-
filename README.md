# Burn Manager – Sequential Disc Burn Utility

A Windows PowerShell GUI tool designed to streamline sequential disc burning workflows with **ImgBurn**.  
This utility provides a user-friendly interface for generating burn lists, creating `.ibb` project files, and executing sequential burns with advanced options for compatibility and automation.

---

## ✨ Features

- **Graphical Interface** built with Windows Forms for easy navigation.
- **Disc Size Presets**: BD-50, BD-25, BD-20, DVD (SL/DL), CD.
- **CSV Compare Integration**:
  - Supports single or multiple CSVs for selective burning.
  - Automatically detects previously burned folders/files.
- **ImgBurn Project Handling**:
  - Generate `.ibb` projects with safe ANSI encoding.
  - Optionally run ImgBurn sequentially with process monitoring.
- **Short Path Support**:
  - Convert file/folder entries to 8.3 short paths for legacy ImgBurn compatibility.
- **Persistent Settings**:
  - Saves per-output-folder settings in `Settings.json`.
- **Logging**:
  - Real-time log output in the GUI.
  - Auto-append logs to output folder.
- **Safety Options**:
  - Dry-run mode (no ImgBurn execution).
  - Skip long-path folders.
  - Split oversize folders into file-level batches.

---

## 📦 Requirements

- Windows with PowerShell 5+  
- [ImgBurn](https://www.imgburn.com/) installed  
- .NET Framework (for Windows Forms and System.Drawing assemblies)

---

## 🚀 Usage

1. Launch the script in PowerShell:
   ```powershell
   .\BurnManager.ps1
