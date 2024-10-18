#!/bin/bash

# run commands to execute the script
# chmod +x github-automation.sh
# chmod +x config.sh
# ./github-automation.sh

# Global options
set -e  # Exit script immediately on any command that exits with a non-zero status
[[ "$DEBUG" == "true" ]] && set -x  # Enable debug mode when DEBUG=true

# Load configuration values from an external file 'config.sh'
source ./config.sh

# Function to log messages with a timestamp and log level
# Arguments:
#   $1 - Log level (INFO, ERROR, etc.)
#   $* - Log message
log() {
  local level=$1  # Log level passed as the first argument
  shift  # Shift the argument so that $* refers to the rest of the arguments (the log message)
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*"  # Print log with timestamp and level
}
# output
# with shift [2023-10-05 12:34:56] [INFO] This is a log message
# without shift [2023-10-05 12:34:56] [INFO] INFO This is a log message


# Function to handle errors and exit the script
# Arguments:
#   $1 - Exit status code
error_exit() {
  log "ERROR" "$1"  # Log the error message with "ERROR" level
  exit $1  # Exit the script with the specified status code
}

# Function to check the exit status of the last command and handle failure
# Arguments:
#   $1 - Error message to display if the last command failed
check_status() {
  # $? is a special variable in shell scripting that holds the exit status of the last executed command.
  # An exit status of 0 typically means that the command was successful, while a non-zero exit status indicates an error.
  if [[ $? -ne 0 ]]; then  # Check if the exit status of the last command is non-zero (i.e., an error)
    # $1 refers to the first argument passed to the check_status function.
    # The error_exit function is called with the provided error message.
    # Without quotes around $1, if the error message contains spaces, it will be split into multiple arguments.
    error_exit "$1"  # Call the error_exit function with the provided error message, preserving spaces and special characters
  fi
  # The 'fi' keyword marks the end of the 'if' statement.
}

# Function to create a team in a GitHub organization
# Uses GitHub CLI (gh) to interact with the GitHub API
create_team() {
  log "INFO" "Creating team $TEAM_NAME in the $ORG organization..."
  
  gh api -X POST "orgs/$ORG/teams" \
    -H "Accept: application/vnd.github+json" \
    --field name="$TEAM_NAME" \
    --field description="Team responsible for managing the website repository." \
    --field privacy="closed" || check_status "Failed to create team $TEAM_NAME."
}



# Function to add a user to the created team
# Arguments:
#   $USERNAME - The GitHub username of the person to add to the team
add_user_to_team() {
  log "INFO" "Adding $USERNAME to the $TEAM_NAME team..."  # Log the action
  
  # Send a PUT request to add the user to the team
  gh api -X PUT "orgs/$ORG/teams/$TEAM_NAME/memberships/$USERNAME" \
    -H "Accept: application/vnd.github+json" || check_status "Failed to add user $USERNAME to team $TEAM_NAME."
}

# Function to set team permissions for a repository
# Arguments:
#   $REPO - The name of the repository
#   $TEAM_NAME - The team whose permissions are being set
set_team_repo_permissions() {
  log "INFO" "Setting $TEAM_NAME team permissions to $PERMISSION for the $REPO repository..."  # Log the action
  
  # Send a PUT request to set the team's repository permissions
  gh api -X PUT "orgs/$ORG/teams/$TEAM_NAME/repos/$REPO" \
    -H "Accept: application/vnd.github+json" \
    -F permission="$PERMISSION" || check_status "Failed to set permissions for $TEAM_NAME on $REPO."
}

# Function to orchestrate team setup
# Creates a team, adds a user to it, and sets the team's permissions on a repository
team_setup() {
  create_team  # Call the function to create a team
  add_user_to_team  # Call the function to add a user to the team
  set_team_repo_permissions  # Call the function to set repository permissions for the team
  log "INFO" "Team setup and repository permissions complete!"  # Log that setup is complete
}

# Function to set branch protection rules for a repository branch
# Arguments:
#   $BRANCH - The branch name (e.g., "main")
set_branch_protection() {
  log "INFO" "Setting branch protection rules for $BRANCH branch of $REPO..."  # Log the action
  
  # Create a temporary file to hold the branch protection rules JSON
  tmpfile=$(mktemp)
  
  # Write the branch protection rules to the temporary file
  cat <<EOF > $tmpfile
{
  "required_status_checks": {
    "strict": true,
    "contexts": []
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1
  },
  "restrictions": {
    "users": [],
    "teams": ["$TEAM_NAME"],
    "apps": []
  },
  "allow_deletions": false,
  "allow_force_pushes": false
}
EOF

  # Send a PUT request to set the branch protection rules for the specified branch
  gh api -X PUT "repos/$REPO/branches/$BRANCH/protection" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    --input $tmpfile || check_status "Failed to set branch protection for $BRANCH."
  
  # Remove the temporary file after use
  rm $tmpfile
}

# Function to set the default branch of a repository
# Arguments:
#   $BRANCH - The branch to set as the default
set_default_branch() {
  log "INFO" "Setting default branch to $BRANCH for repository $REPO..."  # Log the action
  
  # Send a PATCH request to update the default branch of the repository
  gh api -X PATCH "repos/$REPO" -F "default_branch=$BRANCH" || check_status "Failed to set default branch to $BRANCH for $REPO."
}


print_final_message() {
  log "INFO" "Automation complete!"
  
  # Print script location and execution directory
  echo "The script is located in: $(realpath "$0")"  # realpath "$0" to get the full path of the script (where the script is located).
  echo "The script is executed from: $(pwd)" # pwd to get the current working directory (where the script is being executed from).
}

# Main function to coordinate the script's operations
main() {
  team_setup  # Call the function to set up the team
  set_branch_protection  # Call the function to set branch protection rules
  set_default_branch  # Call the function to set the default branch for the repository
  print_final_message  # Call the function to print the final message
}



# Run the main function
main
