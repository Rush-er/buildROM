#!/bin/bash

#Grazie Ezio !
#https://github.com/ezio84/scripts/blob/q/build_rom.sh


# Colorize and add text parameters
red=$(tput setaf 1)             #  red
grn=$(tput setaf 2)             #  green
blu=$(tput setaf 4)             #  blue
txtbld=$(tput bold)             #  bold
bldgrn=${txtbld}$(tput setaf 1) #  bold red
bldgrn=${txtbld}$(tput setaf 2) #  bold green
bldblu=${txtbld}$(tput setaf 4) #  bold blue
txtrst=$(tput sgr0)             #  reset


#Start the build
curl -s -X POST https://api.telegram.org/bot"insertyourbotid"/sendMessage -d chat_id="insertyourchatid" -d text="Start building"

#Log rom building output
# http://www.ludovicocaldara.net/dba/bash-tips-5-output-logfile/
export LOGDIR=~/log/
export DATE=`date +"%Y%m%d"`
export DATETIME=`date +"%Y%m%d_%H%M%S"`
 
ScriptName=`basename $0`
Job=`basename $0 .sh`"-build-"
JobClass=`basename $0 .sh`
 
function Log_Open() {
        if [ $NO_JOB_LOGGING ] ; then
                einfo "Not logging to a logfile because -Z option specified." #(*)
        else
                [[ -d $LOGDIR/$JobClass ]] || mkdir -p $LOGDIR/$JobClass
                Pipe=${LOGDIR}/$JobClass/${Job}_${DATETIME}.pipe
                mkfifo -m 700 $Pipe
                LOGFILE=${LOGDIR}/$JobClass/${Job}_${DATETIME}.log
                exec 3>&1
                tee ${LOGFILE} <$Pipe >&3 &
                teepid=$!
                exec 1>$Pipe
                PIPE_OPENED=1
                enotify Logging to $LOGFILE  # (*)
                [ $SUDO_USER ] && enotify "Sudo user: $SUDO_USER" #(*)
        fi
}
 
function Log_Close() {
        if [ ${PIPE_OPENED} ] ; then
                exec 1<&3
                sleep 0.2
                ps --pid $teepid >/dev/null
                if [ $? -eq 0 ] ; then
                        # a wait $teepid whould be better but some
                        # commands leave file descriptors open
                        sleep 1
                        kill  $teepid
                fi
                rm $Pipe
                unset PIPE_OPENED
        fi
}
 
OPTIND=1
while getopts ":Z" opt ; do
        case $opt in
                Z)
                        NO_JOB_LOGGING="true"
                        ;;
        esac
done
 
Log_Open
echo "Logging to $LOGFILE"

# Start tracking time
echo -e ${bldblu}
echo -e "---------------------------------------"
echo -e "SCRIPT AT $(date +%D\ %r)"
echo -e "---------------------------------------"
echo -e ${txtrst}

START=$(date +%s)

# Setup environment
echo -e "${bldblu}Setting up build environment ${txtrst}"
cd ~/validus/
. build/envsetup.sh
# Setup ccache
export USE_CCACHE=1
export CCACHE_DIR="home/stoccomatis7/cchace/"
/usr/bin/ccache -M 25G

#Clean the out dir
  echo -e "${bldblu}Cleaning up the OUT folder with make clobber ${txtrst}"
  make clean

#Building time !
lunch validus_whyred-userdebug && mka api-stubs-docs && mka hiddenapi-lists-docs && mka system-api-stubs-docs && mka test-api-stubs-docs && mka validus

# back to root dir
cd ~/

# Stop tracking time
END=$(date +%s)
echo -e ${bldblu}
echo -e "-------------------------------------"
echo -e "ENDING AT $(date +%D\ %r)"
echo -e ""
echo -e "${BUILD_RESULT}!"
echo -e "TIME: $(echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}')"
echo -e "-------------------------------------"
echo -e ${txtrst}

BUILDTIME="Build time: $(echo $((${END}-${START})) | awk '{print int($1/60)" minutes and "int($1%60)" seconds"}')"

command
Log_Close

echo "FINDING ROM FILE"

if 
    find ~/validus/out/target/product/whyred/ -name '*Validus-whyred-*'.zip
then 
rclone copy ~/validus/out/target/product/whyred/Validus-whyred-*.zip  gdrive:rom
rclone copy ~/validus/out/target/product/whyred/Validus-whyred-*.md5sum  gdrive:rom

#Send message to Telegram group after build & upload complete
curl -s -X POST https://api.telegram.org/bot"insertyourbotid"/sendMessage -d chat_id="insertyourchatid" -d text= "Build done !
Get it here http://url.stoccomatis.com/rom"

#shut down the VM
sudo poweroff

else
    curl -s -X POST https://api.telegram.org/bot"insertyourbotid"/sendMessage -d chat_id="insertyourchatid" -d text="Build failed !"
    sudo poweroff
fi
