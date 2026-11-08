#!/system/bin/sh
#
# Checks for total number of files on the persist partition, and ensures that
# each one is bigger than zero bytes, and that it can be read by
# doing a cat on it.

NUM_SFS_FILES=26

required_directories=()
required_directories+=('/persist')
required_directories+=('/persist/data')
required_directories+=('/persist/data/SFS')

required_files=()
required_files+=('/persist/data/hdcpv1.enc')

# function dump()
# dumps the argument to dmesg
dump ()
{
	echo $1 > /dev/kmsg
}

check_directory ()
{
	d=${1:-no.argument.supplied}
	exit_on_fail=${2:-1}
	if [ ! -d ${d} ]
	then
		dump "${d} does not exist"
		if [ "${exit_on_fail}" == "1" ]
		then
			exit 1
		fi
	fi
}

check_file ()
{
	f=${1:-no.argument.supplied}
	exit_on_fail=${2:-1}
	if [ ! -s ${f} ]
	then
		dump "${f} does not exist or have size > 0"
		if [ "${exit_on_fail}" == "1" ]
		then
			exit 1
		fi
	fi
	cat ${f} 2>&1 > /dev/null
	if [ "$?" != "0" ]
	then
		dump "could not cat ${f}"
		if [ "${exit_on_fail}" == "1" ]
		then
			exit 1
		fi
	fi
}

check_files_in_directory ()
{
	d=${1:-no.argument.supplied}
	exit_on_fail=${2:-1}

	f=(${d}/*)
	num_files=${#f[@]}
	if [ $num_files -ne $NUM_SFS_FILES ] ; then
		dump "file count incorrect, required $NUM_SFS_FILES found $num_files"
		if [ "${exit_on_fail}" == "1" ]
		then
			exit 1
		fi
	fi

	for i in ${f[@]}
	do
	check_file ${i} 1
	done
}

for d in "${required_directories[@]}"
do
	check_directory ${d} 1
done

for f in "${required_files[@]}"
do
	check_file ${f} 1
done

check_files_in_directory /persist/data/SFS 1

exit 0
