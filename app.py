import pandas as pd
import numpy as np
from io import StringIO
from flask import request
from flask import Flask
import yaml
import json
import requests
import sys

app = Flask(__name__)

apiconf = yaml.safe_load(open('api_config.yml')) 
config = yaml.safe_load(open('model_config.yml')) 
models = pd.read_table('model_list.tsv')
models['key'] = models['key'].astype(str)

# ###########################################################################
# DEFAULT ENDPOINT
# SHOWS SIMPLE HTML PAGE WITH SOME EXAMPLES AND OPTIONS
@app.route("/")
def summary():
    return """<H1>Model Factory - Scoring API</H1>  
    <h3>Endpoints</h3> 
	[<a href='/list'>List Models</a>] <br/>
	[<a href='/config'>Show Config</a>] <br/>
	[<a href='/keyexists/1'>Test if model key '1' is available</a>] <br/>
	[<a href='/keymodel/1'>Show model for key '1'</a>] <br/>
	[<a href='/howto'>How to use</a>] """

# ###########################################################################
# ENDPOINT TO SHOW ALL MODELS BUILT BY THE FACTORY
@app.route("/list", methods=["GET"])
def list_models():
    return "<h1>Model List</h1>" + models.to_html()

# ###########################################################################
# ENDPOINT TO SHOW FACTORY CONFIG
@app.route("/config", methods=["GET"])
def showconfig():
    return "<h1>Factory Config</h1><br/>" + str(config) 

# ###########################################################################
# ENDPOINT TO DISPLAY API HOWTO
@app.route("/howto", methods=["GET"])
def howto():
    return """<h1>Howto</h1>
	<p>This API is an intermediary between your system and the set of models built using the <b>Model Factory</b></p>
	<p>Deploy one or more of these applications in a container behind a reverse proxy to pass data for scoring by the appropriate model.<p>
	<p>Point your system at one of the following API endpoints:</p>
	<pre>
	%spredict_single  # score a single row of data
	%spredict         # score multiple rows of data
	</pre> 
	<p>... and pass your dataset in the <b>data</b> parameter.</p>
	<br/>
	</p>Use the following python example as a guideline:</p>
	<pre>
	# Usage: python example.py <input-file.csv>
	import requests
	import sys
	headers = {'Content-Type': 'text/plain; charset=UTF-8'}
	data = open(sys.argv[1], 'rb').read()
	preds = requests.post('https://API_ENDPOINT/predict',  data=data, headers=headers)
	</pre>
	<p>This example will use the intermediate API to break the data into subsets based on the key column</p> 
	<p>It will then forward each subset to the appropriate DataRobot model, collate the results and return them.</p>
	""" % (request.url_root, request.url_root)

# ###########################################################################
# ENDPOINT TO CHECK IF A MODEL FOR <KEY> EXISTS
@app.route("/keyexists/<key>", methods=["GET"])
def key_exists(key):
    exists = (key in models['key'].unique())
    return "{ key: %s, exists: %s }" % (key, exists)

# ###########################################################################
# ENDPOINT TO CHECK MODEL FOR <KEY>
@app.route("/keymodel/<key>", methods=["GET"])
def key_model(key):
    exists = (key in models['key'].unique() )
    if exists:
        mod = models.loc[models['key'] ==  str(key)]
        return "{ key: %s, projectid: %s, modelid: %s }" % (key, mod.iloc[0]['datarobot_project_id'], mod.iloc[0]['datarobot_model_id'])
    else:
        return "{ key: %s, message: 'no such key'}"  % (key)

def get_model(key):
    exists = (key in models['key'].unique() )
    if exists:
        mod = models.loc[models['key'] ==  str(key)]
    else:
        mod = models.loc[models['key'] ==  'nan']
    return mod

# ###########################################################################
# HELPER FUNTION TO UPDATE THE ROW INDEXES
# ###########################################################################
def correctIndex(df):
    payload = df['payload']
    payload['rowId'] = df['rowId']
    return payload


