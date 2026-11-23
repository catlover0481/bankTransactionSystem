#!/bin/bash

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Generate secure PIN hash
hash_pin() {
    local pin="$1"
    local salt="$2"

    printf '%s' "$salt$pin" | sha256sum | awk '{print $1}'
}

# Account Registration
register_account() {
    echo -e "${BLUE}===== ACCOUNT REGISTRATION =====${NC}"

    read -r -p "Enter Account Number: " acc_no

    if [[ ! "$acc_no" =~ ^[0-9]+$ ]]; then
        echo -e "${ERROR} Invalid account number."
        return 1
    fi

    if grep -q "^${acc_no}|" "$DB_FILE"; then
        echo -e "${ERROR} Account already exists!"
        return 1
    fi

    read -r -p "Enter Full Name: " name

    if [[ -z "$name" || "$name" == *"|"* ]]; then
        echo -e "${ERROR} Invalid name."
        return 1
    fi

    read -r -p "Enter Initial Deposit: " balance

    if [[ ! "$balance" =~ ^[0-9]+([.][0-9]{1,2})?$ ]] ||
       ! awk -v b="$balance" 'BEGIN { exit !(b > 0) }'; then
        echo -e "${ERROR} Enter a valid positive deposit."
        return 1
    fi

    while true; do
        read -r -s -p "Create 4-digit PIN: " pin
        echo

        if [[ "$pin" =~ ^[0-9]{4}$ ]]; then
            break
        fi

        echo -e "${YELLOW}PIN must contain exactly 4 digits.${NC}"
    done

    read -r -s -p "Confirm PIN: " confirm_pin
    echo

    if [[ "$pin" != "$confirm_pin" ]]; then
        echo -e "${ERROR} PINs do not match!"
        return 1
    fi

    salt=$(openssl rand -hex 16)
    pin_hash=$(hash_pin "$pin" "$salt")

    (
        umask 077
        printf '%s|%s|%s|%s|%s\n' \
            "$acc_no" "$name" "$balance" "$salt" "$pin_hash" >> "$DB_FILE"
    )

    echo -e "${GREEN}Account registered successfully!${NC}"
}

# Change Existing PIN
change_pin() {
    echo -e "${BLUE}===== CHANGE PIN =====${NC}"

    read -r -p "Enter Account Number: " acc_no

    if [[ ! "$acc_no" =~ ^[0-9]+$ ]]; then
        echo -e "${ERROR} Invalid account number."
        return 1
    fi

    if ! grep -q "^${acc_no}|" "$DB_FILE"; then
        echo -e "${ERROR} Account not found!"
        return 1
    fi

    local line
    line=$(awk -F'|' -v id="$acc_no" '$1 == id {print; exit}' "$DB_FILE")

    IFS='|' read -r account name balance salt stored_hash <<< "$line"

    read -r -s -p "Enter Current PIN: " old_pin
    echo

    old_hash=$(hash_pin "$old_pin" "$salt")

    if [[ "$old_hash" != "$stored_hash" ]]; then
        echo -e "${ERROR} Incorrect PIN!"
        return 1
    fi

    while true; do
        read -r -s -p "Enter New 4-digit PIN: " new_pin
        echo

        if [[ "$new_pin" =~ ^[0-9]{4}$ ]]; then
            break
        fi

        echo -e "${YELLOW}PIN must contain exactly 4 digits.${NC}"
    done

    read -r -s -p "Confirm New PIN: " confirm_pin
    echo

    if [[ "$new_pin" != "$confirm_pin" ]]; then
        echo -e "${ERROR} PINs do not match!"
        return 1
    fi

    new_salt=$(openssl rand -hex 16)
    new_hash=$(hash_pin "$new_pin" "$new_salt")

    temp_file=$(mktemp) || return 1

    if ! awk -F'|' -v OFS='|' \
        -v id="$acc_no" \
        -v s="$new_salt" \
        -v h="$new_hash" '
        $1 == id {
            $4 = s
            $5 = h
        }
        {print}
    ' "$DB_FILE" > "$temp_file"; then
        rm -f "$temp_file"
        return 1
    fi

    chmod 600 "$temp_file"

    if mv "$temp_file" "$DB_FILE"; then
        echo -e "${GREEN}PIN changed successfully!${NC}"
    else
        rm -f "$temp_file"
        echo -e "${ERROR} Unable to update PIN."
        return 1
    fi
}