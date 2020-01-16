#!/bin/bash

#
# gather info about the board and start with loading menu
#
function main(){

	DIALOG_CANCEL=1
	DIALOG_ESC=255
	BOARD_NAME="OrangePi 3"
	DISTRO=$(lsb_release -is)
	DISTROID=$(lsb_release -sc)
	KERNELID=$(uname -r)
	[[ -z "${ORANGEPI// }" ]] && ORANGEPI="$DISTRO $DISTROID"
	DEFAULT_ADAPTER=$(ip -4 route ls | grep default | tail -1 | grep -Po '(?<=dev )(\S+)')
	LOCALIPADD=$(ip -4 addr show dev $DEFAULT_ADAPTER | awk '/inet/ {print $2}' | cut -d'/' -f1)
	BACKTITLE="Configuration utility, $ORANGEPI"
	[[ -n "$LOCALIPADD" ]] && BACKTITLE=$BACKTITLE", "$LOCALIPADD
	TITLE="$BOARD_NAME "
	[[ -z "${DEFAULT_ADAPTER// }" ]] && DEFAULT_ADAPTER="lo"
	# detect desktop
	check_desktop
#	dialog --backtitle "$BACKTITLE" --title "Please wait" --infobox "\nLoading OrangePi configuration utility ... " 5 45
#	sleep 1
}

#
# check dpkg status of $1 -- currently only 'not installed at all' case caught
#
check_if_installed (){

	local DPKG_Status="$(dpkg -s "$1" 2>/dev/null | awk -F": " '/^Status/ {print $2}')"
	if [[ "X${DPKG_Status}" = "X" || "${DPKG_Status}" = *deinstall* ]]; then
		return 1
	else
		return 0
	fi

}

#
# read desktop parameters
#
function check_desktop()
{

	DISPLAY_MANAGER=""; DESKTOP_INSTALLED=""
	check_if_installed nodm && DESKTOP_INSTALLED="nodm";
	check_if_installed lightdm && DESKTOP_INSTALLED="lightdm";
	check_if_installed lightdm && DESKTOP_INSTALLED="gnome";
	[[ -n $(service lightdm status 2> /dev/null | grep -w active) ]] && DISPLAY_MANAGER="lightdm"
	[[ -n $(service nodm status 2> /dev/null | grep -w active) ]] && DISPLAY_MANAGER="nodm"
	[[ -n $(service gdm status 2> /dev/null | grep -w active) ]] && DISPLAY_MANAGER="gdm"

}

#
# show box
#
function show_box ()
{

	dialog --colors --backtitle "$BACKTITLE" --no-collapse --title " $1 " --clear --msgbox "\n$2\n \n" $3 56

}

