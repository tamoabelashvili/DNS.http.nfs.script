#!/bin/bash
#######################TAMUNA ABELASHVILI###################

# Function to set static IP address
 echo "Setting up static IP address..."
set_static_ip_manually() {
echo "Setting up static IP address..."
#show network adapter name
nmcli connection show
#show ip 
# Check if ip command is available
if command -v ip -c a &> /dev/null; then
    echo "Using ip command:"
    ip -c a
else
    echo "ip command not found. Trying ifconfig..."
    # Check if ifconfig command is available
    if command -v ifconfig &> /dev/null; then
        echo "Using ifconfig command:"
        ifconfig
    else
        echo "ifconfig command not found. Please install iproute2 or net-tools package."
        exit 1
    fi
fi
echo "Setting up static IP address manually..."
    # Set network interface name
    read -p "Enter network interface name (e.g., ens33): " interface
    read -p "Enter the IP address: " ip_address
    read -p "Enter the subnet mask: " netmask
    read -p "Enter the default gateway: " gateway
    read -p "Enter Default DNS server: " dns1
    read -p "Enter second DNS server (if you want) (e.g., 8.8.8.8): " dns2

    # Create a backup of the original network configuration file
    cp "/etc/sysconfig/network-scripts/ifcfg-$interface" "/etc/sysconfig/network-scripts/ifcfg-$interface.bak"

    # Update the network configuration file with the static IP settings
    cat <<EOF > "/etc/sysconfig/network-scripts/ifcfg-$interface"
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=$interface
DEVICE=$interface
ONBOOT=yes
IPADDR=$ip_address
NETMASK=$netmask
GATEWAY=$gateway
DNS1=$dns1
DNS2=$dns2
EOF

    # Restart the network service to apply changes
    systemctl restart network

    echo "Static IP address configured successfully!"
}

# Function to set static IP automatically
set_static_ip_auto() {
    echo "Setting up static IP address automatically..."

    # Extracting IP address, gateway, subnet mask, and DNS
    IP_ADDRESS=$(ifconfig | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
    GATEWAY=$(ip route show default | awk '/default/ {print $3}')
    SUBNET_MASK=$(ifconfig | grep -oP '(?<=netmask\s)\d+(\.\d+){3}' | head -n 1)
    DNS=$(ifconfig | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
    CUR_INTER=$(ip route | awk '/default/ {print $5}')
    NET_INTER=$(ls -1 /etc/sysconfig/network-scripts/ifcfg-* | head -n 1)

    # Update the network configuration file with the extracted information
    cat <<EOF > "$NET_INTER"
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=$CUR_INTER
DEVICE=$CUR_INTER
ONBOOT=yes
IPADDR=$IP_ADDRESS
NETMASK=$SUBNET_MASK
GATEWAY=$GATEWAY
DNS1=$DNS
EOF
    # Flush the IP address and restart the network service to apply changes
    ip addr flush dev $CUR_INTER
    systemctl restart network

    echo "Static IP address configured successfully!"
}

# Function to set static IP
set_static_ip() {
    echo "Setting up static IP..."
    echo "Choose how to configure the static IP:"
    echo "1. Manually"
    echo "2. Automatically"
    echo "3. Exit"
    read -p "Enter your choice:" static_choice

    case "$static_choice" in
        1) set_static_ip_manually;;
        2) set_static_ip_auto;;
        3) exit;;
        *) echo "Invalid choice. Please enter 1,2 or 3.";;
    esac
}

# Function to set DHCP
set_dhcp() {
    echo "Setting up DHCP..."
#show network adapter name
nmcli connection show
    # Set network interface name
    read -p "Enter network interface name (e.g., ens33): " interface

    # Create a backup of the original network configuration file
    cp "/etc/sysconfig/network-scripts/ifcfg-$interface" "/etc/sysconfig/network-scripts/ifcfg-$interface.bak"

    # Update the network configuration file to use DHCP
    cat <<EOF > "/etc/sysconfig/network-scripts/ifcfg-$interface"
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=dhcp
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=$interface
DEVICE=$interface
ONBOOT=yes
EOF

    # Restart the network service to apply changes
    systemctl restart network

    echo "DHCP configured successfully!"
}

