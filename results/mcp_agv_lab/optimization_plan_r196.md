# Optimization candidates

Safe changes already made:
- Created isolated lab root: 
C:\Users\文少\0mcp-agv-arena-optimized
- Did not modify the original 0mcp-agv folder.
- Did not register any new MCP server inside Antigravity or Codex automatically.

Good optimization candidates:
1. Convert repeated PowerShell task scripts into idempotent modules: path discovery, process control, settings JSON update, scheduled task creation, and report writing.
2. Add a safe GUI automation layer using Windows UI Automation / pywinauto with active-window scope.
3. Add an MCP server only after local smoke tests pass; keep it in this lab folder and use explicit allowlists.
4. Keep all node subscriptions and secrets under %USERPROFILE%\.arena-private, never in Git or public logs.
5. For desktop software, prefer app-specific adapters before broad screen-control agents.

Projects evaluated:
- windows-computer-use: best match for native Windows app control through MCP.
- Windows-MCP: good lightweight MCP option for Windows operations.
- Anthropic computer-use-demo: useful reference, but Docker/Linux desktop focused rather than native Windows app control.

