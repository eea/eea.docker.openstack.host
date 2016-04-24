#!/bin/ash

if [ "$#" -gt 1 ]; then
	echo "$#";
	exec /bin/ash;
fi

if [ x$INSTANCE_NAME = 'x' ]; then INSTANCE_NAME="$(python -c 'import sys,uuid; sys.stdout.write(uuid.uuid4().hex)')"; fi

image_id="$(glance --os-image-api-version 1 image-list --name  $IMAGE_NAME | awk '/'$IMAGE_NAME'/ {print $2}')"

if [ x"$KEYNAME" != 'x' ]; then injectKEY="--key-name '$KEYNAME'"; else injectKEY=''; fi
if [ x"$OS_NETWORK_ID" != 'x' ]; then injectNETcmd="--nic"; injectNetID="net-id="; else injectNETcmd=''; injectNetID=''; fi 
if [ x"$OS_AVAILABILITY_ZONE" != 'x' ]; then injectAVLcmd="--availability-zone"; else injectAVLcmd=''; fi

#########################
#Root Volume creation
#########################

rootvol_id="$(cinder create --image-id $image_id --display-name $INSTANCE_NAME-Root $INSTANCE_ROOT_SIZE | awk '/\|[ ]+id[ ]+\|/ {print $4}')"
i=20; vol_status=''
echo "Creating Root volume "$INSTANCE_NAME-Root
while [ $((--i)) -gt 0 -a x$vol_status != 'xavailable' ]; do
   vol_status="$(cinder show $rootvol_id | awk '/\|[ ]+status/ {print $4}')"
   printf "\rWaiting to became available. Will timeout in %s" $((i*10))s 
   if [ x$vol_status != 'xavailable' ]; then sleep 10s; fi
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

dsvol_id="$(cinder create --volume-type $INSTANCE_DOCKERSTORAGE_TYPE --display-name $INSTANCE_NAME-DockerStorage $INSTANCE_DOCKERSTORAGE_SIZE | awk '/\|[ ]+id[ ]+\|/ {print $4}')"
echo "Creating Docker Storage volume "$INSTANCE_NAME-DockerStorage
i=20; vol_status=''
while [ $((--i)) -gt 0 -a x$vol_status != 'xavailable' ]; do
   vol_status="$(cinder show $dsvol_id | awk '/\|[ ]+status/ {print $4}')"
   printf "\rWaiting to became available. Will timeout in %s" $((i*10))s
   if [ x$vol_status != 'xavailable' ]; then sleep 10s; fi
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
  dvvol_id="$(cinder create --volume-type $INSTANCE_DOCKER_VOLUME_TYPE --display-name $INSTANCE_NAME-DockerVolumes $INSTANCE_DOCKER_VOLUME_SIZE | awk '/\|[ ]+id[ ]+\|/ {print $4}')"
  echo "Creating Docker Volumes volume "$INSTANCE_NAME-DockerVolumes
  i=20; vol_status=''
  while [ $((--i)) -gt 0 -a x$vol_status != 'xavailable' ]; do
     vol_status="$(cinder show $dvvol_id | awk '/\|[ ]+status/ {print $4}')"
     printf "\rWaiting to became available. Will timeout in %s" $((i*10))s
     if [ x$vol_status != 'xavailable' ]; then sleep 10s; fi
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
if [ $INSTANCE_DOCKER_VOLUME == true ]; then injectVOL2cmd="--block-device source=volume,id=$dvvol_id,dest=volume,size=$INSTANCE_DOCKER_VOLUME_SIZE,shutdown=remove,bootindex=2"; else  injectVOL2cmd=''; fi
                                                                                                                                                                                                                   
cmd="nova boot --flavor $flavor_id $injectNETcmd $injectNetID$OS_NETWORK_ID --block-device source=volume,id=$rootvol_id,dest=volume,size=$INSTANCE_ROOT_SIZE,shutdown=remove,bootindex=0 --block-device source=volume,id=$dsvol_id,dest=volume,size=$INSTANCE_DOCKERSTORAGE_SIZE,shutdown=remove,bootindex=1 $injectVOL2cmd $injectAVLcmd $OS_AVAILABILITY_ZONE $injectKEY $INSTANCE_NAME | awk '/\|[ ]+id[ ]+\|/ {print \$4}'"
instance_id="$(eval $cmd)"  

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


