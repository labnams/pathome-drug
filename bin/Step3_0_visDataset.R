library(getopt)
args = ( commandArgs(TRUE) )

opt=getopt( matrix(c(
'input', 'i', 1, "character",
'output', 'o', 1, "character"
), ncol=4, byrow=TRUE))


if(is.null(opt$input)) {
    opt$input =  ""
}

if(is.null(opt$output)) {
    opt$output= "temp.out"
}

a <- read.table(opt$input, header=T, stringsAsFactors=F)
png(opt$output)
hist(a, main="Histogram of fold-changes", xlab="Fold change of c2 over c1")
dev.off()
