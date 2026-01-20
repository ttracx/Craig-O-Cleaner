# fastlane Documentation for Craig-O-Clean

## App Store Connect API Setup

This project uses App Store Connect API Key for authentication, which provides:
- No 2FA prompts during automated builds
- Faster and more reliable uploads
- Better for CI/CD pipelines

### Configuration Files

1. **AuthKey_G6XU698DPT.p8** - Your private API key (NEVER commit to git!)
2. **AppStoreConnectAPIKey.json** - JSON configuration with key details (NEVER commit to git!)
3. **Fastfile** - fastlane configuration with lanes for deployment

### API Key Details

- **Key ID**: G6XU698DPT
- **Issuer ID**: c0528ef6-6818-4168-a759-16361557e455
- **Duration**: 1200 seconds (20 minutes)
- **Team Type**: App Store (not Enterprise)

## Available Lanes

### Screenshots
```bash
fastlane screenshots
```
Takes screenshots for App Store using the UI Tests.

### Build
```bash
fastlane build
```
Builds and signs the app for App Store distribution.

### Beta (TestFlight)
```bash
fastlane beta
```
Builds the app and uploads to TestFlight for beta testing.

### Release
```bash
fastlane release
```
Builds and uploads a new version to App Store Connect (does not submit for review).

### Metadata
```bash
fastlane metadata
```
Uploads only metadata and screenshots to App Store Connect (no binary upload).

### Download Metadata
```bash
fastlane download_metadata
```
Downloads existing metadata from App Store Connect.

## Usage Examples

### Complete Release Flow
```bash
# 1. Take screenshots
fastlane screenshots

# 2. Build and upload to TestFlight
fastlane beta

# 3. After testing, upload to App Store
fastlane release

# 4. Upload metadata and screenshots
fastlane metadata
```

### Using API Key Directly
You can also pass the API key as a command-line parameter:

```bash
fastlane pilot --api_key_path fastlane/AppStoreConnectAPIKey.json
```

## API Key Methods

The Fastfile uses the `app_store_connect_api_key` action with these parameters:

```ruby
app_store_connect_api_key(
  key_id: "G6XU698DPT",
  issuer_id: "c0528ef6-6818-4168-a759-16361557e455",
  key_filepath: "./fastlane/AuthKey_G6XU698DPT.p8",
  duration: 1200,
  in_house: false
)
```

### Alternative: JSON File
You can also load from the JSON file:

```ruby
@api_key = app_store_connect_api_key(
  key_filepath: "fastlane/AppStoreConnectAPIKey.json"
)
```

## Security Notes

⚠️ **IMPORTANT**: Never commit these files to version control:
- `AuthKey_*.p8`
- `AppStoreConnectAPIKey.json`

These files are excluded in `.gitignore` to prevent accidental commits.

### Regenerating API Keys

If your API key is compromised:
1. Go to App Store Connect → Users and Access → Keys
2. Revoke the compromised key
3. Create a new key
4. Download the new `.p8` file
5. Update the Fastfile and JSON with the new Key ID
6. Replace the old `.p8` file

## Troubleshooting

### "Authentication failed" errors
- Verify your Key ID, Issuer ID, and .p8 file are correct
- Check that the API key has appropriate permissions in App Store Connect
- Ensure the key hasn't been revoked

### "Invalid duration" errors
- Duration must be between 1 and 1200 seconds (20 minutes max)

### "Binary upload failed" errors
- Ensure your app is properly signed
- Check that your bundle identifier matches App Store Connect
- Verify your Xcode project is configured for App Store distribution

## Additional Resources

- [fastlane Documentation](https://docs.fastlane.tools/)
- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)
- [fastlane App Store Connect API Setup](https://docs.fastlane.tools/app-store-connect-api/)
