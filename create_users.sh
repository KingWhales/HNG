#!/bin/bash

# Log file and password storage file
LOGFILE="/var/log/user_management.log"
SECURE_PASSWORD_FILE="/var/secure/secure_user_passwords.txt"

# Function to generate a random password securely
generate_password() {
    openssl rand -base64 12
}

# Ensure log and password files exist with secure permissions
touch "$LOGFILE" "$SECURE_PASSWORD_FILE"
chmod 600 "$LOGFILE" "$SECURE_PASSWORD_FILE"

# Function to log actions
log_action() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOGFILE"
}

# Function to encrypt passwords securely
encrypt_password() {
    local password=$1
    echo "$password" | openssl enc -aes-256-cbc -a -salt -pass pass:$(openssl rand -base64 32)
}

# Check if the input file is provided as an argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <user_file>"
    exit 1
fi

USERFILE="$1"

# Read the input file line by line
while IFS=';' read -r user groups; do
    # Remove leading/trailing whitespace
    user=$(echo "$user" | xargs)
    groups=$(echo "$groups" | xargs)

    # Validate username
    if [ -z "$user" ]; then
        log_action "Error: Empty username found. Skipping line."
        continue
    fi

    # Create personal group if not exists
    if ! getent group "$user" > /dev/null 2>&1; then
        groupadd "$user"
        if [ $? -eq 0 ]; then
            log_action "Group $user created"
        else
            log_action "Error: Failed to create group $user"
            continue
        fi
    else
        log_action "Group $user already exists"
    fi

    # Create user with home directory and primary group
    if ! id -u "$user" > /dev/null 2>&1; then
        useradd -m -g "$user" -G "$groups" -d "/home/$user" -s "/bin/bash" "$user"
        if [ $? -eq 0 ]; then
            log_action "User $user created with home directory /home/$user and groups $groups"

            # Generate and set password
            password=$(generate_password)
            echo "$user:$password" | chpasswd
            if [ $? -eq 0 ]; then
                log_action "Password set for $user"

                # Encrypt and save the password to the secure file
                encrypted_password=$(encrypt_password "$password")
                echo "$user:$encrypted_password" >> "$SECURE_PASSWORD_FILE"

                # Set home directory permissions
                chmod 700 "/home/$user"
                chown "$user:$user" "/home/$user"
                log_action "Home directory permissions set for $user"

                # Verify user creation
                if id -u "$user" > /dev/null 2>&1; then
                    log_action "Verification: User $user exists"
                else
                    log_action "Verification: User $user does not exist"
                fi

                # Verify group membership
                for group in $groups; do
                    if groups "$user" | grep -q "\b$group\b"; then
                        log_action "Verification: User $user belongs to group $group"
                    else
                        log_action "Verification: User $user does not belong to group $group"
                    fi
                done
            else
                log_action "Error: Failed to set password for $user"
            fi
        else
            log_action "Error: Failed to create user $user"
        fi
    else
        log_action "User $user already exists"
    fi
done < "$USERFILE"

log_action "User creation process completed. Check $LOGFILE for details."
