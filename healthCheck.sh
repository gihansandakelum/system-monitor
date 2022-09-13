#!/bin/bash

##---------- Author : XXXX XXXXXXX (abc@xyz.com) 07aaaaaaaa----------------------------------##
##---------- Purpose : To quickly check and report health status in a linux system.----------##
##---------- Tested on : SUSE 12|Red Hat-----------------------------------------------------## 
##---------- Version : v1.0 (Updated on 13th September 2022) --------------------------------##
##-----NOTE: This script requires root privileges, otherwise one could run the script -------##
##---- as a sudo user who got root privileges. ------"sudo /bin/bash <ScriptName>" ----------##

#------Static variables------#
S="**********************************"
D="----------------------------------"
GCOLOR=" ------ OK/HEALTHY"
WCOLOR=" ------ WARNING"
CCOLOR=" ------ CRITICAL"
script=${0##*/}
log=$(echo "$script"|sed -e 's/.sh/.log/g') #LogFile
hostname="HOSTA" #If needs change this to define a hostname 
ipAddress="xxx.xxx.xxx.xxx" #If needs change this to define an ipaddress 
operatingSystem="No Details" 
uname="No Details"
systemUptime="No Details"
totalCPUs="No Details"
memThreshold=90
cpuIdleThreshold=10
vncServer="no" #If VNC server is not running in this server, then change "yes" to "no"
mySQLService="no" #If mySQL server is not running in this server, then change "yes" to "no"
crondService="no" #If mySQL server is not running in this server, then change "yes" to "no"
applicationList="app1 app2" #Update List of running application
monitoringApplication="monitoringApp" #Update List of running monitoring application
receivers="abc@xyz.com,def@xyz.com" #Update List of email contacts
sender="isalarm@xyz.com" #Update Sender email address
dataCenter="WALIKADA-ROOM1" #Update Data Center
applicationType="ABCDEF" #Update Application Type
#--------Writing Log Function--------#
writeLog(){
    printf "%s %`expr 100 - ${#1}`s\n" "$1" "$2" >>$log
}

#--------Send Alarm Function--------#
# sendalarm -s "Subject" -r "Receivers seperate by comma" "Message Body"
function sendalarm {
	alarm="Alarm"
	subject="Critical $alarm - $hostname | $ipAddress"
	body=""
	mail="/tmp/out$$.mail"
	mailhtml="/tmp/out$$.html"
	while [ "$1" != "" ]; do
		case $1 in
   	-s | --subject ) shift
                    subject=$1
                    ;;
    -a | --alarm )  shift
                    alarm=$1" "$alarm
                    subject="Critical $alarm - $hostname | $ipAddress"
                    ;;
   	-r | --receivers ) shift
                    receivers=$receivers,$1
                    ;;
          * )       body=$1
		esac
    shift
	done
	
  echo $body>"$mail"
  
	if [[ -s "$mail" ]]; then 
  	awk '
		BEGIN { print "<html>""<body bgcolor=\"#ffffff\" text=\"#000000\">""<pre>""<font size="2" color=\"#0000FF\" face="Calibri">" 
		}
		{
		print $0
		print ""
		print ""
		print ""
		}
		END { 
		print "</font>""</pre>""</body>""</html>"
		}
		' "$mail" > "$mailhtml"
		rm "$mail"
  else
  	writeLog "[$(date +%F" "%T)] $mail file not exist" "[ERROR]"
  fi
  
	if [[ -s "$mailhtml" ]]; then
		(
 		echo "From: IS-Alarm <"$sender">"
 		echo "To: You <"${receivers}">"
 		echo "Cc:"
 		echo "Subject: "$subject""
 		echo "MIME-Version: 1.0"
 		echo "Content-Type: text/html"
 		echo "Content-Disposition: inline"
 		echo "<b><pre><font size="5" color=\"#AA4A44\" face="Calibri">Alert: $alarm</font></pre></b>"
 		echo "<b><pre><font size="4" face="Calibri">Data Center: $dataCenter</font></pre></b>"
 		echo "<b><pre><font size="4" face="Calibri">Application Type: $applicationType</font></pre></b>"
 		echo "<b><pre><font size="4" face="Calibri">Server Instance: $ipAddress|$hostname</font></pre></b>"
 		echo "<b><pre><font size="4" face="Calibri">Description: </font></pre></b>"
 		echo "<b><pre><font size="4" face="Calibri">$(cat "${mailhtml}")</font></pre></b>"		
 		echo "<b><font size="3" color=\"#7E2B7E\" face="Calibri">Note : This is an automatically generated e-mail and if you are not the intended recipient or the content seems abnormal, please inform to isalarm@xyz.com</font></b>"
 		echo "</pre>"
 		echo "</body>"
 		echo "</html>"
 		echo
		) | /usr/sbin/sendmail "${receivers}"
		if [[ $? -eq 0 ]]; then
			writeLog "[$(date +%F" "%T)] Sending $alarm Email Notification" "[SUCCESS]"
		else
			writeLog "[$(date +%F" "%T)] Sending $alarm Email Notification" "[FAILED]"
		fi
		rm "$mailhtml"
	else
		writeLog "[$(date +%F" "%T)] $mailhtml file not exist" "[ERROR]"
	fi
}

