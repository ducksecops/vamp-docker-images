#!/usr/bin/env bash

dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

reset=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)

target='target/docker'
if [[ $( git describe --tags --abbrev=0 ) = $( git describe --tags ) ]] ; then
  vamp_version="$( git describe --tags )"
else
  if [[ "$VAMP_GIT_BRANCH" != "" && "$VAMP_GIT_BRANCH" != "master" ]]; then
    vamp_version=${VAMP_GIT_BRANCH//\//_}
  else
    vamp_version="katana"
  fi
fi

function parse_command_line() {
    flag_help=0
    flag_list=0
    flag_clean=0
    flag_make=0
    flag_build=0

    for key in "$@"
    do
    case ${key} in
        -h|--help)
        flag_help=1
        ;;
        -l|--list)
        flag_list=1
        ;;
        -c|--clean)
        flag_clean=1
        ;;
        -m|--make)
        flag_make=1
        ;;
        -b|--build)
        flag_make=1
        flag_build=1
        ;;
        -v=*|--version=*)
        vamp_version="${key#*=}"
        shift
        ;;
        -i=*|--image=*)
        target_image="${key#*=}"
        length=${#target_image}
        ((length--))
        if [ "${target_image:$length:1}" == "/" ]; then
            target_image="${target_image%?}"
        fi
        shift
        ;;
        *)
        ;;
    esac
    done
}

function print_help() {
    echo "${green}Usage of $0:${reset}"
    echo "${yellow}  -h  |--help       ${green}Help.${reset}"
    echo "${yellow}  -l  |--list       ${green}List all available and built images.${reset}"
    echo "${yellow}  -c  |--clean      ${green}Remove all available images.${reset}"
    echo "${yellow}  -m  |--make       ${green}Copy all available Docker files to '${target}' directory.${reset}"
    echo "${yellow}  -b  |--build      ${green}Build all available images.${reset}"
    echo "${yellow}  -v=*|--version=*  ${green}Specifying Vamp version, e.g. -v=${vamp_version}${reset}"
    echo "${yellow}  -i=*|--image=*    ${green}Specifying single image to be processed, e.g. -i=marathon${reset}"
}

function docker_rmi {
    echo "${green}removing docker image: $1 ${reset}"
    docker rmi -f $1 2> /dev/null
}

function docker_make {
    rm -rf "${dir}"/${target}/$1
    mkdir -p "${dir}"/${target}/$1
    if [ -x "${dir}"/$1/make.sh ]
    then
        echo "${green}executing make.sh from $1 ${reset}"
        "${dir}"/$1/make.sh "${dir}"/${target}/$1
        exit_code=$?
        if [ ${exit_code} != 0 ]; then
            echo "${red}make.sh failed with code: ${exit_code}${reset}"
            exit ${exit_code}
        fi
    elif [ -e "${dir}"/$1/Makefile ]
    then
        echo "${green}executing make in $1 directory ${reset}"
        ${MAKE:-make} -C "${dir}"/$1
        exit_code=$?
        if [ ${exit_code} != 0 ]; then
            echo "${red}make failed with code: ${exit_code}${reset}"
            exit ${exit_code}
        fi
        # only alpine-jdk is build with a Makefile and the build is fully contained
        flag_build=0
    else
        echo "${green}copying files from: $1 ${reset}"
        cp -R "${dir}"/$1 "${dir}"/${target} 2> /dev/null
        rm -f "${dir}"/${target}/$1/version 2> /dev/null
    fi

    # Change all instances of "katana" to a release, if we're on a tag
    if [[ $vamp_version != "katana" && -d "${dir}"/${target}/${1} ]] ; then
      # Whitelist of files to look for
      local whitelist
      local target_file
      whitelist="application.conf vga.js recipes.yml supervisord.conf vamp-workflow-javascript.yml"

      for X in $whitelist ; do
        # Find path of the file we want to modify
        target_file="$( find "${dir}"/${target}/${1} -type f -name "$X" )"
        [[ -z $target_file ]] && continue

        # Check if we need to modify file
        grep -q katana "$target_file"
        if [[ $? -eq 0 ]] ; then
          echo "${green}changing 'katana' to '$vamp_version' in: $target_file${reset}"

          local tmpfile="${dir}"/${target}/${1}/.build.tmp
          > "$tmpfile"
          sed "s/katana/${vamp_version}/g" "${target_file}" > "$tmpfile"
          mv "$tmpfile" "${target_file}"
          rm -f "$tmpfile"
        fi
      done

    fi

    if [ -e "${dir}"/${target}/$1/Dockerfile ];
    then
        local tmpfile="${dir}"/${target}/${1}/.build.tmp
        > "$tmpfile"
        sed "s/VAMP_VERSION/${vamp_version}/g" "${dir}"/${target}/$1/Dockerfile > "$tmpfile"
        mv "$tmpfile" "${dir}"/${target}/$1/Dockerfile
        rm -f "$tmpfile"
    fi
}

