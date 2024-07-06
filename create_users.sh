#!/bin/bash

# Log file and password storage file
LOGFILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"

ENCRYPTED_PASSWORD_FILE="/var/secure/user_passwords.csv.gpg"
GPG_RECIPIENT="olawaleafosi@gmail.com"

# Function to generate a random password
generate_password() {
    echo $(openssl rand -base64 12)
}

# Ensure log and password files exist
sudo touch $LOGFILE
sudo touch $PASSWORD_FILE
sudo chmod 600 $PASSWORD_FILE

# Check if the input file is provided as an argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <user_file>"
    exit 1
fi

USERFILE=$1

# Function to log actions
log_action() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | sudo tee -a $LOGFILE
}

# Function to encrypt password file
encrypt_password_file() {
    sudo gpg --yes --batch --recipient $GPG_RECIPIENT --output $ENCRYPTED_PASSWORD_FILE --encrypt $PASSWORD_FILE
    sudo shred -u $PASSWORD_FILE
}

# Decrypt the password file if it exists
if [ -f $ENCRYPTED_PASSWORD_FILE ]; then
    sudo gpg --decrypt $ENCRYPTED_PASSWORD_FILE > $PASSWORD_FILE
fi

# Ensure the password file exists with proper permissions
sudo touch $PASSWORD_FILE
sudo chmod 600 $PASSWORD_FILE

# Read the input file line by line and create groups
while IFS=';' read -r username groups; do
    # Remove leading/trailing whitespace
    username=$(echo "$username" | xargs)

    # Debugging output
    echo "Read username: '$username'"
    echo "Read groups: '$groups'"

    # Validate username
    if [ -z "$username" ]; then
        log_action "Error: Empty username found. Skipping line."
        continue
    fi

    # Create user
    if ! id -u "$username" > /dev/null 2>&1; then
        sudo useradd -m "$username"
        if [ $? -eq 0 ]; then
            log_action "User $username created"

            # Generate and set password
            password=$(generate_password)
            echo "$username:$password" | sudo chpasswd
            if [ $? -eq 0 ]; then
                log_action "Password set for $username"

                # Save the password securely
                echo "$username:$password" | sudo tee -a $PASSWORD_FILE > /dev/null

                # Encrypt the password file
                encrypt_password_file

                # Set home directory permissions
                sudo chmod 700 /home/"$username"
                sudo chown "$username:$username" /home/"$username"
                log_action "Home directory permissions set for $username"
            else
                log_action "Error: Failed to set password for $username"
            fi
        else
            log_action "Error: Failed to create user $username. Check permissions."
            continue
        fi
    else
        log_action "User $username already exists"
    fi

    # Verify additional groups
    for group in $(echo $groups | tr "," "\n"); do
        # Create group if it doesn't exist
        if ! getent group "$group" > /dev/null 2>&1; then
            sudo groupadd "$group"
            if [ $? -eq 0 ]; then
                log_action "Group $group created"
            else
                log_action "Error: Failed to create group $group. Check permissions."
                continue
            fi
        else
            log_action "Group $group already exists"
        fi

        # Add user to the group
        sudo usermod -aG "$group" "$username"
        if [ $? -eq 0 ]; then
            log_action "User $username added to group $group"
        else
            log_action "Error: Failed to add user $username to group $group"
        fi
    done

done < "$USERFILE"

# Encrypt password file one last time before finishing
encrypt_password_file

# Output the required format
echo "Users and Groups created:"
echo "Username;Groups"
while IFS=';' read -r username groups; do
    username=$(echo "$username" | xargs)
    if [ -n "$username" ]; then
        echo "$username;$groups"
    fi
done < "$USERFILE"

echo "User, Group creation, and Password storage process completed. Check $LOGFILE for details."
