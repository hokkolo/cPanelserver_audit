#!bin/bash
#Author: GAUTHAM
#Version: 05072019

function details() {
echo " Hostname: $(hostname)" >> $temp
echo " Host IP: $(hostname -i)" >> $temp
echo " Number of CPU core: $(nproc)" >> $temp
echo " Memory: $( free -m | grep Mem: | awk '{print $2}')" >> $temp
echo " Server Uptime: $( uptime | awk --field-separator="," '{print $1}' )" >> $temp
}

function ret() {
if [ $@ == 1 ]; then
 echo " Check OK" >> $temp

elif [ $@ == 2 ]; then
 echo " Problem " >> $temp

else 
 echo " Check failed" >> $temp
fi
}

function serverload(){
 if [ $(sar -q | tail | grep Average | awk '{print $6}') > "nproc" ]; then
  ret 1
 else
  ret 2
 fi
 echo " The load on the server varies between $(sar -q | tail | grep Average | awk '{print $6}') and $( sar -q | tail | grep Average | awk '{print $4}')" >> $temp
}

function swapcheck() {
 if [ $(free -g | grep Swap | awk '{print $4}') > 1 ]; then
  ret 1
  
 else 
  ret 2
 fi
}

function memcheck() {
 k=$(echo $(( $(free -m | grep buffers/cache: | awk '{print $4}') * 100 / $(free -m | grep Mem: | awk '{print $2}') )))
 if [ $k > 25 ] ; then
  ret 1
  echo " Out of $(free -m | grep Mem: | awk '{print $2}') MB , $(free -m | grep buffers/cache: | awk '{print $3}') MB used." >> $temp
 else 
  ret 2
 fi
}

function eximcheck() {
# exim=$(exim -bp | grep "frozen" | awk '{print $3}' | xargs exim -Mrm &> /dev/null)
  exim=$(exiqgrep -i | xargs exim -Mrm 2> /dev/null )
 if [ "$exim" ]; then
  ret 1
 else 
  ret 2
 fi
}

function shellaccess() {
 shell="/tmp/shell.txt"
 >$shell
 grep "/bin/bash" /etc/passwd >> $shell
 if [ "$?" ]; then
  ret 1
  echo " Users with Shell access are" >> $temp
  echo "____________" >> $temp
  cut -d : -f 1 $shell >> $temp 
  echo "____________" >> $temp
 else
  ret 2
 fi
 rm -f $shell
}

function wheeluser() {
 wheel="/tmp/wheel.txt"
 >$wheel
 cat /etc/group | grep wheel | awk --field-separator=":" '{print $4}' >> $wheel
 if [ ! $wheel == " " ]; then
 { ret 1
   echo " Wheel users are:" >> $temp
   echo "____________" >> $temp
   cat $wheel >> $temp
   echo "____________" >> $temp
  }
 else 
  echo " No wheel users found" >> $temp 
 fi
 rm -f $wheel
}

