#!/bin/bash

if [[ $1 == "" ]]; then
  echo "usage: ./create-user.sh [user-csv-path]"
  exit 0
fi

csvPath=$1
seperator=","

#process users
while IFS="$seperator" read -r username name surname password group; do
  samba-tool user create "$username" "$password" --given-name="$name" --surname="$surname" || echo "failed to create user $username"
  if ! samba-tool group list | grep ^$group$ ; then
    samba-tool group add $group
    sleep 1
  fi
  samba-tool group addmembers $group $username || echo "failed to add $username to $group!"
done < <(tail -n +2 "$csvPath")
