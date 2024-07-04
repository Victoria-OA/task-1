#!/bin/bash

# Define log file and password storage locations
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Create log file and password file with secure permissions (read/write only for owner)
mkdir -p /var/secure
touch "$LOG_FILE" "$PASSWORD_FILE" 2>/dev/null
chmod 600 "$PASSWORD_FILE" 2>/dev/null

# Function to log messages to the log file and console for debugging
log_message() {
  echo "$(date) - $1" | tee -a "$LOG_FILE"
}

# Function to create a user and group with proper permissions
create_user_and_group() {
  username="$1"
  groups="$2"

  # Check if user already exists
  if id "$username" &> /dev/null; then
    log_message "User $username already exists."
    return 1  # Exit function with error code 1
  fi

  # Create the user's primary group with the same name as the username
  if ! getent group "$username" &> /dev/null; then
    groupadd "$username" &>> "$LOG_FILE"
    log_message "Primary group $username created."
  else
    log_message "Primary group $username already exists."
  fi

  # Create the user with a random password
  password=$(head /dev/urandom | tr -dc A-Za-z0-9 | fold -w 12 | head -n 1)
  useradd -m -g "$username" -s /bin/bash "$username" &>> "$LOG_FILE"
  log_message "User $username added to primary group $username."

  # Set the user's password and store it securely
  echo "$username,$password" >> "$PASSWORD_FILE"
  echo "$username:$password" | chpasswd &>> "$LOG_FILE"
  log_message "Password for user $username set and stored securely."

  # Create additional groups if they don't exist and add user to these groups
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

# Read user data from the file provided as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <user_file>"
  exit 1
fi

user_file="$1"

if [ ! -f "$user_file" ]; then
  echo "File $user_file not found!"
  exit 1
fi

# Pre-create all groups to avoid usermod errors
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

# Create users and assign groups
while IFS=";" read -r username groups; do
  # Trim any leading or trailing whitespace from username and groups
  username=$(echo "$username" | xargs)
  groups=$(echo "$groups" | xargs)
  create_user_and_group "$username" "$groups"
done < "$user_file"

echo "User creation process completed. Check $LOG_FILE for details."
