# VeriHash

VeriHash is a PowerShell 7+ tool for computing and verifying SHA256 file hashes.

🔁 PowerShell 7 is a modern, open-source, *cross-platform* edition of PowerShell. 
🛟 It can be safely installed alongside the built-in Windows PowerShell without causing conflicts.

**Note:** PowerShell 7 (also known as PowerShell Core) is different from the older Windows PowerShell (version 5.1) that comes pre-installed with Windows 10/11. 

## Why PowerShell 7?

- 🔁 **Modern and Cross-Platform:** PowerShell 7 runs on Windows, macOS, and Linux, making VeriHash more widely usable.
- 🧑‍💻 **Active Development:** PowerShell 7 receives regular updates, performance improvements, and new features.
- 🛟 **No Conflict with Windows PowerShell:** Installing PowerShell 7 does not remove or break the existing Windows PowerShell. Both can coexist, allowing you to explore this tool without losing any native capabilities.

If you're new to PowerShell 7, here are some quick pointers:

1. **Installation is Simple:**
   On Windows, you can install PowerShell 7 from the [Microsoft Store](https://aka.ms/PSWindows) or download the installer from the [official GitHub releases page](https://github.com/PowerShell/PowerShell/releases). 
   On macOS or Linux, you can follow the straightforward instructions provided in the [PowerShell Documentation](https://docs.microsoft.com/powershell/).

2. **Running VeriHash with PowerShell 7:** 
   After installing PowerShell 7, open a **PowerShell 7 console** (often listed as `pwsh` on Windows). Navigate to the directory containing `VeriHash.ps1` and run:
   
   ```powershell
   .\VeriHash.ps1
   ```
   
3. **Secure:** 
   PowerShell 7 supports execution policies and script signing, just like the older Windows PowerShell. You remain in control of what scripts you run. VeriHash itself is a simple hashing tool with transparent source code, allowing you to inspect it before running if you like.

## Features

- **SHA256 Hashing:** Compute SHA256 hashes for any file.
- **Verification from `.sha2_256`:** Verify files using automatically generated `.sha2_256` files.
- **Input Hash Comparison:** Compare a computed hash against a provided input hash.
- **Interactive File Selection (Windows):** If no file is given, easily select one via a file dialog.
- **Progress Display:** For larger files, see a progress bar while verifying hashes.

## Requirements

- **PowerShell 7+** is required to run VeriHash.
- Works on Windows and non-Windows platforms. On non-Windows, you'll be prompted to enter a file path manually instead of using a dialog.

## Execution Policy (Optional)
- On some Windows systems, you may need to allow running this script. In PowerShell 7, run:
  ```bash
  Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```
This command allows locally created scripts like VeriHash to run without being blocked while still maintaining some security. You can always revert this by running Set-ExecutionPolicy Default.

## Installation

1. Clone the repository:
   ```bash
   git clone https://<BR>.git
   ```
   
2. Navigate into the directory:
   ```bash
   cd VeriHash
   ```

3. Run `VeriHash.ps1` in PowerShell:
   ```powershell
   .\VeriHash.ps1
   ```

## Usage Examples

### 1. Compute a SHA256 Hash for a File

If you provide just a file path, `VeriHash` will compute and display its SHA256 hash. 
If the hash is SHA256 (the default), it also creates a `.sha2_256` file in the same directory.

```powershell
.\VeriHash.ps1 "C:\path\to\yourfile.exe"
```

### 2. Verify Using a `.sha2_256` File

If you run `VeriHash` on a `.sha2_256` file:
```powershell
.\VeriHash.ps1 "C:\path\to\yourfile.exe.sha2_256"
```
It will verify that `yourfile.exe` matches the stored hash. 
If the referenced file isn't found or the hash doesn't match, you'll be notified.

### 3. Compare Against an Input Hash

Provide both the file and a known-good hash to verify:
```powershell
.\VeriHash.ps1 "C:\path\to\yourfile.exe" -hash "ABC123456..."
```
`VeriHash` will display whether the computed hash matches the input hash.

### 4. Interactive File Selection

Just run:
```powershell
.\VeriHash.ps1
```
If no path is given, on Windows you can select a file using a GUI dialog. 
On other systems, you'll be prompted to type the path.

## Use Cases

- 🔬 **Software Integrity Checks:** 
  Downloaded a new piece of software? Compute its SHA256 hash and compare it to the vendor-provided hash.

- 🔐 **Automated Verification in CI/CD:** 
  Integrate VeriHash in your build pipeline to verify that build artifacts haven't been tampered with.

- 💾 **Backup Integrity Checks:** 
  Generate `.sha2_256` files for backups and run periodic checks to ensure no corruption over time.

## Contributing

Feel free to open issues, submit pull requests, or suggest enhancements.

## License

Choose a license (e.g., MIT, Apache 2.0). Refer to the `LICENSE` file for more details.
