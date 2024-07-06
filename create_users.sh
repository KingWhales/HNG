#!/bin/bash

# Log file and password storage file
LOGFILE="/var/log/user_management.log"
SECURE_PASSWORD_FILE="/var/secure/secure_user_passwords.txt"

# Function to generate a random password
generate_password() {
    echo $(openssl rand -base64 12)
}

# Ensure log and password files exist with secure permissions
touch $LOGFILE
touch $SECURE_PASSWORD_FILE
chmod 600 $LOGFILE
chmod 600 $SECURE_PASSWORD_FILE

# Check if the input file is provided as an argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <user_file>"
    exit 1
fi

USERFILE=$1

# Function to log actions
log_action() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a $LOGFILE
}

# Function to encrypt passwords
encrypt_password() {
    local password=$1
    echo "$password" | openssl enc -aes-256-cbc -a -salt -pass pass:$(openssl rand -base64 32)
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

    # Create personal group
    if ! getent group "$username" > /dev/null 2>&1; then
        groupadd "$username"
        if [ $? -eq 0 ]; then
            log_action "Group $username created"
        else
            log_action "Error: Failed to create group $username"
            continue
        fi
    else
        log_action "Group $username already exists"
    fi

    # Create user with personal group
    if ! id -u "$username" > /dev/null 2>&1; then
        useradd -m -g "$username" -G "$groups" "$username"
        if [ $? -eq 0 ]; then
            log_action "User $username created with groups $groups"

            # Generate and set password
            password=$(generate_password)
            echo "$username:$password" | chpasswd
            if [ $? -eq 0 ]; then
                log_action "Password set for $username"

                # Encrypt and save the password to the secure file
                encrypted_password=$(encrypt_password "$password")
                echo "$username:$encrypted_password" >> $SECURE_PASSWORD_FILE

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

    # Verify user and group creation
    if id -u "$username" > /dev/null 2>&1; then
        log_action "Verification: User $username exists"
        echo "Verification: User $username exists"
    else
        log_action "Verification: User $username does not exist"
        echo "Verification: User $username does not exist"
    fi

    if getent group "$username" > /dev/null 2>&1; then
        log_action "Verification: Group $username exists"
        echo "Verification: Group $username exists"
    else
        log_action "Verification: Group $username does not exist"
        echo "Verification: Group $username does not exist"
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

log_action "User creation process completed. Check $LOGFILE for details."
