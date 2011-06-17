#! /bin/bash

# Victor Lambret - juin 2011 - WTFPL
# Only for canalblog.com hosted blogs for now

SOURCE=$1
DIR=copyof_${1##*/}
MSG=${DIR}/posts
TMP=${DIR}/tmp

# test paramaters
if [[ -z ${SOURCE} ]]; then
	echo "$0: missing url operand"
	echo "usage: $0 http://example.canalblog.com"
	exit
else
	echo "Copying blog at ${SOURCE}"
fi

# test to avoid erasing existing files
if [[ -f ${DIR} ]]; then
	echo "There is already an ${DIR} existing file"
	exit
elif [[ -d ${DIR} ]]; then
	echo "There is already an ${DIR} existing directory"
	exit
fi
	
# Create directories
mkdir -p ${DIR}
mkdir -p ${MSG}
mkdir -p ${TMP}

# Usage : getpage src dest
function getpage {
	SRC=$1
	TARGET=$2
	wget -q -O - ${SRC} > ${TARGET}
	if [[ $? -eq "0" ]]; then
		echo "Copy of ${SRC} OK"
	else
		echo "Cant copy ${SRC} to ${TARGET}"
		exit
	fi
	sleep 1s
}

# MAIN

PAGE_COUNTER=0

# Copying blog
while [[ -n ${SOURCE} ]];
do
	# Copy html source 
	PAGE_COUNTER=$(($PAGE_COUNTER+1))
	echo "Copying page ${PAGE_COUNTER} at ${SOURCE}"
	PAGE=${TMP}/page_${PAGE_COUNTER}.html
	getpage ${SOURCE} ${PAGE}

	# We copy each message
	grep "<h3><a href=" ${PAGE} |
	while read line;
	do
		MSG_SRC=`echo $line | cut -d\" -f2`
		MSG_TITLE=`echo $line | cut -d\" -f4`
		MSG_TITLE_CLEAN=`echo $MSG_TITLE | sed -E 's/[ :/]+/_/g'`
		MSG_YEAR=`echo $MSG_SRC | cut -d\/ -f5`
		MSG_MONTH=`echo $MSG_SRC | cut -d\/ -f6`
		MSG_DAY=`echo $MSG_SRC | cut -d\/ -f7`
		MSG_ID=`echo ${MSG_SRC/.html} | cut -d\/ -f8`
		MSG_TARGET="${MSG}/${MSG_YEAR}${MSG_MONTH}${MSG_DAY}_${MSG_ID}_${MSG_TITLE_CLEAN}"
		mkdir -p $MSG_TARGET
		getpage $MSG_SRC $MSG_TARGET/src.html
		
		MSG_START=`grep -n "<a name=\"${MSG_ID}\"></a>" $MSG_TARGET/src.html | cut -d: -f1`
		MSG_END=`grep -n "<div class=\"itemfooter\">" $MSG_TARGET/src.html| head -n 1 | cut -d: -f1`
		MSG_SIZE=$(($MSG_END-$MSG_START))
		MSG_SIZE=$(($MSG_SIZE-2))

		head -n $((${MSG_END}-1)) $MSG_TARGET/src.html | tail -n ${MSG_SIZE} > $MSG_TARGET/msg.html
		pandoc -f html -t markdown $MSG_TARGET/msg.html > $MSG_TARGET/msg.pdc
		# Download only pictures included in the message content
		for i in `grep '!\[' $MSG_TARGET/msg.pdc | cut -d\( -f2 |  cut -d\) -f1`;
		do
			IMG=`basename $i`
			getpage $i $MSG_TARGET/${IMG}
		done

		# Copy comments
		COMMENTS_COUNTER=0
		for i in `grep -n '^<a id="c' $MSG_TARGET/src.html | cut -d: -f1`;
		do
			echo "Copying comment $COMMENTS_COUNTER"
			COMMENTS_COUNTER=$(($COMMENTS_COUNTER+1))
			COMMENT_END=`tail -n +$(($i+1)) $MSG_TARGET/src.html | grep -n '<div class="itemfooter">' | head -n 1 |cut -d: -f1`
			tail -n +$(($i+1)) $MSG_TARGET/src.html | head -n $COMMENT_END | pandoc -f html -t markdown | grep -v 'http://www.gravatar.com/avatar.php?gravatar_id' > $MSG_TARGET/comment_${COMMENTS_COUNTER}.pdc
		done

		sed -E 's/http:\/\/storage.canalblog.com.*\///' $MSG_TARGET/msg.pdc > $MSG_TARGET/msg.pdc2	


	done

	# Compute next page
	SOURCE=`grep 'Page suivante' ${PAGE} | grep href | head -n 1 | sed -e 's/.*href/href/' | cut -d\" -f2`
done
echo "work done"
