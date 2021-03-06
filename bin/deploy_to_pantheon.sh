#!/bin/bash

# Variables
BUILD_DIR=$(pwd)
txtred=$(tput setaf 1) # Red
txtgrn=$(tput setaf 2) # Green
txtylw=$(tput setaf 3) # Yellow
txtblu=$(tput setaf 4) # Blue
txtpur=$(tput setaf 5) # Purple
txtcyn=$(tput setaf 6) # Cyan
txtwht=$(tput setaf 7) # White
txtrst=$(tput sgr0) # Text reset.

COMMIT_MESSAGE="$(git show --name-only --decorate)"

cd $HOME

# If the Pantheon directory does not exist
if [ ! -d "$HOME/pantheon" ]
then
	# Clone the Pantheon repo
	echo -e "\n${txtylw}Cloning Pantheon repository into $HOME/pantheon  ${txtrst}"
	git clone $PANTHEON_GIT_URL pantheon
fi

cd pantheon

git fetch

# Log into terminus.
echo -e "\n${txtylw}Logging into Terminus ${txtrst}"
terminus auth:login --machine-token=$PANTHEON_MACHINE_TOKEN

# Check if we are NOT on the master branch
if [ $CIRCLE_BRANCH != "master" ]
then

	# Branch name can't be more than 11 characters
	# Normalize branch name to adhere with Multidev requirements
	export normalize_branch="$CIRCLE_BRANCH"
	export valid="^[-0-9a-z]" # allows digits 0-9, lower case a-z, and -
	# If the branch name is invalid
  	if [[ $normalize_branch =~ $valid ]]
  	then
		export normalize_branch="${normalize_branch:0:11}"
		# Attempt to normalize it
		export normalize_branch="${normalize_branch//[-_]}"
		echo "Success: "$normalize_branch" is a valid branch name."
  	else
  		# Otherwise exit
		echo "Error: Multidev cannot be created due to invalid branch name: $normalize_branch"
		exit 1
	fi

	# Update the environment variable
	PANTHEON_ENV="${normalize_branch}"

	echo -e "\n${txtylw}Checking for the multidev environment ${normalize_branch} via Terminus ${txtrst}"

	# Get a list of all environments
	PANTHEON_ENVS="$(terminus multidev:list $PANTHEON_SITE_UUID --format=list --field=Name)"
	terminus multidev:list $PANTHEON_SITE_UUID --fields=Name

	MULTIDEV_FOUND=0

	while read -r line; do
    	if [[ "${line}" == "${normalize_branch}" ]]
    	then
    		MULTIDEV_FOUND=1
    	fi
	done <<< "$PANTHEON_ENVS"

	# If the multidev for this branch is found
	if [[ "$MULTIDEV_FOUND" -eq 1 ]]
	then
		# Send a message
		echo -e "\n${txtylw}Multidev found! ${txtrst}"
	else
		# otherwise, create the multidev branch
		echo -e "\n${txtylw}Multidev not found, creating the multidev branch ${normalize_branch} via Terminus ${txtrst}"
		terminus multidev:create $PANTHEON_SITE_UUID.dev $normalize_branch
		git fetch
	fi

	# Checkout the correct branch
	GIT_BRANCHES="git show-ref --verify refs/heads/$normalize_branch"
	if [[ ${GIT_BRANCHES} == *"${normalize_branch}"* ]]
	then
		echo -e "\n${txtylw}Branch ${normalize_branch} found, checking it out ${txtrst}"
    	git checkout $normalize_branch
  	else
  		echo -e "\n${txtylw}Branch ${normalize_branch} not found, creating it ${txtrst}"
		git checkout -b $normalize_branch
  	fi

fi

# Delete the web, vendor and config subdirectories if they exist
if [ -d "$HOME/pantheon/web" ]
then
	# Remove it
	echo -e "\n${txtylw}Removing $HOME/pantheon/web ${txtrst}"
	rm -rf $HOME/pantheon/web
fi
if [ -d "$HOME/pantheon/vendor" ]
then
	# Remove it
	echo -e "\n${txtylw}Removing $HOME/pantheon/vendor ${txtrst}"
	rm -rf $HOME/pantheon/vendor
fi
if [ -d "$HOME/pantheon/config" ]
then
	# Remove it
	echo -e "\n${txtylw}Removing $HOME/pantheon/vendor ${txtrst}"
	rm -rf $HOME/pantheon/vendor
fi

# Create empty directories for web, vendor and config
mkdir -p web
mkdir -p vendor
mkdir -p config

echo -e "\n${txtylw}Rsyncing $BUILD_DIR/web to web ${txtrst}"
rsync -a --recursive $BUILD_DIR/web/ ./web --exclude '.gitignore' --exclude '.git'

echo -e "\n${txtylw}Copying $BUILD_DIR/wp-cli.yml ${txtrst}"
cp $BUILD_DIR/wp-cli.yml .

echo -e "\n${txtylw}Rsyncing $BUILD_DIR/vendor ${txtrst}"
rsync -a --recursive $BUILD_DIR/vendor/ ./vendor

echo -e "\n${txtylw}Rsyncing $BUILD_DIR/config ${txtrst}"
rsync -a --recursive $BUILD_DIR/config ./config

# Some plugins have .svn directories, nuke 'em
echo -e "\n${txtylw}Removing all '.svn' directories${txtrst}"
find . -name '.svn' -type d -exec rm -rf {} \;

# Remove node_modules left by gulp/grunt
echo -e "\n${txtylw}Removing all 'node_modules' directories${txtrst}"
find . -name 'node_modules' -type d -exec rm -rf {} \;

# Remove wp-content/uploads if it exists
# Checking in Pantheon's files symlink is bad new
if [ -d "$HOME/pantheon/web/wp-content/uploads" ]
then
	echo -e "\n${txtylw}Removing 'web/wp-content/uploads' symlink${txtrst}"
	rm web/wp-content/uploads
fi

echo -e "\n${txtylw}Forcibly adding all files and committing${txtrst}"
git add -A --force .
git commit -m "Circle CI build $CIRCLE_BUILD_NUM by $CIRCLE_PROJECT_USERNAME" -m "$COMMIT_MESSAGE"

# Force push to Pantheon
if [[ $CIRCLE_BRANCH != "master" ]]
then
	echo -e "\n${txtgrn}Pushing the ${normalize_branch} branch to Pantheon ${txtrst}"
	git push -u origin $normalize_branch --force
else
	echo -e "\n${txtgrn}Pushing the master branch to Pantheon ${txtrst}"
	git push -u origin master --force
fi
