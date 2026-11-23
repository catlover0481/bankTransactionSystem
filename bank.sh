#!/bin/bash

# Load modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/auth.sh"
source "$SCRIPT_DIR/transactions.sh"

# Ensure database directory and file exist with restricted permissions
init_db() {
    local db_dir
    db_dir=$(dirname "$DB_FILE")

    if [[ ! -d "$db_dir" ]]; then
        mkdir -p "$db_dir" || {
            echo -e "${ERROR} Failed to create database directory: $db_dir"
            exit 1
        }
    fi

    if [[ ! -f "$DB_FILE" ]]; then
        (
            umask 077
            touch "$DB_FILE"
        ) || {
            echo -e "${ERROR} Failed to create database file: $DB_FILE"
            exit 1
        }
    fi
}

show_menu() {
    echo ""
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}         BASH BANKING SYSTEM          ${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo "1. Register Account"
    echo "2. Check Balance"
    echo "3. Deposit Funds"
    echo "4. Withdraw Funds"
    echo "5. Change PIN"
    echo "6. Exit"
    echo -e "${BLUE}======================================${NC}"
}

init_db

while true; do
    show_menu
    read -r -p "Choose an option [1-6]: " choice

    case "$choice" in
        1) register_account ;;
        2) check_balance ;;
        3) deposit_funds ;;
        4) withdraw_funds ;;
        5) change_pin ;;
        6)
            echo -e "${INFO} Thank you for banking with us."
            exit 0
            ;;
        *)
            echo -e "${ERROR} Invalid option. Please choose between 1 and 6."
            ;;
    esac

    read -r -p "Press Enter to continue..."
done