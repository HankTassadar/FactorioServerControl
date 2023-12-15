#!/bin/bash

#user variable

#shell variable
portfile=./config/port
pidfile=./config/.factorio.pid
serverpackurl=https://factorio.com/get-download/stable/headless/linux64
modbackupPath=./config/modbackup
mapbackupPath=./config/mapbackup

MD(){
    if [ ! -d $1 ]
    then
        mkdir $1
    fi
}

InitCtlServerEnv(){
    MD config
    MD $modbackupPath
    MD $mapbackupPath
}

LogRed(){
    echo -e "\033[31m$1\033[0m"
}

LogGreen(){
    echo -e "\033[32m$1\033[0m"
}

LogYellow(){
    echo -e "\033[33m$1\033[0m"
}

IsPidExist(){
if kill -0 $1 >/dev/null 2>&1; then
    return 0
else
    return 1
fi
}

IsServerRunning(){
    if [ -f $pidfile ]
    then
        pid=$(cat $pidfile)
        if IsPidExist $pid
        then
            return 0
        fi
    fi
    return 1
}

StopServer(){
    if [ -f $pidfile ]
    then
        pid=$(cat $pidfile)
        if IsPidExist $pid
        then
            kill $pid
            LogGreen "Server Stoped! PID: $pid"
        else
            LogRed "PID: $pid Is Not Exist"
			return 0
        fi

		#start stop the server
        echo -ne "\033[?25l"
        counter=0
        while IsPidExist $pid
        do
            let "counter++"
            if [ $counter -gt 10 ]
            then
                echo -ne "\033[1K\r"
                counter=0
            fi
            sleep 0.5
            echo -n "."
        done
        echo -ne "\033[?25h"
		
		#remove the pid file
        rm -rf $pidfile
    fi
    echo -ne "\033[1K\r"
    LogGreen "Server Stop Finish!"

}

StartServer(){
    if IsServerRunning
    then
        LogYellow "Server Is Already Running!"
        return 1
    fi
    port=$(cat $portfile) 
    startcmd=nohup ./factorio/bin/x64/factorio --start-server-load-latest --server-settings ./config/server-settings.json --server-adminlist server-adminlist.json --port=$port > app.log 2>&1 &
    echo $startcmd
    $startcmd
    pid=$(echo $!)
    cat <<< $pid > $pidfile

	LogYellow "Start Server Now, Please Wait!"	
	counter=0
	startupflag=0
    echo -ne "\033[?25l"
	while IsPidExist $pid
	do
		let "counter++"
		if [ $counter -gt 10 ]
		then
			echo -ne "\033[1K\r"
			counter=0
		fi
		sleep 0.5
		echo -n "."
		matchresult=$(tail -n1 app.log|grep -o 'Matching server')
		if [ "$matchresult" = "Matching server" ]
		then
			startupflag=1
			echo -ne "\033[1K\r"
			break
		fi
	done
	echo -ne "\033[?25h"

	if [ $startupflag == 1 ]
	then	
        LogGreen "Start Succeed, Server Is Running Now!"
	else
        LogRed "Start Failed, check the app.log for more infomation."
        rm -rf $pidfile
	fi

    return 0
}

RestartServer(){
    StopServer
    StartServer
}

UpdateServer(){
    if [ -f linux64 ]
    then
         rm -rf linux64
    fi
    LogGreen "Begin Download Latest Server Package!"
    echo ""
    if wget --no-check-certificate  $serverpackurl
    then
        LogGreen "Download Succeed!"
    else
        LogRed "Download Failed!"
        return 1
    fi
    echo "" 
    LogGreen "Start Decompressing......"
    tar -xf linux64
    LogGreen "Decompressing Finish!"
    echo ""
    rm -rf linux64
    echo ""
    LogGreen "Update Finished!"
}

PrintHelp(){

helpstr=" \n\
stop : Stop the server if it's running \n\
start : Start the server if it's not running \n\
reboot : Restart the server whether it's running \n\
update : Download the latest Server Package and decompress it \n\
init : Initialize the server to create some floder like mods, config \n\
install : Install the latest Server \n
"
echo -e $helpstr

}

InitServer(){
    testmap=testmap.zip
    cmdstr="./factorio/bin/x64/factorio --create $testmap"
    LogYellow "Initialize...... \nStart to Create TestMap"
    $cmdstr
    LogGreen "Initialize Finish!"
    rm -rf $testmap
    MD factorio/saves
    if [ ! -f config/server-settings.json ]
    then
        cp ./factorio/data/server-settings.example.json ./config/server-settings.json
    fi
    if [ ! -f config/port ]
    then
        cat <<< "1438" > $portfile
    fi
}

BackupServer(){
    if [ -d ./factorio/mods ]
    then
        LogYellow "Backup mods ......"
        cp -r factorio/mods $modbackupPath
    fi
    if [ -d ./factorio/saves ]
    then
        LogYellow "Backup maps ......"
        cp -r ./factorio/saves $mapbackupPath
    fi
    LogGreen "Backup Finish!"
}

InstallServer(){
    if [ -d ./factorio ]
    then
        LogYellow "Server is Already Exist!"
        return 1
    fi
    UpdateServer
    InitServer
    return 0
}

InitCtlServerEnv

if [ $# -lt 1 ]
then
    PrintHelp
    exit 0
fi

echo -e "\n\n"

if [ $1 == "stop" ]
then
    StopServer
elif [ $1 == "start" ]
then
    StartServer
elif [ $1 == "reboot" ]
then
    RestartServer
elif [ $1 == "update" ]
then
    UpdateServer
elif [ $1 == "init" ]
then
    InitServer
elif [ $1 == "backup" ]
then
    BackupServer
elif [ $1 == "install" ]
then
    InstallServer
else
    echo "Error Param $1"
    PrintHelp
fi

echo ""
echo ""
