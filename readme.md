## Table of Contents

1. [Step-by-Step Process](#step-by-step-process)
   - [Setting Up Logging and Password Storage](#setting-up-logging-and-password-storage)
   - [Logging Function](#logging-function)
   - [User and Group Creation Function](#user-and-group-creation-function)
   - [Reading User Data](#reading-user-data)
   - [Pre-Creating Groups](#pre-creating-groups)
   - [Creating Users and Assigning Groups](#creating-users-and-assigning-groups)
2. [Conclusion](#conclusion)



Setting Up Logging and Password Storage
We define the locations for the log file and the password file and ensure they have the correct permissions in a script called _**create_users.sh**_

```bash
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"

mkdir -p /var/secure
touch "$LOG_FILE" "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"
```

Logging Function
A function log_message logs messages to both the log file and the console for debugging purposes.

```bash
log_message() {
  echo "$(date) - $1" | tee -a "$LOG_FILE"
}
```

User and Group Creation Function
The create_user_and_group function handles the creation of users and groups, assigns a random password, and adds the user to the specified groups.

```bash
create_user_and_group() {
  username="$1"
  groups="$2"

  if id "$username" &> /dev/null; then
    log_message "User $username already exists."
    return 1
  fi

  if ! getent group "$username" &> /dev/null; then
    groupadd "$username" &>> "$LOG_FILE"
    log_message "Primary group $username created."
  else
    log_message "Primary group $username already exists."
  fi

  password=$(head /dev/urandom | tr -dc A-Za-z0-9 | fold -w 12 | head -n 1)
  useradd -m -g "$username" -s /bin/bash "$username" &>> "$LOG_FILE"
  log_message "User $username added to primary group $username."

  echo "$username,$password" >> "$PASSWORD_FILE"
  echo "$username:$password" | chpasswd &>> "$LOG_FILE"
  log_message "Password for user $username set and stored securely."

  IFS=',' read -ra group_array <<< "$groups"
  for group in "${group_array[@]}"; do
    if ! getent group "$group" &> /dev/null; then
      groupadd "$group" &>> "$LOG_FILE"
      log_message "Group $group created."
    fi
    usermod -a -G "$group" "$username" &>> "$LOG_FILE"
    log_message "User $username added to group $group."
  done

  log_message "User $username created successfully."
}
```

Reading User Data
The script reads user data from a specified file and processes each line to create users and groups.

```bash
if [ -z "$1" ]; then
  echo "Usage: $0 <user_file>"
  exit 1
fi

user_file="$1"

if [ ! -f "$user_file" ]; then
  echo "File $user_file not found!"
  exit 1
fi
```

Pre-Creating Groups
To avoid errors when adding users to groups, we pre-create all groups mentioned in the file.

``` bash
declare -A groups_map

while IFS=";" read -r username groups; do
  IFS=',' read -ra group_array <<< "$groups"
  for group in "${group_array[@]}"; do
    groups_map["$group"]=1
  done
done < "$user_file"

for group in "${!groups_map[@]}"; do
  if ! getent group "$group" &> /dev/null; then
    groupadd "$group" &>> "$LOG_FILE"
    log_message "Pre-created group $group."
  fi
done
```

Creating Users and Assigning Groups
Finally, we iterate through the user file and call the create_user_and_group function for each user.

```bash
while IFS=";" read -r username groups; do
  username=$(echo "$username" | xargs)
  groups=$(echo "$groups" | xargs)
  create_user_and_group "$username" "$groups"
done < "$user_file"

echo "User creation process completed. Check $LOG_FILE for details."
```

to run the Script, make it executable and run it
_note: users.txt is the file that contains your users and groups_ 
_```bash tife; security,developer
seun; developers,designer
esther; writer
lola; designer
```_

```bash
chmod +x create_users.sh

sudo ./create_users.sh users.txt
```

Verify the Output by checking the logs and password file:

```bash
sudo cat /var/log/user_management.log
sudo cat /var/secure/user_passwords.csv
ls -l /var/secure/user_passwords.csv
```

This should create the users and groups as specified, and log the actions properly.


![image](Screenshot%20from%202024-07-03%2022-46-03.png)



Conclusion
This script automates the process of user and group management, ensuring efficiency and consistency. For more information on similar projects and learning opportunities, check out the HNG Internship: https://hng.tech/internship and HNG Premium: https://hng.tech/premium

For further inquiries, feel free to reach out, and happy automating!

