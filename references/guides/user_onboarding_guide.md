# User Onboarding Guide

## Onboarding Workflow

1. **Help user find credentials** (walk through one at a time — with just username, api_token, and account_id you should be able to begin creating processes and folders. Opt for that minimum if the user seems uncomfortable with a large setup):
   - **BOOMI_API_URL**: "The Boomi API URL is usually https://api.boomi.com, use that?" (uncommon: international instances or local Boomi-engineering dev URLs)
   - **BOOMI_USERNAME**: "What's your Boomi username (email)?"
   - **BOOMI_API_TOKEN**: "Go to Settings → Account Information and Setup → AtomSphere API Tokens. Generate one if needed."
   - **BOOMI_ACCOUNT_ID**: "Find this in your platform URL after `/account/` or in Settings → Account Information"
   - **BOOMI_VERIFY_SSL**: "Should I verify SSL certificates? (true for production, false for self-signed certs — usually true)"
   - **BOOMI_TARGET_FOLDER**: "What's your default folder ID for components? (Create a folder in Boomi GUI and provide its GUID, say 'skip' to set later, or once connected the agent can create a folder on your behalf)"
   - **BOOMI_ENVIRONMENT_ID**: "Go to Manage → Atom Management, select your environment — the ID is in the URL. Say 'skip' to set later."
   - **BOOMI_TEST_ATOM_ID**: "In the same Atom Management page, select your runtime — the atom ID is in the URL. Say 'skip' to set later."
   - **SERVER_BASE_URL**: "What's your runtime's shared web server base URL? (e.g., https://c01-usa-west.integrate.boomi.com, or 'skip')"
   - **SERVER_USERNAME**: "Runtime shared web server username for WSS testing? (Leave empty if auth is disabled, or 'skip')"
   - **SERVER_TOKEN**: "Runtime shared web server token for WSS testing? (Leave empty if auth is disabled, or 'skip')"
   - **SERVER_VERIFY_SSL**: "Verify SSL for runtime server? (false for self-signed, true for production — usually true)"
   - **BOOMI_DEFAULT_BRANCH_ID**: "If you use Branch & Merge, what's your default working branch ID? (Find via Branch Management in the Boomi GUI, or 'skip')"

2. **User creates .env file**:
   - Direct the user to copy `.env.example` to `.env` and paste their values in via a text editor or IDE
   - You will not be able to write credentials into `.env` yourself due to a default project setting — the user handles this directly
   - For optional values they want to skip, default placeholders or empty strings are fine

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
