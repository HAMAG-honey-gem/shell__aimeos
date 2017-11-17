#!/bin/bash

echo "====================="
echo "======= PREREQUISITES"
echo "The version number of the aimeos release to set up and optionally a relative path to the .zip given as parameter to this script."

# Definitions:
# cwd := current working directory
# rel := relative
# dir := directory

step_file=/tmp/aimeos_update_step
step='create'
if [ -f $step_file ]; then
	step=$(cat $step_file)
fi

function delay {
IFS=''
action='Continuing'
if [ ! -z $1 ]; then
	action=$1
fi
echo -e "Press [ENTER] to continue or [ESC] to abort"
echo ""
for (( i=10; i>0; i--)); do

	echo -en "\e[1A";  # amend line 1 before
	echo -e "\e[0K\r$action in $i seconds..."
	read -s -N 1 -t 1 key

	if [ "$key" = $'\e' ]; then
		echo -e "\nAborting"
		exit 0
	elif [ "$key" == $'\x0a' ] ;then
		echo -e "\nContinuing"
		break
	fi
done
}


echo ""
echo "====================="
echo "======= INPUT"
echo "Processing input ..."
destination_prefix='/var/www/aimeos_'
version='17.7.2'
link_instead_of_copy=1  # return code >0 := false; code = 0 := true

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
			echo "e.g. update.sh --version=17.7.2 --prefix=/var/www/aimeos_ --copy"
			exit 0  # This is not an error, User asked for help. Don't "exit 1".
			;;

		--copy)
			printf >&2 'Copying symbolically instead of linking the files.'
			link_instead_of_copy=0  # return code = 0 := true
			shift
			;;

		--prefix=*)
			destination_prefix=${1#*=}
			shift 1
			;;

		--step=*)
			step=${1#*=}
			if [ -z $step ]; then
				echo 'Step parameter given but not defined (--step=)'
				exit 1
			fi
			shift 1
			;;
		--step)
			shift 1
			echo '--step parameter given but not defined (--step=)'
			exit 1
			;;

		--version=*)
			version=${1#*=}
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
			remaining_input=$1
			break
			;;

	esac
done


destination=$destination_prefix$version




case $step in


	create)
echo ""
echo "====================="
echo "======= CREATE"
echo 'Creating '$destination

#shop t -s dotglob  # Include hidden items http://stackoverflow.com/questions/33226264/string-concatenation-without-spaces-in-bash
#wget https://typo3.org/extensions/repository/download/aimeos/17.7.0/zip/
#rm index.html.1
mkdir /tmp/ai; cd /tmp/ai; unzip '/tmp/aimeos_'$version'.zip'
mv -i /tmp/ai $destination
cd $destination
git init
git add *
git commit -m "."
git status
git branch master_ HEAD
git remote add unix__aimeos-core ../aimeos-core
git remote add unix__aimeos-typo3 ../aimeos-typo3
git remote add unix__ai-client-html ../ai-client-html
delay
	;&


	backup)
echo ""
echo "====================="
echo "======= BACKUP"
echo 'Creating database backup'
echo 'backup' > $step_file
# TODO generalize
sql_filename='hamag0__aimeos_'$version'__2017_07_31__https.sql'
mysqldump -u root  -p -hlocalhost --compatible=ansi --skip-extended-insert hamag0 > $sql_filename
mv -i $sql_filename /var/www/hamag/
delay
	;&


	activate)
echo ""
echo "====================="
echo "======= ACTIVATE"
echo "Linking destination as active"
echo 'activate' > $step_file
cd /var/www
cd hamag
cd typo3conf/ext/
ls -l | grep aimeos
rm aimeos; ln -si ../../../aimeos_$version ./aimeos
ls -l | grep aimeos


delay
echo 'modify' > $step_file
	;&
	modify)
echo ""
echo "====================="
echo "======= MODIFY"
echo "Modifying destination "$destination
git checkout master

delay
mod_id=aimeos-core
echo 'modify__'$mod_id > $step_file
	;&
	modify__aimeos-core)
mod_id=aimeos-core
echo "Modifying destination "$destination" using "$mod_id
cd /var/www
cd $mod_id
git branch -avv
delay "log $mod_id"
git log --oneline --graph --all --decorate
cd $destination
delay "fetch $mod_id"
git fetch unix__$mod_id
delay "log $mod_id functionality"
git log unix__aimeos-core/functionality --oneline --graph --all --decorate
delay "rebase $mod_id functionality"
git rebase --onto HEAD unix__aimeos-core/master unix__aimeos-core/functionality
git tag -d unix__aimeos-core__functionality; git tag unix__aimeos-core__functionality
git checkout master_ && git merge unix__aimeos-core__functionality


