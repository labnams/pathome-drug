
# command example: R --no-save --slave --args -i Step3_1.cutoff0.05.pval -o Step3_2_sorted_pval_qval_table_for_Step3_1 < Step3_2_TableForAllPValuesAndTheirQValues.R 

############# Re-calculate q-values for all the p-values (We considered all the p-values without regard to p-value cutoff.)
############# We obtained the table for p-value and q-value
############# Added in 2012-03-28

### History
# 2014-06-25 : arguments were added by yoon

library(getopt)
args <- ( commandArgs(TRUE) )

opt <- getopt( matrix(c(
'input', 'i', 1, "character",
'output', 'o', 1, "character"
), ncol=4, byrow=TRUE))


if(is.null(opt$input)) {
    opt$input =  "Step3_1.cutoff0.05.pval"
}

if(is.null(opt$output)) {
    opt$output= "Step3_2_sorted_pval_qval_table_for_Step3_1"
}




pvals <- sort( unlist( read.table ( opt$input, colClasses="double" )))
qvals <- p.adjust(pvals, method="BH")


uniq.pval.id <- match( unique(pvals), pvals )

#I selected the unique p-values and their corresponding q-values.
write.table( cbind(pvals[uniq.pval.id], qvals[uniq.pval.id]) , file=opt$output, row.names = FALSE,  col.names = FALSE, quote=FALSE )



