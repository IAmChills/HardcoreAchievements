# HardcoreAchievements Admin Panel Deployment Guide

## Overview
This guide explains how to deploy the admin panel system for your HardcoreAchievements addon.

## File Organization

### Your Local Version (Admin Panel Enabled)
Include these files in your local TOC:
```
Functions\GetUHCPreset.lua
HardcoreAchievements.lua
Achievements\Common.lua
Achievements\Catalog.lua
Achievements\FourCandles.lua
Utils\Embed_UltraHardcore.lua
CommandHandler.lua
AdminPanel.lua
AdminPanelTest.lua
```

### Player Versions (Admin Panel Disabled)
Include these files in player TOC:
```
Functions\GetUHCPreset.lua
HardcoreAchievements.lua
Achievements\Common.lua
Achievements\Catalog.lua
Achievements\FourCandles.lua
Utils\Embed_UltraHardcore.lua
CommandHandler.lua
```

## Installation Steps

### Step 1: Prepare Your Local Version
1. Copy all the new files to your local HardcoreAchievements folder
2. Update your local TOC file to include all files
3. Ensure you have Ace3 libraries available

### Step 2: Prepare Player Versions
1. Create a copy of your addon for distribution
2. Remove `AdminPanel.lua` and `AdminPanelTest.lua` from the TOC
3. Keep `CommandHandler.lua` in the TOC
4. Distribute this version to players

### Step 3: Test the System
1. Load your local version in-game
2. Type `/hcatest` to run the test suite
3. Type `/hcaadmin` to open the admin panel
4. Test sending a command to yourself

## Security Configuration

### Admin Signature
Before deploying, change the admin signature in both files:
- `AdminPanel.lua` line 8: `local ADMIN_SIGNATURE = "HC_ADMIN_2024"`
- `CommandHandler.lua` line 8: `local ADMIN_SIGNATURE = "HC_ADMIN_2024"`

Choose a unique signature that only you know.

### Whisper Prefix
The whisper prefix uses hidden characters. You can change this if needed:
- `AdminPanel.lua` line 9: `local WHISPER_PREFIX = "\127\127"`
- `CommandHandler.lua` line 9: `local WHISPER_PREFIX = "\127\127"`

## Usage Workflow

### For Appeals
1. Player contacts you with an appeal
2. You open the admin panel (`/hcaadmin`)
3. Select the achievement they completed
4. Enter their character name
5. Send the command
6. Player receives the achievement completion

### For Testing
1. Use `/hcatest` to verify the system is working
2. Test with a friend or alt character
3. Verify the achievement completion works correctly

## Monitoring and Logs

### Admin Logs
All admin commands are logged to `HardcoreAchievementsDB.adminLog`:
- Timestamp
- Achievement ID
- Target character
- Admin character

### Client Logs
All received commands are logged to `HardcoreAchievementsDB.adminCommands`:
- Timestamp
- Achievement ID
- Admin signature
- Payload hash

## Troubleshooting

### Common Issues
1. **Ace3 libraries not found**: Ensure Ace3 is installed
2. **Admin panel not opening**: Check TOC file includes AdminPanel.lua
3. **Commands not working**: Verify both files have the same admin signature
4. **Achievement not found**: Check the achievement ID exists in the catalog

### Debug Commands
- `/hcatest` - Run system tests
- `/hcaadmin` - Open admin panel
- Check chat logs for error messages

## Security Best Practices

1. **Keep Admin Panel Local**: Never distribute the admin panel to players
2. **Use Unique Signatures**: Change the admin signature to something unique
3. **Monitor Logs**: Regularly check admin logs for suspicious activity
4. **Limit Access**: Only use the admin panel for legitimate appeals
5. **Test Thoroughly**: Always test commands before sending to players

## Future Enhancements

Consider these improvements for future versions:
- Web-based admin dashboard
- Batch achievement operations
- Achievement revocation system
- Enhanced logging and analytics
- Player appeal submission system

## Support

If you encounter issues:
1. Check the console for error messages
2. Run `/hcatest` to verify system status
3. Check the logs in SavedVariables
4. Verify all files are properly included in the TOC