#---------- variables----------#
MOUNT=$(mount|egrep -iw "ext4|ext3|xfs|gfs|gfs2|btrfs"|grep -v "loop"|sort -u -t' ' -k1,2)
FS_USAGE=$(df -PThl -x tmpfs -x iso9660 -x devtmpfs -x squashfs|awk '!seen[$1]++'|sort -k6n|tail -n +2)
IUSAGE=$(df -iPThl -x tmpfs -x iso9660 -x devtmpfs -x squashfs|awk '!seen[$1]++'|sort -k6n|tail -n +2)

#-------------Start Main Program-------------#
writeLog "$S$S$S"
writeLog "[$(date +%F" "%T)] Checking System Health" "[START]"
writeLog "$S$S$S"

#------------Find System Details------------#
writeLog "$D$D$D"
writeLog "[$(date +%F" "%T)] Finding System Information" "[START]"

#----------Hostname System Details----------#
if [[ "$hostname" == "" ]]; then
	hostname &> /dev/null
	if [[ $? -eq 0 ]]; then
		writeLog "-----System Hostname : $(hostname)"
		hostname=$(awk -v hnameSys=$(hostname) -v hname=$hostname 'BEGIN{if(length(hnameSys)>10) print hname;else print hnameSys}')
	else
		writeLog "[$(date +%F" "%T)] Extracting hostname Detail from server" "[ERROR]"
		writeLog "-----System Hostname : $hostname"
	fi
else
	writeLog "-----System Hostname : $hostname"
fi
#---------------------------------------------#
#-----------IP Adresses Details---------------#
if [[ "$ipAddress" == "" ]]; then
	ifconfig -a &> /dev/null
	if [[ $? -eq 0 ]]; then
		#ifconfig format - "inet 172.19.11.51  netmask 255.255.255.224  broadcast 172.19.11.63"
		ipAddress=$(ifconfig -a| grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | awk '{if(NR==1) printf $1; else printf "|"$1}')
		writeLog "-----System IP(s) : $ipAddress"
		ipAddress=$(ifconfig -a| grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | awk '{if(NR==1) print $1}')
	else
		writeLog "[$(date +%F" "%T)] Extracting IP Addresses Details" "[ERROR]"
	fi
else
	writeLog "-----System IP(s) : $ipAddress"
fi
#---------------------------------------------#
#-----------Operating System Details----------#
([ -f /etc/os-release ] && echo $(egrep -w "NAME|VERSION" /etc/os-release|awk -F= '{ print $2 }'|sed 's/"//g') || cat /etc/redhat-release ) &> /dev/null
if [[ $? -eq 0 ]]; then
	operatingSystem=$([ -f /etc/os-release ] && echo $(egrep -w "NAME|VERSION" /etc/os-release|awk -F= '{ print $2 }'|sed 's/"//g') || cat /etc/redhat-release)
	writeLog "-----Operating System: $operatingSystem"
