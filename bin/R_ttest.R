args <- commandArgs()
path <- args[length(args)-1]
outpath <- args[length(args)]
tbl <- read.table(path, comment.char='', sep="\t", stringsAsFactors=F)
c1 <- tbl[1,] == "c1"
c2 <- tbl[1,] == "c2"
ret <- matrix(NA, nrow(tbl)-2, 2)
for (i in 3:nrow(tbl)) {
  res <- try(t.test(as.numeric(tbl[i,c1]), as.numeric(tbl[i,c2])), T)
  if (class(res) == 'try-error')
    res <- NA
  else
    res <- res$p.value
  ret[i-2,] <- c(tbl[i,1], res)
}
write.table(ret, outpath, row.names=F, col.names=F, quote=F)