#
# Generic select box
#
function generic_select()
{
        IFS=$' '
        PARAMETER=($1)
        local LIST=()
        for i in "${PARAMETER[@]}"
        do
                        if [[ -n $3 ]]; then
                                [[ ${i[0]} -ge $3 ]] && \
                                LIST+=( "${i[0]//[[:blank:]]/}" "" )
                        else
                                LIST+=( "${i[0]//[[:blank:]]/}" "" )
                        fi
        done
        LIST_LENGTH=$((${#LIST[@]}/2));
        if [ "$LIST_LENGTH" -eq 1 ]; then
                        PARAMETER=${PARAMETER[0]}
        else
                        exec 3>&1
                        PARAMETER=$(dialog --nocancel --backtitle "$BACKTITLE" --no-collapse \
                        --title "$2" --clear --menu "" $((6+${LIST_LENGTH})) 0 $((1+${LIST_LENGTH})) "${LIST[@]}" 2>&1 1>&3)
                        exec 3>&-
        fi
}

#
# check if package manager is doing something
#
function is_package_manager_running() {

  fuser -s /var/lib/dpkg/lock
  if [[ $? = 0 ]]; then
    # 0 = true
	dialog --colors --title " \Z1Error\Z0 " --backtitle "$BACKTITLE" --no-collapse --msgbox \
	"\n\Z0Package manager is running in the background. \n\nCan't install dependencies. Try again later." 9 53
    return 0
  else
    # 1 = false
    return 1
  fi

}

#
# create or pick unprivileged user
#
function add_choose_user ()
{

	IFS=$'\r\n'
	GLOBIGNORE='*'

	local USERS=($(awk -F'[/:]' '{if ($3 >= 1000 && $3 != 65534) print $1}' /etc/passwd))
	local LIST=()
	for i in "${USERS[@]}"
	do
		LIST+=( "${i[0]//[[:blank:]]/}" "" )
	done
	LIST_LENGTH=$((${#LIST[@]}/2));

	if [ "$LIST_LENGTH" -eq 0 ]; then
		dialog --backtitle "$BACKTITLE" --title " Notice " --msgbox \
		"\nWe didn't find any unprivileged user with sudo rights which is required to run this service.\
		\n\nPress enter to create one!" 10 48
		read -t 0 temp
		echo -e "\nPlease provide a username (eg. your forename) or leave blank for canceling user creation: \c"
		read -e username
		CHOSEN_USER="$(echo "$username" | tr '[:upper:]' '[:lower:]' | tr -d -c '[:alnum:]')"
		[ -z "$CHOSEN_USER" ] && return
		echo "Trying to add user $CHOSEN_USER"
		adduser $CHOSEN_USER || return
	elif [ "$LIST_LENGTH" -eq 1 ]; then
			CHOSEN_USER=${USERS[0]}
	else
			exec 3>&1
			CHOSEN_USER=$(dialog --nocancel --backtitle "$BACKTITLE" --no-collapse \
			--title "Select unprivileged user" --clear --menu "" $((6+${LIST_LENGTH})) 40 15 "${LIST[@]}" 2>&1 1>&3)
			exec 3>&-
	fi

}

#
# reload network related services
#
function reload-nety() {

	systemctl daemon-reload
	if [[ "$1" == "reload" ]]; then WHATODO="Reloading services"; else WHATODO="Stopping services"; fi
	(service network-manager stop; echo 10; sleep 1; service hostapd stop; echo 20; sleep 1; service dnsmasq stop; echo 30; sleep 1;\
	[[ "$1" == "reload" ]] && service dnsmasq start && echo 60 && sleep 1 && service hostapd start && echo 80 && sleep 1;\
	service network-manager start; echo 90; sleep 5;) | dialog --backtitle "$BACKTITLE" --title " $WHATODO " --gauge "" 6 70 0
	systemctl restart systemd-resolved.service

}

function select_interface ()
{
	IFS=$'\r\n'
	GLOBIGNORE='*'
	local ADAPTER=($(nmcli device status | grep ethernet | awk '{ print $1 }' | grep -v lo))
	local LIST=()
	for i in "${ADAPTER[@]}"
	do
		local IPADDR=$(LC_ALL=C ip -4 addr show dev ${i[0]} | awk '/inet/ {print $2}' | cut -d'/' -f1)
		ADD_SPEED=""
		[[ $i == eth* || $i == en* ]] && ADD_SPEED=$(ethtool $i | grep Speed)
		[[ $i == wl* ]] && ADD_SPEED=$(LC_ALL=C nmcli -f RATE,DEVICE,ACTIVE dev wifi list | grep $i | grep yes | awk 'NF==4{print $1""$2}NF==1' | sed -e 's/^/  Speed: /' | tail -1)
		LIST+=( "${i[0]//[[:blank:]]/}" "${IPADDR} ${ADD_SPEED}" )
	done
	LIST_LENGTH=$((${#LIST[@]}/2));
	if [ "$LIST_LENGTH" -eq 0 ]; then
		SELECTED_ADAPTER="lo"
	elif [ "$LIST_LENGTH" -eq 1 ]; then
		SELECTED_ADAPTER=${ADAPTER[0]}
	else
	exec 3>&1
	SELECTED_ADAPTER=$(dialog --nocancel --backtitle "$BACKTITLE" --no-collapse --title "Select $1 interface" --clear \
	--menu "" $((6+${LIST_LENGTH})) 74 14 "${LIST[@]}" 2>&1 1>&3)
	exec 3>&-
	fi

}

#
# create interface configuration section
#
function create_if_config() {

		address=$(ip -4 addr show dev $1 | awk '/inet/ {print $2}' | cut -d'/' -f1)
		netmask=$(ip -4 addr show dev $1 | awk '/inet/ {print $2}' | cut -d'/' -f2)
		gateway=$(route -n | grep 'UG[ \t]' | awk '{print $2}' | sed -n '1p')
		echo -e "# armbian-config created"
		echo -e "source /etc/network/interfaces.d/*\n"
		if [[ "$3" == "fixed" ]]; then
			echo -e "# Local loopback\nauto lo\niface lo init loopback\n"
			echo -e "# Interface $2\nauto $2\nallow-hotplug $2"
			echo -e "iface $2 inet static\n\taddress $address\n\tnetmask $netmask\n\tgateway $gateway\n\tdns-nameservers 8.8.8.8"
		fi

}

#
# edit ip address within network manager
#
function nm_ip_editor ()
{

exec 3>&1
	dialog --title " Static IP configuration" --backtitle "$BACKTITLE" --form "\nAdapter: $1
	\n " 12 38 0 \
	"Address:"				1 1 "$address"				1 15 15 0 \
	"Netmask:"			2 1 "$netmask"	2 15 15 0 \
	"Gateway:"			3 1 "$gateway"			3 15 15 0 \
	2>&1 1>&3 | {
		read -r address;read -r netmask;read -r gateway
		if [[ $? = 0 ]]; then
			localuuid=$(LC_ALL=C nmcli -f UUID,DEVICE connection show | grep $1 | awk '{print $1}')
      # convert netmask value to CIDR if required
      if [[ $netmask =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        CIDR=$(netmask_to_cidr ${netmask})
      else
        CIDR=${netmask}
      fi
			if [[ -n "$localuuid" ]]; then
				# adjust existing
				nmcli con mod $localuuid ipv4.method manual ipv4.addresses "$address/$CIDR" >/dev/null 2>&1
				nmcli con mod $localuuid ipv4.method manual ipv4.gateway  "$gateway" >/dev/null 2>&1
				nmcli con mod $localuuid ipv4.dns "8.8.8.8,$gateway" >/dev/null 2>&1
				nmcli con down $localuuid >/dev/null 2>&1
				sleep 2
				nmcli con up $localuuid >/dev/null 2>&1
			else
				# create new
				nmcli con add con-name "armbian" ifname "$1" type 802-3-ethernet ip4 "$address/$CIDR" gw4 "$gateway" >/dev/null 2>&1
				nmcli con mod "armbian" ipv4.dns "8.8.8.8,$gateway" >/dev/null 2>&1
				nmcli con up "armbian" >/dev/null 2>&1
			fi
		fi
		}
}

#
# edit ip address
#
function ip_editor ()
{

	exec 3>&1
	dialog --title " Static IP configuration" --backtitle "$BACKTITLE" --form "\nAdapter: $1
	\n " 12 38 0 \
	"Address:"				1 1 "$address"				1 15 15 0 \
	"Netmask:"			2 1 "$netmask"	2 15 15 0 \
	"Gateway:"			3 1 "$gateway"			3 15 15 0 \
	2>&1 1>&3 | {
		read -r address;read -r netmask;read -r gateway
		if [[ $? = 0 ]]; then
				echo -e "# armbian-config created\nsource /etc/network/interfaces.d/*\n" >$3
				echo -e "# Local loopback\nauto lo\niface lo inet loopback\n" >> $3
				echo -e "# Interface $2\nauto $2\nallow-hotplug $2\niface $2 inet static\
				\n\taddress $address\n\tnetmask $netmask\n\tgateway $gateway\n\tdns-nameservers 8.8.8.8" >> $3
		fi
		}

}

MonitorMode() {
	# $1 is the time in seconds to pause between two prints, defaults to 5 seconds
	# This functions prints out endlessly:
	# - time/date
	# - average 1m load
	# - detailed CPU statistics
	# - Soc temperature if available
	# - PMIC temperature if available
	# - DC-IN voltage if available

	# Allow armbianmonitor to return back to armbian-config
	trap "echo ; exit 0" 0 1 2 3 15
	
	# Try to renice to 19 to not interfere with OS behaviour
	renice 19 $BASHPID >/dev/null 2>&1

	LastUserStat=0
	LastNiceStat=0
	LastSystemStat=0
	LastIdleStat=0
	LastIOWaitStat=0
	LastIrqStat=0
	LastSoftIrqStat=0
	LastCpuStatCheck=0
	LastTotal=0

	SleepInterval=${interval:-5}

	Sensors="/etc/armbianmonitor/datasources/"
	if [ -f /sys/devices/system/cpu/cpu4/cpufreq/cpuinfo_cur_freq ]; then
		DisplayHeader="Time       big.LITTLE   load %cpu %sys %usr %nice %io %irq"
		CPUs=biglittle
	elif [ -f /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq ]; then
		DisplayHeader="Time        CPU    load %cpu %sys %usr %nice %io %irq"
		CPUs=normal
	else
		DisplayHeader="Time      CPU n/a    load %cpu %sys %usr %nice %io %irq"
		CPUs=notavailable
	fi
	# Set freq output to --- if non-privileged. Overwrites settings above.
	if [ "$(id -u)" != "0" ]; then
		echo "Running unprivileged. CPU frequency will not be displayed."
		CPUs=notavailable
	fi

	[ -f "${Sensors}/soctemp" ] && DisplayHeader="${DisplayHeader}   CPU" || SocTemp='n/a'
	[ -f "${Sensors}/pmictemp" ] && DisplayHeader="${DisplayHeader}   PMIC" || PMICTemp='n/a'
	DCIN=$(CheckDCINVoltage)
	[ -f "${DCIN}" ] && DisplayHeader="${DisplayHeader}   DC-IN" || DCIN='n/a'
	[ -f /sys/devices/virtual/thermal/cooling_device0/cur_state ] \
		&& DisplayHeader="${DisplayHeader}  C.St." || CoolingState='n/a'
	echo -e "Stop monitoring using [ctrl]-[c]"
	[ $(echo "${SleepInterval} * 10" | bc | cut -d. -f1) -le 15 2>/dev/null ] \
		&& echo "Warning: High update frequency (${SleepInterval} sec) might change system behaviour!"
	echo -e "${DisplayHeader}"
	Counter=0
	while true ; do
		if [ "$c" == "m" ]; then
			let Counter++
			if [ ${Counter} -eq 15 ]; then
				echo -e "\n${DisplayHeader}\c"
				Counter=0
			fi
		elif [ "$c" == "s" ]; then
			# internal mode for debug log upload
			let Counter++
			if [ ${Counter} -eq 6 ]; then
				exit 0
			fi
		else
			printf "\x1b[1A"
		fi
		LoadAvg=$(cut -f1 -d" " </proc/loadavg)
		case ${CPUs} in
			biglittle)
				BigFreq=$(awk '{printf ("%0.0f",$1/1000); }' </sys/devices/system/cpu/cpu4/cpufreq/cpuinfo_cur_freq) 2>/dev/null
				LittleFreq=$(awk '{printf ("%0.0f",$1/1000); }' </sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq) 2>/dev/null
				ProcessStats
				echo -e "\n$(date "+%H:%M:%S"): $(printf "%4s" ${BigFreq})/$(printf "%4s" ${LittleFreq})MHz $(printf "%5s" ${LoadAvg}) ${procStats}\c"
				;;
			normal)
				CpuFreq=$(awk '{printf ("%0.0f",$1/1000); }' </sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq) 2>/dev/null
				ProcessStats
				echo -e "\n$(date "+%H:%M:%S"): $(printf "%4s" ${CpuFreq})MHz $(printf "%5s" ${LoadAvg}) ${procStats}\c"
				;;
			notavailable)
				ProcessStats
				echo -e "\n$(date "+%H:%M:%S"):   ---     $(printf "%5s" ${LoadAvg}) ${procStats}\c"
				;;
		esac
		if [ "X${SocTemp}" != "Xn/a" ]; then
			read SocTemp <"${Sensors}/soctemp"
			if [ ${SocTemp} -ge 1000 ]; then
				SocTemp=$(awk '{printf ("%0.1f",$1/1000); }' <<<${SocTemp})
			fi
			echo -e " $(printf "%4s" ${SocTemp})°C\c"
		fi
		if [ "X${PMICTemp}" != "Xn/a" ]; then
			read PMICTemp <"${Sensors}/pmictemp"
			if [ ${PMICTemp} -ge 1000 ]; then
				PMICTemp=$(awk '{printf ("%0.1f",$1/1000); }' <<<${PMICTemp})
			fi
			echo -e " $(printf "%4s" ${PMICTemp})°C\c"
		fi
		if [ "X${DCIN}" != "Xn/a" ]; then
			case "${DCIN##*/}" in
				in_voltage2_raw)
					# Tinkerboard S
					read RAWvoltage <"${DCIN}"
					DCINvoltage=$(echo "(${RAWvoltage} / ((82.0/302.0) * 1023.0 / 1.8)) + 0.1" | bc -l)
					;;
				*)
					DCINvoltage=$(awk '{printf ("%0.2f",$1/1000000); }' <"${DCIN}")
					;;
			esac
			echo -e "  $(printf "%5s" ${DCINvoltage})V\c"
		fi
		[ "X${CoolingState}" != "Xn/a" ] && printf "  %d/%d" $(cat /sys/devices/virtual/thermal/cooling_device0/cur_state) $(cat /sys/devices/virtual/thermal/cooling_device0/max_state)
		[ "$c" == "s" ] && sleep 0.3 || sleep ${SleepInterval}
	done
} # MonitorMode

ProcessStats() {
	if [ -f /tmp/cpustat ]; then
		# RPi-Monitor/Armbianmonitor already running and providing processed values
		set $(awk -F" " '{print $1"\t"$2"\t"$3"\t"$4"\t"$5"\t"$6}' </tmp/cpustat)
		CPULoad=$1
		SystemLoad=$2
		UserLoad=$3
		NiceLoad=$4
		IOWaitLoad=$5
		IrqCombinedLoad=$6		
	else
		procStatLine=(`sed -n 's/^cpu\s//p' /proc/stat`)
		UserStat=${procStatLine[0]}
		NiceStat=${procStatLine[1]}
		SystemStat=${procStatLine[2]}
		IdleStat=${procStatLine[3]}
		IOWaitStat=${procStatLine[4]}
		IrqStat=${procStatLine[5]}
		SoftIrqStat=${procStatLine[6]}

		Total=0
		for eachstat in ${procStatLine[@]}; do
			Total=$(( ${Total} + ${eachstat} ))
		done

		UserDiff=$(( ${UserStat} - ${LastUserStat} ))
		NiceDiff=$(( ${NiceStat} - ${LastNiceStat} ))
		SystemDiff=$(( ${SystemStat} - ${LastSystemStat} ))
		IOWaitDiff=$(( ${IOWaitStat} - ${LastIOWaitStat} ))
		IrqDiff=$(( ${IrqStat} - ${LastIrqStat} ))
		SoftIrqDiff=$(( ${SoftIrqStat} - ${LastSoftIrqStat} ))
		
		diffIdle=$(( ${IdleStat} - ${LastIdleStat} ))
		diffTotal=$(( ${Total} - ${LastTotal} ))
		diffX=$(( ${diffTotal} - ${diffIdle} ))
		CPULoad=$(( ${diffX}* 100 / ${diffTotal} ))
		UserLoad=$(( ${UserDiff}* 100 / ${diffTotal} ))
		SystemLoad=$(( ${SystemDiff}* 100 / ${diffTotal} ))
		NiceLoad=$(( ${NiceDiff}* 100 / ${diffTotal} ))
		IOWaitLoad=$(( ${IOWaitDiff}* 100 / ${diffTotal} ))
		IrqCombined=$(( ${IrqDiff} + ${SoftIrqDiff} ))
		IrqCombinedLoad=$(( ${IrqCombined}* 100 / ${diffTotal} ))

		LastUserStat=${UserStat}
		LastNiceStat=${NiceStat}
		LastSystemStat=${SystemStat}
		LastIdleStat=${IdleStat}
		LastIOWaitStat=${IOWaitStat}
		LastIrqStat=${IrqStat}
		LastSoftIrqStat=${SoftIrqStat}
		LastTotal=${Total}
	fi
	procStats=$(echo -e "$(printf "%3s" ${CPULoad})%$(printf "%4s" ${SystemLoad})%$(printf "%4s" ${UserLoad})%$(printf "%4s" ${NiceLoad})%$(printf "%4s" ${IOWaitLoad})%$(printf "%4s" ${IrqCombinedLoad})%")
} # ProcessStats

CheckDCINVoltage() {
	for i in /sys/devices/platform/sunxi-i2c.0/i2c-0/0-0034/axp20-supplyer.28/power_supply/usb/voltage_now \
		/sys/power/axp_pmu/vbus/voltage \
		/sys/devices/platform/sunxi-i2c.0/i2c-0/0-0034/axp20-supplyer.28/power_supply/ac/voltage_now \
		/sys/power/axp_pmu/ac/voltage '/sys/bus/iio/devices/iio:device0/in_voltage2_raw' ; do
		if [ -f $i ]; then
			read DCINvoltage <$i 2>/dev/null
			if [ ${DCINvoltage} -gt 4080000 ]; then
				echo $i
				break
			fi
		fi
	done
} # CheckDCINVoltage

#
# naming exceptions for packages
#
function exceptions ()
{

	TARGET_FAMILY=$LINUXFAMILY
	UBOOT_BRANCH=$TARGET_BRANCH # uboot naming is different

	if [[ $TARGET_BRANCH == "default" ]]; then TARGET_BRANCH=""; else TARGET_BRANCH="-"$TARGET_BRANCH; fi
	# pine64
	if [[ $TARGET_FAMILY == pine64 ]]; then
		TARGET_FAMILY="sunxi64"
	fi
	# allwinner legacy kernels
	if [[ $TARGET_FAMILY == sun*i ]]; then
		TARGET_FAMILY="sunxi"
		if [[ $UBOOT_BRANCH == "default" ]]; then
			TARGET_FAMILY=$(cat /proc/cpuinfo | grep "Hardware" | sed 's/^.*Allwinner //' | awk '{print $1;}')
		fi
	fi

}
