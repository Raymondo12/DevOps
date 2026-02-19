#!/bin/bash
#curl -fsSL https://raw.githubusercontent.com/waqasahmed055/DevOpsLinux/edit/main/create-user.sh -o create-user.sh
#chmod +x create-user.sh
#sudo ./create-user.sh
# todjitest User Setup Script
# This script sets up an todjitest user with SSH key authentication

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================
# REPLACE THIS WITH YOUR ACTUAL CONTROLLER'S PUBLIC KEY
# Run: cat /home/todjitest/.ssh/id_rsa.pub  (on the controller)
# ============================================================
CONTROLLER_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCirrZa1ikNjfqvUcF30eyTdGjNnQpTDEEsXSZjHkKnjpfQzSzLpMqfPksdUU6gyRBPiPMMTGZtrSABZGb5s9lVNaIXxeoLlPZHUqn6HJzYRRspcaDxuTgMI/Zy+LMFcza/HYDpWtCWRNJl1ffzFHAHqzgr+gQ/kcMmfjCfr6yxhYJmf8zlBgBQDKlK5u1r4CdqOjU8rVZvgaW9IPv+jUgqNWo3Uc/C7XD5JyCUnPMvU/+SzTLx1AOJ76qIYN+WqDAq7SR7BmKDENZB/UR9RX9hg3CMCE0BK8ysndYeJ3IWdMUGX6BpaGUNFtmbD3wUXyd51FSOCs6prvefLQOwno03fEXtgJ2pgY23Doo1Trg+CJmA1kwJzixOu2koRn1dzGfrFSRaWqdRx17jzkZaZnSudhso7fKkQdTrEsJxzN7LpwN9jnQj0QeiLhg2VgFIyB6ATFQbvbDcVX1V6jHyLLPRa7uys4TPxFnOIv2bI5o0Wc9qbFNFgkQpv++3CI35c3gvxgVQKw+R9Q6PHKqxEbr4qzm4SUSjJOG2pvzMACd6w8O60mz3qE8wpHK4ggQH4ctwHv/9LwoiSr/pfjV2NYZVR+j69NlkHDR6+DmlliK6wLjaJ93OdZOfxwtRZCXmQKs4LGVugcDt1bHOYFbqKKoOeDlrNBfA1CiD+zFpz8BeJw== ansible@controller"

# Check if script is run as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        print_error "Please run: sudo $0"
        exit 1
    fi
    print_success "Running as root - OK"
}

# Check if user exists
user_exists() {
    id "$1" &>/dev/null
}

# Check if directory exists
directory_exists() {
    [[ -d "$1" ]]
}

# Check if file exists
file_exists() {
    [[ -f "$1" ]]
}

# Create todjitest user
create_todjitest_user() {
    local username="todjitest"

    if user_exists "$username"; then
        print_warning "User '$username' already exists, skipping user creation"
    else
        print_status "Creating user '$username'..."
        useradd -m -s /bin/bash "$username"
        if user_exists "$username"; then
            print_success "User '$username' created successfully"
        else
            print_error "Failed to create user '$username'"
            exit 1
        fi
    fi
}

# Set password for todjitest user
set_todjitest_password() {
    local username="todjitest"

    print_status "Setting password for user '$username'..."
    if echo "todjitest:UneeD2024" | chpasswd; then
        print_success "Password set for user '$username'"
    else
        print_error "Failed to set password for user '$username'"
        exit 1
    fi
}

# Create .ssh directory
create_ssh_directory() {
    local username="todjitest"
    local home_dir="/home/$username"
    local ssh_dir="$home_dir/.ssh"

    if ! directory_exists "$home_dir"; then
        print_error "Home directory '$home_dir' does not exist"
        exit 1
    fi

    if directory_exists "$ssh_dir"; then
        print_warning ".ssh directory already exists at '$ssh_dir'"
    else
        print_status "Creating .ssh directory at '$ssh_dir'..."
        mkdir -p "$ssh_dir"
        if directory_exists "$ssh_dir"; then
            print_success ".ssh directory created at '$ssh_dir'"
        else
            print_error "Failed to create .ssh directory"
            exit 1
        fi
    fi

    print_status "Setting ownership and permissions for .ssh directory..."
    chown "$username:$username" "$ssh_dir"
    chmod 700 "$ssh_dir"
    print_success "Set proper ownership and permissions for .ssh directory"
}

