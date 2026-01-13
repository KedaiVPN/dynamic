#!/bin/bash
clear
DEFAULT_LIMIT=1
DEFAULT_DURATION=5
MULTILOGIN_WINDOW=600
LIMIT_FILE="/etc/ssh/limit-user.conf"
DURATION_FILE="/etc/ssh/autokill-duration.conf"
if [ -e "/var/log/auth.log" ]; then
        OS=1;
        LOG="/var/log/auth.log";
fi
if [ -e "/var/log/secure" ]; then
        OS=2;
        LOG="/var/log/secure";
fi

if [ $OS -eq 1 ]; then
	service ssh restart > /dev/null 2>&1;
fi
if [ $OS -eq 2 ]; then
	service sshd restart > /dev/null 2>&1;
fi
	service dropbear restart > /dev/null 2>&1;
				
if [[ ${1+x} ]]; then
        DEFAULT_LIMIT=$1;
fi
get_duration() {
        local duration
        duration=$(awk 'NF{print $1; exit}' "$DURATION_FILE" 2>/dev/null)
        if [ -z "$duration" ]; then
                duration=$DEFAULT_DURATION
        fi
        echo "$duration"
}
get_limit() {
        local user="$1"
        local limit
        limit=$(awk -v user="$user" '$1==user {print $2; found=1; exit} END{if(!found) print ""}' "$LIMIT_FILE" 2>/dev/null)
        if [ -z "$limit" ]; then
                limit=$DEFAULT_LIMIT
        fi
        echo "$limit"
}

        cat /etc/passwd | grep "/home/" | cut -d":" -f1 > /root/user.txt
        username1=( `cat "/root/user.txt" `);
        i="0";
        for user in "${username1[@]}"
			do
                username[$i]=`echo $user | sed 's/'\''//g'`;
                jumlah[$i]=0;
                i=$i+1;
			done
        log_has_dropbear=0
        log_has_sshd=0
        if [ -f "$LOG" ]; then
                if grep -qi "Password auth succeeded" "$LOG"; then
                        log_has_dropbear=1
                fi
                if grep -qi "Accepted password for" "$LOG"; then
                        log_has_sshd=1
                fi
        fi

        if [ $log_has_dropbear -eq 1 ]; then
                cat $LOG | grep -i dropbear | grep -i "Password auth succeeded" > /tmp/log-db.txt
                proc=( `ps aux | grep -i dropbear | awk '{print $2}'`);
                for PID in "${proc[@]}"
                        do
                                cat /tmp/log-db.txt | grep "dropbear\[$PID\]" > /tmp/log-db-pid.txt
                                NUM=`cat /tmp/log-db-pid.txt | wc -l`;
                                USER=`cat /tmp/log-db-pid.txt | awk '{print $10}' | sed 's/'\''//g'`;
                                if [ $NUM -eq 1 ]; then
                                        i=0;
                                        for user1 in "${username[@]}"
                                                do
                                                        if [ "$USER" == "$user1" ]; then
                                                                jumlah[$i]=`expr ${jumlah[$i]} + 1`;
                                                        fi
                                                        i=$i+1;
                                                done
                                fi
                        done
        fi

        if [ $log_has_sshd -eq 1 ]; then
                cat $LOG | grep -i sshd | grep -i "Accepted password for" > /tmp/log-db.txt
                data=( `ps aux | grep "\[priv\]" | sort -k 72 | awk '{print $2}'`);
                for PID in "${data[@]}"
                        do
                                cat /tmp/log-db.txt | grep "sshd\[$PID\]" > /tmp/log-db-pid.txt;
                                NUM=`cat /tmp/log-db-pid.txt | wc -l`;
                                USER=`cat /tmp/log-db-pid.txt | awk '{print $9}'`;
                                if [ $NUM -eq 1 ]; then
                                        i=0;
                                        for user1 in "${username[@]}"
                                                do
                                                        if [ "$USER" == "$user1" ]; then
                                                                jumlah[$i]=`expr ${jumlah[$i]} + 1`;
                                                        fi
                                                        i=$i+1;
                                                done
                                fi
                done
        fi

        if [ $log_has_dropbear -eq 0 ] && [ $log_has_sshd -eq 0 ]; then
                while read -r active_user
                        do
                                i=0;
                                for user1 in "${username[@]}"
                                        do
                                                if [ "$active_user" == "$user1" ]; then
                                                        jumlah[$i]=`expr ${jumlah[$i]} + 1`;
                                                fi
                                                i=$i+1;
                                        done
                        done < <(ps -eo user=,args= | awk '
                        /sshd: / {
                                split($0, parts, "sshd: ");
                                split(parts[2], userparts, " ");
                                if (userparts[1] != "") {
                                        print userparts[1];
                                }
                        }
                ')
        fi
        j="0";
        duration=$(get_duration)
        for i in ${!username[*]}
			do
                limit=$(get_limit "${username[$i]}")
                if [ ${jumlah[$i]} -gt $limit ]; then
                        start_file="/tmp/limit-start-${username[$i]}"
                        if [ ! -f "$start_file" ]; then
                                date +%s > "$start_file"
                        fi
                        start_time=$(cat "$start_file" 2>/dev/null)
                        now_time=$(date +%s)
                        if [ -n "$start_time" ] && [ $((now_time - start_time)) -ge $MULTILOGIN_WINDOW ]; then
                                date=`date +"%Y-%m-%d %X"`;
                                echo "$date - ${username[$i]} - ${jumlah[$i]}";
                                echo "$date - ${username[$i]} - ${jumlah[$i]}" >> /root/log-limit.txt;
                                if passwd -S "${username[$i]}" 2>/dev/null | awk '{print $2}' | grep -q "L"; then
                                        :
                                else
                                        lock_file="/tmp/lock-${username[$i]}"
                                        if [ ! -f "$lock_file" ]; then
                                                touch "$lock_file"
                                                usermod -L "${username[$i]}"
                                                (sleep "$duration" && usermod -U "${username[$i]}" && rm -f "$lock_file") >/dev/null 2>&1 &
                                                j=`expr $j + 1`;
                                        fi
                                fi
                        fi
                else
                        rm -f "/tmp/limit-start-${username[$i]}"
                fi
			done
        if [ $j -gt 0 ]; then
                if [ $OS -eq 1 ]; then
                        service ssh restart > /dev/null 2>&1;
                fi
                if [ $OS -eq 2 ]; then
                        service sshd restart > /dev/null 2>&1;
                fi
                service dropbear restart > /dev/null 2>&1;
                j=0;
		fi
