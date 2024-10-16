#!/bin/bash

# Global options
set -e  # Exit on any error
[[ "$DEBUG" == "true" ]] && set -x  # Enable debug mode when DEBUG=true

source ./config.sh

# Function for logging messages with levels
log() {
  local level=$1
  shift
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*"
}

# Function to handle errors
error_exit() {
  log "ERROR" "$1"
  exit 1
}

# Function to check the exit status and handle failures
check_status() {
  if [[ $? -ne 0 ]]; then
    error_exit "$1"
  fi
}

create_team() {
  log "INFO" "Creating team $TEAM_NAME in the $ORG organization..."
  
  gh api -X POST "orgs/$ORG/teams" \
    -H "Accept: application/vnd.github+json" \
    -F name="$TEAM_NAME" \
    -F description="Team responsible for managing the website repository." \
    -F privacy="closed" || check_status "Failed to create team $TEAM_NAME."
}

add_user_to_team() {
  log "INFO" "Adding $USERNAME to the $TEAM_NAME team..."
  
  gh api -X PUT "orgs/$ORG/teams/$TEAM_NAME/memberships/$USERNAME" \
    -H "Accept: application/vnd.github+json" || check_status "Failed to add user $USERNAME to team $TEAM_NAME."
}

set_team_repo_permissions() {
  log "INFO" "Setting $TEAM_NAME team permissions to maintain for the $REPO repository..."
  
  gh api -X PUT "orgs/$ORG/teams/$TEAM_NAME/repos/$REPO" \
    -H "Accept: application/vnd.github+json" \
    -F permission="maintain" || check_status "Failed to set permissions for $TEAM_NAME on $REPO."
}

team_setup() {
  create_team
  add_user_to_team
  set_team_repo_permissions
  log "INFO" "Team setup and repository permissions complete!"
}

set_branch_protection() {
  log "INFO" "Setting branch protection rules for $BRANCH branch of $REPO..."
  
  tmpfile=$(mktemp)
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

  gh api -X PUT "repos/$REPO/branches/$BRANCH/protection" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    --input $tmpfile || check_status "Failed to set branch protection for $BRANCH."
  
  rm $tmpfile
}

set_default_branch() {
  log "INFO" "Setting default branch to $BRANCH for repository $REPO..."
  
  gh api -X PATCH "repos/$REPO" -F "default_branch=$BRANCH" || check_status "Failed to set default branch to $BRANCH for $REPO."
}

main() {
  team_setup
  set_branch_protection
  set_default_branch
  log "INFO" "Automation complete!"
}

# Run the main function
main
