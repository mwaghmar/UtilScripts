# .bashrc
export HOSTNAME="ManojRHEL"
PS1="[\u@$HOSTNAME \W]\$"
export PATH=.:/sbin:/usr/sbin:/root/UtilScripts:$PATH
export CVS_RSH='ssh'
#export CVSROOT=':ext:veeral@192.168.20.22:/var/home/cvsrsd/cvsroot'

export LD_LIBRARY_PATH="/usr/local/lib"
alias tmux='/root/code/try/tmux/tmuxInstall/bin/tmux';
alias lssessions='/root/code/try/tmux/tmuxInstall/bin/tmux ls'
alias attachsession='tmux attach-session -t "$@"'

source /root/UtilScripts/cdiff.bash
route add -net 192.168.20.0 netmask 255.255.255.0 gw 192.168.0.201
eval `dircolors`
export LS_OPTIONS='--color=auto'
alias ls='ls $LS_OPTIONS'
alias ssh='ssh -oStrictHostKeyChecking=no'
export EDITOR=vim

#export MARSBUILD_MACHINE="192.168.20.36"
#export MARSBUILD_MACHINE="192.168.20.81"
export MARSBUILD_MACHINE="192.168.20.138"
alias gomarsbuild='ssh $MARSBUILD_MACHINE'

export MARSBUILDLOGDIR="/var/www/twiki/pub/MARS/MARSBuildLogs"
alias mountbuilddir='mount -t nfs 192.168.20.81:/home/build/Builds /var/www/twiki/pub/MARS/BuildZips/'
alias mountdebugfs='mount -t debugfs debugfs /sys/kernel/debug'

# User specific aliases and functions
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias vi='vim'
# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

if [ -f ~/.currworkdir ]; then
	export WORK=`cat ~/.currworkdir`
fi

# exporting LANG options for proper display of text
export LANG=C

#mwaghmar aliases
alias listsourcefiles='find ./ -name "*.[chsS]"  -o -name *.cpp -o -name "Makefile.*" -o -name "*.mak" -o -name *.py -o -name *.pl'
alias tarsource='listsourcefiles | xargs tar -cjvf $@'
alias untarsource='tar -xjvf $@'
#find . -name "*.[chsS]" -o -name "*.cpp" -o -name "Makefile*" | grep -v "build_win*" | grep -v "build_rhel*" | grep -v "build_aix*" | 

#alias setcs='find $PWD -name "*.[cChsS]" -o -name "*.cpp" | grep -v "build\|RPMBUILD\|build_rhelx64\|build_winx64\|build_winx86\|build_aix\|hicapi-devel-01.0.8\|hicapi-01.0.8\|build_rhelx86\|external/hiarrayinf/include/hiStor/" > cscope.files; cscope -b -q; ctags -L cscope.files; CSCOPE_DB=$PWD\/cscope.out; export CSCOPE_DB; CSCOPE_EDITOR=vim; export CSCOPE_EDITOR; echo "CSCOPE ENV now is as follows-"; env | grep CSCOPE'

alias setcs='find $PWD -name "*.[cChsS]" -o -name "*.cpp" > cscope.files; cscope -b -q; ctags -L cscope.files; CSCOPE_DB=$PWD\/cscope.out; export CSCOPE_DB; CSCOPE_EDITOR=vim; export CSCOPE_EDITOR; echo "CSCOPE ENV now is as follows-"; env | grep CSCOPE'

alias refreshcs='CSCOPE_DB=$PWD\/cscope.out; export CSCOPE_DB; echo "CSCOPE ENV now is as follows-"; env | grep CSCOPE'
alias refreshtags='for d in `find . -type d | grep -v "doxydocs\|external\|RPMBUILD\|build"`; do ln $PWD/tags $d/; done'
#alias refreshtags='for d in `find . -type d | grep -v "doxydocs\|external\|RPMBUILD\|build"`; do yes | cp tags $d/; done'
alias cleantags="find . -type f -name tags -exec rm '{}' \;"

alias vi='vim'
export CSCOPE_EDITOR=vim
export DEFAULT_WORK=/root/code/work

if [ -z "$WORK" ]; then
	export WORK=`echo $DEFAULT_WORK`
fi  

alias setworkdir='export WORK=$PWD; echo $WORK > ~/.currworkdir; echo "Your Current Work Directory is Now: $WORK";'
alias gowork='cd $WORK'
alias capicmds='more $DEFAULT_WORK/cmds.txt'
alias bash='bash --login'
alias addtocdpath='export CDPATH=$CDPATH:$PWD; echo "Your CDPATH is now: $CDPATH"'

alias todatamart='ftpto.bash datamartftp.hds.com /manoj/get/ $@'
alias fromdatamart='ftpfrom.bash datamartftp.hds.com /manoj/get $@'
alias startvncserver='vncserver :1 -name manoj  -geometry 1900x1024'

alias mountmywindowsdrive='mount -t cifs -o credentials=/etc/sambapasswords //192.168.1.100/F /mnt/mywindows/f'

alias mountdatamartsandbox='curlftpfs datamartftp.hds.com/manoj/sandbox /mnt/datamart -o user=tdg_cs:tdg123cs,allow_other,uid=0,gid=0,umask=0022'

#alias hicapisync='rsync -vur --inplace --size-only --delete --times --omit-dir-times --files-from=/root/code/sandbox/hicapi_files --exclude=cscope.* --exclude=*.o --exclude=CVS --exclude=tags --exclude=libhicapi.so --exclude=TestApp --exclude=.tags.* --exclude=*.config /root/code/sandbox/hicapi/ /mnt/datamart/hicapi'

#alias hiarraysync='rsync -vur --inplace --size-only --delete --times --omit-dir-times --files-from=/root/code/sandbox/hiarray_files --exclude=cscope.* --exclude=*.o --exclude=CVS --exclude=tags --exclude=.tags.* --exclude=*.config  /root/code/sandbox/hiarrayinf/ /mnt/datamart/hiarrayinf/'


alias mountsftp='sshfs itpd@ftp.cumulus-systems.com:/home/itpd/CCM/from_ITPD_to_Cumulus /var/www/twiki/pub/CCM/ConfCalls -o user=itpd:W3d20nuj,allow_other,uid=0,gid=0,umask=0022'

alias scanports='nmap -sS -P0 -A -v $@'
alias scanhosts='nmap -sP $@'

export CDPATH=.:$DEFAULT_WORK
export DISPLAY=`echo $SSH_CLIENT | cut -d' ' -f 1`:0.0
#gowork

alias ..='cd ..'
alias ...='cd ../../../'
alias ....='cd ../../../../'
alias .....='cd ../../../../'
alias .4='cd ../../../../'
alias .5='cd ../../../../..'
 
