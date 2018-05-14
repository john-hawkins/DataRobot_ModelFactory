DataRobot Model Factory with API Container
========================================================

The goal of this project is to demonstrate a Model Factory process
that allows you to build and deploy large numbers of models in an
automated fashion. Including a demonstration of how you could deploy
an intermediate API container that forwards data for scoring to the
appropriate model.

### Assumptions

This project assumes you have a valid DataRobot account and that you
have set up your account credentials in the drconfig.yaml file so that
you can use the API.
 
We assume that you have R installed with the DataRobot package.

We assume you have docker installed.

We assume that your data consists of many subsets for which you want
a model built. That each subset will have the same target column, and
that there is a single column which will tell the factory how you want
the data broken up for modelling.

It also currently assumes that you want to run the full autopilot and 
choose the model at the top of the leaderboard.



### What you get

The model factory code will store the details of each project and model
ID in a config file that will be used by the intermediate API.

You can then use the dockerfile to build a container that runs a python
API to accept scoring requests, and forward them to the appropriate 
DataRobot model (based on the KEY).


### How to use it

The [EXAMPLE.R](EXAMPLE.R) script shows you how to run just the model factory component. 

This will build all the models for each KEY in the data and store the results.

To do a complete run including setting up the required config and building the docker
image, you can use the [RUN.sh](RUN.sh) script and pass in the following parameters:

* The training data 
* The key column
* The target column
* A directory name for your output (will be created)
* Your DataRobot credendtials: USERNAME, API_TOKEN, and API_KEY
* The metric you want to see reported (e.g. AUC for binary classification, MAPE or MAE for regression) 

This script will do the following:

* Create the app directory
* Copy the dockerfile and python code inside
* Create the required config files
* Execute the model factory on your dataset 
  - Write the results to a model config file in your app
* Execute the docker script to build your container
* Deploy the container

You can then test the container and modify it as needed.

View the running container [127.0.0.1:5000](http://127.0.0.1:5000)

Note: Currently it uses a flask server which is not recommended for production. 
You will need to wok with a production team to determine the ideal webserver for
deploying the intermediate API.


