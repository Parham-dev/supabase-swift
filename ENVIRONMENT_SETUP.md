# Environment Setup

This project uses environment variables to securely store Supabase credentials and other configuration values.

## Setup Instructions

1. **Copy the example environment file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit the `.env` file with your credentials:**
   ```bash
   # Your actual Supabase configuration
   SUPABASE_URL=https://your-project-id.supabase.co
   SUPABASE_ANON_KEY=your_actual_anon_key_here
   ```

3. **Get your Supabase credentials:**
   - Go to your [Supabase Dashboard](https://app.supabase.com)
   - Select your project
   - Go to Settings > API
   - Copy your `URL` and `anon` key

## File Structure

- `.env` - Your actual environment variables (git-ignored)
- `.env.example` - Template file (safe to commit)
- `Tests/SwiftSupabaseSyncTests/EnvironmentReader.swift` - Environment variable loader

## Security Notes

- The `.env` file is automatically git-ignored to prevent credential exposure
- The `anon` key is safe to expose publicly as it only allows row-level security controlled access
- However, it's still best practice to keep credentials in environment variables

## Testing

The test suite automatically loads credentials from the `.env` file. If credentials are not found, tests will fail with a descriptive error message.

## CI/CD

For continuous integration, set the environment variables in your CI system:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
