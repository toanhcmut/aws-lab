import asyncio
import json
from fastmcp import FastMCP

mcp = FastMCP("infracost-mcp")

@mcp.tool()
async def get_terraform_cost_estimate(tf_directory: str = ".") -> str:
    """
    Estimate monthly cost using Infracost.
    """
    try:
        process = await asyncio.create_subprocess_exec(
            "infracost", "breakdown", "--path", tf_directory, "--format", "json",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await process.communicate()

        if process.returncode != 0:
            return f"Error: {stderr.decode().strip()}"

        data = json.loads(stdout.decode())
        total = data.get("totalMonthlyCost", "0")
        currency = data.get("currency", "USD")
        
        resources = []
        for proj in data.get("projects", []):
            for res in proj.get("breakdown", {}).get("resources", []):
                if float(res.get("monthlyCost") or 0) > 0:
                    resources.append({
                        "name": res.get("name"),
                        "cost": float(res.get("monthlyCost"))
                    })
        
        resources.sort(key=lambda x: x["cost"], reverse=True)
        top_5 = resources[:5]

        report = [f"💰 EST. COST: ${total} {currency}/mo", "-" * 30]
        for r in top_5:
            report.append(f"{r['name']}: ${r['cost']:.2f}")
            
        return "\n".join(report)

    except Exception as e:
        return f"Error: {str(e)}"

if __name__ == "__main__":
    mcp.run()