library(data.table)

# PULL THE DATA FROM
# https://archive.ics.uci.edu/ml/datasets/statlog+(german+credit+data)
# TURN IT INTO A CSV

df 		<- read.csv('german.csv')
dt      	<- data.table(df)

temp.data       <- dt[get('Cheq_status')!='A13',]

write.csv(temp.data, 'test_data.csv')

