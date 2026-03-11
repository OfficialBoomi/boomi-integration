# User Onboarding Guide

## Onboarding Workflow

1. **Collect credentials interactively** (ask one at a time, with the minimum viable configuration of username, api_token, account_id, and sensible platform/ssl defaults you can begin creating processes and folders in their account. You may opt for that if the user seems uncomfortable with a large setup):
   - **BOOMI_API_URL**: "The Boomi API URL is usually https://api.boomi.com, use that?" (This would apply in the uncommon circumstances of international platform instance or local Boomi-engineering team developer instance URL)"
   - **BOOMI_USERNAME**: "What's your Boomi username?"
   - **BOOMI_API_TOKEN**: "What's your Boomi API token? (Find this in Account Settings → API Management - generate one if needed)"
   - **BOOMI_ACCOUNT_ID**: "What's your Boomi Account ID? (Visible in platform URL or account settings)"
   - **BOOMI_VERIFY_SSL**: "Should I verify SSL certificates? (true for production, false for self-signed certs - usually true)"
   - **BOOMI_TARGET_FOLDER**: "What's your default folder ID for components? (Create a folder in Boomi GUI and provide its GUID, say 'skip' to set later, or if the platform is already accessible the agent should offer to create a folder on their behalf)"
   - **BOOMI_ENVIRONMENT_ID**: "What's your test environment ID? (Find in Manage → Atom Management → [your environment], or say 'skip' to set later)"
   - **BOOMI_TEST_ATOM_ID**: "What's your test runtime ID? (Find in Manage → Runtime Management → [your runtime ID], or say 'skip' to set later)"
   - **SERVER_BASE_URL**: "What's your runtime's shared web server base URL for testing WSS endpoints? (e.g., https://c01-usa-west.integrate.boomi.com, or say 'skip' to set later)"
   - **SERVER_USERNAME**: "Runtime shared web server username for WSS testing? (Leave empty if authentication is disabled, or say 'skip')"
   - **SERVER_TOKEN**: "Runtime shared web server token for WSS testing? (Leave empty if authentication is disabled, or say 'skip')"
   - **SERVER_VERIFY_SSL**: "Verify SSL for runtime server? (false for self-signed certs, true for production - usually true)"

2. **Create .env file**:
   - Use Write tool to create `.env` with collected values
   - Use "skip" or empty string for optional values user wants to set later

3. **Update .gitignore**:
   - Check if `.gitignore` exists
   - Ensure it includes `.env` and `active-development/`
   - If no `.gitignore` exists, create one with those entries

4. **Check prerequisites**:
   - Verify `curl` and `jq` are available: `curl --version && jq --version`
   - If `jq` is missing: `brew install jq` (macOS) or `apt install jq` (Linux)

5. **Test connection**:
   - Run: `bash scripts/boomi-component-push.sh --test-connection`
   - If success: "Great! Your connection to the Boomi platform is working."
   - If failure: Explain the error and help troubleshoot (usually credentials)

6. **Ready to work**:
   - "You're all set! What would you like to build?"
   - Proceed with their original request
