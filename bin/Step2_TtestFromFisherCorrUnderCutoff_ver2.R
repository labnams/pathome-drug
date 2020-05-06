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

num.lines <- tryCatch( countLines ( f.fisherCorr  ) , error=function(e) { c() } )

if( num.lines  <= 1 ) {
        print(paste ("No data in ", f.fisherCorr, sep="") )
        quit(save="no", status=0, runLast=FALSE) 
}

ff <- file( f.fisherCorr, open="rt" )
block.size <- 100000
nblocks <- floor( num.lines / block.size )
res.lines <- num.lines %% block.size

temp.f<-function (){ ### temp.f block BEGIN

writeLines( paste("beginId", "subpathId", "pval" , "subLenEdgeC1", "subLenEdgeC2",  sep="\t" ), f.out )

for (ii in 1:(nblocks+1)) { 

	if( ii == 1) {
		dat.lines <- readLines(ff, n=block.size)[-1]
	} else if (ii== nblocks + 1) {
		dat.lines <- readLines(ff, n=res.lines)
	} else {
		dat.lines <- readLines(ff, n=block.size)
	}

	list.char <- lapply ( dat.lines, function(x){ unlist( strsplit (x, split=c(":"))) } )
	begin.id.vec <- as.numeric ( unlist (lapply (list.char, function(x){ x[1] } )))
	subpath.id.vec <- as.numeric ( unlist ( lapply (list.char, function(x){ x[2] } )))
	sublen.c1.vec <- as.numeric ( unlist (lapply (list.char, function(x){ x[5] } )))
	sublen.c2.vec <- as.numeric ( unlist (lapply (list.char, function(x){ x[6] } )))

	list.vec.c1 <- lapply ( list.char, function(x){ as.numeric( unlist( strsplit(x[3] , split=c("\t"), perl=TRUE ))) }) 
	list.vec.c2 <- lapply ( list.char, function(x){ as.numeric( unlist( strsplit(x[4] , split=c("\t"), perl=TRUE ))) }) 

	p.vec <- c()

	for( i in 1:length(list.vec.c1) ){
        	p.vec <- c( p.vec,  t.test(abs( list.vec.c1[[i]] ), abs( list.vec.c2[[i]]) )$p.value )   ## absolute value of fisher transformed value
	}	

	write.table( cbind( begin.id.vec, subpath.id.vec, p.vec, sublen.c1.vec, sublen.c2.vec), file=f.out, quote=FALSE, sep="\t", row.names=FALSE, col.names=FALSE, append=TRUE )
}


} ### temp.f block END

system.time( temp.f () )


