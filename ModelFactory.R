library(datarobot)
library(data.table)

# ####################################################################
# Generate a range of models from the specified data
# df - A dataframe containing all data
# keycol - The column name for splitting the data into subsets
# target - The name of the target column
# projectName - Prefix for project name in datarobot
# resultDir - Path to write the results
# metric - The metric to include in the results file
# mode - (optional) autopilot or quick
# ####################################################################

maxWorkers=20

runModelFactory <- function(df, keycol, target, projectNamePrefix, resultDir, metric, mode='autopilot') {

	
	# WE WRITE OUT THE MODEL RESULTS INTO A TABLE
	if(resultDir=='') {
		resultsFile = 'model_list.tsv'
	} else {
		if(!dir.exists(resultDir)) dir.create(resultDir)
		resultsFile = paste(resultDir, 'model_list.tsv', sep='/')
	}

	# Test the output file before we begin 
	result = tryCatch({
		rez <- file(resultsFile, "w")
		writeLines("key\tMetric\tModelType\tBlueprintID\tdatarobot_project_id\tdatarobot_model_id",con=rez,sep="\n")
		flush(rez)
	}, warning = function(w) {
    		message('Potential problem with writing your results file.')
		message(w)
		return(0)
	}, error = function(e) {
	        message('Problem with your results file. Please check the path')
                message(e)
                return(0)
	}, finally = {
    		# CLEAN UP
	})

	# Force data frame to be a data table
	dt	<- data.table(df)

	# Get the number of unique keys
	keyset 	<- unique(dt[[keycol]])
	maxnum	<- 0

	# iterate over the keyset
	for(key in keyset) { 
		# Subset the data and create the project for this key
		temp.data	<- dt[get(keycol)==key,]
		if( nrow(temp.data)>maxnum) { maxnum <- nrow(temp.data) }
		projName 	<- paste(projectNamePrefix, key, sep='_')
		temp.proj	<- SetupProject( dataSource=temp.data, projectName=projName )
		if( mode=='autopilot') {
			SetTarget(project=temp.proj, target=target)
		} else {
			SetTarget(project=temp.proj, target=target, mode = 'quick')
		}
		UpdateProject(project = temp.proj$projectId, workerCount = maxWorkers, holdoutUnlocked = TRUE)
		WaitForAutopilot(project = temp.proj)

		# Once Autopilot has finished we retrieve the best model ID
		all.models 	<- ListModels(temp.proj)
		model.frame 	<- as.data.frame(all.models)
		# ###############################################
		# INSERT YOUR MODEL SELECTION LOGIC HERE
		# ###############################################
		best.model	<- all.models[[1]]
        	model.type      <- best.model$modelType
        	model.bp        <- best.model$blueprintId
		modelId		<- best.model$modelId
		metric		<- best.model$metrics[[metric]]$holdout		
		writeLines(paste(key, metric, model.type, model.bp, temp.proj$projectId, modelId, sep='\t'), con=rez, sep="\n")		
		flush(rez)
	}

	# NOW BUILD THE NULL MODEL USING A SAMPLE DATASET
	temp.data <- dt[sample(nrow(dt), maxnum), ]

	projName        <- paste(projectNamePrefix, 'NULL', sep='_')
        temp.proj       <- SetupProject( dataSource=temp.data, projectName=projName )
        if( mode=='autopilot') {
                   SetTarget(project=temp.proj, target=target)
        } else {
                   SetTarget(project=temp.proj, target=target, mode = 'quick')
        }
        UpdateProject(project = temp.proj$projectId, workerCount = maxWorkers)
        WaitForAutopilot(project = temp.proj)

        # Once Autopilot has finished we retrieve the best model ID
        all.models      <- ListModels(temp.proj)
        model.frame     <- as.data.frame(all.models)
        best.model      <- all.models[[1]]
        model.type      <- best.model$modelType
        model.bp        <- best.model$blueprintId
        modelId         <- best.model$modelId
        metric          <- best.model$metrics[[metric]]$validation
        writeLines(paste('NULL', metric, model.type, model.bp, temp.proj$projectId, modelId, sep='\t'), con=rez, sep="\n")
	flush(rez)

	# CLOSE THE RESULTS FILE 
	close(rez)
	return(1)
} 

