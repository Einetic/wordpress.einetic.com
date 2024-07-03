#!/bin/bash

# Function to generate MD5 hash
generate_md5() {
    local input="$1"
    md5sum <<<"$input" | cut -d ' ' -f 1
}

generate_username() {
    domain_name="$1"
	if [[ "$domain_name" == www.* ]]; then
		domain_name=$(echo "$domain_name" | cut -d '.' -f 2)
	else
		domain_name=$(echo "$domain_name" | cut -d '.' -f 2)-$(echo "$domain_name" | cut -d '.' -f 1)
	fi
	if [[ ${#domain_name} -gt 30 ]]; then
        domain_name="${domain_name:0:30}"
    fi
	echo "$domain_name"
}

# Function to perform POST request
upload_backup() {
    local domain_name="$1"
    local zip_filename="$2"
    local url="https://beta.einetic.com/api/v2/server/backup"

	echo "Uploading...$domain_name"

    # Perform POST request
    curl  -# -X POST -F "domain=$domain_name" -F "file=@$zip_filename"  --max-time 7200 --connect-timeout 300 --limit-rate 10M --retry 5 --expect100-timeout 60 "$url"
	echo "Done"
	rm "$zip_filename"
#	read -p "Press any key to continue" choice
#	manage_websites
}

# Function to take backup
take_backup() {
	directory_path="$1"
	domain_name=$(basename "$directory_path")
	username=$(basename "$(dirname "$(dirname "$directory_path")")")
	zip_folder="/home/$username/htdocs/$domain_name"
	database_filename="/home/$username/$domain_name.sql.gz"
	zip_filename="/home/$username/$domain_name.zip"
	clpctl db:export --databaseName="$username" --file="$database_filename"
	echo "Zipping..."
	zip -qr "$zip_filename" "$zip_folder" "$database_filename"
	rm "$database_filename"
	upload_backup "$domain_name" "$zip_filename"
#	mv "$zip_filename" "/home/ubuntu/wp-backup"
}

take_all_backup() {
	clear
	echo "===== Backup Menu ====="
    i=1
	for htdocs_dir in /home/*/htdocs/*/; do
		if [ -d "$htdocs_dir" ] && [ ! "$(basename "$htdocs_dir")" == "app" ]; then
			((i++))
		fi
	done 
	echo "Backup all $((i-1)) websites. Are you sure?"
	read -p "Confirm (y/n): " confirm_choice
	if [ "$confirm_choice" == "y" ]; then		
		for htdocs_dir in /home/*/htdocs/*/; do
			if [ -d "$htdocs_dir" ] && [ ! "$(basename "$htdocs_dir")" == "app" ]; then
				take_backup "$htdocs_dir"
			fi
		done				
   		read -p "Press any key to continue. " confirm_choice
	fi	
}


install_ssl() {
	directory_path="$1"
	domain_name=$(basename "$directory_path")
	if [[ "$domain_name" == www.* ]]; then
		tld=$(echo "$domain_name" | sed 's/^www\.//')
		echo "Requesting ssl for $tld, $domain_name"
		clpctl lets-encrypt:install:certificate --domainName=$domain_name --subjectAlternativeName=$tld,$domain_name
	else
		echo "Requesting ssl for $domain_name"
		clpctl lets-encrypt:install:certificate --domainName=$domain_name
	fi
}

install_all_ssl() {
	clear
	echo "===== SSL Menu ====="
    i=1
	for htdocs_dir in /home/*/htdocs/*/; do
        if [ -d "$htdocs_dir" ] && [ ! "$(basename "$htdocs_dir")" == "app" ]; then
            ((i++))
        fi
    done 
	echo "Request ssl for all $((i-1)) websites. Are you sure?"
	read -p "Confirm (y/n): " confirm_choice
	if [ "$confirm_choice" == "y" ]; then		
		for htdocs_dir in /home/*/htdocs/*/; do
			if [ -d "$htdocs_dir" ] && [ ! "$(basename "$htdocs_dir")" == "app" ]; then
				install_ssl "$htdocs_dir"
			fi
		done
   		read -p "Press any key to continue. " confirm_choice
	fi	
}

restore_all_wp_local_backup() {
	clear
	echo "===== Restore Menu ====="
    i=1
    for web_bkp in /home/ubuntu/wp-backup/*; do
       if [ -f "$web_bkp" ]; then
            ((i++))
       fi
    done 
	echo "Restore all $((i-1)) websites. Are you sure?"
	read -p "Confirm (y/n): " confirm_choice
	if [ "$confirm_choice" == "y" ]; then		
		for web_bkp in /home/ubuntu/wp-backup/*; do
			if [ -f "$web_bkp" ]; then
				restore_backup "$web_bkp"
			fi
		done
	   	read -p "Press any key to continue. " confirm_choice
	fi 
}

restore_backup() {
	directory_path="$1"
	domain_name=$(basename "$directory_path" .zip)
	echo "Domain Name: $domain_name"
	user_password=$(generate_md5 "$domain_name")
	echo "Password: $user_password"
	user_name=$(generate_username "$domain_name")
	echo "User Name: $user_name"

    if [ -d "/home/$user_name/htdocs/$domain_name" ]; then
        echo "Domain $domain_name already exists."
    else
		echo "Restoring Backup"
		clpctl site:add:php --domainName="$domain_name" --phpVersion=8.3 --vhostTemplate='WordPress' --siteUser="$user_name" --siteUserPassword="$user_password"
		clpctl db:add --domainName="$domain_name" --databaseName="$user_name" --databaseUserName="$user_name" --databaseUserPassword="$user_password"
		unzip -q "/home/ubuntu/wordpress-6.5.5.zip" -d /home/ubuntu
		mv -f /home/ubuntu/wordpress/* /home/$user_name/htdocs/$domain_name/
		rm -rf /home/ubuntu/wordpress
		rm -rf /home/$user_name/htdocs/${domain_name}/wp-content/*
		unzip -q "$directory_path" -d /home/ubuntu/tmp
		database_filename=$(find /home/ubuntu/tmp/home/*/ -name "$domain_name.sql.gz")
		wp_content_directory="${database_filename%/*}/htdocs/${domain_name}/wp-content"
		mv -f ${wp_content_directory}/* /home/$user_name/htdocs/${domain_name}/wp-content/
		clpctl db:import --databaseName="$user_name" --file="$database_filename"
		rm -rf /home/ubuntu/tmp/*
		sudo wp config create --dbname=$user_name --dbuser=$user_name --dbpass=$user_password --dbhost=localhost --dbprefix=wp_ --dbcharset=utf8mb4 --path=/home/$user_name/htdocs/${domain_name}/ --allow-root
		chown -R $user_name:$user_name /home/$user_name/htdocs/${domain_name}/
		find /home/$user_name/ -type d -exec chmod 770 {} \;
		find /home/$user_name/ -type f -exec chmod 660 {} \;		
#		sudo wp user create $user_name $user_name@einetic.com --role=administrator --user_pass=$user_password --display_name==Administrator --path=/home/$user_name/htdocs/${domain_name}/ --allow-root

  fi
	echo "Done."
}

manage_wp_backup() {
	clear
    echo "===== Local Backup Menu ====="
    i=1
	website_list=()
    for web_bkp in /home/ubuntu/wp-backup/*; do
       if [ -f "$web_bkp" ]; then
            echo "$i. $(basename "$web_bkp" .zip)"
			  website_list+=("$web_bkp")
            ((i++))
       fi
    done 
	echo "0. Back"
    echo "====================="
    read -p "Enter your choice: " website_choice
	
	if [ "$website_choice" -eq 0 ]; then
    	add_new_website
	elif [ "$website_choice" -gt 0 ] && [ "$website_choice" -lt "$i" ]; then
		echo "===== $(basename "${website_list[$((website_choice-1))]}") ====="
		restore_backup "${website_list[$((website_choice-1))]}"
	else
		echo "Invalid choice. Please enter a number from 1 to $((i-1))."
	fi
	read -p "Press any key to continue. " choice 
	manage_wp_backup
}

add_new_website() {
	clear
    echo "===== Add New Website ====="
    echo "1. Restore from URL"
    echo "2. Restore from local"
	echo "0. Back"
    read -p "Enter your choice: " restore_choice

    case $restore_choice in
		1) echo "Restoring website from URL coming soon" ;;
		2) manage_wp_backup ;;
		0) main_menu ;;
		*) echo "Invalid choice.." ;;
    esac
	read -p "Press any key to continue. " choice 
	add_new_website
}

manage_websites() {
	clear
    echo "===== Website Menu ====="
    i=1
	website_list=()
    for htdocs_dir in /home/*/htdocs/*/; do
        if [ -d "$htdocs_dir" ] && [ ! "$(basename "$htdocs_dir")" == "app" ]; then
            echo "$i.  $(basename "$htdocs_dir")"
			  website_list+=("$htdocs_dir")
            ((i++))
        fi
    done 
    echo "0. Back"
    echo "====================="
    read -p "Enter your choice: " website_choice
	
	if [ "$website_choice" -eq 0 ]; then
    	main_menu
	elif [ "$website_choice" -gt 0 ] && [ "$website_choice" -lt "$i" ]; then
		echo "===== $(basename "${website_list[$((website_choice-1))]}") ====="
    	echo "1. Backup"
    	echo "2. SSL"
		echo "3. Fix"
    	echo "0. Back"
    	echo "====================="
		read -p "Enter your choice: " selected_website_choice
		case $selected_website_choice in
			1) take_backup "${website_list[$((website_choice-1))]}" ;;
			2) install_ssl "${website_list[$((website_choice-1))]}" ;;
			3) fix_wp "${website_list[$((website_choice-1))]}" ;;
			0) main_menu ;;
           *) echo "Invalid choice." ;;
		esac
	else
		echo "Invalid choice. Please enter a number from 1 to $((i-1))."
	fi
	read -p "Press any key to continue" choice 
	manage_websites
}

list_local_backup(){
	clear
    echo "===== Local Backup List ====="
    i=1
	backup_list=()
    for backups in /home/ubuntu/wp-backup/*; do
        if [ -f "$backups" ]; then
            echo "$i.  $(basename "$backups")"
			backup_list+=("$backups")
            ((i++))
        fi
    done 
    echo "0. Back"
    echo "====================="
    read -p "Enter your choice: " website_choice
	
	if [ "$website_choice" -eq 0 ]; then
    	main_menu
	elif [ "$website_choice" -gt 0 ] && [ "$website_choice" -lt "$i" ]; then
		echo "===== $(basename "${backup_list[$((website_choice-1))]}") ====="
    	echo "1. Upload"
    	echo "2. Restore"
    	echo "0. Delete"
    	echo "====================="
		read -p "Enter your choice: " selected_website_choice
		case $selected_website_choice in
			1) upload_local_backup "${backup_list[$((website_choice-1))]}" ;;
			0) main_menu ;;
           *) echo "Invalid choice." ;;
		esac
	else
		echo "Invalid choice. Please enter a number from 1 to $((i-1))."
	fi
	read -p "Press any key to continue" choice 
	list_local_backup
}

upload_local_backup(){
	zip_path="$1"
	zipFileName=$(basename "$zip_path")
	domain_name="${zipFileName%.*}"
	upload_backup "$domain_name" "$zip_path"
}

fix_wp() {
	directory_path="$1"
	domain_name=$(basename "$directory_path")
	user_name=$(generate_username "$domain_name")
	echo "Fixing ${domain_name}"
	if [ -d "${directory_path}wp-content/wphb-cache" ]; then
    	rm -rf "${directory_path}wp-content/wphb-cache"
	fi
	if [ -d "${directory_path}wp-content/wphb-logs" ]; then
    	rm -rf "${directory_path}wp-content/wphb-logs"
	fi
	if [ -d "${directory_path}wp-content/updraft" ]; then
    	rm -rf "${directory_path}wp-content/updraft"
	fi
	if [ -d "${directory_path}wp-content/aiowps_backups" ]; then
    	rm -rf "${directory_path}wp-content/aiowps_backups"
	fi
	if [ -f "${directory_path}wp-content/debug.log" ]; then
    	rm -rf "${directory_path}wp-content/debug.log"
	fi
	if [ -d "${directory_path}wp-content/backup-migration" ]; then
    	rm -rf "${directory_path}wp-content/backup-migration"
	fi
	if [ -f "${directory_path}wp-content/backup-migration-config.php" ]; then
    	rm -rf "${directory_path}wp-content/backup-migration-config.php"
	fi

	unzip -q "/home/ubuntu/wordpress-6.5.5.zip" -d /home/ubuntu/tmp
	rm -rf /home/ubuntu/tmp/wordpress/wp-content
	find "$directory_path" -mindepth 1 -maxdepth 1 ! -name 'wp-content' ! -name 'wp-config.php' -exec rm -rf {} +
	mv -f /home/ubuntu/tmp/wordpress/* $directory_path
	rm -rf /home/ubuntu/tmp/wordpress
	chown -R $user_name:$user_name /home/$user_name/htdocs/${domain_name}/
	find /home/$user_name/ -type d -exec chmod 770 {} \;
	find /home/$user_name/ -type f -exec chmod 660 {} \;
	echo "Done."	
}

fix_all_wp() {
	clear
	echo "===== Fix all Wordpress ====="
    local i=1
	for htdocs_dir in /home/*/htdocs/*/; do
        if [ -d "$htdocs_dir" ] && [ ! "$(basename "$htdocs_dir")" == "app" ]; then
            ((i++))
        fi
    done 
	echo "Fix wordpress for all $((i-1)) websites. Are you sure?"
	read -p "Confirm (y/n): " confirm_choice
	if [ "$confirm_choice" == "y" ]; then		
		for htdocs_dir in /home/*/htdocs/*/; do
			if [ -d "$htdocs_dir" ] && [ ! "$(basename "$htdocs_dir")" == "app" ]; then
				fix_wp "$htdocs_dir"
			fi
		done
   		read -p "Press any key to continue. " confirm_choice
	fi	
}


# Main menu function
main_menu() {
	clear
    echo "===== Main Menu v0.0.1====="
    echo "1. List websites"
    echo "2. New website"
    echo "3. Backup all"
    echo "4. Restore all"
    echo "5. SSL all"
	echo "6. List backups"
	echo "7. Fix all wordpress"
    echo "0. Exit"
    echo "====================="
    read -p "Enter your choice: " main_choice
	case $main_choice in
		1) manage_websites ;;
		2) add_new_website ;;
		3) take_all_backup ;;
		4) restore_all_wp_local_backup ;;
		5) install_all_ssl ;;
		6) list_local_backup ;;
		7) fix_all_wp ;;
		0) echo "Exiting program."
			exit ;;
		*) echo "Invalid choice. Please enter a number from 1 to 5." ;;
	esac
}

# Main loop
while true; do
    main_menu
done



