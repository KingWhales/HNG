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

# Decrypt the password file if it exists
if [ -f $ENCRYPTED_PASSWORD_FILE ]; then
    sudo gpg --decrypt $ENCRYPTED_PASSWORD_FILE > $PASSWORD_FILE
fi

# Ensure the password file exists with proper permissions
sudo touch $PASSWORD_FILE
sudo chmod 600 $PASSWORD_FILE

# Read the input file line by line and create users
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

                # Save the password to the secure file
                echo "$username:$password" | sudo tee -a $PASSWORD_FILE > /dev/null

                # Encrypt the password file
                sudo gpg --yes --batch --recipient $GPG_RECIPIENT --output $ENCRYPTED_PASSWORD_FILE --encrypt $PASSWORD_FILE
                sudo shred -u $PASSWORD_FILE

                # Set home directory permissions
                sudo chmod 700 /home/"$username"
                sudo chown "$username:$username" /home/"$username"
                log_action "Home directory permissions set for $username"
            else
                log_action "Error: Failed to set password for $username"
            fi
        else
            log_action "Error: Failed to create user $username. Check permissions."
        fi
    else
        log_action "User $username already exists"
    fi

done < "$USERFILE"

# Output the required format
echo "Users created:"
echo "Username"
while IFS=';' read -r username groups; do
    username=$(echo "$username" | xargs)
    if [ -n "$username" ]; then
        echo "$username"
    fi
done < "$USERFILE"

echo "User creation process completed. Check $LOGFILE for details."
