---
inclusion: always
---
1.  **Tool Preference:** ALWAYS use the `aws-diagrams` MCP server tools (e.g., `generate_diagram`) to create visual architecture diagrams for AWS-related systems.

2.  **Strict Failure Policy (NO Fallback):**
    * **Forbidden:** DO NOT use Mermaid.js, PlantUML, or ASCII art for AWS architecture diagrams.
    * **On Failure:** If the `aws-diagrams` MCP tool fails, **STOP the process immediately** and report the error.

3.  **Output Format:**
    * Generate the diagram as a PNG file in the current directory.
    * Embed the generated image into the `design.md` file using standard Markdown syntax.

4.  **Review:** Ensure the diagram includes all major components mentioned in the requirements.

5.  **Service Granularity & Labeling:**
    * **Distinct Nodes:** Each AWS service must be a separate icon.
    * **Multiple Instances:** Use SEPARATE nodes for multiple instances (e.g., "SQS (MQTT)" vs "SQS (LoRaWAN)").
    * **No Grouping:** DO NOT combine distinct services into a single node.
    * **Exclusion of Non-Logical Infra:** Omit purely infrastructural network components like **Internet Gateways (IGW), NAT Gateways, or Route Tables** unless they are explicitly critical to the requested logic. Focus strictly on the application data flow and active services.

6.  **Visual Hierarchy & Boundaries (Standard AWS Style):**
    * **AWS Cloud Boundary:** Wrap ALL AWS resources inside an outer Cluster labeled **"AWS Cloud"**.
    * **External Users:** Place Users/IoT Devices **OUTSIDE** the "AWS Cloud".
    * **VPC Boundary:** Wrap network-isolated resources inside a Cluster labeled **"VPC"**.
    * **Subnet Grouping:** Group resources into "Public Subnet" and "Private Subnet" clusters where possible.

7.  **Flow, Connection & Layout:**
    * **Direction:** Flow should generally go from **Left to Right** (Users -> Backend).
    * **Configuration/Association Arrows:** For services that protect or are attached to another service, draw the arrow **FROM the configuration TO the target**. (Example: `waf >> cloudfront` represents WAF applied to CloudFront).
    * **Edge Labels:** Label edges with protocols/data types (e.g., "HTTPS", "Trigger").
    * **Edge Style:** Solid lines for traffic; dashed lines for async/control.
    * **Avoid Overlaps:** Optimize node placement and clustering to **prevent arrows from crossing/overlapping** each other. The diagram must be clean and readable; avoid "spaghetti" connections.