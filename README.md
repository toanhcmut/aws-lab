# Infracost MCP Server

A Model Context Protocol (MCP) server that wraps the Infracost CLI to provide Terraform cost estimation capabilities to AI agents.

## Features

- Estimates monthly costs for Terraform infrastructure
- Returns concise summaries with total cost and top 5 most expensive resources
- Handles errors gracefully with helpful error messages
- Built with Python and FastMCP for minimal boilerplate

## Prerequisites

1. **Python 3.10+** installed
2. **uv** package manager installed
3. **Infracost CLI** installed and authenticated

### Install Infracost

```bash
# Install Infracost
curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh

# Authenticate
infracost auth login
```

## Installation

### Option 1: Using uvx (Recommended)

No installation needed! The MCP server will be run directly via `uvx`.

### Option 2: Local Development

```bash
# Install dependencies
uv pip install -e .
```

## Configuration

Add the following to your Kiro/Claude Desktop MCP configuration file (`~/.kiro/settings/mcp.json`):

```json
{
  "mcpServers": {
    "infracost": {
      "command": "/home/tqtcse/.local/bin/uvx",
      "args": [
        "--from",
        ".",
        "infracost-mcp"
      ],
      "env": {},
      "disabled": false,
      "autoApprove": [
        "get_terraform_cost_estimate"
      ]
    }
  }
}
```

**Note:** Adjust the `command` path to match your `uvx` installation location. You can find it with:

```bash
which uvx
```

### Alternative: Run from local directory

If you want to run the server directly from the project directory:

```json
{
  "mcpServers": {
    "infracost": {
      "command": "python3",
      "args": [
        "/full/path/to/infracost_mcp.py"
      ],
      "env": {},
      "disabled": false,
      "autoApprove": [
        "get_terraform_cost_estimate"
      ]
    }
  }
}
```

## Usage

Once configured, the AI agent can use the tool:

```
Tool: get_terraform_cost_estimate
Input: { "tf_directory": "." }
```

### Example Output

```
============================================================
TERRAFORM COST ESTIMATE
============================================================

Total Monthly Cost: $152.30 USD

Top 5 Most Expensive Resources:
------------------------------------------------------------
1. aws_rds_cluster.main
   Type: aws_rds_cluster
   Monthly Cost: $87.60 USD

2. aws_elasticache_cluster.redis
   Type: aws_elasticache_cluster
   Monthly Cost: $43.80 USD

3. aws_instance.app_server
   Type: aws_instance
   Monthly Cost: $14.60 USD

4. aws_s3_bucket.data
   Type: aws_s3_bucket
   Monthly Cost: $4.50 USD

5. aws_cloudwatch_log_group.app_logs
   Type: aws_cloudwatch_log_group
   Monthly Cost: $1.80 USD

============================================================
```

## Tool Details

### `get_terraform_cost_estimate`

Estimates the monthly cost of Terraform infrastructure.

**Parameters:**
- `tf_directory` (string, optional): Path to the Terraform directory. Default: `"."`

**Returns:**
- Formatted text summary with:
  - Total monthly cost in USD
  - Top 5 most expensive resources with their types and costs

**Error Handling:**
- Checks if Infracost is installed
- Validates Terraform directory
- Provides helpful error messages with installation/authentication instructions

## Development

### Project Structure

```
.
├── infracost_mcp.py    # Main MCP server implementation
├── pyproject.toml      # Python project configuration
└── README.md           # This file
```

### Testing Locally

```bash
# Run the server directly
python3 infracost_mcp.py

# Or with uvx
uvx --from . infracost-mcp
```

## Troubleshooting

### "Infracost CLI is not installed"

Install Infracost:
```bash
curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh
```

### "Error running Infracost"

Make sure you're authenticated:
```bash
infracost auth login
```

### "Failed to parse Infracost JSON output"

Ensure your Terraform files are valid:
```bash
terraform validate
```

## License

MIT