else
	writeLog "-----Operating System: $operatingSystem"
	writeLog "[$(date +%F" "%T)] Extracting Operating System Details" "[ERROR]"
fi
#---------------------------------------------#
#-----------Kernel Version Details------------#
uname -r &> /dev/null
if [[ $? -eq 0 ]]; then
	uname=$(uname -r)
	writeLog "-----Kernel Version : $uname"
else
	writeLog "-----Kernel Version : $uname"
	writeLog "[$(date +%F" "%T)] Extracting Kernel Version Details" "[ERROR]"
fi
#---------------------------------------------#
#--------System uptime and Load Average-------#
uptime &> /dev/null
if [[ $? -eq 0 ]]; then
	echo $(uptime)|grep day &> /dev/null
	if [[ $? -eq 0 ]]; then
		systemUptime=$(uptime)
		writeLog "-----System Uptime : $(echo $systemUptime|grep -w min &> /dev/null && echo -en "$(echo $systemUptime|awk '{print $2" by "$3}'|sed -e 's/,.*//g') minutes" \
  	|| echo -en "$(echo $systemUptime|awk '{print $2" by "$3" "$4}'|sed -e 's/,.*//g') hours")"
  	writeLog "-----Current Load Average : $(uptime|grep -o "load average.*"|awk '{print $3" " $4" " $5}')"
	else
		writeLog "-----System Uptime : $(echo -en $(echo $systemUptime|awk '{print $2" by "$3" "$4" "$5" hours"}'|sed -e 's/,//g'))"
		writeLog "-----Current Load Average : $(uptime|grep -o "load average.*"|awk '{print $3" " $4" " $5}')"
	fi
else
	writeLog "[$(date +%F" "%T)] Extracting System Uptime Details" "[ERROR]"
	writeLog "-----System Uptime : "$systemUptime""
fi
writeLog "-----System Date : $(date +%c)"

#---------------------------------------------#
writeLog "[$(date +%F" "%T)] Finding System Information" "[END]"

#---------------------------------------------#
#-----Check for any read-only file systems----#
writeLog "$D$D$D"
writeLog "[$(date +%F" "%T)] Checking for any read-only file systems" "[START]"
writeLog "$(echo "$MOUNT"|grep -w ro && echo -e "-----Read Only file systems found"|| echo -e "-----Read-only file system not found")"
writeLog "[$(date +%F" "%T)] Checking for any read-only file systems" "[END]"

#---------------------------------------------#
#---Check for currently mounted file systems--#
writeLog "$D$D$D"
writeLog "[$(date +%F" "%T)] Checking For Currently Mounted File Systems" "[START]"
writeLog "$(echo "$MOUNT"|column -t)"
writeLog "[$(date +%F" "%T)] Checking For Currently Mounted File Systems" "[END]"

#---------------------------------------------#
#-Check disk usage on all mounted file systems#
writeLog "$D$D$D"
writeLog "[$(date +%F" "%T)] Checking the Disk Usage On Mounted File Systems" "[START]"
writeLog "( 0-85% = OK/HEALTHY,  85-95% = WARNING,  95-100% = CRITICAL )"
COL1=$(echo "$FS_USAGE"|awk '{print $1 " "$7}')
COL2=$(echo "$FS_USAGE"|awk '{print $6}'|sed -e 's/%//g')
diskUsageAlertCounter=0
for i in $(echo "$COL2"); do
{
  if [ $i -ge 95 ]; then
    COL3="$(echo -e $i"% $CCOLOR\n$COL3")"
    diskUsageAlertCounter+=1
  elif [[ $i -ge 85 && $i -lt 95 ]]; then
    COL3="$(echo -e $i"% $WCOLOR\n$COL3")"
  else
    COL3="$(echo -e $i"% $GCOLOR\n$COL3")"
  fi
}
done
COL3=$(echo "$COL3"|sort -k1n)
writeLog "$(paste  <(echo "$COL1") <(echo "$COL3") -d' '|column -t)"
#--------Send disk usage SMS notification-------#
if [ $diskUsageAlertCounter -ne 0 ]; then
	diskMountPoints=$(echo "$FS_USAGE"|awk '{print $7}')
	maxLengthDiskMountPoint=0
	for i in $(echo "$diskMountPoints"); do
	{
		lenghtOfi=$(echo $i |awk '{print length}')
		if [ $lenghtOfi -ge $maxLengthDiskMountPoint ]; then
			maxLengthDiskMountPoint=$lenghtOfi
		fi
	}
	done
	message="Disk Usage: Critical\n"
	message+=$(echo "$FS_USAGE"|awk -v maxLength="$maxLengthDiskMountPoint" '{
	{printf $7"__"};
	for (counter = length($7); counter < maxLength; counter++) {printf "_"};
	{printf $6"\n"};
	}')
	sendalarm -a "High Disk Utilization" "$message" 
