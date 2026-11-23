#!/bin/bash

# Load configuration and authentication helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/auth.sh"

# Helper: Fetch account line and verify PIN
authenticate_account() {
    local acc_no="$1"
    local pin="$2"

    if [[ ! "$acc_no" =~ ^[0-9]+$ ]]; then
        echo -e "${ERROR} Invalid account number."
        return 1
    fi

    if [[ ! -f "$DB_FILE" ]]; then
        echo -e "${ERROR} Account database not found."
        return 1
    fi

    local line
    line=$(awk -F'|' -v id="$acc_no" '$1 == id {print; exit}' "$DB_FILE")

    if [[ -z "$line" ]]; then
        echo -e "${ERROR} Account not found!"
        return 1
    fi

    local account name balance salt stored_hash computed_hash
    IFS='|' read -r account name balance salt stored_hash <<< "$line"

    computed_hash=$(hash_pin "$pin" "$salt")

    if [[ "$computed_hash" != "$stored_hash" ]]; then
        echo -e "${ERROR} Incorrect PIN!"
        return 1
    fi

    AUTH_ACCOUNT="$account"
    AUTH_NAME="$name"
    AUTH_BALANCE="$balance"
    AUTH_SALT="$salt"
    AUTH_HASH="$stored_hash"
    return 0
}

# Helper: Atomically update balance in DB_FILE
update_balance_in_db() {
    local acc_no="$1"
    local new_balance="$2"
    local temp_file

    temp_file=$(mktemp) || return 1

    if ! awk -F'|' -v OFS='|' \
        -v id="$acc_no" \
        -v bal="$new_balance" '
        $1 == id {
            $3 = bal
        }
        {print}
    ' "$DB_FILE" > "$temp_file"; then
        rm -f "$temp_file"
        return 1
    fi

    chmod 600 "$temp_file"

    if ! mv "$temp_file" "$DB_FILE"; then
        rm -f "$temp_file"
        return 1
    fi

    return 0
}

# Check Account Balance
check_balance() {
    echo -e "${BLUE}===== CHECK BALANCE =====${NC}"

    read -r -p "Enter Account Number: " acc_no
    read -r -s -p "Enter PIN: " pin
    echo

    authenticate_account "$acc_no" "$pin" || return 1

    local formatted_balance
    formatted_balance=$(awk -v b="$AUTH_BALANCE" 'BEGIN {printf "%.2f", b}')

    echo "------------------------------"
    echo "Account Holder: $AUTH_NAME"
    echo -e "Current Balance: ${GREEN}\$$formatted_balance${NC}"
    echo "------------------------------"
}

# Deposit Funds
deposit_funds() {
    echo -e "${BLUE}===== DEPOSIT FUNDS =====${NC}"

    read -r -p "Enter Account Number: " acc_no
    read -r -s -p "Enter PIN: " pin
    echo

    authenticate_account "$acc_no" "$pin" || return 1

    read -r -p "Enter Amount to Deposit: " amount

    if [[ ! "$amount" =~ ^[0-9]+([.][0-9]{1,2})?$ ]] ||
       ! awk -v a="$amount" 'BEGIN { exit !(a > 0) }'; then
        echo -e "${ERROR} Enter a valid positive deposit amount."
        return 1
    fi

    local new_balance
    new_balance=$(awk -v cur="$AUTH_BALANCE" -v amt="$amount" 'BEGIN {printf "%.2f", cur + amt}')

    if update_balance_in_db "$AUTH_ACCOUNT" "$new_balance"; then
        echo -e "${SUCCESS} Deposited \$$amount. New Balance: ${GREEN}\$$new_balance${NC}"
    else
        echo -e "${ERROR} Unable to update account balance."
        return 1
    fi
}

# Withdraw Funds
withdraw_funds() {
    echo -e "${BLUE}===== WITHDRAW FUNDS =====${NC}"

    read -r -p "Enter Account Number: " acc_no
    read -r -s -p "Enter PIN: " pin
    echo

    authenticate_account "$acc_no" "$pin" || return 1

    read -r -p "Enter Amount to Withdraw: " amount

    if [[ ! "$amount" =~ ^[0-9]+([.][0-9]{1,2})?$ ]] ||
       ! awk -v a="$amount" 'BEGIN { exit !(a > 0) }'; then
        echo -e "${ERROR} Enter a valid positive withdrawal amount."
        return 1
    fi

    if awk -v amt="$amount" -v cur="$AUTH_BALANCE" 'BEGIN { exit !(amt > cur) }'; then
        echo -e "${ERROR} Insufficient funds!"
        return 1
    fi

    local new_balance
    new_balance=$(awk -v cur="$AUTH_BALANCE" -v amt="$amount" 'BEGIN {printf "%.2f", cur - amt}')

    if update_balance_in_db "$AUTH_ACCOUNT" "$new_balance"; then
        echo -e "${SUCCESS} Withdrew \$$amount. New Balance: ${GREEN}\$$new_balance${NC}"
    else
        echo -e "${ERROR} Unable to update account balance."
        return 1
    fi
}