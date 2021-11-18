#!/bin/bash


caption_image_endpoint="https://api.imgflip.com/caption_image"
get_memes_endpoint="https://api.imgflip.com/get_memes"


function usage() { 
    echo "Usage: " 1>&2
    echo "create meme: $0 <template> <top text> <bottom text>" 1>&2
    echo "search memes: $0 <template search query>" 1>&2 
    echo "list all memes: $0" 1>&2 
    exit 1 
}

function getTemplateNum() {
    # get template number for meme given name of meme
    local templateName="$1"
    templateId=$(curl -s "$get_memes_endpoint" \
        | jq -r --arg templateName "$templateName"  '.data.memes[] | select( (.name | ascii_downcase ) | contains($templateName | ascii_downcase)) | .id' )
}
# need facility to prompt 'did you mean' ... if no memes by case-insensitive match 

function createMeme() {
    
    local templateId="$1" 
    if [ -z $templateId ]; then 
        echo "Empty meme" 1>&2
        exit 1
    fi
    local text_0="$2"
    local text_1="$3"
    local username="$IMGFLIP_USERNAME"
    local password="$IMGFLIP_PASSWORD"

    # urlencode the vars
    templateId=$(printf %s "$templateId" | jq -sRr @uri)
    text_0=$(printf %s "$text_0" | jq -sRr @uri)
    text_1=$(printf %s "$text_1"| jq -sRr @uri)
    username=$(printf %s "$username" | jq -sRr @uri)
    password=$(printf %s "$password" | jq -sRr @uri)

    local urlencoded="$caption_image_endpoint?template_id=$templateId&username=$username&password=$password&text0=$text_0&text1=$text_1" 
    
    curl -s "$urlencoded"  \
        --header 'Content-Type: application/json' -X POST  | jq -r '.data.url'
}

function listMemes() { 
        curl -s "$get_memes_endpoint" | jq -r '.data.memes[].name'
}

function searchMemes() { 
    local templateNamePat="$1"
    curl -s "$get_memes_endpoint" | jq -r '.data.memes[].name' | grep -Fi "$templateNamePat"
}

function getUserConfig() {
    configDir="${HOME}/.config/mkmeme/"
    configPath="${HOME}/.config/mkmeme/config"
    if ! [ -f "$configPath" ]; then
        echo no config found! 
        read -p "Enter Imgflip.com username: " IMGFLIP_USERNAME
        read -s -p "Enter Imgflip.com password: " IMGFLIP_PASSWORD
        echo ""
        read -p "Save credentials in ${configPath}?" desiredSaveConfig
        if [ ${desiredSaveConfig:0:1} == "Y" ] || [ ${desiredSaveConfig:0:1} == "y" ]; then
            mkdir -p "$configDir"
            echo "IMGFLIP_USERNAME=\"$IMGFLIP_USERNAME\"" >> "$configPath"
            echo "IMGFLIP_PASSWORD=\"$IMGFLIP_PASSWORD\"" >> "$configPath" 
            chmod go-rw "$configPath"
        fi
    else
        source "${HOME}/.config/mkmeme/config"
    fi
}

if [ $# -gt 0 ]; then
    if [ "$1" == '--help' ] || [ "$1" == '-h' ]; then
        usage
    fi
fi

type jq >/dev/null 2>/dev/null
jqFound=$?
type curl >/dev/null 2>/dev/null
curlFound=$?


if [ $curlFound == 1 ] || [ $jqFound == 1 ]; then
    echo "Please install jq and curl to use this" 1>&2
    echo "e.g. 'apt install jq curl'" 1>&2
    exit 1
fi


if [ $# -lt 3 ]; then
    if [ $# -eq 0 ]; then
        listMemes 
    elif [ $# -eq 1 ]; then
        templateName="$1"
        searchMemes "$templateName"
    else 
        usage
    fi
else
    getUserConfig
    templateId=0
    templateName="$1"
    topText="$2"
    bottomText="$3"

    getTemplateNum "$templateName"
    if [ -z $templateId ]; then
        echo "Meme not found!" 1>&2
        exit 1
    fi
    createMeme "$templateId" "$topText" "$bottomText"
fi
