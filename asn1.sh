#!/bin/bash

# This script tests the reachability of every network connection in cs-vnl
# from one specific client host
#
# The scan can be conducted using host names, IPv4 or IPv6 addresses.  It can
# also find the ethernet addresses of network connections 



# How to run the script:
# 
# 1. ssh into one of the 20 hosts in the network
# 2. open a terminal session
# 3. chmod the file, typing chmod +x asn1.sh, if file is not executable
# 4. execute script by typing ./asn1.sh, commenting last three lines as necessary

 
# globals
REPEAT=1	# the number of times to initiate ICMP in ping.
DESTINATION=(
	spring 
	summer
	autumn
	fall
	winter
	equinox
	solstice
	year
	january
	february
	march
	april
	may
	june
	july
	august
	september
	october
	november
	december) # an array of virtual machine names

HOSTIPv4_A=$(hostname -i)	# source ip in admin
HOSTNAME_A=$(hostname).admin	#source host name in admin
# echo "source host name in admin is: ${HOSTNAME_A}"

# source host ipv4 in net16...net19
HOSTIPv4_N=$(ifconfig eth1 | grep "inet addr" | cut -d ':' -f 2 | cut -d ' ' -f 1)	
# echo "source host ipv4 is: ${HOSTIPv4_N}"

# network number, XX, in which the host is currently situated 
# (depends on which vm script is executed)
XX=$(echo ${HOSTIPv4_N} | cut -d '.' -f 2)
# echo "network number is: ${XX}"

# source host name - those ending with net16...19 
HOSTNAME_N=$(hostname).net${XX}	
# echo "source host name is: ${HOSTNAME_N}"

# source host ipv6 in net16...19
HOSTIPv6_N=$(ip addr show dev eth1 | sed -e's/^.*inet6 \([^ ]*\)\/.*$/\1/;t;d'| head -1)
# echo "source ipv6 is: ${HOSTIPv6_N}"



# function to find ethernet addresses of network connections in admin and net16...19
# if source and destination hosts belong to the same network
# parameters: 	${1} - either admin or ${XX}
FindEthernetAddressIPv4()
{
	# convert host address to ipv4 if not done so already, and 
	# find the network in which the host is situated

	# get the network number, 16...19 or 168	
	INFIX=$(cat pingOUTPUT | grep "PING" | cut -d ' '  -f 3 | egrep -o '[^()]+' | cut -d '.' -f 2)
	# echo "The destination host is situated in network: ${INFIX}"


	# get the host id or ip
	HOST=$(cat pingOUTPUT | grep "PING" | cut -d ' '  -f 2)
	# echo "The destination host id or ip is: ${HOST}"	
	# echo "The source host is situated in network: ${2}"

	if [ ${INFIX} = ${1} ] ; then
		echo "The ethernet address of host ${HOST} is $(arp -a | grep "${HOST}" | cut -d ' ' -f 4)"
	fi
}



FindEthernetAddressIPv6()
{
	# convert host address to ipv4 if not done so already, and 
	# Find ethernet address	
	DADDR=$(echo ${1} | cut -d ':' -f 1,2,3,4)
	echo "destination host IPv6 prefix is: ${DADDR}"

	SADDR=$(echo ${HOSTIPv6_N} | cut -d ':' -f 1,2,3,4)
	echo "source host IPv6 prefix is ${SADDR}"


	if [ "${DADDR}" = "${SADDR}" ] ; then	# if prefixes are the same
		echo "The ethernet address of ${1} is $(arp -a | grep "${1}" | cut -d ' ' -f 4)"
	fi
}




