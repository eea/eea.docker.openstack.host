#!/bin/ash

if [ "$#" -gt 1 ]; then
	echo "$#";
	exec /bin/ash;
fi

##########################
#Sanity checks
##########################

if [ x$INSTANCE_NAME = 'x' ]; then
	case "$OS_TENANT_NAME" in
		dev-env@eea.europa.eu) 
			INSTANCE_NAME="dev-";;
		Soren.Roug@eea.europa.eu|Production)
			INSTANCE_NAME="prod-";;
                *)
			INSTANCE_NAME="$(python -c 'import sys,uuid; sys.stdout.write(uuid.uuid4().hex)')";;
	esac
	case "$OS_REGION_NAME" in
		it-mil1)
			INSTANCE_NAME=$INSTANCE_NAME"mil-";;
		nl-ams1)
			INSTANCE_NAME=$INSTANCE_NAME"ams-";;
		de-fra1)
			INSTANCE_NAME=$INSTANCE_NAME"fra-";;
		dk-cph1)	
			INSTANCE_NAME=$INSTANCE_NAME"cph-";;		
		*)
			INSTANCE_NAME="$(python -c 'import sys,uuid; sys.stdout.write(uuid.uuid4().hex)')";;
	esac
fi

expr $INSTANCE_NAME : '.*-$'
if [ $? == 0 ]; then
	lastno="$(nova list | awk -F '[-,|]' '/'$INSTANCE_NAME'/ {print $9}' | sort | tail -1)"
	expr $lastno : '[0-9][0-9]*$'
	if  [ $? == 1 ] ; then
		lastno=0
	fi
	lastno=$(echo $lastno | sed 's/^0*//')
       	nextno=`printf "%02d" $((lastno+1))`
	INSTANCE_NAME=$INSTANCE_NAME$nextno
fi


nova list | grep $INSTANCE_NAME
if [ $? == 0 ]; then 
  echo "An instance named $INSTANCE_NAME already exists or not enough priviledge (see the above line for details). Exiting ..."
  exit 1
fi

image_id="$(glance --os-image-api-version 1 image-list --name  $IMAGE_NAME | awk '/'$IMAGE_NAME'/ {print $2}')"
if [ x$image_id == 'x' ]; then
	echo "Could not find an image by the name $IMAGE_NAME. Exiting ..."
	exit 1
fi

flavor_id="$(nova flavor-list |  awk '/\| '"$INSTANCE_FLAVOR"'[ ]+\|/ {print $2}')"
if [ x$flavor_id == 'x' ]; then
	 echo "Coud not find a flavour by the name $INSTANCE_FLAVOR. Exiting ..."
	 exit 1
fi

if [ x"$KEYNAME" != 'x' ]; then injectKEY="--key-name '$KEYNAME'"; else injectKEY=''; fi
if [ x"$OS_NETWORK_ID" != 'x' ]; then injectNETcmd="--nic"; injectNetID="net-id="; else injectNETcmd=''; injectNetID=''; fi 
if [ x"$OS_AVAILABILITY_ZONE" != 'x' ]; then injectAVLcmd="--availability-zone"; else injectAVLcmd=''; fi

#########################
#Root Volume creation
#########################

rootvol_id="$(cinder create --image-id $image_id --display-name $INSTANCE_NAME-Root --display-description 'Boot Volume based on '$IMAGE_NAME' image' $INSTANCE_ROOT_SIZE | awk '/\|[ ]+id[ ]+\|/ {print $4}')"
i=$TIMEOUT; vol_status=''
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

if [ x"$INSTANCE_DOCKERSTORAGE_TYPE" != 'x' ]; then injectVTYPEcmd="--volume-type"; else injectVTYPEcmd=''; fi

dsvol_id="$(cinder create $injectVTYPEcmd $INSTANCE_DOCKERSTORAGE_TYPE --display-name $INSTANCE_NAME-DockerStorage --display-description 'Docker storage' $INSTANCE_DOCKERSTORAGE_SIZE | awk '/\|[ ]+id[ ]+\|/ {print $4}')"
echo "Creating Docker Storage volume "$INSTANCE_NAME-DockerStorage
i=$TIMEOUT; vol_status=''
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

if [ x"$INSTANCE_DOCKER_VOLUME_TYPE" != 'x' ]; then injectVTYPEcmd="--volume-type"; else injectVTYPEcmd=''; fi

if [ $INSTANCE_DOCKER_VOLUME = true ]; then 
  dvvol_id="$(cinder create $injectVTYPEcmd $INSTANCE_DOCKER_VOLUME_TYPE --display-name $INSTANCE_NAME-DockerVolumes --display-description 'Docker volumes' $INSTANCE_DOCKER_VOLUME_SIZE | awk '/\|[ ]+id[ ]+\|/ {print $4}')"
  echo "Creating Docker Volumes volume "$INSTANCE_NAME-DockerVolumes
  i=$TIMEOUT; vol_status=''
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
#Prepare first boot script
##############################
sed -i "s/###REPLACE-ME-NAME###/$INSTANCE_NAME/" user_data.file
sed -i "s/###REPLACE-ME-DOMAIN###/$INSTANCE_DOMAIN/" user_data.file
sed -i "s/###REPLACE-ME-DNS-A###/$DNS_IP_A/" user_data.file
sed -i "s/###REPLACE-ME-DNS-B###/$DNS_IP_B/" user_data.file
sed -i "s/###REPLACE-ME-KEY###/$DNS_KEY/" user_data.file


##############################
#Instance creation and boot
##############################

echo "Creating Instance "$INSTANCE_NAME
if [ $INSTANCE_DOCKER_VOLUME == true ]; then injectVOL2cmd="--block-device source=volume,id=$dvvol_id,dest=volume,size=$INSTANCE_DOCKER_VOLUME_SIZE,shutdown=remove,bootindex=2"; else  injectVOL2cmd=''; fi
                                                                                                                                                                                                                   
cmd="nova boot --flavor $flavor_id $injectNETcmd $injectNetID$OS_NETWORK_ID --block-device source=volume,id=$rootvol_id,dest=volume,size=$INSTANCE_ROOT_SIZE,shutdown=remove,bootindex=0 --block-device source=volume,id=$dsvol_id,dest=volume,size=$INSTANCE_DOCKERSTORAGE_SIZE,shutdown=remove,bootindex=1 $injectVOL2cmd $injectAVLcmd $OS_AVAILABILITY_ZONE $injectKEY --user-data user_data.file $INSTANCE_NAME | awk '/\|[ ]+id[ ]+\|/ {print \$4}'"
instance_id="$(eval $cmd)"  

i=$TIMEOUT; instance_status=''
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


