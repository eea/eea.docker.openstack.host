# Easily and Repeatably Deploy Docker Hosts in OpenStack clouds

This container provides the prerequisites to access the Openstck API. On startup it runs a (configurable) script to deploy a VM that boots from volume, attaches another volume for docker storage (intended for direct lvm driver) and optionaly creates and attaches yet another volume for docker data volumes (intended to be mounted under /var/lib/docker/volumes).

## Supported tags and respective Dockerfile links

none yet

## Base docker image

 - [hub.docker.com](https://hub.docker.com/r/eeacms/os-docker-vm/)

## Source code

  - [github.com](https://github.com/eea/eea.docker.openstack.host/)

## Usage

Prepare the [.secret](https://github.com/eea/eea.docker.openstack.host/blob/master/.secret.example) and [.cloudaccess](https://github.com/eea/eea.docker.openstack.host/blob/master/.cloudaccess.example) files (see linked examples)

Create a VM named prodXX-mil using defaults

    $ docker run --rm=true \
                 --env-file=.secret \
                 --env-file=.cloudaccess \
                 -e INSTANCE_NAME=prodXX-mil \
                 --name deploy-host \
                 eeacms/os-docker-vm:v1.1


## Supported environment variables

* OS_USERNAME - the openstack username
* OS_PASSWORD - the openstack password
* KEYNAME     - the name of the keypair to be injected into the running instance (optional)

* OS_AUTH_URL           - AUTH URL for the target openstack cloud
* OS_TENANT_ID          - ID of the openstack tenant 
* OS_TENANT_NAME        - name of the openstack tenant 
* OS_REGION_NAME        - openstack region (optional)
* OS_NETWORK_ID		- network ID within the tenant (optional if there is only one network available)
* OS_VOLUME_API_VERSION - API version for cinder. Defaults to 1
* OS_AVAILABILITY_ZONE  - openstack availability zone within the tenant (optional if the provider has only one zone or it uses same default for all services)

* TIMEOUT		- how long shall we wait for volume or instance creation to succeed (in 10s of seconds)

* IMAGE_NAME                  - glance image to be used. defaults to EEA-docker-generic-v2.1 (should be already present in glance)

* INSTANCE_NAME               - provide a name for the new instance. It is considered a prefix if it ends with "-" and consecutive numbers are added to the name. A UUID will be generated if this is missing. 

* INSTANCE_FLAVOR             - name of the flavor to be used. defaults to a flavor named e2standard.x5 (should be already defined)
* INSTANCE_ROOT_SIZE          - self explanatory. defaults to 10 and is in GBytes
* INSTANCE_ROOT_PERSISTENT    - can be "true" or "false" (default). It sets the instance to delete all related volumes on termination
* INSTANCE_DOCKERSTORAGE_SIZE - self explanatory. defaults to 32 and is in GBytes
* INSTANCE_DOCKERSTORAGE_TYPE - openstack volume type for docker storage volume. defaults to "standard"
* INSTANCE_DOCKER_VOLUME      - can be "true" (default) or "false". Creates the optional volume to hold docker data volumes
* INSTANCE_DOCKER_VOLUME_TYPE - openstack volume type for docker volumes volume. defaults to "standard"
* INSTANCE_DOCKER_VOLUME_SIZE - self explanatory. defaults to 10 and is in GBytes

* INSTANCE_DOMAIN 	      - a name for the private openstack domain. If this is set then an atempt will be made to register the name of the new VM and to configure domain search and nameservers for the local resolver. If this is set the next 3 should also be set. 
* DNS_IP_A		      - the authoritative IP of a resolver for the above domain, capable of DDNS updates
* DNS_IP_B		      - the IP of a resolver for the above domain
* DNS_KEY		      - the "secret" key used by DDNS protocol to allow registration

## Copyright and license

The Initial Owner of the Original Code is European Environment Agency (EEA).
All Rights Reserved.

