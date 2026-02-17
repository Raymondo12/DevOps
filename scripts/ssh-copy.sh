#!/bin/bash

# Script to add a public key to /home/ansible/.ssh/authorized_keys
# and set the correct permissions

PUBLIC_KEY="this is my public key"
ANSIBLE_HOME="/home/ansible"
SSH_DIR="${ANSIBLE_HOME}/.ssh"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root or with sudo"
    exit 1
fi

# Check if ansible user exists
if ! id "ansible" &>/dev/null; then
    echo "Error: ansible user does not exist"
    exit 1
fi

# Create .ssh directory if it doesn't exist
if [[ ! -d "${SSH_DIR}" ]]; then
    echo "Creating ${SSH_DIR} directory..."
    mkdir -p "${SSH_DIR}"
fi

# Check if key already exists to avoid duplicates
if grep -qF "${PUBLIC_KEY}" "${AUTHORIZED_KEYS}" 2>/dev/null; then
    echo "Public key already exists in ${AUTHORIZED_KEYS}. Skipping addition."
else
    # Add the public key
    echo "Adding public key to ${AUTHORIZED_KEYS}..."
    echo "${PUBLIC_KEY}" >> "${AUTHORIZED_KEYS}"
    echo "Public key added successfully."
fi

# Set correct ownership
echo "Setting ownership to ansible:ansible..."
chown -R ansible:ansible "${SSH_DIR}"

# Set correct permissions
echo "Setting permissions..."
chmod 700 "${SSH_DIR}"           # .ssh directory: rwx------
chmod 600 "${AUTHORIZED_KEYS}"   # authorized_keys: rw-------

echo ""
echo "Done! Summary:"
echo "  ${SSH_DIR}:        $(stat -c '%a' ${SSH_DIR}) (700) - Owner: $(stat -c '%U:%G' ${SSH_DIR})"
echo "  ${AUTHORIZED_KEYS}: $(stat -c '%a' ${AUTHORIZED_KEYS}) (600) - Owner: $(stat -c '%U:%G' ${AUTHORIZED_KEYS})"
