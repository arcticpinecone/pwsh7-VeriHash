# VeriHash Multi-File Index Enhancement Concept

**Date**: 2026-01-16  
**Status**: Planning Phase  
**Goal**: Enable efficient hashing and verification of multiple files using GNU-standard index files

---

## 🎯 Philosophy

VeriHash exists to make hash verification **fast, visual, and accessible**.
People skip hash checks because they're cumbersome; this tool removes that barrier.
Multi-file indexing extends this philosophy to entire directories and file collections.

---

## 📋 Core Concept

### The Problem

Currently, VeriHash handles one file at a time. Users often need to:

- Verify entire directories haven't changed after transfer/backup
- Maintain hash records for collections of files
- Avoid creating hundreds of individual `.sha256` sidecar files

### The Solution

**Multi-file index files** using GNU `sha256sum` standard format:

```bash
<hash> *<relative/path/to/file.ext>
<hash> *<another/file.exe>
```

---

## 🔧 Technical Design

### 1. Input Detection & Behavior

#### **Send-To / Right-Click Context**

- **Single file** → Create individual `.sha256` sidecar (current behavior)
- **Multiple files/folders** → Create index file (new behavior)
- Auto-detect from input arguments count

#### **CLI Usage**

- Current single-file behavior unchanged
- New flag: `-CreateIndex` - Force index creation even for single file
- New flag: `-RecursiveIndividual` - Create individual `.sha256` for all files in directory
  - **Safety**: Prevent cyclic redundancy (don't hash `.sha256` files)
  - **Performance**: Chunk processing to avoid system overload
  - **Safeguard**: Confirm before processing >1000 files

### 2. Index File Format & Naming

#### **Format**: GNU `sha256sum` standard

```bash
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 *relative/path/file1.txt
5d41402abc4b2a76b9719d911017c592 *subdir/file2.dat
```

#### **Naming Convention**

- Pattern: `YYYY-MM-DDTHHMMSS.sha256` (UTC-0)
- Example: `2026-01-16T234917.sha256`
- Rationale:
  - Sortable chronologically
  - No timezone confusion (UTC-0)
  - Clear purpose (`.sha256` extension)

#### **Creation Flow**

1. User selects multiple files/folders
2. VeriHash processes hashes
3. **GUI prompt appears**:
   - Default location: Parent directory of selected items
   - Default name: Timestamp (UTC)
   - User can browse to different location
   - User can edit filename
4. Index file created with relative paths

### 3. Recursive Directory Handling

#### **When folder(s) selected**

- Hash **all files recursively**
- Skip:
  - Existing hash files (`.sha256`, `.sha512`, `.md5`)
  - Hidden system files (optional flag should be included)
  - Symlinks (to prevent loops!)

#### **Path Format in Index**

- **Relative paths** from index file location
- Example structure:

  ```bash
  MyProject/
  ├── 2026-01-16T234917.sha256  (index file)
  ├── src/
  │   ├── main.cpp
  │   └── utils.cpp
  └── data/
      └── config.json
  ```
  
  Index contains:
  
  ```bash
  abc123... *src/main.cpp
  def456... *src/utils.cpp
  789ghi... *data/config.json
  ```

### 4. Parallel Processing

**Hash Computation**:

- Auto-detect CPU cores: `$env:NUMBER_OF_PROCESSORS` (Windows) or `nproc` (Linux)
- Process 2-4 files simultaneously based on available cores
- Formula: `[Math]::Max(2, [Math]::Min(4, $cores - 1))`
  - Leaves 1 core for system
  - Minimum 2 for efficiency
  - Maximum 4 to avoid I/O bottleneck (SSD limitations)

**PowerShell Implementation**:

```powershell
# Use PowerShell 7's ForEach-Object -Parallel
$files | ForEach-Object -Parallel {
    Get-FileHash $_ -Algorithm SHA256
} -ThrottleLimit $optimalThreads
```

### 5. Verification Workflows

#### **Scenario A: Verifying Against Index**

```powershell
.\VeriHash.ps1 "C:\path\to\2026-01-16T234917.sha256"
```

- Parse index file
- Verify each file listed
- Output summary:

[User tweaked this a bit, so please validate it's even possible] List of files, row by row with ✅❌⚠️ at the start? As a visual indicator as it processes, and easy to scroll back and read?

  ```bash
  ✅  abc123... *src/main.cpp
  ❌  def456... *src/utils.cpp
  ⚠️  789ghi... *data/config.json
  
  ✅  47/50 files verified successfully
  ❌  2 files failed verification
  ⚠️  1 file not found
  ```

- **Only use index** - don't check for individual `.sha256` files in addition to the index; which would confuse everyone.

#### **Scenario B: Individual File Verification**

```powershell
.\VeriHash.ps1 "C:\path\to\file.exe"
```

- Current behavior: Look for `file.exe.sha256`
- **New enhancement**: Also check parent directories for index files
  - Search up to 3 levels up
  - If index found with this file, offer choice:

    ```bash
    Found in index: ../2026-01-16T234917.sha256
    [1] Verify against index
    [2] Create individual .sha256
    [3] Both
    ```

#### **Scenario C: Mixed Verification**

- User has some individual `.sha256` files
- User has an index file
- When verifying index, (optionally) show which files also have individual sidecars
- Flag: `-PreferIndex` or `-PreferIndividual` to control priority

### 6. GUI Integration Points

**When to Show GUI**:

- ✅ Multiple inputs detected (files/folders)
- ✅ User needs to choose index save location
- ✅ Single file verification finds index in parent directory
- ❌ Single file, no index found (use current behavior)
- ❌ CLI with `-NoPause` flag (suppress all GUIs)

**GUI Framework**:

- **Windows**: Continue using Windows Forms (`System.Windows.Forms`)
- **Linux**: Use `kdialog` (KDE) or `zenity` (GNOME) native dialogs
- **Fallback**: PowerShell console prompts

**Index Save Dialog**:

```bash
┌─────────────────────────────────────────┐
│ Save Hash Index                         │
├─────────────────────────────────────────┤
│ Location: [C:\MyFiles\          ] [📁] │
│ Filename: [2026-01-16T234917.sha256   ] │
│                                         │
│ Files to hash: 47                       │
│ Total size: 2.3 GB                      │
│                                         │
│         [Cancel]          [Create]      │
└─────────────────────────────────────────┘
```

**Index Discovery Dialog** (when single file has index available):

```bash
┌─────────────────────────────────────────┐
│ file.exe is tracked in an index:        │
│ ../backups/2026-01-16T234917.sha256     │
│                                         │
│ ○ Verify against index                  │
│ ○ Create individual .sha256             │
│ ○ Verify index + create individual      │
│ ○ Browse for different index...         │
│                                         │
│         [Cancel]          [OK]          │
└─────────────────────────────────────────┘
```

### 7. Path Handling & Index Discovery

**Relative Path Storage**:

- All paths in index are relative to index file location
- Supports cross-platform (use `/` separator, PowerShell normalizes)
- Handle edge cases:
  - Files in same directory: `file.txt`
  - Files in subdirectory: `subdir/file.txt`
  - Files in parent: `../file.txt` (if user manually moved things)

**Index Discovery Algorithm**:
When verifying single file `C:\Projects\MyApp\src\main.cpp`:

1. Check for `main.cpp.sha256` (current behavior)
2. **NEW**: Search for index files:

   ```bash
   C:\Projects\MyApp\src\*.sha256
   C:\Projects\MyApp\*.sha256
   C:\Projects\*.sha256
   ```

3. Parse each index found
4. Check if current file is listed (match by relative path)
5. If found in multiple indexes:
   - Show all matches
   - Let user choose
   - Remember choice? (future enhancement)

**Performance**:

- Cache index search results during session
- Only search up to 3 directory levels (configurable)
- Skip network drives (slow)

---

## 🚀 Implementation Phases

Linux can be done later; for now this is pursuing Windows capability first.

### Phase 1: Core Index Creation

- [ ] Detect multiple input files/folders
- [ ] Recursive file enumeration with safeguards
- [ ] GNU format index generation
- [ ] Timestamp-based naming (UTC)
- [ ] Relative path handling

### Phase 2: Index Verification

- [ ] Parse GNU-format index files
- [ ] Verify all files in index
- [ ] Summary report with statistics
- [ ] Handle missing files gracefully

### Phase 3: Parallel Processing

- [ ] CPU core detection
- [ ] PowerShell 7 `ForEach-Object -Parallel` implementation
- [ ] Throttle limit calculation (2-4 threads)
- [ ] Progress feedback during multi-file hashing

### Phase 4: GUI Enhancements

- [ ] Index save location dialog
- [ ] Filename editing
- [ ] Index discovery dialog (single file → found in index)
- [ ] Browse for index option

### Phase 5: Smart Discovery

- [ ] Search parent directories for indexes
- [ ] Match file against index entries
- [ ] Present choices to user
- [ ] Prefer index vs individual selection

### Phase 6: Advanced Features

- [ ] `-RecursiveIndividual` flag for CLI
- [ ] Cyclic redundancy prevention
- [ ] System overload protection (chunking)
- [ ] Multiple index support (choose between indexes)
- [ ] Index merging? (combine multiple indexes)

---

## 🤔 Open Questions & Considerations

### 1. Index File Conflicts

**Q**: What if an index file already exists with the same timestamp?  
**A**: Options:

- Append counter: `.sha256(1)`
- Prompt user to overwrite/rename

### 2. Large Directory Performance

**Q**: What if user selects folder with 10,000+ files?  
**A**:

- Show file count estimate before processing
- Confirm if > 1000 files
- Show progress indicator. E.g. "Hashing... 15/47 (32%)"
- Allow cancellation (Ctrl+C handling)

### 3. Cross-Platform Path Handling

**Q**: Windows uses `\`, Unix uses `/` - how to handle in index?  
**A**:

- **Store**: Always use `/` (forward slash) in index files
- **Read**: PowerShell's `Join-Path` and `Resolve-Path` handle conversion
- **Compatibility**: GNU tools on both platforms expect `/`

### 4. Signature Verification in Indexes

**Q**: Should index creation also verify Authenticode signatures (Windows)?  
**A**: NO, not yet. Maybe in the future, but that seems very intensive depending on the amount of files. shelf feature for now.

- Could add signature status column (optional)
- Extended format: `<hash> *<path> # Signature: Valid`
- Keep standard GNU format as primary
- Separate signature report file?

### 5. Incremental Updates

**Q**: User adds files to directory - update existing index?  
**A**: Future enhancement.

- `.\VeriHash.ps1 -UpdateIndex "existing.sha256"`
- Re-scan directory
- Add new files
- Re-verify existing files (mark if changed?)
- Timestamp the update?

### 6. Differential/Changed Files Report

**Q**: Show what changed between old and new index?  
**A**: Future enhancement.

- `.\VeriHash.ps1 -CompareIndexes old.sha256 new.sha256`
- Output: Added, Removed, Modified, Unchanged
- Compare 2 indexes

---

## 📝 GNU `sha256sum` Format Reference

**Standard Format**:

```bash
<hash><space><mode><filename>
```

**Mode Indicators**:

- ` ` (space): Text mode (line endings may differ)
- `*`: Binary mode (byte-for-byte)

**Example**:

```bash
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 *file1.bin
5d41402abc4b2a76b9719d911017c592 *subdirectory/file2.txt
```

**Compatibility**:

- Can be verified with GNU `sha256sum -c filename.sha256`
- Cross-platform (Linux, macOS, Windows with GNU tools)
- VeriHash already uses this format for individual files

---

## 🎨 User Experience Examples

### Example 1: Right-Click Multiple Files

**User Action**:

1. Select 3 files in Explorer: `report.pdf`, `data.csv`, `image.png`
2. Right-click → Send To → VeriHash

**VeriHash Behavior**:

1. Detects 3 files (multiple input)
2. Computes SHA256 for each (parallel: 2-3 at once)
3. Shows GUI dialog:
   - Location: Current directory
   - Filename: `2026-01-16T234917.sha256`
4. User clicks "Create"
5. Index file created:

   ```bash
   abc123... *report.pdf
   def456... *data.csv
   789ghi... *image.png
   ```

6. Success message: "Index created with 3 files"

### Example 2: Right-Click Folder

**User Action**:

1. Right-click `MyProject/` folder → Send To → VeriHash

**VeriHash Behavior**:

1. Scans recursively: 47 files found
2. Shows confirmation: "Hash 47 files (2.3 GB)? [Yes/No]"
3. User clicks Yes
4. Progress indicator: "Hashing... 15/47 (32%)"
5. Shows save dialog with default location (parent of `MyProject/`)
6. Index created: `2026-01-16T234917.sha256`

### Example 3: Verify Single File (Index Exists)

**User Action**:

1. Right-click `src/main.cpp` → Send To → VeriHash

**VeriHash Behavior**:

1. Looks for `main.cpp.sha256` - not found
2. Searches parent directories
3. Finds: `../2026-01-16T234917.sha256` (contains this file)
4. Shows dialog: "Found in index, verify against it?"
5. User selects "Verify against index"
6. Result: "✅ main.cpp verified (matches index)"

### Example 4: CLI Index Creation

**User Action**:

```powershell
.\VeriHash.ps1 -CreateIndex "C:\MyFiles\"
```

**VeriHash Behavior**:

1. Scans directory recursively
2. Shows GUI save dialog (unless `-NoPause`)
3. Creates index with timestamp name
4. Outputs summary to console

### Example 5: CLI Index Verification

**User Action**:

```powershell
.\VeriHash.ps1 "C:\MyFiles\2026-01-16T234917.sha256"
```

**VeriHash Behavior**:

1. Detects file is an index (`.sha256` extension + GNU format)
2. Parses all entries
3. Verifies each file (parallel processing)
4. Shows detailed report:

   ```bash
   Verifying index: 2026-01-16T234917.sha256
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ✅ src/main.cpp
   ✅ src/utils.cpp
   ✅ data/config.json
   ❌ images/logo.png (hash mismatch)
   ⚠️  backup/old.txt (file not found)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Summary: 3/5 OK, 1 Failed, 1 Missing
   ```

---

## 🔐 Security Considerations

1. **Path Traversal**: Sanitize relative paths to prevent `../../../etc/passwd` attacks
2. **Symlink Loops**: Detect and skip circular symlinks during recursion
3. **Hash File Recursion**: Never hash `.sha256`, `.sha512`, `.md5` files themselves
4. **Large Files**: Warn if single file > 10 GB (slow to hash)
5. **Permissions**: Handle permission-denied errors gracefully

---

## 🧪 Testing Strategy

### Unit Tests

- [ ] GNU format parsing (valid/invalid)
- [ ] Relative path resolution
- [ ] Multi-input detection
- [ ] Timestamp generation (UTC)
- [ ] Parallel processing logic

### Integration Tests

- [ ] Create index from multiple files
- [ ] Verify index with all files present
- [ ] Verify index with missing file
- [ ] Verify index with modified file
- [ ] Recursive directory hashing
- [ ] Cross-platform path handling (Windows/Linux)

### Performance Tests

- [ ] 100 small files (< 1 MB each)
- [ ] 10 large files (> 100 MB each)
- [ ] 1000+ files (stress test)
- [ ] Parallel vs serial comparison

---

## 📚 Documentation Updates Needed

- [ ] README: Add multi-file index section
- [ ] README: Update usage examples
- [ ] CHANGELOG: Document new feature
- [ ] Help text: Add `-CreateIndex`, `-RecursiveIndividual` flags
- [ ] Screenshots: Show GUI dialogs

---

## 🎯 Success Metrics

- Users can hash entire directories with 1 right-click
- Index verification is faster than individual file checks
- GNU format ensures compatibility with existing tools
- GUI makes it approachable for non-CLI users
- No breaking changes to existing single-file workflow

---

### **End of Concept Document**

*This is a living document. As implementation progresses, update with lessons learned, design decisions, and new considerations.*
