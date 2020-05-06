#R --no-save --slave --args -i fisherCorr/hsa04010.fisherCorr  -o temp.pval < Step2_TtestFromFisherCorrUnderCutoff_ver2.R


library(getopt)
library(R.utils)

args = ( commandArgs(TRUE) )

opt=getopt( matrix(c(
'input', 'i', 1, "character",
'cutoff', 'c', 1, "double",
'output', 'o', 1, "character"
), ncol=4, byrow=TRUE))

if(is.null(opt$cutoff)){
   opt$cutoff = 0.05
}

if(is.null(opt$input)) {
    opt$input =  ""
}

if(is.null(opt$output)) {
    opt$output= "temp.out"
}


f.fisherCorr <- #"hsa04510.fisherCorr"    
		 opt$input 

f.out <- # "temp.out"
        opt$output 


temp.f<-function (){ ### temp.f block BEGIN
	dat.lines <- read.table( f.fisherCorr, stringsAsFactors=F, sep=":" )
	res <- cbind( dat.lines[,1:2], unlist( apply(dat.lines, 1, function(a) {
		t.test( abs( as.numeric(strsplit(a[3], "\t", T, useBytes=T)[[1]]) ), abs( as.numeric(strsplit(a[4], "\t", T, useBytes=T)[[1]]) ) )$p.value
	}) ), dat.lines[,5:6] )
	colnames(res) <- c("beginId", "subpathId", "pval" , "subLenEdgeC1", "subLenEdgeC2") 
	write.table( res , file=f.out, quote=FALSE, sep="\t", row.names=FALSE )
} ### temp.f block END

system.time( temp.f () )


