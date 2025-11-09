import asyncio
import os
import json 
from langchain.agents import create_agent
from langchain_core.messages import HumanMessage
from langchain_mcp_adapters.tools import load_mcp_tools
from langchain_google_genai import ChatGoogleGenerativeAI
from mcp import ClientSession
from mcp.client.streamable_http import streamablehttp_client

# --- USER CONFIGURATION ---
SNOWFLAKE_MCP_URL = "https://{hostname}}.snowflakecomputing.com/api/v2/databases/{database}/schemas/{schema}/mcp-servers/{name}"
SNOWFLAKE_AUTH_TOKEN = "YOUR_SNOWFLAKE_PAT_OR_OAUTH_TOKEN"

# --- Scenario Prompt (The Agent's Goal - Testing Step 1) ---
analysis_prompt = (
    "Using the 'troubleshooter_agent' tool, analyze the data to find the root cause of the "
    "revenue decline in the WEST region for Product_Line_X. Identify the top customer(s) "
    "responsible for the drop and provide a clear, concise summary of your findings. "
    "Then, use the 'external_sales_handoff' tool to create an alert for the responsible sales rep."
)

# --- (Optional) Tool for demonstrating Steps 2 & 3 (External System) ---
# This simulates the critical business action after Snowflake analysis.
def external_sales_handoff(customer_id: str, summary: str) -> str:
    """
    Simulates creating a high-priority alert in an external system (e.g., Salesforce/Jira).
    This function is defined locally for the LangChain agent to discover and use.
    """
    print("\n\n" + "="*40)
    print(f"🚨 ALERT CREATED IN EXTERNAL SYSTEM (Simulated Salesforce/Jira API)")
    print(f"   Target Customer ID: {customer_id}")
    print(f"   Action Summary: {summary[:70]}...")
    print("="*40)
    # In a real app, this would use the 'requests' library to call the actual Salesforce/HubSpot API.
    return f"Successfully created external sales alert for {customer_id} with audit ID: 12345."

async def run_gemini_agent(prompt: str):
    # 1. Define Auth and Load Tools from Snowflake MCP
    # Using PAT (Programmatic Access Token) for demo purposes
    auth_headers = {
        "Authorization": f"Bearer {SNOWFLAKE_AUTH_TOKEN}",
        "X-Snowflake-Authorization-Token-Type": "PROGRAMMATIC_ACCESS_TOKEN"
    }
    print(f"🔗 Connecting to managed MCP Server at: {SNOWFLAKE_MCP_URL}")
    
    async with streamablehttp_client(SNOWFLAKE_MCP_URL, headers=auth_headers) as (read, write, _):
        async with ClientSession(read, write) as session:
            await session.initialize()
            snowflake_tools = await load_mcp_tools(session)
            print(f"✅ Tools Discovered from Snowflake MCP: {[t.name for t in snowflake_tools]}")

            # 2. Combine all tools for the agent to use
            # The agent can call the Snowflake tool OR the external Python function tool
            all_tools = snowflake_tools + [external_sales_handoff]

            # 3. Create the Agent using the Gemini LLM
            model = ChatGoogleGenerativeAI(
                model="gemini-2.0-flash-exp", 
                temperature=0,
                google_api_key=os.getenv("GEMINI_API_KEY")
            ) 
            agent = create_agent(model, all_tools)
            
            # 4. Run the orchestration
            print(f"\n🧠 Running Agent with Goal: {prompt}")
            
            result = await agent.ainvoke(
                {"messages": [HumanMessage(content=prompt)]},
                config={"recursion_limit": 50}
            )
            
            # 5. Print the final synthesis
            final_message = result['messages'][-1].content
            print("\n==================================")
            print("🔥 Final Orchestration Result from Gemini:")
            print(final_message)
            print("==================================")

if __name__ == "__main__":
    asyncio.run(run_gemini_agent(analysis_prompt))