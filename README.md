# HNG

# Creating Users with a Bash Script in a SysOps Environment

As a SysOps engineer, managing user accounts and ensuring their proper setup is a critical task, especially when onboarding new developers. In this article, we will explore a bash script designed to automate the process of creating user accounts, setting up home directories, assigning groups, and handling passwords securely.

Requirements
Our script `create_users.sh` will:

### Read Input: It reads from a text file containing the usernames and group names, formatted as user; groups.
### Create Users and Groups: It ensures each user has a personal group, and users can belong to multiple additional groups.
### Setup Home Directories: It sets up home directories with appropriate permissions and ownership.
### Generate Passwords: It generates random passwords for users.
### Logging: It logs all actions to /var/log/user_management.log.
### Store Passwords Securely: It stores generated passwords securely in /var/secure/user_passwords.txt.
###Error Handling: It includes error handling for scenarios like existing users.


##Script Breakdown

# Here’s a step-by-step breakdown of the create_users.sh script:

# Initialization:
##bash
```
#!/bin/bash  
LOGFILE="/var/log/user_management.log" 
PASSFILE="/var/secure/user_passwords.txt"
```
# 2. Password Generation Function:

##bash
```
generate_password() 
{ echo $(openssl rand -base64 12) }
```

3. File Check and Logging Setup:

## bash
```
touch $LOGFILE 
touch $PASSFILE  
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <user_file>"     
  exit 1 
fi  
USERFILE=$1
```
# 4. Processing the Input File:

bash
```
while IFS=';' read -r username groups; do     
username=$(echo "$username" | xargs)     
groups=$(echo "$groups" | xargs)
```

# 5. Creating Groups and Users:

bash
```
if ! getent group "$username" > /dev/null 2>&1; then
    groupadd "$username"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Group $username created" >> $LOGFILE
fi

if ! id -u "$username" > /dev/null 2>&1; then
    useradd -m -g "$username" -G "$groups" "$username"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - User $username created with groups $groups" >> $LOGFILE

    password=$(generate_password)
    echo "$username:$password" | chpasswd
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Password set for $username" >> $LOGFILE
    echo "$username:$password" >> $PASSFILE

    chmod 700 /home/"$username"
    chown "$username:$username" /home/"$username"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Home directory permissions set for $username" >> $LOGFILE
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - User $username already exists" >> $LOGFILE
fi

done < "$USERFILE"

echo "User creation process completed. Check $LOGFILE for details."
```

Conclusion
This script ensures that new user accounts are created efficiently and securely, adhering to best practices in system administration. It simplifies the onboarding process, maintains security, and provides detailed logging for accountability.

To develop your tech career, check out https://hng.tech/internship or https://hng.tech/hire.





