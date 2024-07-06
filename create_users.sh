pub   rsa3072 2024-07-06 [SC] [expires: 2026-07-06]
      83D1D207F3C3C615223C6F53549570432410CDB2
uid                      Muideen Afosi <olawaleafosi@gmail.com>
sub   rsa3072 2024-07-06 [E] [expires: 2026-07-06]


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
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a $LOGFILE
}

# Decrypt the password file if it exists
if [ -f $ENCRYPTED_PASSWORD_FILE ]; then
            gpg --decrypt $ENCRYPTED_PASSWORD_FILE > $PASSWORD_FILE
fi

# Ensure the password file exists with proper permissions
touch $PASSWORD_FILE
chmod 600 $PASSWORD_FILE

# Read the input file line by line
while IFS=';' read -r user groups; do
        # Remove leading/trailing whitespace
        user=$(echo "$user" | xargs)
        groups=$(echo "$groups" | xargs)

        Debugging output
        echo "Read user: '$user'"
        echo "Read groups: '$groups'"

        # Validate username
        if [ -z "$user" ]; then
                log_action "Error: Empty user found. Skipping line."
                continue
        fi

        # Create personal group
        if ! getent group "$user" > /dev/null 2>&1; then
                groupadd "$user"
                log_action "Group $user created"
        else
                log_action "Group $user already exists"
        fi

        # Create user with personal group
        if ! id -u "$user" > /dev/null 2>&1; then
                useradd -m -g "$user" -G "$groups" "$user"
                if [ $? -eq 0 ]; then
                        log_action "User $user created with groups $groups"

                        # Generate and set password
                        password=$(generate_password)
                        echo "$user:$password" | chpasswd
                        if [ $? -eq 0 ]; then
                                log_action "Password set for $user"

                                # Save the password to the secure file
                                echo "$user:$password" >> $PASSWORD_FILE

                                # Encrypt the password file
                                gpg --yes --batch --recipient $GPG_RECIPIENT --output $ENCRYPTED_PASSWORD_FILE --encrypt $PASSWORD_FILE
                                shred -u $PASSWORD_FILE

                                # Set home directory permissions
                                chmod 700 /home/"$user"
                                chown "$user:$user" /home/"$user"
                                log_action "Home directory permissions set for $user"
                        else
                                log_action "Error: Failed to set password for $user"
                        fi
                else
                        log_action "Error: Failed to create user $user"
                fi
        else
                log_action "User $user already exists"
        fi

        # Check if the user belongs to their personal group
        if id -nG "$user" | grep -qw "$user"; then
                log_action "User $user belongs to their personal group $user"
        else
                log_action "Error: User $user does not belong to their personal group $user"
        fi

done < "$USERFILE"

# Output the required format
echo "User;Groups"
while IFS=';' read -r username groups; do
        user=$(echo "$user" | xargs)
        groups=$(echo "$groups" | xargs)
        if [ -n "$user" ]; then
                echo "$user;$groups"
        fi
done < "$USERFILE"

echo "User creation process completed. Check $LOGFILE for details."
