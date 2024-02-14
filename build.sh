#!/bin/bash

# Initializes build and distribution files.
init () {
  echo -e 'Cleaning up existing build files...'

  # Remove any pre-existing distribution files
  rm -rf .dist
  rm -rf /tmp/stack

  # Create distribution directories
  mkdir -p .dist
  mkdir -p .dist/work
  mkdir -p .dist/out
  mkdir -p /tmp/stack

  echo -e 'Build and distribution files removed'
}

# Copies the archiso custom releng profile.
copy_profile () {
  echo -e 'Copying the custom archiso profile'

  cp -r /usr/share/archiso/configs/releng .dist/archlive

  echo -e 'The releng archiso profile has been copied'
}

# Add all the packages from from the official archlinux
# repository which should be pre-installed in the archiso
# live media.
add_packages () {
  printf '%s\n' \
    'jq' \
    'python-tqdm' >> .dist/archlive/packages.x86_64

  echo -e 'Oficial repo packages have been added to package list'
}

add_aur_packages () {
  echo -e 'Building AUR packages...'

  git clone https://aur.archlinux.org/smenu.git /tmp/stack/smenu
  
  local previous_dir=${PWD}
  cd /tmp/stack/smenu
  makepkg
  cd ${previous_dir}

  echo -e 'The AUR packages have been built'

  echo -e 'Creating the custom local repo...'

  local repo_home=.dist/archlive/local/repo

  mkdir -p "${repo_home}"
  cp /tmp/stack/smenu/smenu-*-x86_64.pkg.tar.zst "${repo_home}"
  repo-add "${repo_home}/custom.db.tar.gz" ${repo_home}/smenu-*-x86_64.pkg.tar.zst

  echo -e 'The custom local repo has been created'

  local pacman_conf=.dist/archlive/pacman.conf

  echo -e '\n[custom]' >> "${pacman_conf}"
  echo -e 'SigLevel = Optional TrustAll' >> "${pacman_conf}"
  echo -e "Server = file:///$(realpath "${repo_home}")" >> "${pacman_conf}"

  echo -e 'Custom local repo added to the pacman configuration'

  printf '%s\n' \
    '# Custom repository packages' \
    'smenu' >> .dist/archlive/packages.x86_64
  
  echo -e 'AUR packages have been added to the package list'
}

copy_installer () {
  echo -e 'Copying the installer files...'

  local installer_home=.dist/archlive/airootfs/opt/stack

  mkdir -p "${installer_home}"

  cp -r ./configs "${installer_home}"
  cp -r ./resources "${installer_home}"
  cp -r ./rules "${installer_home}"
  cp -r ./scripts "${installer_home}"
  cp -r ./services "${installer_home}"
  cp -r ./tools "${installer_home}"

  cp ./install.sh "${installer_home}"

  echo -e 'Installer files have been copied under /airootfs/opt/stack'
}

set_file_permissions () {
  echo -e 'Defining the root fs permissions...'

  local permissions_file=.dist/archlive/profiledef.sh

  sed -i '/file_permissions=(/a ["/opt/stack/tools"]="0:0:755"' "${permissions_file}"
  sed -i '/file_permissions=(/a ["/opt/stack/scripts"]="0:0:755"' "${permissions_file}"
  sed -i '/file_permissions=(/a ["/opt/stack/install.sh"]="0:0:755"' "${permissions_file}"

  echo -e 'Root fs permissions have been defined'
}

make_archiso () {
  echo -e 'Building the archiso file...'

  sudo mkarchiso -v -w .dist/work -o .dist/out .dist/archlive
}

echo -e 'Build process will start in 5 secs...'
sleep 5

init &&
  copy_profile &&
  add_packages &&
  add_aur_packages &&
  copy_installer &&
  set_file_permissions &&
  make_archiso &&
  echo -e 'Build process completed successfully' ||
  echo -e 'Build process has failed'