function docker_build {
    echo "${green}building docker image: $1 ${reset}"
    docker build -t $1 "$2"
    retval="$?"
    if [[ $retval -ne 0 ]] ; then
      echo "${red}Error: ${1}: build failed, exiting!${reset}"
      exit $retval
    fi
}

function docker_images {
    arr=$1[@]
    images=("${!arr}")

    echo "${green}available images:${yellow}"
    for image in "${images[@]}"
    do
      echo ${image}
    done

    echo "${green}built images    :${yellow}"
    docker images | grep 'magneticio/vamp' | grep ${vamp_version}
}

function process() {
    regex="^${dir}\/(.+)\/Dockerfile$"
    images=()
    image_names=()

    find_in="${dir}"
    if [ -n "${target_image}" ]; then
        find_in="${dir}"/${target_image}
    fi

    for file in $(find ${find_in} -type f -name Dockerfile)
    do
      [[ ${file} =~ $regex ]] && [[ ${file} != *"/"* ]]
        image_dir="${BASH_REMATCH[1]}"

        if [[ ${image_dir} != *"/"* ]]; then

            target_version=$(cat "${dir}"/${image_dir}/version 2> /dev/null)

            if [ "$target_version" ]; then
                image=magneticio/vamp-${image_dir}-${target_version}
                images+=(${image})
                image_name=${image}:${vamp_version}
            else
                image=magneticio/vamp-${image_dir}
            fi

            if [[ "$image_dir" == vamp* ]]; then
                image=magneticio/vamp
                images+=(${image})
                image_name=${image}:${vamp_version}${image_dir:4}
            else
                images+=(${image})
                image_name=${image}:${vamp_version}
            fi

            image_names+=(${image_name})

            if [ ${flag_make} -eq 1 ]; then
                docker_make ${image_dir}
            fi
            if [ ${flag_clean} -eq 1 ]; then
                docker_rmi ${image_name}
            fi
            if [ ${flag_build} -eq 1 ]; then
                docker_build ${image_name} "${dir}"/${target}/${image_dir}
            fi
        fi
    done

    if [ ${flag_list} -eq 1 ]; then
        docker_images image_names
    fi

    echo "${green}done.${reset}"
}

parse_command_line $@

echo "${green}
██╗   ██╗ █████╗ ███╗   ███╗██████╗     ██████╗  ██████╗  ██████╗██╗  ██╗███████╗██████╗
██║   ██║██╔══██╗████╗ ████║██╔══██╗    ██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗
██║   ██║███████║██╔████╔██║██████╔╝    ██║  ██║██║   ██║██║     █████╔╝ █████╗  ██████╔╝
╚██╗ ██╔╝██╔══██║██║╚██╔╝██║██╔═══╝     ██║  ██║██║   ██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗
 ╚████╔╝ ██║  ██║██║ ╚═╝ ██║██║         ██████╔╝╚██████╔╝╚██████╗██║  ██╗███████╗██║  ██║
  ╚═══╝  ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝         ╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
                                                                     version ${vamp_version}
                                                                     by magnetic.io
${reset}"

if [ ${flag_help} -eq 1 ] || [[ $# -eq 0 ]]; then
    print_help
fi

if [ ${flag_clean} -eq 1 ]; then
    rm -Rf "${dir}"/${target} 2> /dev/null
fi

if [ ${flag_list} -eq 1 ] || [ ${flag_clean} -eq 1 ] || [ ${flag_make} -eq 1 ] || [ ${flag_build} -eq 1 ]; then
    mkdir -p "${dir}"/${target} && process
fi
