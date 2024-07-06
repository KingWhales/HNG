#!/bin/bash

# Log file and password storage file
LOGFILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Function to generate a random password
generate_password() {
    openssl rand -base64 12
}

# Ensure log and password files exist
touch $LOGFILE
touch $PASSWORD_FILE

# Check if the input file is provided as an argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <user_file>"
    exit 1
fi

USERFILE=$1

# Function to log actions
log_action() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> $LOGFILE
}

# Read the input file line by line
while IFS=';' read -r username groups; do
    # Remove leading/trailing whitespace
    username=$(echo "$username" | xargs)
    groups=$(echo "$groups" | xargs)

    # Validate username
    if [ -z "$username" ]; then
        log_action "Error: Empty username found. Skipping line."
        continue
    fi

    # Create personal group if it does not exist
    if ! getent group "$username" > /dev/null 2>&1; then
        groupadd "$username"
        log_action "Group $username created"
    else
        log_action "Group $username already exists"
    fi

    # Create user with personal group if user does not exist
    if ! id -u "$username" > /dev/null 2>&1; then
        useradd -m -g "$username" -G "$groups" "$username"
        if [ $? -eq 0 ]; then
            log_action "User $username created with groups $groups"

            # Generate and set password
            password=$(generate_password)
            echo "$username:$password" | chpasswd
            if [ $? -eq 0 ]; then
                log_action "Password set for $username"

                # Save the password to the secure file
                echo "$username:$password" >> $PASSWORD_FILE

                # Set home directory permissions
                chmod 700 /home/"$username"
                chown "$username:$username" /home/"$username"
                log_action "Home directory permissions set for $username"
            else
                log_action "Error: Failed to set password for $username"
            fi
        else
            log_action "Error: Failed to create user $username"
        fi
    else
        log_action "User $username already exists"
    fi

    # Verify the user is in their personal group
    user_groups=$(id -nG "$username" | xargs)
    if [[ "$user_groups" == *"$username"* ]]; then
        log_action "User $username is in their personal group $username"
    else
        log_action "Warning: User $username is NOT in their personal group $username"
    fi

done < "$USERFILE"

# Output the required format
echo "Username;Groups"
while IFS=';' read -r username groups; do
    username=$(echo "$username" | xargs)
    groups=$(echo "$groups" | xargs)
    if [ -n "$username" ]; then
        echo "$username;$groups"
    fi
done < "$USERFILE"

echo "User creation process completed. Check $LOGFILE for details."
