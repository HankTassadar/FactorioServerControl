#!/bin/bash

#user variable

#shell variable
exepath=$(pwd)
scriptdir=$(dirname $(readlink -f $0))
configpath=$scriptdir/config
portfile=$configpath/port
pidfile=$configpath/.factorio.pid
configfile=$configpath/server-settings.json
serverpackfile=$configpath/linux64
serverpackurl=https://factorio.com/get-download/stable/headless/linux64
logPath=$configpath/logs
modbackupPath=$configpath/modbackup
mapbackupPath=$configpath/mapbackup
binpath=$scriptdir/factorio/bin/x64/factorio
serverversion='0.0.0'

MD(){
    if [ ! -d $1 ]
    then
        mkdir $1
    fi
}

InitCtlServerEnv(){
    MD $configpath
    MD $modbackupPath
    MD $mapbackupPath
    MD $logPath
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

GetServerVersion(){
    serverversion=$($binpath --version | grep Version|grep -oP '(\d+\.\d+\.\d+)')
}

latestversion="0.0.0"
#get the latest stable version
GetLatestOnlineVersion(){
    cd $configpath
    latestversion="0.0.0"
    wget -q https://www.factorio.com/download
    downloadstatus=$(echo $!)
    if [ ! $downloadstatus == 0 ]
    then
        LogRed "Get Online LatestVersion Failed!"
        cd $exepath
        return 1
    fi
    latestversion=$(cat download |grep 'get-download/.*/headless/linux'|awk '/the latest stable version/{getline;print}'| grep -o download/.*/headless | grep -o '[0-9.]*')
    rm -rf download
    cd $exepath
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
        echo -ne "\033[1K\r"
        LogGreen "Server Stop Finish!"
    else
        LogYellow "Can not Find Pid"
    fi

}

StartServer(){
    if IsServerRunning
    then
        LogYellow "Server Is Already Running!"
        return 1
    fi
    port=$(cat $portfile)
    logfile=$logPath/$(date +%x-%T).log
    startcmd=nohup $binpath --start-server-load-latest --server-settings $configfile --port=$port > $logfile 2>&1 &
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
        matchresult=$(tail -n1 $logfile|grep -o 'Matching server')
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
    if [ -f $serverpackfile ]
    then
         rm -rf $serverpackfile
    fi
    LogGreen "Begin Download Latest Server Package!"
    echo ""
    if wget --no-check-certificate -P $configpath  $serverpackurl
    then
        LogGreen "Download Succeed!"
    else
        LogRed "Download Failed!"
        return 1
    fi
    echo "" 
    LogGreen "Start Decompressing......"
    tar -xf $serverpackfile
    LogGreen "Decompressing Finish!"
    echo ""
    rm -rf $serverpackfile
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
    testmap=$scriptdir/testmap.zip
    cmdstr="$binpath --create $testmap"
    LogYellow "Initialize...... \nStart to Create TestMap"
    $cmdstr
    LogGreen "Initialize Finish!"
    rm -rf $testmap
    MD $scriptdir/factorio/saves
    if [ ! -f $configfile ]
    then
        cp $scriptdir/factorio/data/server-settings.example.json $configfile
    fi
    if [ ! -f $portfile ]
    then
        cat <<< "1438" > $portfile
    fi
}

BackupServer(){
    if [ -d $scriptdir/factorio/mods ]
    then
        LogYellow "Backup mods ......"
        cp -r $scriptdir/factorio/mods $modbackupPath
    fi
    if [ -d $scriptdir/factorio/saves ]
    then
        LogYellow "Backup maps ......"
        cp -r $scriptdir/factorio/saves $mapbackupPath
    fi
    LogGreen "Backup Finish!"
}

InstallServer(){
    if [ -d $scriptdir/factorio ]
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
elif [ $1 == "version" ]
then
    GetServerVersion
    echo $serverversion
elif [ $1 == "latestversion" ]
then
    if GetLatestOnlineVersion
    then
        echo $latestversion
    fi
else
    LogRed "Error Param $1"
    PrintHelp
fi

