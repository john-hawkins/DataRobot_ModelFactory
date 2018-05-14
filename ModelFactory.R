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
# template (optional) - TODO. Parameters you will want to use when 
#                       generating the project and models
# ####################################################################

runModelFactory <- function(df, keycol, target, projectNamePrefix, resultDir, metric, template=null) {


	# WE WRITE OUT THE MODEL RESULTS INTO A TABLE
	resultsFile = paste(resultDir, 'model_list.tsv', sep='/')

	# Test the output file before we begin 
	result = tryCatch({
		rez <- file(resultsFile, "w")
		writeLines("key\tdatarobot_project_id\tdatarobot_model_id\tmetric",con=rez,sep="\n")
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

	# iterate over the keyset
	for(key in keyset) { 
		# Subset the data and create the project for this key
		temp.data	<- dt[get(keycol)==key,]
		projName 	<- paste(projectNamePrefix, key, sep='_')
		temp.proj	<- SetupProject( dataSource=temp.data, projectName=projName )
		SetTarget(project=temp.proj, target=target)
		WaitForAutopilot(project = temp.proj)

		# Once Autopilot has finished we retrieve the best model ID
		all.models 	<- ListModels(temp.proj)
		model.frame 	<- as.data.frame(all.models)
		model.type 	<- model.frame$modelType

		best.model	<- all.models[[1]]
		modelId		<- best.model$modelId
		metric		<- best.model$metrics[[metric]]$validation		
		writeLines(paste(key, temp.proj$projectId, modelId, metric, sep='\t'), con=rez, sep="\n")		
	}

	# CLOSE THE RESULTS FILE 
	close(rez)
	return(1)
} 