function biglogs() {
 logs="/tmp/log.txt"
 find /var/log/* -name "*.log" -size +10M -exec du -h {} \; >> $logs
 find /usr/local/apache/* -name "*.log" -size +10M -exec du -h {} \; >> $logs
 find /usr/local/cpanel/* -name "*.log" -size +10M -exec du -h {} \; >> $logs
 if [ !  $logs == " " ]; then 
 { ret 1
  echo "____________" >> $temp
  cat $logs >> $temp
  echo "____________" >> $temp
 }
 else
  echo " No big log files found" >> $temp
 fi
 rm -f $logs
}

function eaversion {
 echo " List of available PHP binaries" >> $temp
 ls -l /usr/local/bin/ea-php* | awk '{print $9}' >> $temp 
# cat $list >> $temp 

}
#function disabled
function rkhunter {
rk="/tmp/rk.txt"
echo $(rkhunter --versioncheck) >> $rk
if [ ! $rk == " " ]; then
  { #ret 1
    rkhunter --update > /dev/null
    rkhunter --propupd > /dev/null
    rkhunter -c -sk > /dev/null
    tail -17 /var/log/rkhunter/rkhunter.log > $rk
    cat $rk >> $temp
  }
 else
  ret 3
 fi
rm -f $rk
}

function dbinfo {
db="/tmp/db.txt"
echo $(mysqladmin version) >> $db
if [ ! $db == " " ]; then
  { ret 1
    mysqladmin version | grep "Uptime:" > $db
    mysqladmin version | grep "Server version" >> $db
    echo " MySQL Data Directory: $(mysqladmin variables | grep datadir | awk '{print $4}')" >> $db
    echo " MySQL Default Engine: $(mysql -e 'SHOW ENGINES' | grep DEFAULT | awk '{print $1}')" >> $db
    cat $db >> $temp
  }

 else 
  ret 3
fi
rm -f $db
}

function webserver {
Webserver=`curl -Is $(hostname -i) | grep "Server" | awk {'print $2'} | cut -d'/' -f1`
WB1=Apache
WB2=LiteSpeed
 if [[ "$Webserver" == *"$WB1"* ]]
 then
{ ret 1
  echo " Server uptime: $(ps -eo comm,etime,user | grep httpd|grep root | awk '{print $2}')" >> $temp
  echo -e " \nApache version\n==============\n$(httpd -v)" >> $temp
}
 else if [[ "$Webserver" == *"$WB2"* ]]
 then
 { ret 1
  echo " Webserver Litespeed uptime: $(head -n4 /tmp/lshttpd/.rtreport | grep UPTIME)" >> $temp
 }
 else
  ret 3
fi
fi

}

function dmesgcheck {
if dmesg | grep -E ' error|crit|alert' &> /dev/null;
        then
		ret 1
		dmesg | grep -E ' error|crit|alert' >> $temp
	else
		ret 3
fi;
}

function diskspace {
DISK_CHECK_FLAG=0
disk="/tmp/disk.txt"
df -h | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $5 " " $1 }' | \
{
while read output;
do
  usep=$(echo $output | awk '{ print $1}' | cut -d'%' -f1 )
  partition=$(echo $output | awk '{ print $2 }' )
  if [ $usep -ge 70 ];
        then
                DISK_CHECK_FLAG=1
                echo "Running out of space in \"$partition ($usep%)\" as on $(date)" >> $disk
  fi;
done
if [ $DISK_CHECK_FLAG -eq 1 ];
        then
                echo " Disk space usage is high" >> $temp
                cat $disk  >> $temp

        else 
                echo " Disk space usage is normal" >> $temp
		echo -e " Disk usage is ""\n"" $(df -h | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $5 " " $1 }')  " >> $temp
             
fi;
rm -f $disk
}
}

function inodecheck {
INODE_CHECK_FLAG=0
tmp="/var/tmp.txt"
df -i | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $5 " " $1 }' | \
#cat inode | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $5 " " $1 }' | \
{
while read output;
do
  usep=$(echo $output | awk '{ print $1}' | cut -d'%' -f1  )
  partition=$(echo $output | awk '{ print $2 }' )
  if [ $usep -ge 1 ]; 
	then
		INODE_CHECK_FLAG=1
    		echo "Running out of inodes \"$partition ($usep%)\" as on $(date)" >> $tmp
  fi;
done
if [ $INODE_CHECK_FLAG -eq 1 ];
	then
		echo -e " Inode usage is high" >> $temp
		cat $tmp >> $temp
	else
		echo " Inode usage is normal" >> $temp
		echo -e " Inode usage is ""\n"" $(df -i | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $5 " " $1 }')  " >> $temp
fi;
rm -f $tmp
}
}


cpanel=$(/usr/local/cpanel/cpanel -V 2>/dev/null)
if [ "$cpanel" ]; then
 temp="/audit.txt"
 >$temp
 echo "############################" >> $temp
 echo "cPanel server check passed" >> $temp
 echo "############################" >> $temp
 echo " Server Details" >> $temp
 details
 echo "############################" >> $temp
 echo " Checking load on server" >> $temp
 serverload
 echo "############################" >> $temp
 echo " Checking for swap space" >> $temp
 swapcheck
 echo "############################" >> $temp
 echo " Checking for sufficient free memory" >> $temp
 memcheck
 echo "############################" >> $temp
 echo " Clearing Mail Queue" >> $temp
 eximcheck
 echo "############################" >> $temp
 echo " Checking users with shell access" >> $temp
 shellaccess
 echo "############################" >> $temp
 echo " Checking for wheel user" >> $temp
 wheeluser
 echo "############################" >> $temp
 echo " Checking for Big log files" >> $temp
 biglogs
 echo "############################" >> $temp
# echo " Checking for EasyApache version" >> $temp
 eaversion
 echo "############################" >> $temp 
# echo " Running RootKit Scan" >> $temp
# rkhunter
# echo "############################" >> $temp
 echo " MySQL server Information" >> $temp
 dbinfo
 echo "############################" >> $temp
 echo " Webserver Check" >> $temp
 webserver
 echo "############################" >> $temp
 echo " Following logs were found in DMESG " >> $temp
 dmesgcheck
 echo "############################" >> $temp
 echo " Checking Disk space usage" >> $temp
 diskspace
 echo "############################" >> $temp
 echo " Checking Inode usage" >> $temp
 inodecheck
 echo "############################" >> $temp
 cat $temp
 rm -f $temp
else
 echo "This is not a cPanel sever"
fi
