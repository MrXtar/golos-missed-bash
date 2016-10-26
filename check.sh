#!/bin/bash

# cli_wallet --rpc-http-endpoint url
WALLET=http://127.0.0.1:8093

# cli_wallet unlock password
PASSWORD="PASSWORD"

# update_witness params:
NICKNAME="xtar" #your witness nickname
BACKUPKEY="PUBKEY" # backup server brain pub_key
URL="https://golos.io/ru--delegaty/@xtar/kandidat-delegat-xtar-razrabotchik-steemul-ru" # post url
FEE="3.000 GOLOS" # account_creation_fee
BLOCKSIZE=65536 # maximum_block_size
RATE=1000 # sbd_interest_rate


function is_locked {
	LOCKED=`curl -s --data-binary '{"id":"1","method":"is_locked","params":[""]}' "$WALLET" | jq -r '.result'`
}

function checkLockAndExit {
	if [ "$EXITLOCK" = true ]; then
		echo -n "Locking wallet again..."
		curl -s --data-binary '{"id":0,"method":"lock","params":[]}' "$WALLET" > /dev/null
		echo ""
		echo "Locked."
	fi
}

is_locked
if [ "$LOCKED" == "true" ]; then
	EXITLOCK=true
	echo -n "Wallet is locked. Trying to unlock..."
	curl -s --data-binary '{"id":"1","method":"unlock","params":["'"$PASSWORD"'"]}' "$WALLET" > /dev/null
	echo ""
	is_locked
	if [ "$LOCKED" == "true" ]; then
		echo "Can't unlock wallet, exiting."
		checkLockAndExit		
	else
		echo "Wallet unlocked."
	fi
else
	if [ "$LOCKED" == "false" ]; then
		EXITLOCK=false
		echo "Wallet was unlocked before."
	else
		echo "Some error. Is cli_wallet running? Exit."
		exit
	fi
fi

# cd to current dir
parent_path=$( cd "$(dirname "${BASH_SOURCE}")" ; pwd -P )
cd "$parent_path"

# preparing files
if [ -f ${NICKNAME}_data_old.json ]; then
	rm ${NICKNAME}_data_old.json
fi
if [ -f ${NICKNAME}_data_new.json ];then
	mv ${NICKNAME}_data_new.json ${NICKNAME}_data_old.json;
fi

# saving witness new json
curl -s --data-binary '{"id":"1","method":"get_witness","params":["'"$NICKNAME"'"]}' "$WALLET" > ${NICKNAME}_data_new.json

if [ -f ${NICKNAME}_data_old.json ]; then
	if [ `cat ${NICKNAME}_data_old.json | jq -r '.result.owner'` != $NICKNAME ]; then
		echo "No old result for witness $NICKNAME. Exit."
		checkLockAndExit
	fi
	OLD=`cat ${NICKNAME}_data_old.json | jq -r '.result.total_missed'`
	if [ -f ${NICKNAME}_data_old.json ]; then
		if [ `cat ${NICKNAME}_data_new.json | jq -r '.result.owner'` != $NICKNAME ]; then
			echo "No new result for witness $NICKNAME. Exit."
			checkLockAndExit
		fi
		NEW=`cat ${NICKNAME}_data_new.json | jq -r '.result.total_missed'`
		if [ $OLD -eq $NEW ]; then
			echo "No new missed blocks detected. Count = ${NEW}"
		else
			echo "New missed blocks detected. Was ${OLD}. Now ${NEW}."
			echo "Switching to backup node."
			curl -s --data-binary '{"id":"1","method":"update_witness","params":["'"$NICKNAME"'","'"$URL"'","'"$BACKUPKEY"'",{"account_creation_fee":"'"$FEE"'","maximum_block_size":"'"$BLOCKSIZE"'","sbd_interest_rate":"'"$RATE"'"},true],"jsonrpc":"2.0"}' "$WALLET" > /dev/null
		fi
	fi
fi

checkLockAndExit