# Copy controller's public key to authorized_keys
setup_authorized_keys() {
    local username="todjitest"
    local ssh_dir="/home/$username/.ssh"
    local auth_keys="$ssh_dir/authorized_keys"

    print_status "Setting up authorized_keys for '$username'..."

    # Validate that the public key variable is not empty or still a placeholder
    if [[ -z "$CONTROLLER_PUBLIC_KEY" || "$CONTROLLER_PUBLIC_KEY" == *"placeholder"* ]]; then
        print_error "CONTROLLER_PUBLIC_KEY is not set or still contains the placeholder."
        print_error "Please edit this script and replace the placeholder with your actual controller public key."
        exit 1
    fi

    if file_exists "$auth_keys"; then
        # Avoid duplicate entries
        if grep -qF "$CONTROLLER_PUBLIC_KEY" "$auth_keys"; then
            print_warning "Controller public key already exists in authorized_keys, skipping"
        else
            print_status "Appending controller public key to existing authorized_keys..."
            echo "$CONTROLLER_PUBLIC_KEY" >> "$auth_keys"
            print_success "Controller public key appended to authorized_keys"
        fi
    else
        print_status "Creating authorized_keys and writing controller public key..."
        echo "$CONTROLLER_PUBLIC_KEY" > "$auth_keys"
        print_success "Controller public key written to authorized_keys"
    fi

    # Set correct ownership and permissions
    chown "$username:$username" "$auth_keys"
    chmod 600 "$auth_keys"
    print_success "Set permissions 600 on authorized_keys"
}

# Add todjitest user to sudoers
setup_sudo_access() {
    local username="todjitest"
    local sudoers_file="/etc/sudoers.d/$username"

    print_status "Setting up sudo access for '$username'..."

    if ! directory_exists "/etc/sudoers.d"; then
        mkdir -p /etc/sudoers.d
    fi

    if file_exists "$sudoers_file"; then
        print_warning "Sudoers file for '$username' already exists"
    else
        print_status "Adding '$username' to sudoers..."
        echo "$username ALL=(ALL) NOPASSWD:ALL" > "$sudoers_file"
        chmod 660 "$sudoers_file"

        if visudo -c -f "$sudoers_file" &>/dev/null; then
            print_success "Added '$username' to sudoers with NOPASSWD"
        else
            print_error "Sudoers file validation failed, removing invalid file"
            rm -f "$sudoers_file"
            exit 1
        fi
    fi

    if getent group sudo &>/dev/null; then
        print_status "Adding '$username' to sudo group..."
        usermod -aG sudo "$username"
        print_success "Added '$username' to sudo group"
    elif getent group wheel &>/dev/null; then
        print_status "Adding '$username' to wheel group..."
        usermod -aG wheel "$username"
        print_success "Added '$username' to wheel group"
    fi
}

# Main execution
main() {
    print_status "Starting todjitest user setup script..."

    check_root
    create_todjitest_user
    set_todjitest_password
    create_ssh_directory
    setup_authorized_keys
    setup_sudo_access

    print_success "todjitest user setup completed successfully!"
    print_status "=== SETUP SUMMARY ==="
    print_status "Username: todjitest"
    print_status "Password: UneeD2024"
    print_status "Home directory: /home/todjitest"
    print_status "SSH directory: /home/todjitest/.ssh"
    print_status "Authorized keys: /home/todjitest/.ssh/authorized_keys (permissions: 600)"
    print_status "Sudo access: Enabled (NOPASSWD)"
    print_status "===================="
    print_status "You can now switch to todjitest user with: su - todjitest"
    print_status "Or login via SSH: ssh todjitest@<slave-ip>"
}

main "$@"
