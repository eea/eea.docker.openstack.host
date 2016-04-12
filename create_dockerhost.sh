#!/bin/ash



if [ x$INSTANCE_NAME = 'x' ]; then INSTANCE_NAME="$(python -c 'import sys,uuid; sys.stdout.write(uuid.uuid4().hex)')"; fi

image_id="$(glance --os-image-api-version 1 image-list --name  $IMAGE_NAME | awk '/'$IMAGE_NAME'/ {print $2}')"

if [ x'$KEYNAME' != 'x' ]; then injectKEYcmd="--key-name"; else injectKEYcmd=''; fi

#########################
#Root Volume creation
#########################

rootvol_id="$(cinder create --image-id $image_id --display-name $INSTANCE_NAME-Root $INSTANCE_ROOT_SIZE | awk '/\|[ ]+id[ ]+\|/ {print $4}')"
i=20; vol_status=''
echo "Creating Root volume "$INSTANCE_NAME-Root
while [ $((--i)) -gt 0 -a x$vol_status != 'xavailable' ]; do
   vol_status="$(cinder show $rootvol_id | awk '/\|[ ]+status/ {print $4}')"
   printf "\rWaiting to became available. Will timeout in %s" $((i*10))s 
   sleep 10s
done
echo
if [ $i -eq 0 ]; then
   echo "Timed out. The volume might still get created but it is too slow for me!" 
   exit 1
else
   echo "Succesfully created root volume!"
fi


##############################
#Docker-Storage Volume creation
##############################

dsvol_id="$(cinder create --display-name $INSTANCE_NAME-DockerStorage $INSTANCE_DOCKERSTORAGE_SIZE | awk '/\|[ ]+id[ ]+\|/ {print $4}')"
echo "Creating Docker Storage volume "$INSTANCE_NAME-DockerStorage
i=20; vol_status=''
while [ $((--i)) -gt 0 -a x$vol_status != 'xavailable' ]; do
   vol_status="$(cinder show $dsvol_id | awk '/\|[ ]+status/ {print $4}')"
   printf "\rWaiting to became available. Will timeout in %s" $((i*10))s
   sleep 10s
done
echo
if [ $i -eq 0 ]; then
   echo "Timed out. The volume might still get created but it is too slow for me!"
   exit 1
else
   echo "Succesfully created Docker Storage volume!"
fi


#######################################
#Optional Docker-Volumes Volume creation
#######################################

if [ $INSTANCE_DOCKER_VOLUME = true ]; then 
  dvvol_id="$(cinder create --display-name $INSTANCE_NAME-DockerVolumes $INSTANCE_DOCKER_VOLUME_SIZE | awk '/\|[ ]+id[ ]+\|/ {print $4}')"
  echo "Creating Docker Volumes volume "$INSTANCE_NAME-DockerVolumes
  i=20; vol_status=''
  while [ $((--i)) -gt 0 -a x$vol_status != 'xavailable' ]; do
     vol_status="$(cinder show $dvvol_id | awk '/\|[ ]+status/ {print $4}')"
     printf "\rWaiting to became available. Will timeout in %s" $((i*10))s
     sleep 10s
  done
  echo
  if [ $i -eq 0 ]; then
     echo "Timed out. The volume might still get created but it is too slow for me!"
     exit 1
  else
     echo "Succesfully created Docker Volume volume!"
  fi
else
  echo "No Docker-Volumes volume was requested" 
fi

##############################
#Instance creation and boot
##############################

printf "retreving flavor ID for %s ..." "$INSTANCE_FLAVOR"
flavor_id="$(nova flavor-list |  awk '/\| '"$INSTANCE_FLAVOR"' \|/ {print $2}')"
if [ x$flavor_id != 'x' ]; then echo $flavor_id; else echo "Not existent?!"; exit 1; fi

echo "Creating Instance "$INSTANCE_NAME

if [ $INSTANCE_DOCKER_VOLUME = true ]; then
   instance_id=$(nova boot --flavor "$flavor_id" --block-device source=volume,id="$rootvol_id",dest=volume,size="$INSTANCE_ROOT_SIZE",shutdown=remove,bootindex=0 --block-device source=volume,id="$dsvol_id",dest=volume,size="$INSTANCE_DOCKERSTORAGE_SIZE",shutdown=remove,bootindex=1 --block-device source=volume,id="$dvvol_id",dest=volume,size="$INSTANCE_DOCKER_VOLUME_SIZE",shutdown=remove,bootindex=2 "$injectKEYcmd" "$KEYNAME" "$INSTANCE_NAME" | awk '/\|[ ]+id[ ]+\|/ {print $4}')
else
   instance_id=$(nova boot --flavor "$flavor_id" --block-device source=volume,id="$rootvol_id",dest=volume,size="$INSTANCE_ROOT_SIZE",shutdown=remove,bootindex=0 --block-device source=volume,id="$dsvol_id",dest=volume,size="$INSTANCE_DOCKERSTORAGE_SIZE",shutdown=remove,bootindex=1 "$injectKEYcmd" "$KEYNAME" "$INSTANCE_NAME" | awk '/\|[ ]+id[ ]+\|/ {print $4}')
fi
i=20; instance_status=''
while [ $((--i)) -gt 0 -a x$instance_status != 'xactive' ]; do
   instance_status="$(nova show $instance_id | awk '/vm_state/ {print $4}')"
   printf "\rWaiting to became active. Will timeout in %s" $((i*10))s
   sleep 10s
done
echo
if [ $i -eq 0 ]; then
   echo "Timed out. The instance might still get created but it is too slow for me!"
   exit 1
else
   echo "Succesfully created Instance!"
fi