# Main script
echo "Choose network configuration option:"
echo "1. Set Static IP"
echo "2. Use DHCP (REMEMBER you are configuring the server, use this offer only in a special cases)"
echo "3. Exit"
read -p "Enter your choice: " choice

case "$choice" in
    1) set_static_ip;;
    2) set_dhcp;;
    3) exit;;
    *) echo "Invalid choice. Please enter 1,2 or 3.";;
esac


##################################################################################################################

set_dns_only() {
echo "DNS Only Configuration Starting...."
    # Install BIND DNS server
    sudo yum install bind bind-utils -y

    # Check if ip command is available
    if command -v ip &> /dev/null; then
        echo "Using ip command:"
        ip a
    else
        echo "ip command not found. Trying ifconfig..."
        # Check if ifconfig command is available
        if command -v ifconfig &> /dev/null; then
            echo "Using ifconfig command:"
            ifconfig
        else
            echo "ifconfig command not found. Please install iproute2 or net-tools package."
            exit 1
        fi
    fi

    # Set primary DNS server IP
    read -p "Enter default DNS server IP: " primary_dns_ip

    # Number of zones
    read -p "Enter the number of zones you want to configure: " num_zones

    # Set up named configuration file
    config_file_named="/etc/named.conf"
    
    if [ ! -f "$config_file_named" ]; then
        echo "Named configuration file not found: $config_file_named" >&2
        exit 1
    fi

    # Replace specific IPs with "any" in the named configuration file
    sed -i "s/\b127\.0\.0\.1\b/any/g" "$config_file_named"
    sed -i "s/\blocalhost\b/any/g" "$config_file_named"

    # Loop for appending zone configurations
    for ((i=1; i<=$num_zones; i++)); do
        read -p "Enter zone(DOMAIN) $i name (e.g., tamo$i.local): " zone_name
        read -p "Enter reverse zone file name for $zone_name (e.g., reverse$i.db): " reverse_name

        # Append zone configurations to named configuration file
        cat <<EOF >> "$config_file_named"
zone "$zone_name" IN {
    type master;
    file "$zone_name.db";
    allow-update { none; };
};
zone "${reverse_name%.*}.in-addr.arpa" IN {
    type master;
    file "$reverse_name";
    allow-update { none; };
};

EOF

        # Create forward zone file for the zone
        cat <<EOF > "/var/named/$zone_name.db"
@   IN  SOA ns1.$zone_name. root.$zone_name. (
            $(date +%Y%m%d01)
            3600
            1800
            604800
            86400 )

       IN  NS  ns1.$zone_name.
ns1     IN  A   $primary_dns_ip
EOF

        # Create reverse zone file
        last_octet=$(echo $primary_dns_ip | awk -F'.' '{print $4}')
        cat <<EOF > "/var/named/$reverse_name"
@   IN  SOA ns1.$zone_name. root.$zone_name. (
            $(date +%Y%m%d01)
            3600
            1800
            604800
            86400 )
            
       IN  NS  ns1.$zone_name.
$last_octet     IN  PTR ns1.$zone_name.
EOF

        # Set permissions for zone files
        chown named:named "/var/named/$zone_name.db" "/var/named/$reverse_name" || { echo "Failed to set permissions for zone files." >&2; exit 1; }
    done

    # Restart BIND service
    systemctl restart named || { echo "Failed to restart BIND service." >&2; exit 1; }

    echo "DNS-only configuration completed."
}


##########################################################################################################################################