# function to test whether destination host is reachable using ping
# 	and prints relevant statements to indicate reachability
# parameters: 	${1} - destination host name or ipv4
#				${2} - source host name or ipv4
#				${3} - ethernet device, i.e. eth0 or eth1
#				${4} - either admin or ${XX}
TestConnectionToHost()
{
	ping ${1} -c ${REPEAT} -R -I ${3} > pingOUTPUT	# redirect ping output to pingOUTPUT file
	# cat pingOUTPUT    

	if [ ${?} -eq 0 ] ; then	# if reachable, i.e. returns 0
        echo -e "Host ${1} is REACHABLE from host ${2}\n"
		echo -e "The routing path is:\n"
		cat pingOUTPUT | cut -s -f 2	# routing path
		echo -e "\n"
		FindEthernetAddressIPv4 ${4}
		echo -e "------------------------------------------------------------\n\n"

	else
        echo -e "Host ${1} is NOT REACHABLE from host ${2}\n"
		echo -e "------------------------------------------------------------\n"
	fi
}


# Function to scan reachability, using host name as destinations
ScanHostName()
{
	echo "############################################################"
	echo "Running in hostname mode"
	echo -e "############################################################\n"

	# iterate vm names in list
	lastIndex=$((${#DESTINATION[*]}-1))	# last index number in DESTINATION
	for i in $(seq 0 ${lastIndex} ); do	# hosts in admin
		TestConnectionToHost ${DESTINATION[${i}]} ${HOSTNAME_A} eth0 admin
		TestConnectionToHost ${DESTINATION[${i}]} ${HOSTNAME_N} eth1 ${XX}

		for j in $(seq 16 19); do	# networks 16, 17, 18, 19
			DHOSTNAME=${DESTINATION[${i}]}.net${j}
			# echo ${DHOSTNAME}
			TestConnectionToHost ${DHOSTNAME} ${HOSTNAME_A}	eth0 admin
			TestConnectionToHost ${DHOSTNAME} ${HOSTNAME_N}	eth1 ${XX}
		done
	done
	echo -e "############################################################\n"
}
	
	
	
# Function to scan reachability, using IPv4 addresses as destinations
ScanIPv4()
{
	echo "############################################################"
	echo "Running in IPv4 mode"
	echo -e "############################################################\n"
	
	# ping hosts in admin
	for i in $(seq 1 20); do	# if efficiency not required set seq range to [1,254] instead
		DHOSTIPv4=192.168.0.${i}
		# echo ${DHOSTIPv4}
		TestConnectionToHost ${DHOSTIPv4} ${HOSTIPv4_A}	eth0 admin
		TestConnectionToHost ${DHOSTIPv4} ${HOSTIPv4_N}	eth1 ${XX}
	done
	
	# ping hosts in net16, net17, net18, net19
	for i in $(seq 16 19); do
		for j in $(seq 1 20); do	# if efficiency not required set seq range to [1,254] instead
			DHOSTIPv4=172.${i}.1.${j}
			# echo ${DHOSTIPv4}
			TestConnectionToHost ${DHOSTIPv4} ${HOSTIPv4_A} eth0 admin
			TestConnectionToHost ${DHOSTIPv4} ${HOSTIPv4_N}	eth1 ${XX}
		done
	done
	echo -e "############################################################\n"
}
	

	
# Function to scan reachability of one address, using an IPv6 address as destination
ScanIPv6()
{
	echo "############################################################"
	echo "Running in IPv6 mode"
	echo -e "############################################################\n"
	ping6 ${1} -c ${REPEAT} -I eth1 > ping6OUTPUT	# redirect ping output to pingOUTPUT file

	if [ ${?} -eq 0 ] ; then	# if reachable, i.e. returns 0
		echo -e "Host ${1} is REACHABLE from host ${HOSTIPv6_N}\n"

	else
		echo -e "Host ${1} is NOT REACHABLE from host ${HOSTIPv6_N}\n"

	fi


	FindEthernetAddressIPv6 ${1}

	
	echo -e "############################################################\n"
}



# run scans
#FindEthernetAddressIPv4 ${XX}
#TestConnectionToHost december.net18 ${HOSTNAME_N} eth1 ${XX}
ScanHostName
ScanIPv4
ScanIPv6 fdd0:8184:d967:118:250:56ff:fe85:d1d8	# ping may.net18