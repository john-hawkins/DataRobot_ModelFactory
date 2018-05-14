source('ModelFactory.R')

df <- read.csv('test_data.csv')

runModelFactory(df, 'GROUP_COL', 'TARGET_COL', 'TEST_PROJECT', 'model_list.tsv', 'AUC')

