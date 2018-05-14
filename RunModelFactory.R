#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)

source('ModelFactory.R')

# test if there is at least one argument: if not, return an error
if (length(args)<6) {
  stop("6 arguments must be supplied (DATSET, KEY_COL, TARGET_COL, PROJ_NAME, OUTPUT_DIR, METRIC).n", call.=FALSE)
} 
dataset		<- args[1]
keycol		<- args[2]
targcol		<- args[3]
projname	<- args[4]
output		<- args[5]
metric		<- args[6]

df <- read.csv(dataset)

runModelFactory(df, keycol, targcol, projname, output, metric)

