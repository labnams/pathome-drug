#Generated in 2010-12-17

#R --no-save --slave --args -i fisherCorr/hsa04010.fisherCorr  -o temp.pval < Step2_TtestFromFisherCorr.R


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

f.fisherCorr <- opt$input 
f.out <- opt$output 

dat.lines <- tryCatch(readLines (f.fisherCorr)[-1] , error=function(e){ c()  } )


if(length(dat.lines) == 0 ){
	print(paste ("No data in ", f.fisherCorr, sep="") )
	quit(save="no", status=0, runLast=FALSE) 
}

list.char <- lapply ( dat.lines, function(x){ unlist( strsplit (x, split=c(":"))) } )

begin.id.vec <- as.numeric ( unlist (lapply (list.char, function(x){ x[1] } )))
subpath.id.vec <- as.numeric ( unlist ( lapply (list.char, function(x){ x[2] } )))
sublen.c1.vec <- as.numeric ( unlist (lapply (list.char, function(x){ x[5] } )))
sublen.c2.vec <- as.numeric ( unlist (lapply (list.char, function(x){ x[6] } )))



list.vec.c1 <- lapply ( list.char, function(x){ as.numeric( unlist( strsplit(x[3] , split=c("\t"), perl=TRUE ))) }) 
list.vec.c2 <- lapply ( list.char, function(x){ as.numeric( unlist( strsplit(x[4] , split=c("\t"), perl=TRUE ))) }) 


p.vec <- c()
sublen.vec <-c()
for( i in 1:length(list.vec.c1) ){
	p.vec <-c ( p.vec,  t.test(abs( list.vec.c1[[i]] ), abs( list.vec.c2[[i]]) )$p.value  ) 
}



writeLines( paste("beginId", "subpathId", "pval" , "subLenEdgeC1", "subLenEdgeC2",  sep="\t" ), f.out )
write.table( cbind( begin.id.vec, subpath.id.vec, p.vec, sublen.c1.vec, sublen.c2.vec), file=f.out, quote=FALSE, sep="\t", row.names=FALSE, col.names=FALSE, append=TRUE )


