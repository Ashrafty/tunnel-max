#!/bin/bash
# Script to generate Android release keystore
# Run this script to create a release keystore for signing APKs

echo "Generating Android release keystore..."
echo

echo "Please provide the following information:"
echo

read -s -p "Enter keystore password: " KEYSTORE_PASSWORD
echo
read -p "Enter key alias (default: tunnelmax): " KEY_ALIAS
KEY_ALIAS=${KEY_ALIAS:-tunnelmax}
read -s -p "Enter key password: " KEY_PASSWORD
echo
read -p "Enter your name or organization: " DNAME_CN
read -p "Enter organizational unit (optional): " DNAME_OU
read -p "Enter organization (optional): " DNAME_O
read -p "Enter city/locality (optional): " DNAME_L
read -p "Enter state/province (optional): " DNAME_ST
read -p "Enter country code (2 letters, optional): " DNAME_C

# Build the distinguished name
DNAME="CN=$DNAME_CN"
[ ! -z "$DNAME_OU" ] && DNAME="$DNAME, OU=$DNAME_OU"
[ ! -z "$DNAME_O" ] && DNAME="$DNAME, O=$DNAME_O"
[ ! -z "$DNAME_L" ] && DNAME="$DNAME, L=$DNAME_L"
[ ! -z "$DNAME_ST" ] && DNAME="$DNAME, ST=$DNAME_ST"
[ ! -z "$DNAME_C" ] && DNAME="$DNAME, C=$DNAME_C"

echo
echo "Generating keystore with the following details:"
echo "Keystore: release.keystore"
echo "Key Alias: $KEY_ALIAS"
echo "Distinguished Name: $DNAME"
echo

keytool -genkey -v -keystore release.keystore -alias "$KEY_ALIAS" -keyalg RSA -keysize 2048 -validity 10000 -storepass "$KEYSTORE_PASSWORD" -keypass "$KEY_PASSWORD" -dname "$DNAME"

if [ $? -eq 0 ]; then
    echo
    echo "Keystore generated successfully!"
    echo
    echo "To use this keystore for release builds, set the following environment variables:"
    echo "export ANDROID_KEYSTORE_PATH=$(pwd)/release.keystore"
    echo "export ANDROID_KEYSTORE_PASSWORD=$KEYSTORE_PASSWORD"
    echo "export ANDROID_KEY_ALIAS=$KEY_ALIAS"
    echo "export ANDROID_KEY_PASSWORD=$KEY_PASSWORD"
    echo
    echo "Or add them to your gradle.properties file:"
    echo "ANDROID_KEYSTORE_PATH=$(pwd)/release.keystore"
    echo "ANDROID_KEYSTORE_PASSWORD=$KEYSTORE_PASSWORD"
    echo "ANDROID_KEY_ALIAS=$KEY_ALIAS"
    echo "ANDROID_KEY_PASSWORD=$KEY_PASSWORD"
else
    echo
    echo "Failed to generate keystore. Please check that Java keytool is installed and in your PATH."
fi