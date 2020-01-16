#!/bin/bash
#
# Copyright (c) 2018 Igor Pecovnik, igor.pecovnik@gma**.com
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.

# Functions:
# submenu_settings
# submenu_networking
# submenu_personal
# submenu_software


#
# system settings
#
function submenu_settings ()
{
while true; do
	LIST=()
	DIALOG_CANCEL=1
	DIALOG_ESC=255

	# detect desktop
	check_desktop

	# check if eMMC/SD is on the system
	if [[ $(sed -n 's/^DEVNAME=//p' /sys/dev/block/$(mountpoint -d /)/uevent 2> /dev/null) == mmcblk* \
	&& -f /usr/local/sbin/install_to_emmc ]]; then
		LIST+=( "Install" "Install image to emmc" )
	fi

	[[ -n $(grep -w "#kernel.printk" /etc/sysctl.conf ) ]] && LIST+=( "Lowlevel" "Stop low-level messages on console" )
	
	if [[ -f /etc/default/cpufrequtils ]]; then
		LIST+=( "CPU" "Set CPU speed and governor" )
	fi

	LIST+=( "SSH" "Reconfigure SSH daemon" )
	LIST+=( "Firmware" "Run apt update & apt upgrade" )
	
	if [[ "$SHELL" != "/bin/bash" ]]; then
		LIST+=( "BASH" "Revert to stock BASH shell" )
	else
		LIST+=( "ZSH" "Install ZSH with plugins and tmux" )
	fi

	# desktop Todo
	#if [[ -n $DISPLAY_MANAGER ]]; then
	#		LIST+=( "Desktop" "Disable desktop or change login type" )
	#else
	#		if [[ -n $DESKTOP_INSTALLED ]]; then
	#				LIST+=( "Desktop" "Enable desktop" )
	#			else
	#				LIST+=( "Default" "Install desktop with browser and extras" )
	#		fi
	#fi
	# count number of menu items to adjust window size
	LISTLENGTH="$((6+${#LIST[@]}/2))"
	BOXLENGTH=${#LIST[@]}
	temp_rc=$(mktemp)

	local sys_title=" System settings "
	echo > $temp_rc

	exec 3>&1
	selection=$(DIALOGRC=$temp_rc dialog --colors --backtitle "$BACKTITLE" --title " $sys_title " --clear \
	--cancel-label "Back" --menu "$disclaimer" $LISTLENGTH 0 $BOXLENGTH \
	"${LIST[@]}" 2>&1 1>&3)
	exit_status=$?
	exec 3>&-

	[[ $exit_status == $DIALOG_CANCEL || $exit_status == $DIALOG_ESC ]] && clear && break

	# run main function
	jobs "$selection"
done

}


#
# menu for networking
#
function submenu_networking ()
{

# select default interface if there is more than one connected
#select_interface "default"

while true; do

	LIST=()
	DIALOG_CANCEL=1
	DIALOG_ESC=255

	# check if we have some LTE modems
	# for i in $(lsusb | awk '{print $6}'); do lte "$i"; done;

	# edit ip
	LIST+=( "IP" "Select dynamic or edit static IP address" )

	# hostapd
	HOSTAPDBRIDGE=$(cat /etc/hostapd.conf 2> /dev/null | grep -w "^bridge=br0")
	HOSTAPDSTATUS=$(service hostapd status 2> /dev/null | grep -w active | grep -w running)
	if [[ -n "$HOSTAPDSTATUS" ]]; then
			HOSTAPDINFO=$(hostapd_cli get_config 2> /dev/null | grep ^ssid | sed 's/ssid=//g')
			HOSTAPDCLIENTS=$(hostapd_cli all_sta 2> /dev/null | grep connected_time | wc -l)
			LIST+=( "Hotspot" "Manage active wireless access point" )
	fi

	# network throughput test
	if check_if_installed iperf3; then
		if pgrep -x "iperf3" > /dev/null
		then
			LIST+=( "Iperf3" "Disable network throughput tests daemon" )
			else
			LIST+=( "Iperf3" "Enable network throughput tests daemon" )
		fi
	fi

	if [[ -n $(LC_ALL=C nmcli device status 2> /dev/null | grep wifi | grep -v unavailable | grep -v unmanaged) ]]; then
		LIST+=( "WiFi" "Manage wireless networking" )
	else
		LIST+=( "Clear" "Clear possible blocked interfaces" )
	fi

	if check_if_installed bluetooth then ; then
			LIST+=( "BT remove" "Remove Bluetooth support" )
			if [[ -n $(service bluetooth status | grep -w active | grep -w running) ]]; then
				[[ $(hcitool dev | sed '1d') != "" ]] && LIST+=( "BT discover" "Discover and connect Bluetooth devices" )
			fi
		else
			LIST+=( "BT install" "Install Bluetooth support" )
	fi



	[[ -d /usr/local/vpnclient ]] && LIST+=( "VPN" "Manage Softether VPN client" ) && VPNSERVERIP=$(/usr/local/vpnclient/vpncmd /client localhost /cmd accountlist | grep "VPN Server" |grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | head -1)

	LIST+=( "Advanced" "Edit /etc/network/interfaces" )
	[[ $(ls -1 /etc/NetworkManager/system-connections 2> /dev/null) ]] && \
	#LIST+=( "Forget" "Disconnect and forget all wireless connections" )

	# count number of menu items to adjust window size
	LISTLENGTH="$((12+${#LIST[@]}/2))"
	BOXLENGTH=${#LIST[@]}
	WIFICONNECTED=$(LC_ALL=C nmcli -f NAME,TYPE connection show --active 2> /dev/null | grep wireless | awk 'NF{NF-=1};1')

	local disclaimer=""

	local ipadd=$(ip -4 addr show dev $DEFAULT_ADAPTER | awk '/inet/ {print $2}' | cut -d'/' -f1)


	if [[ -n $(LC_ALL=C nmcli device status 2> /dev/null | grep $DEFAULT_ADAPTER | grep connected) ]]; then
		local ifup="\nIP ($DEFAULT_ADAPTER) via Network Manager: \Z1${ipadd}\n\Z0 "
	else
		if [[ -n $(service systemd-networkd status | grep -w active | grep -w running) ]]; then
			local ifup="\nIP ($DEFAULT_ADAPTER) via systemd-networkd: \Z1${ipadd}\n\Z0 "
		else
			local ifup="\nIP ($DEFAULT_ADAPTER) via IFUPDOWN: \Z1${ipadd}\n\Z0 "
		fi
	fi

	disclaimer="$ifup"

	if [[ -n $WIFICONNECTED ]]; then
		LISTLENGTH=$((LISTLENGTH+2))
		local connected="\n\Z0Connected to SSID: \Z1${WIFICONNECTED}\n\Z0 "
		disclaimer=$disclaimer"$connected"
	fi

	if [[ -n $VPNSERVERIP ]]; then
		local vpnserverip="\n\Z0Connected to VPN server: \Z1${VPNSERVERIP}\n\Z0 "
		disclaimer=$disclaimer"$vpnserverip"
		LISTLENGTH=$((LISTLENGTH+2))
	fi

	if [[ -n $HOSTAPDINFO && -n $HOSTAPDSTATUS ]]; then
		LISTLENGTH=$((LISTLENGTH+2))
		chpid=$(dmesg | grep $(grep ^interface /etc/hostapd.conf | sed 's/interface=//g') | head -1 | sed 's/\[.*\]//g' | awk '{print $1}')
		disclaimer=$disclaimer$"\n\Z0Hotspot SSID: \Z1$HOSTAPDINFO\Zn Band:";
		if [[ `grep ^hw_mode=a /etc/hostapd.conf` ]]; then local band="5Ghz"; else band="2.4Ghz"; fi
		if [[ `grep ^ieee80211n /etc/hostapd.conf` ]]; then local type="N"; fi
		if [[ `grep ^ieee80211ac /etc/hostapd.conf` ]]; then local type="AC"; fi
		disclaimer=$disclaimer$" \Z1${band} ${type}\Z0"
		[[ ! "$chpid" =~ .*IPv6.* ]] && disclaimer=$disclaimer$"\n\nChip: \Z1${chpid}\Z0";
		if [ "$HOSTAPDCLIENTS" -gt "0" ]; then disclaimer=$disclaimer$" Connected clients: \Z1$HOSTAPDCLIENTS\Zn"; fi
		if [[ ! "$chpid" =~ .*IPv6.* ]]; then LISTLENGTH=$((LISTLENGTH+2)); fi
		disclaimer=$disclaimer$"\n";
	fi
	disclaimer=$disclaimer"\n\Z1Note\Zn: This tool can be successful only when drivers are configured properly. If auto-detection fails, you are on your own.\n "

	exec 3>&1
	selection=$(dialog --backtitle "$BACKTITLE" --colors --title " Wired, Wireless, Bluetooth, Hotspot " --clear \
	--cancel-label "Back" --menu "${disclaimer}" $LISTLENGTH 70 $BOXLENGTH \
	"${LIST[@]}" 2>&1 1>&3)
	exit_status=$?
	exec 3>&-
	[[ $exit_status == $DIALOG_CANCEL || $exit_status == $DIALOG_ESC ]] && clear && break

	# run main function
	jobs "$selection"

done
}


#
# personal
#
function submenu_personal ()
{
while true; do

	LIST=()
	LIST+=( "Timezone" "Change timezone \Z5($(LC_ALL=C timedatectl | grep zone | awk '{$1=$1;print}' | sed "s/Time zone: //"))\Z0" )
	LIST+=( "Locales" "Reconfigure language \Z5($(locale | grep LANGUAGE | cut -d= -f2 | cut -d_ -f1))\Z0 and character set" )
	LIST+=( "Keyboard" "Change console keyboard layout (\Z5$(cat /etc/default/keyboard | grep XKBLAYOUT | grep -o '".*"' | sed 's/"//g')\Z0)")
	LIST+=( "Hostname" "Change your hostname \Z5($(cat /etc/hostname))\Z0" )
	[[ -f /etc/apt/sources.list ]] && LIST+=( "Mirror" "Change repository server \Z5(${BEFORE_DESC})\Z0" )
	LIST+=( "Welcome" "Toggle welcome screen items" )

	# count number of menu items to adjust window sizee
	LISTLENGTH="$((6+${#LIST[@]}/2))"
	BOXLENGTH=${#LIST[@]}

	exec 3>&1
	selection=$(dialog --colors --backtitle "$BACKTITLE" --title "Personal settings" --clear \
	--cancel-label "Back" --menu "$disclaimer" $LISTLENGTH 70 $BOXLENGTH \
	"${LIST[@]}" 2>&1 1>&3)
	exit_status=$?
	exec 3>&-
	[[ $exit_status == $DIALOG_CANCEL || $exit_status == $DIALOG_ESC ]] && clear && break

	# run main function
	jobs "$selection"

done
}

#
# software
#
function submenu_software ()
{
while true; do

	# detect desktop
	check_desktop

	OPILIB=/usr/local/sbin/opi_config_libs

	LIST=()
	[[ -f /usr/local/sbin/opi_config_libs/softy ]] && LIST+=( "Softy" "3rd party applications installer" )
#	LIST+=( "Monitor" "Simple CLI board monitoring" )

	if [[ -n $DISPLAY_MANAGER ]]; then
			if [[ $(service xrdp status 2> /dev/null | grep -w active) ]]; then
				LIST+=( "RDP" "Disable remote desktop access from Windows" )
				else
				LIST+=( "RDP" "Enable remote desktop access from Windows" )
			fi
	fi

	# count number of menu items to adjust window sizee
	LISTLENGTH="$((10+${#LIST[@]}/2))"
	BOXLENGTH=${#LIST[@]}

	exec 3>&1
	selection=$(dialog --backtitle "$BACKTITLE" --title "System and 3rd party software" --clear \
	--cancel-label "Back" --menu "$disclaimer" $LISTLENGTH 70 $BOXLENGTH \
	"${LIST[@]}" 2>&1 1>&3)
	exit_status=$?
	exec 3>&-
	[[ $exit_status == $DIALOG_CANCEL || $exit_status == $DIALOG_ESC ]] && clear && break

	# run main function
	jobs "$selection"

done
}