fi
writeLog "[$(date +%F" "%T)] Checking the Disk Usage On Mounted File Systems" "[END]"

#---------------------------------------------#
#--------------Check Inode usage--------------#
writeLog "$D$D$D"
writeLog "[$(date +%F" "%T)] Checking the INode Usage On Mounted File Systems" "[START]"
writeLog "( 0-85% = OK/HEALTHY,  85-95% = WARNING,  95-100% = CRITICAL )"
COL11=$(echo "$IUSAGE"|awk '{if(NR!=1) print $1" "$7}')
COL22=$(echo "$IUSAGE"|awk '{if(NR!=1) print $6}'|sed -e 's/%//g')
inodeUsageAlertCounter=0
for i in $(echo "$COL22"); do
{
  if [[ $i = *[[:digit:]]* ]]; then
  {
  if [ $i -ge 95 ]; then
    COL33="$(echo -e $i"% $CCOLOR\n$COL33")"
		inodeUsageAlertCounter+=1
  elif [[ $i -ge 85 && $i -lt 95 ]]; then
    COL33="$(echo -e $i"% $WCOLOR\n$COL33")"
  else
    COL33="$(echo -e $i"% $GCOLOR\n$COL33")"
  fi
  }
  else
    COL33="$(echo -e $i"% (Not available)\n$COL33")"
  fi
}
done

COL33=$(echo "$COL33"|sort -k1n)
writeLog "$(paste  <(echo "$COL11") <(echo "$COL33") -d' '|column -t)"
#-----Send INode usage SMS notification------#
if [ $inodeUsageAlertCounter -ne 0 ]; then
	inodeMountPoints=$(echo "$IUSAGE"|awk '{print $7}')
	maxLengthInodeMountPoint=0
	for i in $(echo "$inodeMountPoints"); do
	{
		lenghtOfi=$(echo $i |awk '{print length}')
		if [ $lenghtOfi -ge $maxLengthInodeMountPoint ]; then
			maxLengthInodeMountPoint=$lenghtOfi
		fi
	}
	done
	message="Inode Usage: Critical\n"
	message+=$(echo "$IUSAGE"|awk -v maxInodeLength="$maxLengthInodeMountPoint" '{if(NR!=1) 
	{printf $7"__"};
	for (counter = length($7); counter < maxInodeLength; counter++) {printf "_"};
	if(NR!=1) {printf $6"\n"};
	}')
	sendalarm -a "High iNode Utilization" "$message" 
fi
writeLog "[$(date +%F" "%T)] Checking the INode Usage On Mounted File Systems" "[END]"

