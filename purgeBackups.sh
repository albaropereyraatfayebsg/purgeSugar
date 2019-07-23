#! /bin/sh -

if [ "X-h" = "X$1" ];
then
  printf "\
This script removes backup files on the demo server.\n\
To get a list of backups for an instace you can pass the name of the directory\n\
%s sugaranidemo\n\
" \
"$(basename -az $0)";
  exit 0;
fi

httpdRootDir="/var/www/html/";
escapedHttpdRootDir=$(printf "%s" "$httpdRootDir" | sed 's/\//\\\//g');

if [ -z "$1" ];
then
  # Prompt for instance interested in
  printf "Enter the name of the diretory you would like to remove archives from : ";
  read dir;
else 
  dir="${1}";
fi

# find archives
sitePath=$(sudo find ${httpdRootDir} -maxdepth 2 -type d -name ${dir} -print)
# Exeption handling
if [ -z "$sitePath" ];
then
  printf "The directory you entered %s does not exist.\n" "$dir";
  exit 1;
fi
httpdDir=${sitePath#$httpdRootDir}
archiveHttpdDir=$(printf "%s" "$httpdDir"| sed 's/\//_/g');
# Notice trailing '/'
escapedSitePath=$(printf "%s/" "$sitePath" | sed 's/\//\\\//g');

# Skip none sugar dirs
if [ -f "$sitePath/sugar_version.json" ];
then
  sugarPath="$sitePath"
elif [ -f "$sitePath/crm/sugar_version.json" ];
  then
   sugarPath="$sitePath/crm"
else
  printf "This is not a Sugar directory"
fi
    
# Get config_overide.php file path
config_override_file_path=$(sudo find "${sugarPath}" -maxdepth 1 -type f -name 'config_override.php');

if [ "$config_override_file_path" ]; then
  include_config_override="include '${config_override_file_path}';";
fi

# Sugar edition
sugarFlavor=$(jq '.sugar_flavor' "${sugarPath}/sugar_version.json" | sed 's/"//g');
sudo find "$sitePath" -maxdepth 3 -type f -name "${archiveHttpdDir}_????-???-??\.tar\.gz" -print | sed "s/$escapedSitePath//g";
sudo find "$sitePath" -maxdepth 3 -type f -name "${archiveHttpdDir}_*${sugarFlavor}_????-???-??T??????\.tar\.gz" -print | sed "s/$escapedSitePath//g";

# DB Name
sugar_config_string="\$sugar_config['dbconfig']['db_name']";
dbName=$(sudo php -r "require '${sugarPath}/config.php';${include_config_override}if(isset(${sugar_config_string})){print_r(${sugar_config_string});}");
sudo find "$sitePath" -maxdepth 3 -type f -name "${dbName}_data_dump\.????-???-??\.sql" -print | sed "s/$escapedSitePath//g";
sudo find "$sitePath" -maxdepth 3 -type f -name "${dbName}_*${sugarFlavor}_data_dump\.????-???-??T??????\.sql" -print | sed "s/$escapedSitePath//g";

printf "Enter the name of the files you would like to delete or * for all(sugarani80_data_dump.2019-May-10.sql): ";
read purgeFile;

if [ "$purgeFile" ]; 
then
  if [ -z "${purgeFile##*\.sql}" ] || [ -z "${purgeFile##*\.tar\.gz}" ];
  then
    sudo find "$sitePath" -maxdepth 3 -type f -name "$purgeFile" -exec rm -i {} \;
  elif [ "X$purgeFile" = "X*" ]
  then
    sudo find "$sitePath" -maxdepth 3 -type f -name "${archiveHttpdDir}_????-???-??\.tar\.gz" -exec rm -i {} \;
    sudo find "$sitePath" -maxdepth 3 -type f -name "${archiveHttpdDir}_*${sugarFlavor}_????-???-??T??????\.tar\.gz" -exec rm -i {} \;
    sudo find "$sitePath" -maxdepth 3 -type f -name "${dbName}_data_dump\.????-???-??\.sql" -exec rm -i {} \;
    sudo find "$sitePath" -maxdepth 3 -type f -name "${dbName}_*${sugarFlavor}_data_dump\.????-???-??T??????\.sql" -exec rm -i {} \;
    
  else
    printf "This script only removes files that end in .tar.gz or .sql"
  fi
fi
