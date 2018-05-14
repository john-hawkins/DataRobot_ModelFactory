#!/bin/bash

# ####################################
#   WE NEED EXACTLY 8 PARAMETERS
# ####################################
if [ $# -ne 8 ]; then
    echo $0: "usage: RUN.sh <PROJECTNAME> <DATASET> <KEY_COL> <TARGET_COL> <DR_API_KEY> <DR_USERNAME> <DR_API_TOKEN> <METRIC>"
    exit 1
fi

project=$1
dataset=$2
keycol=$3
targetcol=$4
apikey=$5
username=$6
token=$7
metric=$8

# SET UP THE PROJECT DIRECTORY AND RUN THE MODEL FACTORY
mkdir $project

Rscript --vanilla RunModelFactory.R $dataset $keycol $targetcol $project $project $metric

# NOW COPY IN THE REQUIRED FILES 
cp app.py $project
cp Dockerfile $project

# AND SET UP THE CONFIG 
cd $project
echo "API_TOKEN: $token" > api_config.yml
echo "USERNAME: $username" >> api_config.yml
echo "DR_KEY: $apikey" >> api_config.yml

echo "key_col: $keycol" > model_config.yml
echo "target_col: $targetcol" >> model_config.yml

dockerimage=$(echo "$project" | awk '{print tolower($0)}')

# BUILD THE DOCKER IMAGE
docker build -t $dockerimage .

# RUN IT
docker run -d -p 5000:5000 $dockerimage

