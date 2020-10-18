#!/bin/bash

IMAGE_URL="https://xo-appliance.yawn.fi/downloads/image.xva"

function OSCheck {
	set -e

	if [[ -z $(which xe 2>/dev/null) ]]; then
                echo "this scripts needs xe command. make sure you're on xenserver/xcp-ng host"
                exit 1
        fi

	echo
	echo "Welcome. This script will import a working Xen Orchestra appliance built using https://github.com/ronivay/XenOrchestraInstallerUpdater"
	echo "You need at least 2vCPU/4GB/10GB disk free resources to import VM"	
	echo
	echo "Please report any issues to this github project"
	echo


}

function NetworkChoose {

	set +e

	IFS=$'\n' read -r -d '' -a networks <<< "$(xe network-list | grep "uuid\|name-label" | cut -d':' -f2 | sed 's/^ //' | paste - -)"


	echo "Which network should the VM use?"
	echo
	local PS3="Pick a number. CTRL+C to exit: "
	select network in "${networks[@]}"
	do
		read -a network_split <<< "$network"
		networkuuid=${network_split[0]}
		networkname=${network_split[@]:1}

		case $network in
			*)
			vifuuid="$networkuuid"
			break
			;;
		esac
	done

}

function NetworkSettings {

	set -e

	ipregex="^[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}$"

	echo
	echo "Set network settings for VM. Leave IP-address as blank to use DHCP"
	echo

	read -p "IP address: " ipaddress
	ipaddress=${ipaddress:-dhcp}

	if [[ "$ipaddress" != "dhcp" ]]; then
		if ! [[ $ipaddress =~ $ipregex ]]; then
			echo "Check ip-address format"
			exit 1
		fi 
		read -p "Netmask [255.255.255.0]: " netmask
		netmask=${netmask:-255.255.255.0}
		if ! [[	$netmask =~ $ipregex ]]; then
                	echo "Check netmask format"
                	exit 1
                fi
		read -p "Gateway: " gateway
		if [[ $gateway != "" ]]; then
			if ! [[ $gateway =~ $ipregex ]]; then
				echo "Check gateway format"
				exit 1
			fi
		fi
		read -p "DNS [8.8.8.8]: " dns
		dns=${dns:-8.8.8.8}
		if ! [[ $dns =~ $ipregex ]]; then
			echo "Check dns format"
			exit 1
		fi

	fi

}

function VMImport {
	
	set -e

	echo
	echo "Downloading and importing XVA image..."
	echo

	uuid=$(curl "$IMAGE_URL" | xe vm-import filename=/dev/stdin 2>/dev/null)

	if [[ $? != "0" ]]; then
		echo "Import failed"
		exit 1
	fi
	echo
	echo "Import complete"

	xe vif-create network-uuid=$vifuuid vm-uuid=$uuid device=0 >/dev/null

	if [[ "$ipaddress" != "dhcp" ]]; then
		xe vm-param-set uuid=$uuid xenstore-data:vm-data/ip=$ipaddress xenstore-data:vm-data/netmask=$netmask xenstore-data:vm-data/gateway=$gateway xenstore-data:vm-data/dns=$dns
	fi

	xe vm-param-remove uuid=$uuid param-name=HVM-boot-params param-key=order
	xe vm-param-set uuid=$uuid HVM-boot-params:"order: c"

	echo
	echo "Starting VM..."
	xe vm-start uuid=$uuid

	set +e

	count=0
	limit=10
	ip=$(xe vm-param-get uuid=$uuid param-name=networks param-key=0/ip 2>/dev/null)
	while [[ -z "$ip" ]] && [[ "$count" -lt "$limit" ]]; do
		echo "Waiting for VM to start and announce it got IP-address"
		sleep 30
		ip=$(xe vm-param-get uuid=$uuid param-name=networks param-key=0/ip 2>/dev/null)
		(( count++ ))
	done

	if [[ "$ipaddress" != "dhcp" ]]; then
		xe vm-param-remove param-name=xenstore-data param-key=vm-data/ip uuid=$uuid 2>/dev/null
		xe vm-param-remove param-name=xenstore-data param-key=vm-data/netmask uuid=$uuid 2>/dev/null
		xe vm-param-remove param-name=xenstore-data param-key=vm-data/gateway uuid=$uuid 2>/dev/null
		xe vm-param-remove param-name=xenstore-data param-key=vm-data/dns uuid=$uuid 2>/dev/null
	fi

	if [[ $ip != "" ]]; then
		echo
		echo "VM Started successfully"
		echo
		echo "You can access Xen Orchestra at https://$ip and via SSH at $ip"
		echo "Default credentials for UI: admin@admin.net/admin"
		echo "Default credentials for SSH: xo/xopass"
		echo
		echo "Remember to change both passwords before putting VM to use!"
	else
		echo
		echo "VM started but we couldn't fetch it's ip-address from xentools"
		echo
		echo "Check VM status/ip-address manually. If VM started correctly, it should have Web UI and SSH accessible at it's ip-address"
		echo "Default credentials for UI: admin@admin.net/admin"
		echo "Default credentials for SSH: xo/xopass"
		echo 
		echo "Remember to change both passwords before putting VM to use!"
	fi

}

OSCheck
NetworkChoose
NetworkSettings
VMImport
