# Snowflake + LangChain MCP Demo

A demonstration of using **LangChain/LangGraph** with **Model Context Protocol (MCP)** to connect AI agents to [Snowflake's fully managed MCP server](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp). This demo showcases an agentic workflow where a LangChain agent (powered by any LLM - Gemini in this example) orchestrates secure data analysis through Snowflake Cortex Agent and triggers downstream business actions.

## Overview

This demo implements a complete agentic workflow using **LangGraph's agent framework**:

1. **Goal Reception**: Agent receives a business objective (e.g., "Find root cause of revenue decline")
2. **Tool Selection**: LLM (Gemini/OpenAI/etc.) reasons and selects the appropriate Snowflake Cortex Agent tool
3. **Data Action**: LangChain agent calls the Snowflake Managed MCP Server
4. **Observation**: Receives structured findings from Snowflake's secure analysis
5. **Downstream Decision**: LLM synthesizes data and determines next actions
6. **Business Action**: Triggers external system handoffs (simulated Salesforce/Jira alerts)
7. **Final Synthesis**: Provides comprehensive natural language report

**Note**: While this demo uses Gemini, you can easily swap in any LLM (OpenAI GPT-4, Claude, Llama, etc.) by changing the model initialization.

## Architecture

```
┌──────────────┐      ┌──────────────────────────────────┐      ┌─────────────────┐
│  LangChain   │◄────►│  Snowflake Managed MCP Server    │◄────►│   Cortex Agent  │
│   Agent      │      │  (OAuth/PAT Authentication)      │      │  + Analyst Tool │
│ (LLM-powered)│      │                                  │      │                 │
└──────────────┘      └──────────────────────────────────┘      └─────────────────┘
       │                                                                   │
       │                                                                   ▼
       │                                                         ┌──────────────────┐
       └────────────────────────────────────────────────────────►│  Revenue Data    │
                                                                 │  (Semantic View) │
                                                                 └──────────────────┘
```

## Prerequisites

- **Snowflake Account** 
  - Ability to create databases, schemas, and MCP servers
- **LLM API Key** - This demo uses Gemini ([Get API key](https://aistudio.google.com/app/apikey)), but you can use:
  - OpenAI GPT-4 ([OpenAI API](https://platform.openai.com/))
  - Anthropic Claude ([Anthropic Console](https://console.anthropic.com/))
  - Any other LangChain-supported LLM
- **Python 3.8+**

## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/sfc-gh-aperezgonzalez/mcp-client-demo.git
cd mcp-client-demo
```

### 2. Set Up Snowflake Environment

Execute the `setup.sql` script in your Snowflake account. This will:
- Create the `MCP_DEMO` database and `SALES_DATA` schema
- Create a `REVENUE_FACT` table with mock sales data
- Create a semantic view (`REVENUE_SV`) for Cortex Analyst
- Create a Cortex Agent (`REVENUE_TROUBLESHOOTER_AGENT`) for deep revenue analysis
- Create the MCP Server (`SALES_INSIGHT_SERVER`) exposing the agent as a tool

```sql
-- Run the entire setup.sql file in a Snowflake worksheet
-- Or execute via Snowflake CLI:
snow sql -f setup.sql
```

### 3. Generate Snowflake Authentication Token

You'll need a Programmatic Access Token (PAT) or OAuth token. For PAT:

1. In Snowflake, go to "Users & roles", select a user
2. Navigate to "Programmatic Access Tokens"
3. Generate a new token
4. Copy the token value (it will look like a long JWT string)

For more details, see [Snowflake REST API Authentication](https://docs.snowflake.com/en/developer-guide/snowflake-rest-api/authentication#label-sfrest-authenticating-pat).

### 4. Configure the Demo

Edit `agent_test_mcp_gemini.py` and update the configuration section:

```python
# --- USER CONFIGURATION ---
SNOWFLAKE_MCP_URL = "https://{your-account}.snowflakecomputing.com/api/v2/databases/MCP_DEMO/schemas/SALES_DATA/mcp-servers/SALES_INSIGHT_SERVER"
SNOWFLAKE_AUTH_TOKEN = "your_pat_token_here"
```

**Important**: Replace `{your-account}` with your Snowflake account identifier. Note:
- Use **hyphens** (not underscores) in hostnames
- Example: `sfseeurope-aperez-aws1.snowflakecomputing.com`
- [More on account identifiers](https://docs.snowflake.com/en/user-guide/admin-account-identifier)

### 5. Set Up Python Environment

```bash
# Create virtual environment
python -m venv venv_mcp_gemini

# Activate virtual environment
# On macOS/Linux:
source venv_mcp_gemini/bin/activate
# On Windows:
# venv_mcp_gemini\Scripts\activate

# Install dependencies
pip install mcp langchain langchain-core langchain-google-genai langchain-mcp-adapters langgraph
```

### 6. Set Environment Variables

```bash
# Set your Gemini API key
export GEMINI_API_KEY="your_gemini_api_key_here"
```

## Running the Demo

```bash
python agent_test_mcp_gemini.py
```

### Expected Output

```
🔗 Connecting to managed MCP Server at: https://your-account.snowflakecomputing.com/...
✅ Tools Discovered from Snowflake MCP: ['troubleshooter_agent']

🧠 Running Agent with Goal: Using the 'troubleshooter_agent' tool, analyze the data...

========================================
🚨 ALERT CREATED IN EXTERNAL SYSTEM (Simulated Salesforce/Jira API)
   Target Customer ID: CUST_A
   Action Summary: CUST_A revenue declined by 75%...
========================================

==================================
🔥 Final Orchestration Result from Gemini:
The revenue decline in the WEST region for Product_Line_X is primarily due to 
CUST_A's 75% revenue reduction and CUST_B's complete inactivity after August...
==================================
```

## What's Happening?

1. **Connection**: The agent connects to your Snowflake MCP Server using PAT authentication
2. **Tool Discovery**: Lists available tools (the Cortex Agent you created)
3. **Analysis**: Gemini agent calls the `troubleshooter_agent` tool through MCP
4. **Snowflake Processing**: Cortex Agent uses Cortex Analyst to query the semantic view and analyze revenue patterns
5. **Results**: Agent receives findings identifying CUST_A and CUST_B as problem areas
6. **Action**: Agent triggers external alerts (simulated) for sales team follow-up
7. **Synthesis**: Gemini provides a natural language summary combining all insights

## Project Structure

```
mcp-client-demo/
├── README.md                   # This file
├── setup.sql                   # Snowflake database and MCP server setup
├── agent_test_mcp_gemini.py   # Main demo script
├── .gitignore                 # Git ignore file
└── venv_mcp_gemini/           # Python virtual environment (not tracked)
```

## Key Technologies

- **[LangChain](https://python.langchain.com/)** & **[LangGraph](https://langchain-ai.github.io/langgraph/)**: Agent orchestration framework - the core that enables the agentic workflow
- **[Model Context Protocol (MCP)](https://spec.modelcontextprotocol.io/)**: Open standard for AI agent tool integration
- **[Snowflake Managed MCP Server](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp)**: Secure, managed MCP implementation
- **[Cortex Agent](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents)**: Snowflake's agentic orchestration system
- **[Cortex Analyst](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst)**: Natural language to SQL for semantic data
- **LLM of your choice**: Gemini, OpenAI GPT-4, Claude, or any LangChain-supported model

## Security Best Practices

- ⚠️ **Never commit tokens**: Keep `SNOWFLAKE_AUTH_TOKEN` and LLM API keys out of version control
- 🔒 Use OAuth for production deployments. Using hardcoded tokens can lead to token leakage.
- 🛡️ Apply least-privilege RBAC for MCP server and tool access
- 🔑 Rotate tokens regularly
- 📋 See [MCP Security Recommendations](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp#mcp-server-security-recommendations)

## Troubleshooting

### SSL Certificate Error
```
certificate verify failed: Hostname mismatch
```
**Solution**: Ensure your hostname uses hyphens, not underscores (e.g., `aperez-aws1` not `aperez_aws1`)

### Authentication Failed
```
PAT_INVALID error
```
**Solution**: 
- Verify your PAT token is correct and not expired
- Ensure the user has proper permissions to access the MCP server

### Gemini API Rate Limits
```
429 Resource exhausted
```
**Solution**: The script will automatically retry. If it persists, wait a few seconds between runs.

## Customization

### Swap the LLM

This demo uses Gemini, but you can easily use any other LLM. Just change the model initialization in `agent_test_mcp_gemini.py`:

**For OpenAI:**
```python
from langchain_openai import ChatOpenAI

model = ChatOpenAI(
    model="gpt-4", 
    temperature=0,
    openai_api_key=os.getenv("OPENAI_API_KEY")
)
```

**For Anthropic Claude:**
```python
from langchain_anthropic import ChatAnthropic

model = ChatAnthropic(
    model="claude-3-5-sonnet-20241022",
    temperature=0,
    anthropic_api_key=os.getenv("ANTHROPIC_API_KEY")
)
```

**For Azure OpenAI:**
```python
from langchain_openai import AzureChatOpenAI

model = AzureChatOpenAI(
    azure_deployment="your-deployment-name",
    api_version="2024-02-15-preview",
    temperature=0
)
```

### Change the Analysis Prompt

Modify the `analysis_prompt` variable in `agent_test_mcp_gemini.py`:

```python
analysis_prompt = (
    "Your custom business question here..."
)
```

### Add More Mock Data

Edit `setup.sql` and add more INSERT statements to `REVENUE_FACT`:

```sql
INSERT INTO REVENUE_FACT (CUSTOMER_ID, REGION, PRODUCT_LINE, SALES_REP_ID, REVENUE_USD, SALE_DATE) 
VALUES ('CUST_NEW', 'NORTH', 'Product_Line_Z', 'ABC', 30000.00, '2025-12-01');
```

### Create Additional Tools

Add more tools to your MCP server in `setup.sql`:

```sql
CREATE OR REPLACE MCP SERVER SALES_INSIGHT_SERVER
  FROM SPECIFICATION $$
    tools:
      - name: "troubleshooter_agent"
        type: "CORTEX_AGENT_RUN"
        identifier: "MCP_DEMO.SALES_DATA.REVENUE_TROUBLESHOOTER_AGENT"
        description: "Revenue analysis agent"
      - name: "your_new_tool"
        type: "SYSTEM_EXECUTE_SQL"  # or other type
        description: "Your tool description"
  $$;
```

## Learn More

- 📚 [Snowflake MCP Server Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp)
- 🚀 [Getting Started with Managed Snowflake MCP Server Quickstart](https://www.snowflake.com/en/developers/guides/getting-started-with-snowflake-mcp-server/)
- 🤖 [Cortex Agent Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents)
- 📊 [Cortex Analyst Guide](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst)
- 🔗 [Model Context Protocol Specification](https://spec.modelcontextprotocol.io/)

## License

This project is provided as-is for demonstration purposes.

## Contributing

Issues and pull requests are welcome! Please feel free to contribute improvements or additional examples.

## Contact

For questions or feedback, please open an issue on this repository.