delay
mod_id=aimeos-typo3
echo 'modify__'$mod_id > $step_file
	;&
	modify__aimeos-typo3)
mod_id=aimeos-typo3
echo "Modifying destination "$destination" using "$mod_id
cd /var/www
cd aimeos-typo3/
git branch -avv
delay "log $mod_id"
git log --oneline --graph --all --decorate
cd $destination
delay "fetch $mod_id"
git fetch unix__aimeos-typo3
delay "rebase $mod_id"
git rebase --onto HEAD unix__aimeos-typo3/master unix__aimeos-typo3/style
delay "log $mod_id"
git tag -d unix__aimeos-typo3__style; git tag unix__aimeos-typo3__style
git checkout master_ && git merge unix__aimeos-typo3__style
git log --oneline --graph --all --decorate


delay
mod_id=ai-client-html
echo 'modify__'$mod_id > $step_file
	;&
	modify__ai-client-html)
mod_id=ai-client-html
echo "Modifying destination "$destination" using "$mod_id
cd /var/www
cd ai-client-html/
git branch -avv
delay "log $mod_id"
git log --oneline --graph --all --decorate
cd $destination
delay "fetch $mod_id"
git fetch unix__ai-client-html
delay "rebase $mod_id hamag"

git rebase --onto HEAD unix__ai-client-html/master unix__ai-client-html/hamag
#vim Resources/Private/Extensions/ai-client-html/client/html/src/Client/Html/Checkout/Standard/Process/Account/Standard.php
#git rebase --skip
git tag -d unix__ai-client-html__hamag; git tag unix__ai-client-html__hamag
git checkout master_ && git merge unix__ai-client-html__hamag
delay

echo 'modify__'$mod_id'__translation' > $step_file
	;&
	'modify__ai-client-html__translation')
mod_id=ai-client-html
echo "Modifying destination "$destination" using "$mod_id" branch translation"
cd $destination
delay "fetch $mod_id"
git fetch unix__ai-client-html
delay "rebase $mod_id translation"
#cd /var/www
#cd ai-client-html/
#git rebase --onto HEAD hamag-honey-gem/hamag translation
#git push hamag-honey-gem translation
#git log --oneline --graph --all --decorate
git rebase --onto HEAD unix__ai-client-html/master unix__ai-client-html/translation
git tag -d unix__ai-client-html__translation; git tag unix__ai-client-html__translation
git checkout master_ && git merge unix__ai-client-html__translation
msgfmt Resources/Private/Extensions/ai-client-html/client/i18n/code/de.po --output-file Resources/Private/Extensions/ai-client-html/client/i18n/code/de  # NOT TO FORGET: clear the frontend cache in TYPO3 backend
msgfmt Resources/Private/Extensions/ai-client-html/client/i18n/de.po --output-file Resources/Private/Extensions/ai-client-html/client/i18n/de  # NOT TO FORGET: clear the frontend cache in TYPO3 backend
msgfmt Resources/Private/Extensions/ai-client-html/client/i18n/en.po --output-file Resources/Private/Extensions/ai-client-html/client/i18n/en  # NOT TO FORGET: clear the frontend cache in TYPO3 backend
msgfmt Resources/Private/Extensions/ai-client-html/client/i18n/code/en.po --output-file Resources/Private/Extensions/ai-client-html/client/i18n/code/en  # NOT TO FORGET: clear the frontend cache in TYPO3 backend
git status
delay


echo 'correct_locations' > $step_file
	;&
	correct_locations)
echo ""
echo "====================="
echo "======= CORRECT MISPLACED FILES"
echo "Move|link files to correct locations"
echo "Modifying destination "$destination" using "$mod_id" files directly (linking)"
#vim Resources/Public/Themes/elegance/common.css
#git log -- Resources/Private/Extensions/ai-client-html/client/html/themes/elegance/aimeos.js
#git log -- Resources/Private/Extensions/ai-client-html/client/html/themes/aimeos.js
cd Resources/Public/Themes/elegance/
echo "correcting common.css"
ln -si ../../../Private/Extensions/ai-client-html/client/html/themes/elegance/common.css ./
echo "correcting hamag.css"
ln -si ../../../../../aimeos-typo3/Resources/Public/Themes/elegance/hamag.css ./
echo "correcting aimeos.js"
ln -si ../../Private/Extensions/ai-client-html/client/html/themes/aimeos.js ../

cd $destination

esac

rm $step_file