# ###########################################################################
# ENDPOINT TO SCORE A MULTIPLE ROWS OF DATA
#
@app.route("/predict", methods=["POST"])
def predict():
    thedata = request.data
    df = pd.read_csv( StringIO(thedata.decode()) )
    # USE A ROW INDEX COLUMN FOR WHEN WE REVERT TO THE ORIGINAL ORDER
    df['rowindex'] = list(range(0, len(df)))
    print('DATA TO SCORE. ROWS: %s SHAPE: %s ' % (len(df), df.shape))

    # Create a dataframe to compile the results
    rez =  pd.DataFrame(np.nan, index=[], columns=['rowId', 'payload'])

    keys = df[ config['key_col'] ].unique()
    for key in keys[:]:
        # Get the subset that has that key
        subset = df.loc[df[ config['key_col'] ] == key]
        print("Subset for key [%s] has [%s] rows" % (key, len(subset)))
        mod = get_model(key)
        projectid, modelid = (mod.iloc[0]['datarobot_project_id'], mod.iloc[0]['datarobot_model_id'])
        print("PROJECT: %s MODEL: %s" % (projectid, modelid) )
        s = StringIO()
        subset.to_csv(s)
        send = str.encode(s.getvalue())
        scored = score_data(projectid, modelid, send)
        if scored==0:
            return "{ message: 'Scoring with DR failed on subset for key: %s - model: %s project %s' % (key, modelid, projectid)}"
        else:
            # Extract the correct rowindexes into a vector and build dataframe
            indexes = subset['rowindex']
            temp = pd.DataFrame({'rowId':indexes, 'payload':scored['data']})
            rez = rez.append(temp)
    # Now we have all the results in a single dataframe
    # Sort by the original row index
    sorted = rez.sort_values('rowId')
    # We need to correct the row indexes
    corrected = sorted.apply(lambda row: correctIndex(row), axis=1) 
    result={}
    result['data'] = corrected.tolist()
    return json.dumps(result)


# ###########################################################################
# ENDPOINT TO SCORE A SINGLE ROW OF DATA
# NOTE: THIS ENDPOINT ASSUMES THAT THERE IS ONLY A SINGLE ROW OF DATA
#       IF THERE ARE MULTIPLE ROWS IT WILL SCORE ALL ROWS USING THE MODEL 
#       DERIVED FROM THE KEY IN THE FIRST ROW OF DATA. 
@app.route("/predict_single", methods=["POST"])
def predict_single():
    thedata = request.data
    df = pd.read_csv( StringIO(thedata.decode()) )
    print('DATA TO SCORE. ROWS: %s SHAPE: %s CONTENT: %s' % (len(df), df.shape, df))
    # AT THIS POINT WE ASSUME IT IS A SINGLE ROW
    key = str(df.iloc[0][ config['key_col'] ])
    print("KEY: %s" % key)
    mod = get_model(key)
    print("PROJECT: %s MODEL: %s" % (mod.iloc[0]['datarobot_project_id'], mod.iloc[0]['datarobot_model_id']) )
    projectid, modelid = (mod.iloc[0]['datarobot_project_id'], mod.iloc[0]['datarobot_model_id'])
    results = score_data(projectid, modelid, thedata)
    if results==0:
        return "{ message: 'Scoring with DR failed.'}"
    else:
        return "%s" % results


# ###########################################################################
# HELPER FUNCTION TO SCORE A SET OF DATA USING A SPECIFIED DATAROBOT MODEL
# ###########################################################################
def score_data(projectid, modelid, data):
    API_TOKEN = apiconf['API_TOKEN'] 
    USERNAME = apiconf['USERNAME']
    DR_KEY = apiconf['DR_KEY'] 
    headers = {'Content-Type': 'text/plain; charset=UTF-8', 'datarobot-key': DR_KEY}
    response = requests.post('https://cfds.orm.datarobot.com/predApi/v1.0/%s/%s/predict' % (projectid, modelid),
                                     auth=(USERNAME, API_TOKEN), data=data, headers=headers)

    print("Returned. Status: %s " % response.status_code)
    if response.status_code != 200:
        return 0
    else:
        return response.json()



# ###########################################################################
# ::: NOTE ::::
# RUNNING USING THE DEFAULT FLASK SERVER IS NOT PRODUCTION GRADE 
# YOU WILL WANT TO SET THIS UP USING APACHE OR NGINX FOR PRODUCTION
#
if __name__ == '__main__':
    app.run(debug=True,host='0.0.0.0')