#---------------------------------------------#
#---------Check for Memory Utilization--------#
writeLog "$D$D$D"
writeLog "[$(date +%F" "%T)] Checking System Memory Usage" "[START]"
free -tm &> /dev/null
if [ "$?" -eq 0 ]; then
	totalMem=`free -tm|grep Mem|awk '{print $2}'`
	totalSwap=`free -tm|grep Swap|awk '{print $2}'`
	usedMem=`free -tm|grep Mem|awk '{print $3}'`
	usedSwap=`free -tm|grep Swap|awk '{print $3}'`
	thresholdUsedMem=$(echo "scale=0; $totalMem*$memThreshold/100" | bc)
	thresholdUsedSwap=$(echo "scale=0; $totalSwap*$memThreshold/100" | bc)
	if [[ "$usedMem" -gt "$thresholdUsedMem" || "$usedSwap" -gt "$thresholdUsedSwap" ]];then
		writeLog "[$(date +%F" "%T)] High Memory Utilization" "[ERROR]"
		writeLog "-----Total Physical Memory in MB : $(free -tm|grep Mem|awk '{print $2}')"
		writeLog "-----Free Physical Memory in MB : $(free -tm|grep Mem|awk '{print $4}')"
		writeLog "-----Total Swap Memory in MB : $(free -tm|grep Swap|awk '{print $2}')"
		writeLog "-----Free Swap Memory in MB : $(free -tm|grep Swap|awk '{print $4}')"
		message="Memory Usage: Critical"
		message+="\nTotal Phy.Mem(G) : "$(free -tg|grep Mem|awk '{print $2}')"\nUsed Phy.Mem(G) : "$(free -tg|grep Mem|awk '{print $3}')
		message+="\nTotal Swp.Mem(G) : "$(free -tg|grep Swap|awk '{print $2}')"\nUsed Swp.Mem(G) : "$(free -tg|grep Swap|awk '{print $3}')
		sendalarm -a "High Memory Utilization" "$message" 
	else
		writeLog "[$(date +%F" "%T)] Memory Utilization" "[NORMAL]"
		writeLog "-----Total Physical Memory in MB : $(free -tm|grep Mem|awk '{print $2}')"
		writeLog "-----Free Physical Memory in MB : $(free -tm|grep Mem|awk '{print $4}')"
		writeLog "-----Total Swap Memory in MB : $(free -tm|grep Swap|awk '{print $2}')"
		writeLog "-----Free Swap Memory in MB : $(free -tm|grep Swap|awk '{print $4}')"
	fi
else
	writeLog "[$(date +%F" "%T)] Checking System Memory Usage" "[ERROR]"
fi
writeLog "[$(date +%F" "%T)] Checking System Memory Usage" "[END]"

#---------------------------------------------#
#----------Check for CPU Utilization ---------#
writeLog "$D$D$D"
writeLog "[$(date +%F" "%T)] Checking System CPU Usage" "[START]"
nproc --all &> /dev/null
if [ "$?" -eq 0 ]; then
	totalCPUs=$(nproc --all)
	writeLog "-----Total Number of CPUs : $totalCPUs"
else
	writeLog "[$(date +%F" "%T)] Checking Total Number of CPUs" "[ERROR]"
fi
vmstat &> /dev/null
if [ "$?" -eq 0 ]; then
	idealCPUs=$(vmstat 2 3 | tail -1 | awk '{ print $15 }')
	if [[ "$idealCPUs" -lt "$cpuIdleThreshold" ]];then
		writeLog "[$(date +%F" "%T)] CPU Utilization" "[ERROR]"
		writeLog "-----System Idle CPU Presentage: $idealCPUs%"
		message="CPU Usage: Critical\n"
		message+="Total Number of CPUs : $totalCPUs\n"
		message+="System Idle CPU% : $idealCPUs"
		sendalarm -a "High CPU Utilization" "$message" 
	else
		writeLog "[$(date +%F" "%T)] CPU Utilization" "[NORMAL]"
		writeLog "-----System Idle CPU Presentage: $idealCPUs%"
	fi
else
	writeLog "[$(date +%F" "%T)] Checking System CPU Usage Process" "[ERROR]"
fi
writeLog "[$(date +%F" "%T)] Checking System CPU Usage Process" "[END]"

#---------------------------------------------#
#---Most recent 3 reboot events if available--#
writeLog "$D$D$D"
writeLog "[$(date +%F" "%T)] Checking Most Recent 3 Reboot Events" "[START]"
last -x &> /dev/null
if [ "$?" -eq 0 ]; then
	writeLog "$(last -x 2> /dev/null|grep reboot 1> /dev/null && /usr/bin/last -x 2> /dev/null|grep reboot|head -3 || \
	echo -e "-----No reboot events are recorded.")"
else
	writeLog "[$(date +%F" "%T)] Checking Most Recent 3 Reboot Events" "[ERROR]"
