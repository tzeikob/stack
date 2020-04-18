#!/bin/bash
# A bash script to install java

log "Installing open JDK 8."

sudo apt install openjdk-8-jdk openjdk-8-doc openjdk-8-source

java -version

log "Open JDK 8 has been installed successfully."

log "Installing open JDK 11 (LTS)."

sudo apt install openjdk-11-jdk openjdk-11-doc openjdk-11-source

java -version

log "Open JDK 11 (LTS) has been installed successfully."

log "Configuring update alternatives."

sudo update-alternatives --config java

log "Installing the maven."

sudo apt install maven

mvn -version

info "Java has been installed successfully."
