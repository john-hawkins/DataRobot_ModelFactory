#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)

source('ModelFactory.R')

# test if there is at least one argument: if not, return an error
if (length(args)<7) {
  stop("7 arguments must be supplied (DATSET, KEY_COL, TARGET_COL, PROJ_NAME, OUTPUT_DIR, MODE, METRIC).n", call.=FALSE)
} 
dataset		<- args[1]
keycol		<- args[2]
targcol		<- args[3]
projname	<- args[4]
output		<- args[5]
mode		<- args[6]
metric		<- args[7]

df <- read.csv(dataset)

runModelFactory(df, keycol, targcol, projname, output, metric, mode)