fi
writeLog "[$(date +%F" "%T)] Checking Most Recent 3 Reboot Events" "[END]"

#---------------------------------------------#
#--Most recent 3 shutdown events if available-#
writeLog "$D$D$D"
writeLog "[$(date +%F" "%T)] Checking Most Recent 3 Shutdown Events" "[START]"
last -x &> /dev/null
if [ "$?" -eq 0 ]; then
	writeLog "$(last -x 2> /dev/null|grep shutdown 1> /dev/null && /usr/bin/last -x 2> /dev/null|grep shutdown|head -3 || \
	echo -e "-----No shutdown events are recorded.")"
else
	writeLog "[$(date +%F" "%T)] Checking Most Recent 3 Shutdown Events" "[ERROR]"
fi
writeLog "[$(date +%F" "%T)] Checking Most Recent 3 Shutdown Events" "[END]"

#---------------------------------------------#
#-Top 5 Memory & CPU consumed process threads-#
writeLog "$D$D$D"
writeLog "[$(date +%F" "%T)] Checking for Top 5 Hog Processes" "[START]"
writeLog "-----Top 5 Memory Resource Hog Processes:"
writeLog "$(ps -eo pmem,pid,ppid,user,stat,args --sort=-pmem|grep -v $$|head -6|sed 's/$/\n/')"
writeLog "-----Top 5 CPU Resource Hog Processes:"
writeLog "$(ps -eo pcpu,pid,ppid,user,stat,args --sort=-pcpu|grep -v $$|head -6|sed 's/$/\n/')"
writeLog "[$(date +%F" "%T)] Checking for Top 5 Hog Processes" "[END]"

#---------------------------------------------#
#--------Check for any zombie processes-------#
writeLog "$D$D$D"
writeLog "[$(date +%F" "%T)] Checking for zombie processes" "[START]"
ps -eo stat|grep -w Z 1>&2 > /dev/null
if [ $? == 0 ]; then
	writeLog "-----Number of zombie process : $(ps -eo stat|grep -w Z|wc -l)"
	writeLog "-----Details of each zombie processes found"
  ZPROC=$(ps -eo stat,pid|grep -w Z|awk '{print $2}')
  for i in $(echo "$ZPROC"); do
      writeLog "$(ps -o pid,ppid,user,stat,args -p $i)"
  done
else
 writeLog "-----No zombie processes found"
fi
writeLog "[$(date +%F" "%T)] Checking for zombie processes" "[END]"

#---------------------------------------------#
#----------Check VNC Server Running-----------#
if [[ "$vncServer" == "yes" ]]; then
	writeLog "$D$D$D"
	writeLog "[$(date +%F" "%T)] Verifying VNC Server Running" "[START]"
	/etc/init.d/vncserver status &> /dev/null
	if [ "$?" -eq 0 ]; then
		vncStatus=`/etc/init.d/vncserver status|grep 'OK\|SUCCESS\|is running'|wc -l`
		if [ "$vncStatus" -ne 0 ];then
			writeLog "[$(date +%F" "%T)] VNC Server is Running" "[NORMAL]"
		else
			writeLog "[$(date +%F" "%T)] VNC Server is not Running" "[ERROR]"
			message="\nVNC Server is not Running: Critical"
			sendalarm -a "VNC Server Status" "$message" 
			
		fi
	else
		writeLog "[$(date +%F" "%T)] Verifying VNC Server Running" "[ERROR]"
	fi
	writeLog "[$(date +%F" "%T)] Verifying VNC Server Running" "[END]"
fi

#---------------------------------------------#
#----------Check MySQL Service Running-----------#
if [[ "$mySQLService" == "yes" ]]; then
	writeLog "$D$D$D"
	writeLog "[$(date +%F" "%T)] Verifying mySQL Service Running" "[START]"
	/etc/init.d/mysqld status &> /dev/null
	if [ "$?" -eq 0 ]; then
		mySQLStatus=`/etc/init.d/mysqld status|grep 'OK\|SUCCESS\|is running'|wc -l`
		if [ "$mySQLStatus" -ne 0 ];then
			writeLog "[$(date +%F" "%T)] mySQL Service is Running" "[NORMAL]"
		else
			writeLog "[$(date +%F" "%T)] mySQL Service is not Running" "[ERROR]"
			message="\nmySQL Service is not Running: Critical"
			sendalarm -a "MySQL Service Status" "$message" 
		fi
	else
		writeLog "[$(date +%F" "%T)] Verifying mySQL Service Running" "[ERROR]"
	fi
	writeLog "[$(date +%F" "%T)] Verifying mySQL Service Running" "[END]"
