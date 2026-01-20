# /// script
# dependencies = [
#     "fastmcp",
# ]
# ///

import asyncio
import json
from fastmcp import FastMCP

# 1. Khởi tạo Server bằng FastMCP (Cách mới, gọn nhẹ)
mcp = FastMCP("infracost-mcp")

@mcp.tool()
async def get_terraform_cost_estimate(tf_directory: str = ".") -> str:
    """
    Estimate monthly cost using Infracost.
    """
    try:
        # Chạy lệnh infracost ngầm
        process = await asyncio.create_subprocess_exec(
            "/usr/local/bin/infracost", "breakdown", "--path", tf_directory, "--format", "json",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await process.communicate()

        if process.returncode != 0:
            return f"Error: {stderr.decode().strip()}"

        # Parse kết quả
        data = json.loads(stdout.decode())
        total = data.get("totalMonthlyCost", "0")
        currency = data.get("currency", "USD")
        
        # Lọc ra top resource đắt đỏ
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

        # Tạo báo cáo text
        report = [f"💰 EST. COST: ${total} {currency}/mo", "-" * 30]
        for r in top_5:
            report.append(f"{r['name']}: ${r['cost']:.2f}")
            
        return "\n".join(report)

    except Exception as e:
        return f"Error: {str(e)}"

# 2. Lệnh này sẽ giữ server chạy mãi mãi (đúng ý bạn cần)
if __name__ == "__main__":
    mcp.run()