#!/bin/bash
#
#
# Copyright (c) 2017 Igor Pecovnik, igor.pecovnik@gma**.com
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.

[[ -n ${SUDO_USER} ]] && SUDO="sudo "

function jobs ()
{
	# Shows box with loading ...
	#
	dialog --backtitle "$BACKTITLE" --title " Please wait " --infobox "\nLoading ${selection,,} submodule ... " 5 $((26+${#selection}))
	case $1 in

	#-------------------------------------------------------------------------------------------------------------------------------------#


	# Install to SATA, eMMC, NAND or USB
	#
	"Install" )
		/usr/local/sbin/install_to_emmc
	;;

	# Stop low-level messages on console
	#
	"Lowlevel" )
		dialog --title " Kernel messages " --backtitle "$BACKTITLE" --help-button \
		--help-label "Yes & reboot" --yes-label "Yes" --no-label "Cancel" --yesno "\nStop low-level messages on console?" 7 64
		exitstatus=$?;
		[[ $exitstatus = 0 ]] && sed -i 's/^#kernel.printk\(.*\)/kernel.printk\1/' /etc/sysctl.conf
		[[ $exitstatus = 2 ]] && sed -i 's/^#kernel.printk\(.*\)/kernel.printk\1/' /etc/sysctl.conf && reboot
	;;

	# CPU speed and governor
	#
	"CPU" )
		POLICY="policy0"
	        [[ $(grep -c '^processor' /proc/cpuinfo) -gt 4 ]] && POLICY="policy4"
		[[ ! -d /sys/devices/system/cpu/cpufreq/policy4 ]] && POLICY="policy0"
		generic_select "$(cat /sys/devices/system/cpu/cpufreq/$POLICY/scaling_available_frequencies)" "Select minimum CPU speed"
		MIN_SPEED=$PARAMETER
		generic_select "$(cat /sys/devices/system/cpu/cpufreq/$POLICY/scaling_available_frequencies)" "Select maximum CPU speed" "$PARAMETER"
		MAX_SPEED=$PARAMETER
		generic_select "$(cat /sys/devices/system/cpu/cpufreq/$POLICY/scaling_available_governors)" "Select CPU governor"
		GOVERNOR=$PARAMETER
		if [[ -n $MIN_SPEED && -n $MAX_SPEED && -n $GOVERNOR ]]; then
			dialog --colors --title " Apply and save changes " --backtitle "$BACKTITLE" --yes-label "OK" --no-label "Cancel" --yesno \
			"\nCPU frequency will be within \Z1$(($MIN_SPEED / 1000))\Z0 and \Z1$(($MAX_SPEED / 1000)) MHz\Z0. The governor \Z1$GOVERNOR\Z0 will decide which speed to use within this range." 9 58
			if [[ $? -eq 0 ]]; then
				sed -i "s/MIN_SPEED=.*/MIN_SPEED=$MIN_SPEED/" /etc/default/cpufrequtils
				sed -i "s/MAX_SPEED=.*/MAX_SPEED=$MAX_SPEED/" /etc/default/cpufrequtils
				sed -i "s/GOVERNOR=.*/GOVERNOR=$GOVERNOR/" /etc/default/cpufrequtils
				systemctl restart cpufrequtils
				sync
			fi
		fi
	;;

	# Toggle sshd options
	#
	"SSH" )
	if ! is_package_manager_running; then
		while true; do
			if ! check_if_installed libpam-google-authenticator ; then
				debconf-apt-progress -- apt-get -y install libpam-google-authenticator
			fi
			if ! check_if_installed qrencode ; then
				debconf-apt-progress -- apt-get -y install qrencode
			fi
			DIALOG_CANCEL=2
			DIALOG_ESC=255
			LIST_CONST=9
			WINDOW_SIZE=21

			# variables cleanup
			PermitRootLogin="";
			PubkeyAuthentication="";
			PasswordAuthentication="";
			PhoneAuthentication=""
			MergeParameter="";
			ExtraDesc="";

			Buttons="--no-cancel --ok-label "Save" --help-button --help-label Cancel"

			# read values
			[[ $(grep "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}') == "yes" ]] 			&& PermitRootLogin="on"
			[[ $(grep "^@include common-auth" /etc/pam.d/sshd | awk '{print $2}') == "common-auth" ]]  	&& PasswordAuthentication="on"
			[[ $(grep "^PubkeyAuthentication" /etc/ssh/sshd_config | awk '{print $2}') == "yes" ]]  	&& PubkeyAuthentication="on"
			[[ -n $(grep "pam_google_authenticator.so" /etc/pam.d/sshd) ]] 								&& PhoneAuthentication="on"

			# create menu
			MOTD=( "PermitRootLogin" "Allow root login" "$PermitRootLogin" )
			MOTD+=( "PasswordAuthentication" "Password login" "$PasswordAuthentication" )
			MOTD+=( "PubkeyAuthentication" "SSH key login" "$PubkeyAuthentication" )
			MOTD+=( "PhoneAuthentication" "Google two-step authentication with one-time passcode" "$PhoneAuthentication" )

			Buttons="--no-cancel --ok-label "Save" --help-button --help-label Cancel"
			if [[ $PhoneAuthentication == "on" ]]; then
				Buttons="--cancel-label Generate-token --ok-label "Save" --help-button --help-label Cancel"
				ExtraDesc="\n\Z1Note:\Z0 Two-step verification token is identical for all users on the system.\n \n"
				LIST_CONST=11
				if [[ -f ~/.google_authenticator ]]; then
					Buttons="--cancel-label New-token --ok-label "Save" --help-button --help-label Cancel --extra-button --extra-label Show-token"
				fi
			fi

			LISTLENGTH="$((${#MOTD[@]}/3))"
			HEIGHT="$((LISTLENGTH + $LIST_CONST))"

			exec 3>&1
				selection=$(dialog --colors $Buttons --backtitle "$BACKTITLE" --title " Toggle sshd options " --clear --checklist \
				"\nChoose what you want to enable or disable:\n $ExtraDesc" $HEIGHT 0 $LISTLENGTH "${MOTD[@]}" 2>&1 1>&3)
				exit_status=$?
			exec 3>&-

			case $exit_status in
				$DIALOG_CANCEL | $DIALOG_ESC)
				break
				;;
				0)
					# read values, adjust config and restart service
					my_array=($selection)
					for((n=0;n<${#MOTD[@]};n++)); do
						if (( $(($n % 3 )) == 0 )); then

								# generic options if any
								if [[ " ${my_array[*]} " == *" ${MOTD[$n]} "* ]]; then
									sed -i "s/^#\?${MOTD[$n]}.*/${MOTD[$n]} yes/" /etc/ssh/sshd_config
									else
									sed -i "s/^#\?${MOTD[$n]}.*/${MOTD[$n]} no/" /etc/ssh/sshd_config
								fi

								if [[ $n -eq 0 ]]; then

									# phone
									if [[ " ${my_array[*]} " == *" PhoneAuthentication "* ]]; then
										MergeParameter="keyboard-interactive"
										sed -i "s/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/" /etc/ssh/sshd_config
										sed -i -n '/password updating/{p;:a;N;/@include common-password/!ba;s/.*\n/auth required pam_google_authenticator.so nullok\n/};p' /etc/pam.d/sshd
										else
										MergeParameter=""
										sed -i '/^auth required pam_google_authenticator.so nullok/ d' /etc/pam.d/sshd
										sed -i "s/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/" /etc/ssh/sshd_config
									fi

									# password
									if [[ " ${my_array[*]} " == *" PasswordAuthentication "* ]]; then
											MergeParameter="password keyboard-interactive"
											sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication yes/" /etc/ssh/sshd_config
											sed -i "s/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/" /etc/ssh/sshd_config
											sed -i "s/^\#@include common-auth/\@include common-auth/" /etc/pam.d/sshd
										else
											sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config
											#sed -i "s/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/" /etc/ssh/sshd_config
											sed -i "s/^\@include common-auth/\#@include common-auth/" /etc/pam.d/sshd
									fi

									# pubkey
									if [[ " ${my_array[*]} " == *" PubkeyAuthentication "* ]]; then
											MergeParameter="publickey keyboard-interactive "
											sed -i "s/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/" /etc/ssh/sshd_config
										else
											sed -i "s/^#\?PubkeyAuthentication.*/PubkeyAuthentication no/" /etc/ssh/sshd_config
									fi


									if [[ " ${my_array[*]} " == *" PubkeyAuthentication "* && " ${my_array[*]} " == *" PhoneAuthentication "* ]]; then
											MergeParameter="publickey,password publickey,keyboard-interactive"
											sed -i "s/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/" /etc/ssh/sshd_config
									fi


								fi
						fi
					done

					if [[ -z $MergeParameter ]]; then
							sed -i '/^AuthenticationMethods.*/ d' /etc/ssh/sshd_config
						else
							sed -i '/^AuthenticationMethods.*/ d' /etc/ssh/sshd_config
							sed -i -n '/and ChallengeResponseAuthentication to/{p;:a;N;/UsePAM yes/!ba;s/.*\n/AuthenticationMethods '"$MergeParameter"'\n/};p' /etc/ssh/sshd_config
					fi

					# reload sshd
					systemctl restart sshd.service
				;;
				3)
					display_qr_code
				;;
				1)
					dialog --colors --title " \Z1Warning\Z0 " --backtitle "$BACKTITLE" --yes-label "Generate" --no-label "No" --yesno "\nWhen you generate new token you have to scan it with your mobile device again.\n\nUnderstand?" 10 48
					if [[ $? = 0 ]]; then
						google-authenticator -t -d -f -r 3 -R 30 -W -q
						google_token_allusers
						display_qr_code
					fi
				;;
				esac
		done
	fi
	;;

	# Firmware update
	#
	"Firmware" )
		if ! is_package_manager_running; then
			clear
			exec 3>&1
			monitor=$(dialog --print-maxsize 2>&1 1>&3)
			exec 3>&-
			mon_x=$(echo $monitor | awk '{print $2}' | sed 's/,//');mon_x=$(( $mon_x / 2 ))
			mon_y=$(echo $monitor | awk '{print $3}' | sed 's/,//');
			dialog --title " Update " --backtitle "$BACKTITLE" --no-label "No" --yesno "\nDo you want to update board firmware?" 7 41
			if [[ $? = 0 ]]; then
				debconf-apt-progress -- apt-get update
				debconf-apt-progress -- apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y upgrade
				dialog --title " Firmware update " --colors --no-label "No" --backtitle "$BACKTITLE" --yesno \
				"\nFirmware has been updated. Reboot?   " 7 39
				if [[ $? = 0 ]]; then reboot; fi
			fi
		fi
	;;

	# ZSH
	#
	"BASH" )
		# change shell for root
		chsh -s /bin/bash
		add_choose_user
		if [ -n "$CHOSEN_USER" ]; then
			chsh -s /bin/bash $CHOSEN_USER
		fi
		# cleanup
		rm -rf /etc/oh-my-zsh /etc/skel/.zshrc /etc/skel/.oh-my-zsh
		rm -rf /root/{.zshrc,.oh-my-zsh}
		# and for selected normal user
		add_choose_user
		if [ -n "$CHOSEN_USER" ]; then
			rm -rf /home/$CHOSEN_USER/{.zshrc,.oh-my-zsh}
		fi
		# change shell for future users
		sed -i "s/^SHELL=.*/SHELL=\/bin\/bash/" /etc/default/useradd
		# remove crontab
		crontab -l | grep -v oh-my  | crontab -
		dialog --backtitle "$BACKTITLE" --title "Info" --colors --msgbox "\nYour default shell was switched to: \Z1BASH\Z0\n\nPlease logout & login from this session!" 9 47
	;;

	# ZSH
	#
	"ZSH" )
		if ! is_package_manager_running; then
		if ! check_if_installed zsh ; then
			debconf-apt-progress -- apt-get update
			debconf-apt-progress -- apt-get install -y zsh tmux
		fi
		rm -rf /etc/oh-my-zsh
		git clone --quiet https://github.com/robbyrussell/oh-my-zsh.git /etc/oh-my-zsh
		cp /etc/oh-my-zsh/templates/zshrc.zsh-template /etc/skel/.zshrc
		mkdir -p /etc/skel/.oh-my-zsh/cache
		# change shell for future users
		sed -i "s/^SHELL=.*/SHELL=\/usr\/bin\/zsh/" /etc/default/useradd
		# we have common settings
		sed -i "s/^export ZSH=.*/export ZSH=\/etc\/oh-my-zsh/" /etc/skel/.zshrc
		# user cache
		sed -i "/^export ZSH=.*/a export ZSH_CACHE_DIR=~\/.oh-my-zsh\/cache" /etc/skel/.zshrc
		# define theme
		sed -i 's/^ZSH_THEME=.*/ZSH_THEME="risto"/' /etc/skel/.zshrc
		# define default plugins
		sed -i 's/^plugins=.*/plugins=(git git-extras debian tmux screen history extract colorize web-search docker)/' /etc/skel/.zshrc		
		# change shell for root
		chsh -s $(grep /zsh$ /etc/shells | tail -1)
		# copy cache directory
		cp -R --attributes-only /etc/skel/.oh-my-zsh /root/.oh-my-zsh
		cp /etc/skel/.zshrc /root/.zshrc
		# and for selected normal user
		add_choose_user
		if [ -n "$CHOSEN_USER" ]; then
			chsh -s $(grep /zsh$ /etc/shells | tail -1) $CHOSEN_USER
			# copy cache directory
			cp -R --attributes-only /etc/skel/.oh-my-zsh /home/$CHOSEN_USER/.oh-my-zsh
			cp /etc/skel/.zshrc /home/$CHOSEN_USER/.zshrc
			chown -R ${CHOSEN_USER}:${CHOSEN_USER} /home/${CHOSEN_USER}/{.zshrc,.oh-my-zsh}
		fi
		# add a cronjob to update oh-my-zsh once per month
		(crontab -l 2>/dev/null; echo "0 0 1 * * cd /etc/oh-my-zsh ; git -q pull origin master >/dev/null 2>/dev/null") | crontab -
		dialog --backtitle "$BACKTITLE" --title "Info" --colors --msgbox "\nYour default shell was switched to: \Z1ZSH\Z0\n\nPlease logout & login from this session!" 9 47
		fi
	;;


	# Enable or disable desktop
	#
	"Desktop" )
		if [[ -n $DISPLAY_MANAGER ]]; then
			dialog --title " Desktop is enabled and running " --backtitle "$BACKTITLE" \
			--yes-label "Stop" --no-label "Cancel" --yesno "\nDo you want to stop and disable this service?" 7 50
			exitstatus=$?;
			if [[ $exitstatus = 0 ]]; then
				function stop_display()
				{
					bash -c "service lightdm stop >/dev/null 2>&1
					systemctl disable lightdm.service >/dev/null 2>&1
					service nodm stop >/dev/null 2>&1
					systemctl disable nodm.service >/dev/null 2>&1"
				}
				if xhost >& /dev/null ; then
					stop_display &
				else
					stop_display
				fi
			fi
		else
			if ! is_package_manager_running; then
				# remove nodm and install lightdm = backward compatibility
				[[ -n $(dpkg -l | grep nodm) ]] && debconf-apt-progress -- apt-get -y purge nodm
				[[ -z $(dpkg -l | grep lightdm) ]] && debconf-apt-progress -- apt-get -o Dpkg::Options::="--force-confold" -y --no-install-recommends install lightdm-gtk-greeter lightdm
				if [[ -n $DESKTOP_INSTALLED ]]; then
					dialog --title " Display manager " --backtitle "$BACKTITLE" --yesno "\nDo you want to enable autologin?" 7 36
					exitstatus=$?;
					if [[ $exitstatus = 0 ]]; then
						add_choose_user
						if [ -n "$CHOSEN_USER" ]; then
							mkdir -p /etc/lightdm/lightdm.conf.d
							echo "[Seat:*]" > /etc/lightdm/lightdm.conf.d/22-orangepi-autologin.conf
							echo "autologin-user=$CHOSEN_USER" >> /etc/lightdm/lightdm.conf.d/22-orangepi-autologin.conf
							echo "autologin-user-timeout=0" >> /etc/lightdm/lightdm.conf.d/22-orangepi-autologin.conf
							echo "user-session=xfce" >> /etc/lightdm/lightdm.conf.d/22-orangepi-autologin.conf
							ln -s /lib/systemd/system/lightdm.service /etc/systemd/system/display-manager.service >/dev/null 2>&1
							service lightdm start >/dev/null 2>&1
						fi
					else
						rm /etc/lightdm/lightdm.conf.d/22-orangepi-autologin.conf >/dev/null 2>&1
						ln -s /lib/systemd/system/lightdm.service /etc/systemd/system/display-manager.service >/dev/null 2>&1
						service lightdm start >/dev/null 2>&1
					fi
					# kill this bash script after desktop is up and if executed on console
					[[ $(tty | sed -e "s:/dev/::") == tty* ]] && kill -9 $$
				fi
			fi
		fi
	;;


	# Select dynamic or edit static IP address
	#
	"IP" )
			select_interface
			# check if we have systemd networking in action
			SYSTEMDNET=$(service systemd-networkd status | grep -w active | grep -w running)
			dialog --title " IP address assignment " --colors --backtitle "$BACKTITLE" --help-button --help-label "Cancel" \
			--yes-label "DHCP" --no-label "Static" --yesno \
			"\n\Z1DHCP:\Z0   automatic IP assignment by your router or DHCP server\n\n\Z1Static:\Z0 manually fixed IP address" 9 70
			exitstatus=$?;

			# dynamic
			if [[ $exitstatus = 0 ]]; then
				if [[ -n $SYSTEMDNET ]]; then
					filename="/etc/systemd/network/10-${SELECTED_ADAPTER}.network"
					if [[ -f $filename ]]; then
						sed -i '/Network/,$d' $filename
						echo -e "[Network]" >>$filename
						echo -e "DHCP=ipv4" >>$filename
					fi
				else
					if [[ -n $(LC_ALL=C nmcli device status | grep $SELECTED_ADAPTER ) ]]; then
						nmcli connection delete uuid $(LC_ALL=C nmcli -f UUID,DEVICE connection show | grep $SELECTED_ADAPTER | awk '{print $1}') >/dev/null 2>&1
						nmcli con add con-name "Armbian ethernet" type ethernet ifname $SELECTED_ADAPTER >/dev/null 2>&1
						nmcli con up "Armbian ethernet" >/dev/null 2>&1
						else
						create_if_config "$SELECTED_ADAPTER" "$SELECTED_ADAPTER" "dynamic" > /etc/network/interfaces
					fi
				fi
			fi

			# static
			if [[ $exitstatus = 1 ]]; then
				create_if_config "$SELECTED_ADAPTER" "$SELECTED_ADAPTER" "fixed" > /dev/null
				if [[ -n $SYSTEMDNET ]]; then
					systemd_ip_editor "${SELECTED_ADAPTER}"
				else
					if [[ -n $(LC_ALL=C nmcli device status | grep $SELECTED_ADAPTER ) ]]; then
						nm_ip_editor "$SELECTED_ADAPTER"
					else
						ip_editor "$SELECTED_ADAPTER" "$SELECTED_ADAPTER" "/etc/network/interfaces"
					fi
				fi
			fi
	;;


	# Connect to wireless access point
	#
	"WiFi" )
			# disable AP mode on certain adapters
			wlan_exceptions "off"
			[[ "$reboot_module" == true ]] && dialog --backtitle "$BACKTITLE" --title " Warning " --msgbox "\nReboot is required for this adapter to switch to STA mode" 7 62 && reboot
			nmtui-connect
	;;

	# Remove BT
	#
	"BT remove" )
		if ! is_package_manager_running; then
			debconf-apt-progress -- apt-get -y remove bluetooth bluez bluez-tools
			check_if_installed xserver-xorg && debconf-apt-progress -- apt-get -y remove pulseaudio-module-bluetooth blueman
			debconf-apt-progress -- apt -y -qq autoremove
		fi
	;;

	# Enabling BT
	#
	"BT install" )
		if ! is_package_manager_running; then
			debconf-apt-progress -- apt-get -y install bluetooth bluez bluez-tools
			check_if_installed xserver-xorg && debconf-apt-progress -- apt-get -y --no-install-recommends install pulseaudio-module-bluetooth blueman
		fi
	;;

	# Edit network settings
	#
	"Advanced" )
		dialog --backtitle "$BACKTITLE" --title " Edit ifupdown network configuration /etc/network/interfaces" --no-collapse \
		--ok-label "Save" --editbox /etc/network/interfaces 30 0 2> /etc/network/interfaces.out
		[[ $? = 0 ]] && mv /etc/network/interfaces.out /etc/network/interfaces && reload-nety "reload"
	;;

	# Remove automatic wifi conections
	#
	"Forget" )
		LC_ALL=C nmcli --fields UUID,TIMESTAMP-REAL,TYPE con show | grep wifi |  awk '{print $1}' | while read line; \
		do nmcli con delete uuid  $line; done > /dev/null
	;;



	# Change timezone
	#
	"Timezone" )
		dpkg-reconfigure tzdata
	;;


	# Change locales
	#
	"Locales" )
		dpkg-reconfigure locales
		source /etc/default/locale
		sed -i "s/^LANGUAGE=.*/LANGUAGE=$LANG/" /etc/default/locale
		export LANGUAGE=$LANG
	;;

	# Change keyboard
	#
	"Keyboard" )
		dpkg-reconfigure keyboard-configuration
		setupcon
	;;

	# Change Hostname
	#
	"Hostname" )
		hostname_current=$(cat /etc/hostname)
		hostname_new=$(\
		dialog --no-cancel --title " Change hostname " --backtitle "$BACKTITLE" --inputbox "\nType new hostname\n " 10 50 $hostname_current \
		3>&1 1>&2 2>&3 3>&- \
		)
		if [[ $? = 0 && -n $hostname_new ]]; then
			sed -i "s/$hostname_current/$hostname_new/g" /etc/hosts
			sed -i "s/$hostname_current/$hostname_new/g" /etc/hostname
			hostname $hostname_new
			systemctl restart systemd-logind.service
			dialog --title " Info " --backtitle "$BACKTITLE" --no-collapse --msgbox "\nYou need to logout to make the changes effective." 7 53
		fi
	;;

	# Toggle welcome screen items
	#
	"Welcome" )
		while true; do
		HOME="/etc/update-motd.d/"
		MOTD=()
		LINES=()
		LIST_CONST=9
		j=0
		DIALOG_CANCEL=1
		DIALOG_ESC=255

		while read line
		do
			STATUS=$([[ -x ${HOME}${line} ]] && echo "on")
			DESC=$(description "$line")
			MOTD+=( "$line" "$DESC" "$STATUS")
			LINES[ $j ]=$line
			(( j++ ))
		done < <(ls -1 $HOME)

				LISTLENGTH="$(($LIST_CONST+${#MOTD[@]}/3))"
				exec 3>&1
				selection=$(dialog --backtitle "$BACKTITLE" --title "Toggle motd executing scripts" --clear --cancel-label \
				"Back" --ok-label "Save" --checklist "\nChoose what you want to enable or disable:\n " \
				$LISTLENGTH 80 15 "${MOTD[@]}" 2>&1 1>&3)
				exit_status=$?
				exec 3>&-
				case $exit_status in
				$DIALOG_CANCEL | $DIALOG_ESC)
						break
						;;
				0)
						chmod -x ${HOME}*
						chmod +x $(echo "$selection" | sed "s|[^ ]* *|${HOME}&|g")
				;;
				esac
		done
	;;

	# Simple CLI monitoring
	#
	"Monitor" )
		clear
		MonitorMode -m
		sleep 2
	;;

	#
	# Install kernel headers
	#
	"Headers" )
		if ! is_package_manager_running; then
			TARGET_BRANCH=$BRANCH
			exceptions "$BRANCH"
			REMOVE_PKG="linux-headers-*"
			if [[ -f /etc/armbian-release ]]; then
				INSTALL_PKG="linux-headers${TARGET_BRANCH}-${TARGET_FAMILY}";
				else
				INSTALL_PKG="linux-headers-$(uname -r | sed 's/'-$(dpkg --print-architecture)'//')";
			fi
			if [[ -n $(dpkg -l | grep linux-headers) ]]; then
					debconf-apt-progress -- apt-get -y purge ${REMOVE_PKG}
					rm -rf /usr/src/linux-headers*
			else
					debconf-apt-progress -- apt-get -y install ${INSTALL_PKG}
			fi
			# cleanup
			apt clean
			debconf-apt-progress -- apt -y autoremove
		fi
	;;


	# Connect to Bluetooth
	#
	"BT discover" )
	dialog --backtitle "$BACKTITLE" --title " Bluetooth " --msgbox "\nVerify that your Bluetooth device is discoverable!" 7 54
	connect_bt_interface
	;;

	# Change to other mirrors
	#
	"Mirror" )

		IFS=$'\r\n'
		GLOBIGNORE='*'
		LIST_CONST=3
		BEFORE=$(cat /etc/apt/sources.list | sed 's/http/\nhttp/g' | grep ^http | sed 's/\(^http[^ <]*\)\(.*\)/\1/g' | sed 's/https\?:\/\///' | head -1) 
		AVAL_MIRROR=()
		AVAL_MIRROR+=("mirrors.ustc.edu.cn/ubuntu-ports/" "ports.ubuntu.com/")
		local LIST=()
		for i in "${AVAL_MIRROR[@]}"
			do
			case ${i[0]} in
				*mirrors.ustc.edu.cn/ubuntu-ports/*)
					DESC="China"
				;;
				*ports.ubuntu.com/*)
					DESC="Official"
				;;
				
			esac
			LIST+=( "${i[0]//[[:blank:]]/}" "$DESC" )
		done
		LIST_LENGTH=$(($LIST_CONST+${#LIST[@]}/2));
		if [ "$LIST_LENGTH" -le 3 ]; then
			TARGET_MIRROR=${AVAL_MIRROR[0]}
			dialog --backtitle "$BACKTITLE" --title "Please wait" --colors --msgbox "\nThere are no mirrors available!" 7 35
		else
			exec 3>&1
			TARGET_MIRROR=$(dialog --cancel-label "Cancel" --backtitle "$BACKTITLE" --no-collapse \
			--title "Change repository location" --colors --clear --menu ""  $((6+${LIST_LENGTH})) 60 15 "${LIST[@]}" 2>&1 1>&3)
			exitstatus=$?;
			exec 3>&-
		fi

		if [[ $exitstatus == 0 ]]; then
			sed -i "s~$BEFORE~$TARGET_MIRROR~" /etc/apt/sources.list
			dialog --backtitle "$BACKTITLE" --title "Info" --colors --msgbox "\n repository was switched to:\n\n\Z1$TARGET_MIRROR\Z0" 9 47
		fi
	;;

	"RDP" )
		if [[ -n $(service xrdp status | grep -w active) ]]; then
			systemctl stop xrdp.service >/dev/null 2>&1
			systemctl disable xrdp.service >/dev/null 2>&1
		else
			if ! is_package_manager_running; then
				debconf-apt-progress -- apt-get -y install xrdp vnc4server
				systemctl enable xrdp.service >/dev/null 2>&1
				systemctl start xrdp.service >/dev/null 2>&1
				dialog --title "Info" --backtitle "$BACKTITLE" --nocancel --no-collapse --pause \
				"\nRemote graphical login to $BOARD_NAME using Microsoft Remote Desktop Protocol (RDP) is enabled." 11 57 3

			fi
		fi
	;;
	# Application installer
	#
	"Softy" )
		[[ -f /usr/local/sbin/opi_config_libs/softy ]] && . /usr/local/sbin/opi_config_libs/softy
	;;

	esac
}
