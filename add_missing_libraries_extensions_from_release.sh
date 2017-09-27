#!/bin/bash


echo "====================="
echo "======= PREREQUISITES"
echo "A copy of an aimeos release, extracted and the relative path/directory name given as parameter to this script."
# Figure files that are only in the new aimeos release, id est those that are missing in the version controlled path:

# Definitions:
# cwd := current working directory
# rel := relative
# dir := directory

echo ""
echo "====================="
echo "======= INPUT"
echo "Processing input ..."
release_path_relative='../aimeos__16_3_1'
link_instead_of_copy=1  # return code >0 := false; code = 0 := true
#if [[ -z $RELEASE_PATH_RELATIVE ]]; then
#	release_path_relative=$RELEASE_PATH_RELATIVE
#fi
# Parse the arguments given to this script:
while :
do
	echo $1
	# Note: Space is delimiter! => $1 is first, $2 is first argument.
	case $1 in

		-h | --help | -\?)
			# TODO Create help function to call?
			echo "Usage:"
			echo "<script> [OPTIONS]"
			echo "add_missing_libraries_extensions_from_release.sh ../aimeos__16_3_1"
			exit 0  # This is not an error, User asked for help. Don't "exit 1".
			;;

		--copy)
			printf >&2 'Copying symbolically instead of linking the files.'
			link_instead_of_copy=0  # return code = 0 := true
			shift
			;;

		--)  # End of all options
			break
			;;

		-*)
			printf >&2 'WARN: Unknown option (ignored): %s\n' "$1"
			shift
			;;

		*)
			release_path_relative=$1
			break
			;;

	esac
done

echo 'Completing repository using release: '$release_path_relative

#shop t -s dotglob  # Include hidden items http://stackoverflow.com/questions/33226264/string-concatenation-without-spaces-in-bash

function get_dir_path {
	#echo 'get_dir_path()'
	dir_path='./'  #echo './' # Prevent returning empty string because then a cd might change the cwd to $HOME.
	IFS='/' read -a filepath_parts <<< $*
	filepath_parts_length=${#filepath_parts[*]}  # * and @ equal
	#echo 'filepath_parts_length: '$filepath_parts_length
	filepath_parts_index=0
	filepath_parts_last_index=$filepath_parts_length
	filepath_parts_last_index=`expr $filepath_parts_last_index - 1`
	while [ "$filepath_parts_index" -lt "$filepath_parts_last_index" ]
	do
		dir_path="$dir_path""${filepath_parts[$filepath_parts_index]}/"
		# ${IFS}"
		filepath_parts_index=`expr $filepath_parts_index + 1`
	done
	unset IFS;
	#echo $dir_path | sed -e 's_([[:blank:]]+/)|(/[[:blank:]]+)__g'
	echo $dir_path
}



function get_filename {
	#echo 'get_filename()'
	# space delimited:
	#echo $*
	#IFS=/
	filepath_parts_last=''
	for filepath_part in $($* | tr '/' ' ')  # <- alternative to modifying $IFS
	do
		#echo 'filepath_part: '$filepath_part
		filepath_parts_last=$filepath_part
	done
	echo $filepath_parts_last
	#unset IFS
}



# Link symbolically the missing files:
missing_files=$(
diff . $release_path_relative -q -r | grep 'Only in '${release_path_relative} | grep -v -i '.git' | grep -v -i 'aimeos-core' | sed -e 's/Only in //g' | sed -e 's/[:][ ]/\//g'
)
# #*aimeos}
echo 'missing files: ' $missing_files
working_directory_to_restore=$PWD
#if [ ${#missing_files[*]} -gt > 0 ]
if [ -n "$missing_files" ]  # nonemptystring?
then
	echo "Looping ..."
	for missing_filelink in $missing_files
	do
		echo 'missing_filelink: '$missing_filelink
		echo "====================="
		echo "======= DETERMINING PATHS"
		release_dir_path=`get_dir_path $missing_filelink`
		path_to_target_dir_rel_to_cwd=`echo $release_dir_path | sed -e "s:$release_path_relative/*::g"`
		echo 'Determined path_to_target_dir_rel_to_cwd: '$path_to_target_dir_rel_to_cwd
		filename=`get_filename echo $missing_filelink`
		echo 'Determined filename: '$filename
		#path_to_source_dir_rel_to_cwd=${missing_filelink#/*$}  # Already contained in what find returns as it's executed from the current working directory.

		#for f in reverse(split($missing_filelink, '/'))
		path_to_cwd_rel_to_target_dir=''  # as many parent directory command calls as count of directories, exempli gratia ../../../
		count=0
		IFS='/' read -a filepath_parts <<< $path_to_target_dir_rel_to_cwd
		filepath_parts_length=${#filepath_parts[*]}  # * and @ equal
		#for filepath_part in $missing_filelink
		for ((i=0; i<$filepath_parts_length; ++i))
		do
			filepath_part=${filepath_parts[$i]}
			echo 'filepath_part: '`expr $i + 1`' of '$filepath_parts_length': '$filepath_part
			if [ $filepath_part == "." ]
			then
				echo 'Skipping self reference of directory: .'
				continue
			fi
			path_to_cwd_rel_to_target_dir=$path_to_cwd_rel_to_target_dir'../'
		done
		echo 'Built path_to_cwd_rel_to_target_dir: '$path_to_cwd_rel_to_target_dir

		echo "current working directory: $PWD"
		echo "Ensuring directory path exists: "$path_to_target_dir_rel_to_cwd
		mkdir $path_to_target_dir_rel_to_cwd -p
		echo "Entering directory: "$path_to_target_dir_rel_to_cwd
		cd $path_to_target_dir_rel_to_cwd
		if [ $link_instead_of_copy -gt 0 ]
		then
			echo "====================="
			echo "======= LINK FILE"
			echo 'Linking using: ln -s '$path_to_cwd_rel_to_target_dir""$missing_filelink' .'
			ln -s "$path_to_cwd_rel_to_target_dir""$missing_filelink" '.'
		else
			echo "====================="
			echo "======= COPY FILE"
			echo 'Copying using: cp -r '$path_to_cwd_rel_to_target_dir""$missing_filelink' .'
			cp -r "$path_to_cwd_rel_to_target_dir""$missing_filelink" '.'
		fi

		echo ""
		cd $working_directory_to_restore

		echo ""
	done
else
	echo 'Nothing to do. No missing files detected.'
fi

