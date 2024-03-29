#!/bin/bash

# enter username
read -p "Enter username (required): " username
if [ -z "$username" ]; then
    echo "[ERROR] The username is empty!"
    exit
fi

# one username can have multiple containers
# => check all existing container names of this username
containers=$(docker ps --all --format="{{.Names}}" --last -1 | grep $username)
newname=$username
if [ ${#containers[@]} = 0 ]; then
    echo "[INFO] There's no container using $username!"
else
    echo "[INFO] $username is being used! -> lists: ${containers[*]}"
    read -p "Versioning: " namever
    newname="$username-$namever"
    while :; do
        exists=0
        for container in ${containers[*]}; do
            # echo $container
            if [ "$container" = "$newname" ]; then
                exists=1
                break
            fi
        done
        if [[ $exists = 1 ]]; then
            echo "[INFO] $newname is also being used!"
            read -p "Versioning: " namever
            newname="$username-$namever"
        else
            break
        fi
    done
fi
echo "[RES] => using $newname"

# enter port
read -p "Enter port (optional, empty for random port): " port
if [ -z "$port" ]; then
    port=$(shuf -i 49152-65535 -n 1) # pick randomly a port
fi

while :; do
    if [ -z "$(ss --all | grep $port)" ]; then
        break
    else
        echo "[INFO] Port $port is being used!"
        port=$(shuf -i 49152-65535 -n 1)
    fi
done
echo "[RES] => using port $port"

# enter team code
# read -p "Enter server (optional, VinUni-0, HUST-1, otherwise-all): " server
# if [ "$server" = "0" ]; then
s="0,1,2,3,4,5"
# elif [ "$server" = "1" ]; then
#     s="4,5,6,7"
# else
#     s="0,1,2,3,4,5,6,7"
# fi

# copy and paste ssh public key
mkdir -p ~/vinuni/user_data/$username # -p will ignore if existing
mkdir -p ~/vinuni/ssh_key/user/$username
if [ -f "/home/cdc/vinuni/ssh_key/user/$username/authorized_keys" ]; then
    echo "[INFO] This username already has authorized keys!"
    read -p "Add a new public key and remove old one (y): " OptPubKey
else
    echo "[INFO] This username doesn't have any authorized keys, please add one!"
    OptPubKey="y"
fi
if [ $OptPubKey = "y" ]; then
    echo "[INPUT] Paste the public key:"
    read pubkey
    echo "$pubkey"
    if [ -z "$pubkey" ]; then
        echo "[ERROR] The public key is empty!"
        exit
    fi
    # write authorized keys to file
    echo $pubkey >~/vinuni/ssh_key/user/$username/authorized_keys
    chmod 644 ~/vinuni/ssh_key/user/$username/authorized_keys
fi

# create a container
docker run --init --restart=always --name $newname \
    --memory 230g --shm-size 64g \
    --cpuset-cpus="0-62" --gpus "\"device=$s\"" \
    -v ~/vinuni/user_data/$username:/home/ubuntu/$username \
    -v ~/vinuni/data_shared/shared:/home/ubuntu/shared \
    -v ~/vinuni/data_shared/protected:/home/ubuntu/data:ro \
    -p $port:22 -itd ubuntu_cecs:20.04

# copy authorized keys inside container
docker cp ~/vinuni/ssh_key/user/$username/authorized_keys $username:/home/ubuntu/.ssh/authorized_keys 