fi

#---------------------------------------------#
#----------Check crond Service Running-----------#
if [[ "$crondService" == "yes" ]]; then
	writeLog "$D$D$D"
	writeLog "[$(date +%F" "%T)] Verifying crond Service Running" "[START]"
	/etc/init.d/crond status &> /dev/null
	if [ "$?" -eq 0 ]; then
		mySQLStatus=`/etc/init.d/crond status|grep 'OK\|SUCCESS\|is running'|wc -l`
		if [ "$mySQLStatus" -ne 0 ];then
			writeLog "[$(date +%F" "%T)] crond Service is Running" "[NORMAL]"
		else
			writeLog "[$(date +%F" "%T)] crond Service is not Running" "[ERROR]"
			message="\ncrondService is not Running: Critical"
			sendalarm -a "Crond Service Status" "$message" 
		fi
	else
		writeLog "[$(date +%F" "%T)] Verifying crond Service Running" "[ERROR]"
	fi
	writeLog "[$(date +%F" "%T)] Verifying crond Service Running" "[END]"
fi

#---------------------------------------------#
#----------Check Applications Running Status-----------#
if [[ "$applicationList" != "" ]]; then
	writeLog "$D$D$D"
	writeLog "[$(date +%F" "%T)] Verifying Applications Running Status" "[START]"
	notRunningApplications=""
	ps -eaf &> /dev/null
	if [ "$?" -eq 0 ]; then
		for i in $applicationList
		do
			if (ps -eaf |grep -v grep| grep "$i") > /dev/null; then
				writeLog "[$(date +%F" "%T)] Running Status - $i : $(ps -eaf|grep -v grep| grep $i| awk '{printf $2" "}')" "[NORMAL]"
			else
				writeLog "[$(date +%F" "%T)] Running Status - $i" "[ERROR]"
				notRunningApplications+="$i\n"
			fi
		done
		if [[ "$notRunningApplications" != "" ]]; then
			message="Applications Status:Not Running\n$notRunningApplications"
			sendalarm -a "Application Status" "$message"
			
		fi
		writeLog "[$(date +%F" "%T)] Verifying Applications Running Status" "[END]"
	else
		writeLog "[$(date +%F" "%T)] Verifying Applications Running Status" "[ERROR]"
	fi
fi

#---------------------------------------------#
#----------Check Monitoring Application Status-----------#
if [[ "$monitoringApplication" != "" ]]; then
	writeLog "$D$D$D"
	writeLog "[$(date +%F" "%T)] Verifying Monitoring Application Running Status" "[START]"
	ps -eaf &> /dev/null
	if [ "$?" -eq 0 ]; then
		if (ps -eaf |grep -v grep| grep "$monitoringApplication") > /dev/null; then
			writeLog "[$(date +%F" "%T)] Running Status - $monitoringApplication : $(ps -eaf |grep -v grep| grep "$monitoringApplication"| awk '{print $2}')" "[NORMAL]"
		else
			writeLog "[$(date +%F" "%T)] Running Status - $monitoringApplication" "[ERROR]"
			message="Monitoring Application Status:Not Running\n$monitoringApplication"
			sendalarm -a "Monitoring Application Status" "$message"
		fi
	else
		writeLog "[$(date +%F" "%T)] Verifying Monitoring Application Running Status" "[ERROR]"
	fi
	writeLog "[$(date +%F" "%T)] Verifying Monitoring Applications Running Status" "[END]"
fi

#---------------------------------------------#
writeLog "$S$S$S"
writeLog "[$(date +%F" "%T)] Checking System Health" "[END]"
writeLog "$S$S$S"
#--------------End Main Program--------------#