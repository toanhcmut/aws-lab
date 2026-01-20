---
inclusion: always
---
1.  **Environment & Path Enforcement (WSL/Linux Context):**
    * **Strict Environment Assumption:** ALWAYS act as if running in a **Linux/WSL** environment.
    * **Path Syntax:** ALWAYS use forward slashes (`/`) for file paths. **NEVER** use Windows backslashes (`\`) to avoid escape character errors (e.g., `\k` in `\kiro`).
    * **Workspace Directory:** When configuring tools or creating files, prefer using `.` (current directory) or relative paths instead of absolute Windows paths (e.g., `D:\...`) to prevent cross-platform conflicts.
    * **Command Execution:** call binaries by their Linux names (e.g., `uvx`, `python`) without appending `.exe`.

2.  **Tool Preference:** ALWAYS use the `aws-diagrams` MCP server tools (e.g., `generate_diagram`) to create visual architecture diagrams for AWS-related systems.

3.  **Strict Failure Policy (NO Fallback):**
    * **Forbidden:** DO NOT use Mermaid.js, PlantUML, or ASCII art for AWS architecture diagrams.
    * **On Failure:** If the `aws-diagrams` MCP tool fails or encounters an error (including `SIGALRM` or missing dependencies), **STOP the process immediately** and report the specific error to the user. **DO NOT** attempt to switch to Mermaid/PlantUML or generate a text-based diagram as a fallback.

4.  **Output Format:**
    * Generate the diagram as a PNG file (e.g., `system_architecture.png`) in the current directory.
    * Embed the generated image into the `design.md` file using standard Markdown syntax: `![System Architecture](./system_architecture.png)`.

5.  **Review:** Ensure the diagram includes all major components mentioned in the requirements (Ingestion, Processing, Storage, Network layers).

6.  **Service Granularity & Labeling:**
    * **Distinct Nodes:** Each AWS service must be a separate icon.
    * **Multiple Instances:** If requirements specify multiple instances (e.g., 2 SQS queues for different purposes), generate SEPARATE nodes for each and label them specifically (e.g., "SQS (MQTT)" and "SQS (LoRaWAN)").
    * **No Grouping:** DO NOT combine distinct services (like WAF + CloudFront) into a single node.

7.  **Visual Hierarchy & Boundaries (Standard AWS Style):**
    * **AWS Cloud Boundary:** Wrap ALL AWS resources inside an outer Cluster/Group labeled **"AWS Cloud"**.
    * **External Users:** Users, IoT Devices, or On-premise systems must be placed **OUTSIDE** the "AWS Cloud" boundary.
    * **VPC Boundary:** Wrap network-isolated resources (EC2, ECS, RDS, Lambda in VPC) inside a Cluster/Group labeled **"VPC"**.
    * **Subnet Grouping (Optional):** If possible, group resources into "Public Subnet" and "Private Subnet" clusters to show network segregation clearly.

8.  **Flow & Connection Style:**
    * **Direction:** The diagram flow should generally go from **Left to Right** (Users -> Frontend -> Backend -> Database).
    * **Edge Labels:** Label the connecting lines (edges) with protocols or data types where relevant (e.g., "HTTPS", "MQTT", "SQL Query").
    * **Edge Style:** Use solid lines for primary traffic flow and dashed lines for asynchronous or control flow (e.g., SQS triggers, EventBridge events).