set_with_httpd() {
echo "DNS With Apache configuration starting..."
    # Install BIND DNS server
    sudo yum install bind bind-utils -y

# Check if ip command is available
if command -v ip -c a &> /dev/null; then
    echo "Using ip command:"
    ip -c a
else
    echo "ip command not found. Trying ifconfig..."
    # Check if ifconfig command is available
    if command -v ifconfig &> /dev/null; then
        echo "Using ifconfig command:"
        ifconfig
    else
        echo "ifconfig command not found. Please install iproute2 or net-tools package."
        exit 1
    fi
fi

    # Set primary DNS server IP
    read -p "Enter default DNS server IP: " primary_dns_ip

    # Number of zones
    read -p "Enter the number of zones you want to configure: " num_zones

    # Set up named configuration file
    config_file_named="/etc/named.conf"
    ip="127\.0\.0\.1"
    lo="localhost"

    if [ ! -f "$config_file_named" ]; then
        echo "Named configuration file not found: $config_file_named" >&2
        exit 1
    fi

    # Replace specific IPs with "any" in the named configuration file
    sed -i "s/\b${ip}\b/any/g" "$config_file_named"
    sed -i "s/\b${lo}\b/any/g" "$config_file_named"

    # Append zone configurations for the specified number of zones
    for ((i=1; i<=$num_zones; i++)); do
        read -p "Enter zone(DOMAIN) $i name (e.g., tamo$i.local): " zone_name
        read -p "Enter reverse zone file name for $zone_name (e.g., reverse$i.db): " reverse_name

        cat <<EOF >> "$config_file_named"
zone "$zone_name" IN {
    type master;
    file "$zone_name.db";
    allow-update { none; };
};
zone "${reverse_name%.*}.in-addr.arpa" IN {
    type master;
    file "$reverse_name";
    allow-update { none; };
};
EOF

        # Create forward zone file for the zone
        cat <<EOF > "/var/named/$zone_name.db"
@   IN  SOA ns1.$zone_name. root.$zone_name. (
            $(date +%Y%m%d01)
            3600
            1800
            604800
            86400 )

       IN  NS  ns1.$zone_name.
ns1     IN  A   $primary_dns_ip
ns2     IN  A   $primary_dns_ip
EOF

        # Create reverse zone file
        last_octet=$(echo $primary_dns_ip | awk -F'.' '{print $4}')
        cat <<EOF > "/var/named/$reverse_name"
@   IN  SOA ns1.$zone_name. root.$zone_name. (
            $(date +%Y%m%d01)
            3600
            1800
            604800
            86400 )
            
       IN  NS  ns1.$zone_name.
$last_octet     IN  PTR ns1.$zone_name.
EOF

        # Set permissions for zone files
        chown named:named "/var/named/$zone_name.db"
        chown named:named "/var/named/$reverse_name"
done
    # Restart BIND service
    systemctl restart named

    # Continue with HTTPD configuration
    # Number of sites
    read -p "Enter the number of sites you want to configure: " num_sites

    # Append site configurations for the specified number of sites
    for ((i=1; i<=$num_sites; i++)); do
        read -p "Enter site $i name (e.g., site$i.local): " site_name
        read -p "Enter site $i config file name (e.g., $site_name.conf): " site_config_name

        cat <<EOF >> "$config_file_named"
zone "$site_name" IN {
    type master;
    file "$site_name.db";
    allow-update { none; };
};
EOF

        # Create site zone file
        cat <<EOF > "/var/named/$site_name.db"
@   IN  SOA ns1.$zone_name. root.$zone_name. (
            $(date +%Y%m%d01)
            3600
            1800
            604800
            86400 )
            
       IN  NS  ns1.$zone_name.
$zone_name.  A   $primary_dns_ip
@  A    $primary_dns_ip
www IN  CNAME @
EOF

# Set permissions for site zone file
chown named:named "/var/named/$site_name.db"

# Restart BIND service
systemctl restart named

#install and config apavhe web server site
yum install httpd -y
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload
systemctl start httpd
systemctl enable httpd

# Define the path to the SELinux configuration file
config_file="/etc/selinux/config"

# Check if the configuration file exists
if [ ! -f "$config_file" ]; then
    echo "SELinux configuration file not found: $config_file" >&2
    exit 1
fi
# Disable SELinux by setting the SELINUX parameter to "disabled"
sed -i 's/^SELINUX=.*/SELINUX=disabled/' "$config_file"
systemctl restart httpd


mkdir -p /var/www/$site_name
mkdir -p /var/www/$site_name/html
mkdir -p /var/www/$site_name/log
touch /var/www/$site_name/html/index.html

chmod -R 755 /var/www

cat << EOF >> /var/www/$site_name/html/index.html
<html>
<head>
<title>Welcome to $site_name!</title>
</head>
<body>
<h1>Success! The $site_name virtual host is working! Congrats</h1>
</body>
</html>
EOF

systemctl restart httpd

mkdir /etc/httpd/sites-available /etc/httpd/sites-enabled
cat << EOF >> /etc/httpd/conf/httpd.conf
IncludeOptional sites-enabled/*.conf
EOF


# Get the current user
current_user=$(whoami)

chown $current_user:apache /etc/httpd/sites-enabled
chown $current_user:apache /etc/httpd/sites-available


cat << EOF > /etc/httpd/sites-available/$site_name.conf
<VirtualHost *:80>
ServerName $site_name
ServerAlias www.$site_name
DocumentRoot /var/www/$site_name/html
</VirtualHost>
EOF
done
ln -s /etc/httpd/sites-available/$site_name.conf /etc/httpd/sites-enabled/$site_name.conf

systemctl restart httpd
echo "DNS With Apache configuration completed."
echo "site is working , lets check"
# Define the command you want to check
COMMAND="links"

# Check if the command exists
if ! command -v $COMMAND &> /dev/null; then
    echo "$COMMAND command not found, installing..."

    # Install the package providing the command using yum
    yum install -y links

    # Check if installation was successful
    if [ $? -eq 0 ]; then
        echo "Installation successful!"
    else
        echo "Installation failed. Please check and try again."
        exit 1
    fi
else
    echo "$COMMAND command already installed."
fi

links "http://$site_name"

}
################################################################################################
set_nfs() {
echo "NFS configuration starting..."
# Install NFS packages
yum install -y nfs-utils

# Accept user input for file path and IP address
echo "Enter the directory path to export (e.g., /home/tamo/forclient):"
read directory_path

# Check if the directory exists, if not, create it
if [ ! -d "$directory_path" ]; then
    mkdir -p "$directory_path"
fi

echo "Enter the filename to share in the shared folder (e.g., forclient.txt):"
read filename
echo "enter permissions for share file (e,g,. 771,r+w):"
read permissionsforfile
# Combine directory path and filename
client_file="$directory_path/$filename"

# Check if the file exists, if not, create it
if [ ! -f "$client_file" ]; then
    touch "$client_file"
fi

chmod $permissionsforfile $client_file

echo "Enter the IP address of the client to allow access (e.g., 192.168.127.2):"
read client_ip

echo "Enter the Subnet Mask of the client to allow access (e.g., 24):"
read client_mask

echo "Enter the mount folder (e.g., /mnt/nfs):"
read mount

echo "Enter export options separated by commas (e.g., rw,sync,no_root_squash):"
read export_options

# Check if the mount folder exists, if not, create it
if [ ! -d "$mount" ]; then
    mkdir -p "$mount"
fi

# Configure NFS exports
echo "$directory_path $client_ip/$client_mask($export_options)" | sudo tee -a /etc/exports

# Export the shares
exportfs -a

# Start and enable NFS server
systemctl start nfs-server
systemctl enable nfs-server

# Allow NFS through firewall
firewall-cmd --permanent --zone=public --add-service=nfs
firewall-cmd --reload

# Mount the directory to the specified mount point
if mount --bind "$directory_path" "$mount"; then
    echo "Directory successfully mounted to $mount."
else
    echo "Failed to mount directory to $mount. Please check your configuration."
fi

echo "NFS server installation and configuration completed."
cd $mount
ls
echo "NFS configuration completed."
}

#main script
echo "Choose which option do you want:"
echo "1. Set DNS"
echo "2. Set DNS with Apache"
echo "3. Set NFS"
echo "4. Exit"
read -p "Enter your choice:" service
case "$service" in
        1)set_dns_only;;
        2)set_with_httpd;;
        3)set_nfs;;
        4)exit;;
        *)echo "Invalid choice. Please enter 1,2,3 or 4.";;
esac

#######################TAMUNA ABELASHVILI###################

