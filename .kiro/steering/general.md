---
inclusion: always
---
* **Workspace Directory:** When configuring tools or creating files, prefer using `.` (current directory) or relative paths instead of absolute Windows paths (e.g., `D:\...`) to prevent cross-platform conflicts.
    * **Command Execution:** call binaries by their Linux names (e.g., `uvx`, `python`) without appending `.exe`