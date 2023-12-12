#!/bin/bash

#user variable
mapfile=2023-12-12.zip
port=1338

#shell variable
pidfile=.factorio.pid
serverpackurl=https://factorio.com/get-download/stable/headless/linux64


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
        fi
        rm -rf $pidfile
    fi
    LogGreen "Server Stop Finish!"
}

StartServer(){
    if IsServerRunning
    then
        LogYellow "Server Is Already Running!"
        return 1
    fi    
    startcmd=nohup ./factorio/bin/x64/factorio --start-server $mapfile --server-settings server-settings.json --server-adminlist server-adminlist.json --port=$port > app.log 2>&1 &
    echo $startcmd
    $startcmd
    pid=$(echo $!)
    cat <<< $pid > $pidfile
    LogGreen "Start Succeed, Server is Running Now!"
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
"
echo -e $helpstr

}


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
else
    echo "Error Param $1"
    PrintHelp
fi

echo ""
echo ""
