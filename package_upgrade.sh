#!/bin/bash
rm -f ./upgrade.zip
mkdir upgrade
rsync -av . ./upgrade/ --exclude upgrade --exclude .git --exclude storage --exclude logs
rm -f ./upgrade/*.zip
cd ./upgrade
zip -r ../upgrade.zip ./*
cd ..
rm -r -f ./upgrade