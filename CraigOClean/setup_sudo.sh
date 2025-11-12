#!/bin/bash

# Craig-O-Clean Sudo Setup Script
# This script helps configure passwordless sudo for the purge command

echo "================================================"
echo "Craig-O-Clean - Sudo Configuration Setup"
echo "================================================"
echo ""
echo "This script will configure passwordless sudo access"
echo "for the 'purge' and 'sync' commands."
echo ""
echo "This allows Craig-O-Clean to purge memory without"
echo "prompting for your password each time."
echo ""

# Get the current username
CURRENT_USER=$(whoami)

echo "Current user: $CURRENT_USER"
echo ""
echo "This will add the following line to your sudoers file:"
echo "$CURRENT_USER ALL=(ALL) NOPASSWD: /usr/bin/purge, /bin/sync"
echo ""

# Ask for confirmation
read -p "Do you want to proceed? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Setup cancelled."
    exit 1
fi

echo ""
echo "Creating sudoers entry..."

# Create a temporary file with the sudoers entry
TEMP_FILE=$(mktemp)
echo "$CURRENT_USER ALL=(ALL) NOPASSWD: /usr/bin/purge, /bin/sync" > "$TEMP_FILE"

# Use visudo to validate and install the sudoers file
# This creates a separate file in /etc/sudoers.d/ which is safer than editing the main sudoers file
sudo sh -c "visudo -c -f '$TEMP_FILE' && cp '$TEMP_FILE' /etc/sudoers.d/craig-o-clean && chmod 0440 /etc/sudoers.d/craig-o-clean"

# Check if the operation was successful
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Success! Sudoers configuration has been updated."
    echo ""
    echo "Testing the configuration..."
    
    # Test the sudo access
    if sudo -n purge 2>/dev/null; then
        echo "✅ Test passed! You can now use Craig-O-Clean without password prompts."
    else
        echo "⚠️  Test failed. You may need to restart your terminal or log out and back in."
    fi
    
    echo ""
    echo "You can now run Craig-O-Clean and use the Purge Memory feature"
    echo "without entering your password."
    echo ""
    echo "If you want to remove this configuration later, run:"
    echo "sudo rm /etc/sudoers.d/craig-o-clean"
else
    echo ""
    echo "❌ Failed to update sudoers configuration."
    echo "Please check the error messages above."
    echo ""
    echo "You can try manually editing with: sudo visudo"
fi

# Clean up
rm -f "$TEMP_FILE"

echo ""
echo "Setup complete!"
