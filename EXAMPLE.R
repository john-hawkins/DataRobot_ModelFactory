source('ModelFactory.R')

#
# THIS IS HOW IT IS USED
# runModelFactory(COMPLETE_DATA_SET, 'GROUP_COL', 'TARGET_COL', 'PROJECT_NAME_PREFIX', 'RESULTS_DIR', 'METRIC_TO_REPORT', 'DATAROBOT_MODE')
#

df <- read.csv('test_data.csv')

runModelFactory(df, 'Cheq_status', 'outcome', 'DSS_DEMO', 'RESULTS', 'AUC', 'quick')

