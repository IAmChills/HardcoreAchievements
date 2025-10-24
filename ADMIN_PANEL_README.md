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

### Payload Security
- **Admin Signature**: Each payload includes a unique admin signature that only your panel knows
- **Timestamp Validation**: Payloads expire after 5 minutes to prevent replay attacks
- **Hash Validation**: Each payload includes a hash to detect tampering
- **Character Validation**: Commands only work for the specified target character

### Command Validation
- Achievement must exist in the catalog
- Achievement must not already be completed
- Target character must match the current player
- Payload must be valid and not tampered with

## Usage Instructions

### For Admins (You)
1. **Open Admin Panel**: Type `/hcaadmin` or `/hcadmin` in chat
2. **Select Achievement**: Choose from the dropdown list of available achievements
3. **Enter Character Name**: Type the exact character name of the player
4. **Send Command**: Click "Send Command" to send the achievement completion

### For Players
- Players don't need to do anything special
- The system automatically processes admin commands via whispers
- Achievement completion will show the normal toast notification

## Admin Panel Features

### UI Elements
- **Achievement Dropdown**: Lists all available achievements sorted by level
- **Character Input**: Text field for entering target character name
- **Send Button**: Sends the admin command
- **Status Text**: Instructions for using the panel

### Logging
- All admin commands are logged to `HardcoreAchievementsDB.adminLog`
- Logs include timestamp, achievement ID, target character, and admin character
- Client-side commands are logged to `HardcoreAchievementsDB.adminCommands`

## Security Considerations

### Admin Signature
The admin signature is set to `"HC_ADMIN_2024"` in both files. You should change this to something unique to you.

### Whisper Prefix
Commands use hidden characters (`\127\127`) as a prefix to make them invisible to players.

### Rate Limiting
The system includes timestamp validation to prevent replay attacks.

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
1. **"Failed to deserialize admin command"**: The payload was corrupted or tampered with
2. **"Admin command rejected: Target character mismatch"**: The command was sent to the wrong character
3. **"Achievement not found"**: The achievement ID doesn't exist in the current catalog
4. **"Achievement already completed"**: The achievement is already marked as completed

### Debug Information
- All admin commands and rejections are logged to chat
- Check the console for detailed error messages
- Admin logs are stored in the SavedVariables for audit purposes

## Future Enhancements
- Batch achievement completion
- Achievement revocation commands
- Web-based admin dashboard
- Enhanced logging and analytics
