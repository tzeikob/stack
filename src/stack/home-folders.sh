#!/bin/bash
# A bash script to rename the default home folders

# Rename home folders
log "Renaming the default home folders to lower case."

mv /home/$USER/Desktop /home/$USER/desktop
mv /home/$USER/Downloads /home/$USER/downloads
mv /home/$USER/Templates /home/$USER/templates
mv /home/$USER/Public /home/$USER/public
mv /home/$USER/Documents /home/$USER/documents
mv /home/$USER/Music /home/$USER/music
mv /home/$USER/Pictures /home/$USER/pictures
mv /home/$USER/Videos /home/$USER/videos

# Update the user dirs file
userdirs="/home/$USER/.config/user-dirs.dirs"

log "Updating the user dirs file $userdirs."

cp $userdirs $userdirs.bak

log "The user dirs file has been backed up to $userdirs.bak."

log "Replacing the contents of the user dirs file."

> $userdirs
echo "XDG_DESKTOP_DIR=\"$HOME/desktop\"" >> $userdirs
echo "XDG_DOWNLOAD_DIR=\"$HOME/downloads\"" >> $userdirs
echo "XDG_TEMPLATES_DIR=\"$HOME/templates\"" >> $userdirs
echo "XDG_PUBLICSHARE_DIR=\"$HOME/public\"" >> $userdirs
echo "XDG_DOCUMENTS_DIR=\"$HOME/documents\"" >> $userdirs
echo "XDG_MUSIC_DIR=\"$HOME/music\"" >> $userdirs
echo "XDG_PICTURES_DIR=\"$HOME/pictures\"" >> $userdirs
echo "XDG_VIDEOS_DIR=\"$HOME/videos\"" >> $userdirs
cat $userdirs

log "User dirs file has been updated successfully."

# Update the nautilus bookmarks file
bookmarks_file="/home/$USER/.config/gtk-3.0/bookmarks"

log "Updating the nautilus bookmarks file $bookmarks_file."

cp $bookmarks_file $bookmarks_file.bak

log "The nautilus bookmarks has been backed up to $bookmarks_file.bak."

> $bookmarks_file
echo "file:///home/"$USER"/downloads Downloads" | tee -a $bookmarks_file
echo "file:///home/"$USER"/documents Documents" | tee -a $bookmarks_file
echo "file:///home/"$USER"/music Music" | tee -a $bookmarks_file
echo "file:///home/"$USER"/pictures Pictures" | tee -a $bookmarks_file
echo "file:///home/"$USER"/videos Videos" | tee -a $bookmarks_file
cat $bookmarks_file

info "The default home folders have been renamed successfully.\n"
