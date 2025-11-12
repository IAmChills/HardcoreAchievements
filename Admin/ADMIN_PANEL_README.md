# HardcoreAchievements Admin Panel System

## Overview
The admin panel system allows you to manually complete achievements for players via secure whisper commands. This is designed for handling appeals when players encounter bugs or issues with achievement completion.

## Files Structure

### Admin Panel (Local Only)
- `AdminPanel.lua` - Contains the admin panel UI and command sending functionality
- This file should only be included in your local version of the addon

### Client Handler (All Versions)
- `CommandHandler.lua` - Processes incoming admin commands from whispers
- This file should be included in all versions of the addon

## Security Features

### Payload Security (Version 2 Protocol)
- **Secret Key Authentication**: Uses a secret key stored in SavedVariables (NOT in source code)
- **HMAC-style Hash**: Each payload includes a secure hash created using the secret key
- **Nonce-based Replay Protection**: Each command includes a unique nonce to prevent replay attacks
- **Timestamp Validation**: Payloads expire after 5 minutes to prevent replay attacks
- **Character Validation**: Commands only work for the specified target character

### Command Validation
- Secret key must be set and match between admin panel and client
- Payload version must be 2 (version 1 is deprecated)
- Achievement must exist in the catalog
- Target character must match the current player
- Payload must be valid and not tampered with
- Nonce must be unique and not previously used

## Usage Instructions

### For Admins (You)

#### Initial Setup (One-Time)
1. **Set Admin Secret Key**: Type `/hca adminkey set <your-secret-key>` in chat
   - The key must be at least 16 characters long
   - Keep this key secret! Anyone with this key can send admin commands
   - Example: `/hca adminkey set MySuperSecretAdminKey12345`
2. **Verify Key is Set**: Type `/hca adminkey check` to verify the key is set

#### Sending Commands
1. **Open Admin Panel**: Type `/hcaadmin` or `/hcadmin` in chat
2. **Check Key Status**: Verify the secret key status indicator shows "Secret Key: Set" (green)
3. **Select Achievement**: Choose from the dropdown list of available achievements
4. **Enter Character Name**: Type the exact character name of the player
5. **Send Command**: Click "Send Command" to send the achievement completion

#### Managing Secret Key
- **Check Status**: `/hca adminkey check` - Check if secret key is set
- **Set Key**: `/hca adminkey set <key>` - Set the admin secret key (min 16 chars)
- **Clear Key**: `/hca adminkey clear` - Clear the admin secret key

### For Players
- Players don't need to do anything special
- The system automatically processes admin commands via whispers
- Achievement completion will show the normal toast notification

## Admin Panel Features

### UI Elements
- **Secret Key Status Indicator**: Shows whether the admin secret key is set (green) or not set (red)
- **Achievement Dropdown**: Lists all available achievements sorted by level
- **Character Input**: Text field for entering target character name
- **Force Update Checkbox**: Override existing completion and update points/level
- **Override Points Input**: Optional override for achievement points
- **Override Level Input**: Optional override for achievement level
- **Send Button**: Sends the admin command
- **Status Text**: Instructions for using the panel

### Logging
- All admin commands are logged to `HardcoreAchievementsDB.adminLog`
- Logs include timestamp, achievement ID, target character, and admin character
- Client-side commands are logged to `HardcoreAchievementsDB.adminCommands`

## Security Considerations

### Secret Key Management
- **Storage**: The secret key is stored in `HardcoreAchievementsDB.adminSecretKey` in SavedVariables
- **Security**: The key is NOT in source code, making it much harder to reverse engineer
- **Unique Keys**: Each admin should use a unique secret key
- **Key Length**: Minimum 16 characters recommended for security
- **Key Protection**: Keep your secret key secret! Anyone with access to your SavedVariables can see it

### Protocol Version
- **Version 2**: Current secure protocol using secret key authentication
- **Version 1**: Deprecated and no longer accepted

### Replay Protection
- **Nonces**: Each command includes a unique nonce (timestamp + random number)
- **Nonce Storage**: Used nonces are stored and checked to prevent reuse
- **Timestamp Validation**: Commands expire after 5 minutes
- **Future Timestamp Check**: Commands with timestamps more than 60 seconds in the future are rejected

### Hash Algorithm
- **HMAC-style**: Uses secret key + message + secret key format
- **Complex Hash**: Uses prime multipliers and multiple passes
- **Hex Output**: Returns hexadecimal hash for better security

## Installation

### For Your Local Version
1. Include both `AdminPanel.lua` and `CommandHandler.lua` in your TOC file
2. Ensure you have Ace3 libraries available
3. The admin panel will be available via `/hcaadmin` or `/hcadmin`

### For Player Versions
1. Include only `CommandHandler.lua` in the TOC file
2. Ensure you have Ace3 libraries available
3. Players will automatically receive and process admin commands

## Dependencies
- Ace3 (AceComm-3.0, AceSerializer-3.0)
- HardcoreAchievements core system

## Troubleshooting

### Common Issues
1. **"Admin secret key not set!"**: You must set the secret key first using `/hca adminkey set <key>`
2. **"Admin secret key not configured"**: The client doesn't have the secret key set (players need to set it too)
3. **"Invalid version (must be 2)"**: Using old version 1 protocol (upgrade to version 2)
4. **"Invalid authentication hash"**: Secret key mismatch between admin panel and client
5. **"Nonce already used (replay attack detected)"**: Command was replayed (should not happen normally)
6. **"Failed to deserialize admin command"**: The payload was corrupted or tampered with
7. **"Admin command rejected: Target character mismatch"**: The command was sent to the wrong character
8. **"Achievement not found"**: The achievement ID doesn't exist in the current catalog
9. **"Achievement already completed"**: The achievement is already marked as completed (use Force Update)

### Debug Information
- All admin commands and rejections are logged to chat
- Check the console for detailed error messages
- Admin logs are stored in the SavedVariables for audit purposes

## Future Enhancements
- Batch achievement completion
- Achievement revocation commands
- Web-based admin dashboard
- Enhanced logging and analytics
