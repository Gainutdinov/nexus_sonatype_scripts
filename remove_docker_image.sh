#!/bin/bash 
cat << EOF
Usage: ./remove_docker_image.sh 'username' 'password' 'repo_name' 'image_name_to_delete'
for example:
       ./remove_docker_image.sh 'username' 'password' 'Docker-Repo' 'basic-image' 
OR for wildcard search
       ./remove_docker_image.sh 'username' 'yourpassword' 'Docker-Repo' '*imagename-*'
OR for wildcard search
       ./remove_docker_image.sh 'username' 'yourpassword' 'Docker-Repo' '*anotherImage*' 

EOF

USERNAME=$1
PASSWORD="$2"
REPONAME=$3
IMAGENAME=$4
INTERACTIVE=""
IMAGELIST=()
DIGESTLIST=()
TAGLIST=()

#CHECK NUMBER OF ARGUMENTS AND EXIT IF NOT ENOUGH ARGUMENTS
if [ "$#" -ne 4 ]; then
    echo "Not enough arguments or too many arguments look for examples "
    exit
fi

#GET AVAILABLE DOCKER REPOS
echo 'Available docker repos:'
curl --silent -u "${USERNAME}:${PASSWORD}" -X GET 'http://localhost:8081/service/rest/v1/repositories' | jq '.[] | select(.format == "docker") | "Repo name: " + .name + "; Url: " + .url'


#LIST FOUND IMAGES FOR POTENTIAL DELETION
echo 'IMAGE NAME --- TAG --- IMAGE DIGEST'
content=`curl --silent -u "${USERNAME}:${PASSWORD}" -X GET "https://yournexussite.com/service/rest/v1/search?docker.imageName=${IMAGENAME}&sort=name&repository=${REPONAME}&format=docker" -H  "accept: application/json" `
echo $content | jq '.items[] |  .name + " --- " + .version + " --- sha256:" + .assets[].checksum.sha256'

IMAGELIST=`echo $content | jq '.items[].name '`
IMAGELIST=($IMAGELIST)
DIGESTLIST=`echo $content | jq '.items[].assets[].checksum.sha256 '`
DIGESTLIST=($DIGESTLIST)
TAGLIST=`echo $content | jq '.items[].version '`
TAGLIST=($TAGLIST)

read -p "Are you want to delete images interactively (onebyone) or delete all list (wholelist)? (onebyone/wholelist)? " INTERACTIVE
echo "You typed ${INTERACTIVE}"

for index in ${!IMAGELIST[*]}; do
#    echo "${IMAGELIST[$index]} ${DIGESTLIST[$index]} ${TAGLIST[$index]}"
    IMAGE_TO_DELETE=`echo "${IMAGELIST[$index]}" | tr -d '"' `
    TAG_TO_DELETE=`echo "${TAGLIST[$index]}" | tr -d '"' `
    DIGEST=`echo "${DIGESTLIST[$index]}" | tr -d '"' `

    echo "Reponame ImageName TagName ImageDigest"
    echo "$REPONAME $IMAGE_TO_DELETE $TAG_TO_DELETE $DIGEST plan to delete"

    if [[ "$INTERACTIVE" == "wholelist"  ]]; then
	echo "delete wholelist of images (non-interactive mode)"
        echo '--------------'
        echo 'Response code:'
        curl -u  "${USERNAME}:${PASSWORD}"  -o /dev/null -s -w "%{http_code}\n"  -H "Accept: application/vnd.docker.distribution.manifest.v2+json" -X DELETE https://yournexussite.com/repository/${REPONAME}/v2/${IMAGE_TO_DELETE}/manifests/sha256:${DIGEST}
    else
        read -p "Are you really want to delete this image (y/n)? " answer
        case ${answer:0:1} in
            y|Y )
                echo 'Yes delete the image'
                echo '--------------'
                echo 'Response code:'
                curl -u  "${USERNAME}:${PASSWORD}"  -o /dev/null -s -w "%{http_code}\n"  -H "Accept: application/vnd.docker.distribution.manifest.v2+json" -X DELETE https://yournexussite.com/repository/${REPONAME}/v2/${IMAGE_TO_DELETE}/manifests/sha256:${DIGEST}
            ;;
            * )
                echo 'No, do not delete the image'
            ;;
        esac
    fi
    sleep 1
    echo "---------------------"
done


