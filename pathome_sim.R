# PATHOME-Drug paper R codes
# Last updated : Jul 10 2021
# By : Sungyoung Lee (biznok@snu.ac.kr)


#
# Configurations
#
conf.wd = "~/pathome/revision"  # Working directory
# Simulation parameter settings
# Number of edges
n.e <- sum(m)
# Number of genes
n.g <- length(gALL)
# Number of samples
n.s <- 80
# Number of trials
n.trial <- 100


#
# Initialize
#
setwd(conf.wd)
library(KEGGgraph)
library(Rgraphviz)
library(bnlearn)
library(predictionet)
library(WebGestaltR)


# Fetch KEGG XMLs
pw = c("04310", "04010", "04151", "04630")
dir.create("tmp", F)
invisible(sapply(pw,function(v) {
  src = paste0("http://rest.kegg.jp/get/hsa",v,"/kgml")
  tgt = paste0("tmp/hsa",v,".xml")
  if (!file.exists(v)) download.file(src, tgt)
}))


v    <- pw[1]
cpw  <- v
KGML <- paste0("tmp/hsa",v,".xml")
nAC  <- paste0("tmp/hsa",v,".acylic.RData")


G <- parseKGML2Graph(KGML, expandGenes=TRUE)
D <- parseKGML2DataFrame(KGML, expandGenes=TRUE)


# Extract networks
N   <- nodes(G)
dN  <- getKEGGnodeData(G)
nmN <- sapply(dN,function(v)v@graphics@name)
i2g <- gsub("\\.+$","",sapply(strsplit(nmN, '[,]'),function(v)v[1]))
D$from <- i2g[D$from]
D$to   <- i2g[D$to]
D2  <- D[,1:2]
D2s <- apply(D2,1,paste,collapse="_")
D3  <- D2[match(unique(D2s),D2s),]


# Convert format
gALL <- as.character(unique(unlist(D3)))
m    <- matrix(0,length(gALL),length(gALL))
rownames(m) <- gALL
colnames(m) <- gALL
for (i in 1:nrow(D3)) m[D3[i,1],D3[i,2]] <- 1


if (!file.exists(nAC)) {
  x = adj.remove.cycles(m,maxlength=7)
  save(x, file=nAC)
} else load(nAC)


m = x$adjmat.acyclic


vG <- new("graphAM", adjMat=t(m), edgemode="directed")
vvG <- as.bn(vG)


# Target dataset
inp.fn <- "tmp/gse27342.sip"
if (!file.exists(inp.fn)) {
  download.file("http://statgen.snu.ac.kr/software/pathome/?act=downjob&cat=dt&id=0324015452", inp.fn)
}


p.list = as.list(1:n.trial)
corr.vec.pos <- 1:n.trial
corr.vec.neg <- 1:n.trial


#
# Generate simulation datasets
#


neg.sd = 1 # sd for control group data set: weak or no correlation between neighborhood genes.
pos.sd = 1 # sd for experimental group
# diff genes about 25%: 12 * 0.25 = 3


xorig = read.table(inp.fn, stringsAsFactors=F, header=F)
rownames(xorig) = xorig[,1]
Dorig = xorig[,-1]
Yorig = strsplit(readLines(inp.fn, 1), "\t")[[1]][-1]
Dorig = Dorig[,c(which(Yorig=='c1'),which(Yorig=='c2'))]
Drdc  = Dorig[-na.omit(match(gALL, rownames(Dorig))),]


# Main simulation loop
p.list <- parallel::mclapply(1:n.trial, function(i) {
  cat("Do",i,"\n")
  set.seed(1000 + i)
  neg.1 = rep(2, n.g*0.25)
  neg.2 = rep(1, n.g-length(neg.1))
  
  coef.1 = rep(0.5, n.e*0.25)
  coef.2 = rep(0.3, n.e-length(coef.1))
  
  neg.intercepts = sample(c(neg.1, neg.2)) # 25 % genes might be diff.
  pos.coeffs = sample(c(coef.1, coef.2)) # 19 coefficients for positive set
  


  neg.L = list()
  for (j in 1:ncol(m)) {
    cG = gALL[j]
    cGX = gALL[which(m[j,] == 1)]
    z = list(coef=c("(Intercept)"=neg.intercepts[j]), sd=neg.sd)
    for (k in cGX)
      z$coef[k] = 0.1
    neg.L[[cG]] = z
  }
  
  bn.neg <- custom.fit(vvG, neg.L)
  
  pos.L = list()
  kk = 1
  for (j in 1:ncol(m)) {
    cG = gALL[j]
    cGX = gALL[which(m[j,] == 1)]
    z = list(coef=c("(Intercept)"=1), sd=pos.sd)
    for (k in cGX) {
      z$coef[k] = pos.coeffs[kk]
          kk = kk+1
    }
    pos.L[[cG]] = z
  }
  
  bn.pos <- custom.fit(vvG, pos.L)
  
  pos.D <- rbn(bn.pos, n.s)
  neg.D <- rbn(bn.neg, n.s)
  
  Dall2 <- t(rbind(neg.D, pos.D))
  colnames(Dall2) <- paste0("V",2:(ncol(Dall2)+1))
  Dall <- rbind(Drdc, Dall2)
  pvall <- unlist(lapply(1:nrow(Dall), function(i) {
    v <- Dall[i,]
    t.test(v[1:80],v[8:160])$p.value
  }))
  names(pvall) <- rownames(Dall)
  
  if (1) {
    Drdc2 = as.matrix(Drdc)
  
    DD <- cbind(
          c("#Class","#NAME",rownames(Dall)),
          rbind(
                c(rep("c1",n.s),rep("c2",n.s)),
                c(paste0("SAMP",1:n.s),paste0("SAMP",(n.s+1):(n.s*2))),
                Drdc2,
                t(rbind(pos.D, neg.D))
          )
    )
    oFN = paste0("data/pathome_input_hsa",cpw,"_",i,".sip")
    write.table(DD,oFN,row.names=F,col.names=F,quote=F,sep="\t")
  }
  #pvals <- unlist(lapply(1:ncol(pos.D), FUN=function(x) {
  #  t.test(pos.D[,x], neg.D[,x])$p.value
  #}))
  pv2 = p.adjust(pvall,method='BH')
  names(pv2) = rownames(Dall)
  list(pvall, pv2)
}, mc.cores=50)


####
## Perform WebGestalt analysis using the simulated datasets
####
outputDirectory = "output"
dir.create(outputDirectory,F)
refFile <- system.file("extdata", "referenceGenes.txt", package="WebGestaltR")
wgs = mclapply(p.list, function(v) {
  z2 = p.adjust(unlist(v),method="BH")
  gn = rownames(Dall)[which(z2 < 0.05)]


  enrichResult <- WebGestaltR(enrichMethod="ORA", organism="hsapiens",
    enrichDatabase="drug_DrugBank", interestGene=gn,
    interestGeneType="genesymbol", referenceGeneFile=refFile,
    referenceGeneType="genesymbol", isOutput=FALSE,
    outputDirectory=outputDirectory, projectName=NULL)
  drug <- WebGestaltR(enrichMethod="ORA", organism="hsapiens",
    enrichDatabase="drug_GLAD4U", interestGene=gn,
    interestGeneType="genesymbol", referenceGeneFile=refFile,
    referenceGeneType="genesymbol", isOutput=FALSE,
    outputDirectory=outputDirectory, projectName=NULL)
}, mc.cores=5)


####
## Perform ClusterProfiler analysis using the simulated datasets
####


library(clusterProfiler)
library(org.Hs.eg.db)
setwd(conf.wd)


D0 = strsplit(readLines(paste0(conf.wd, "/DSigDB_subset.gmt")),"\t")
D = lapply(D0,function(v)v[-(1:2)])
names(D) = sapply(D0,function(v)v[1])


d2g = do.call(rbind, lapply(1:length(D), function(i) {
 cbind(i,D[[names(D)[i]]])
}))
d2n = cbind(1:length(D), names(D))




kegg_organism = "hsa"
for (int1 in c("2", "3", "4")) {
  r = list()
  for (xcpw in pw)
    r[[xcpw]] = parallel::mclapply(1:100,function(i) {
      try({
        prefix = paste0("data/sim/hsa", xcpw,
          "_int", int1, "_", int2, "_eff", eff1, "_", eff2, "/", i)
        rrun = F
        if (!file.exists(paste0(prefix,"/ora.RData"))) rrun = T
        else {
          invisible(try(load(paste0(prefix,"/ora.RData")), T))
          ret.oraold = ret.ora
          if (is.null(ret.oraold[[1]]) | is.na(ret.oraold[[1]])) rrun = T
       }
        if (rrun == T) {
          cat("Do",xcpw,i,"\n")
          load(paste0(prefix,"/result.RData"))
          xs = mapIds(org.Hs.eg.db, names(ret[[2]]),
            "ENTREZID", "SYMBOL")
          #gn = xs[ret[[2]] < 0.05]
          gn = xs[p.adjust(ret[[2]],method='BH') < 0.1]
          ogn = names(ret[[2]])[ret[[2]] < 0.05]
          kk <- try(enrichKEGG(gene=gn, universe=xs,
             organism="hsa",pvalueCutoff = 0.05,
             qvalueCutoff=0.1, keyType = "ncbi-geneid"), T)
          dx = match(xcpw,kk$ID)
          dy = enricher(ogn,TERM2GENE=d2g,TERM2NAME=d2n,pvalueCutoff = 0.05,
             qvalueCutoff=0.1)
          ret.ora = list(kk,dy)
          save(ret.ora, file=paste0(prefix, "/ora.RData"))
          ret.ora
        }
        suppressWarnings(rm(ret.ora))
      }, T)
    }, mc.cores=4)
}


####
## PATHOME-Drug
####
dirs = system("find data/sim -maxdepth 2 -type d", T)
dirs2 = dirs[sapply(strsplit(dirs, "/"), function(v)length(v)==4)]
dd = sapply(strsplit(dirs2, "/"), function(v) {
 paste0(v[1], "/", v[3], "_", v[4])
})
cmd = paste("ln -s",gsub("^data\\/","",dirs2),dd)
sapply(cmd[!file.exists(dd)],system)
r = list()
for (cpw in pw) {
  r[[cpw]] = parallel::mclapply(1:100,function(i) {
    prefix = paste0("data/sim/hsa", cpw,
      "_int", int1, "_", int2,
      "_eff", eff1, "_", eff2, "/", i)
    if (file.exists(paste0(prefix, "/Step6_out"))) {
    } else system(paste0("php bin/analysis.php hsa", cpw,
      "_int", int1, "_", int2, "_eff", eff1, "_", eff2, "_", i,
      " 0.05 0 hsa", cpw,
      "_int", int1, "_", int2,
      "_eff", eff1, "_", eff2, "_", i))
  }, mc.cores=10)
}




############################
## PATHOME-Drug sim summary
############################
options(stringsAsFactors=F)
db.ro5 = read.csv("drugbank_ro5.csv",header=F)
db = read.csv("drugbank_rel.csv",header=F)




parallel::mclapply(1:100,function(i)system(paste0("php bin/analysis.php pathome_input_hsa",pw,"_",i," 0.05 1 pathome_input_hsa",pw,"_",i)),mc.cores=10)


pw = "04310"
ret.drug = parallel::mclapply(1:100,function(i) {
res = suppressWarnings(strsplit(readLines(paste0("data/pathome_input_hsa", pw, "_", i, "/Step6_out")), "\t"))
gg = read.table(paste0("data/pathome_input_hsa", pw, "_", i, "/dataset.tt"))[,1]
res2 = do.call(rbind, res[sapply(res,function(v)v[2] == paste0("ac_hsa",pw))])[,-2]


sg = unique(as.character(res2))
p.drug = sapply(unique(db.ro5$V14), function(v) {
  db.ro5.cur = db.ro5[db.ro5$V14 == v,2]
  v11 = sum(sg %in% db.ro5.cur)
  v12 = length(sg) - v11
  v21 = length(db.ro5.cur) - sum(!(db.ro5.cur %in% sg))
  v22 = length(gg) - v11 - v12 - v21
  fisher.test(matrix(c(v11, v12, v21, v22), 2))$p.value
})
p.drug[p.drug < 0.05]


p.drug = sapply(unique(db$V4), function(v) {
  db.cur = db[db$V4 == v,3]
  v11 = sum(sg %in% db.cur)
  v12 = length(sg) - v11
  v21 = length(db.cur) - sum(!(db.cur %in% sg))
  v22 = length(gg) - v11 - v12 - v21
  fisher.test(matrix(c(v11, v12, v21, v22), 2))$p.value
})
p.drug[p.drug < 0.05]
},mc.cores=50)




###
## Fetch PATHOME-Drug step6
##
pw = "04310"
ret.pd = parallel::mclapply(1:100,function(i) {
tmp = suppressWarnings(strsplit(readLines(paste0("data/pathome_input_hsa", pw, "_", i, "/Step6_out")), "\t"))
ret = do.call(rbind,tmp[sapply(tmp,function(v)length(grep("^_", v)) == 0)])[,-2]
unique(as.character(ret))
},mc.cores=50)


####
## Fetch PATHOME-Drug step6 manually (DRUG)
##
cpw = "04310"
ret.pd = parallel::mclapply(1:100, function(i) {
  a0 = strsplit(readLines(paste0("data/pathome_input_hsa", cpw, "_", i, "/Step4_out"))," \\/\\/ ")
#a0 = strsplit(readLines("./9bfd2b26a1da16668d88bb36f0888d3e/Step4_out")," \\/\\/ ")
  an = sapply(a0,function(v)v[1])
  a = sapply(strsplit(sapply(a0,function(v)v[3]),"\t"),function(v)v[-1])


  aa = unlist(lapply(a,function(v) {
    ix = seq(length(v)-2*as.numeric(v[length(v)-2])-2,length(v)-3,by=2)
    ix = ix[ix>0]
    v[ix]
  }))


  json = readLines(paste0("http://statgen.snu.ac.kr/software/pathome/drug.php?id=x&ngene=21374&mine=2&gene=",
    paste(unique(as.character(aa)), collapse="|")))
  list(
    siggene = unique(as.character(aa)),
    sigdrug = names(rjson::fromJSON(json))
  )
},mc.cores=50)
  
if (0) aaa = lapply(1:length(aa),function(i) {
  v = aa[[i]]
  cbind(an[i],v[-length(v)],v[-1])
})
ret.pd[[i]] = unique(unlist(aa))
}


####
## Fetch PATHOME-Drug step6 manually (DRUG)
##
cpw = "04310"
ret.pd = parallel::mclapply(1:100, function(i) {
  a0 = strsplit(readLines(paste0("data/pathome_input_hsa", cpw, "_", i, "/Step4_out"))," \\/\\/ ")
#a0 = strsplit(readLines("./9bfd2b26a1da16668d88bb36f0888d3e/Step4_out")," \\/\\/ ")
  an = sapply(a0,function(v)v[1])
  a = sapply(strsplit(sapply(a0,function(v)v[3]),"\t"),function(v)v[-1])


  aa = unlist(lapply(a,function(v) {
    ix = seq(length(v)-2*as.numeric(v[length(v)-2])-2,length(v)-3,by=2)
    ix = ix[ix>0]
    v[ix]
  }))


  json = readLines(paste0("http://statgen.snu.ac.kr/software/pathome/drug.php?id=x&ngene=21374&mine=2&gene=",
    paste(unique(as.character(aa)), collapse="|")))
  list(
    siggene = unique(as.character(aa)),
    sigdrug = names(rjson::fromJSON(json))
  )
},mc.cores=50)
  




########################
## Main simulation loop
########################
setwd("~/pathome/revision")


library(KEGGgraph)
library(Rgraphviz)
library(bnlearn)
library(predictionet)
library(WebGestaltR)


# Fetch KEGG XMLs
pw = c("04310", "04010", "04151", "04630")
dir.create("tmp", F)
invisible(sapply(pw,function(v) {
  src = paste0("http://rest.kegg.jp/get/hsa",v,"/kgml")
  tgt = paste0("tmp/hsa",v,".xml")
  if (!file.exists(v)) download.file(src, tgt)
}))


v    <- pw[1]
cpw  <- v
KGML <- paste0("tmp/hsa",v,".xml")
nAC  <- paste0("tmp/hsa",v,".acylic.RData")


G <- parseKGML2Graph(KGML, expandGenes=TRUE)
D <- parseKGML2DataFrame(KGML, expandGenes=TRUE)


# Extract networks
N   <- nodes(G)
dN  <- getKEGGnodeData(G)
nmN <- sapply(dN,function(v)v@graphics@name)
i2g <- gsub("\\.+$","",sapply(strsplit(nmN, '[,]'),function(v)v[1]))
D$from <- i2g[D$from]
D$to   <- i2g[D$to]
D2  <- D[,1:2]
D2s <- apply(D2,1,paste,collapse="_")
D3  <- D2[match(unique(D2s),D2s),]


# Convert format
gALL <- as.character(unique(unlist(D3)))
m    <- matrix(0,length(gALL),length(gALL))
rownames(m) <- gALL
colnames(m) <- gALL
for (i in 1:nrow(D3)) m[D3[i,1],D3[i,2]] <- 1


if (!file.exists(nAC)) {
  x = adj.remove.cycles(m,maxlength=7)
  save(x, file=nAC)
} else load(nAC)


m = x$adjmat.acyclic


vG <- new("graphAM", adjMat=t(m), edgemode="directed")
vvG <- as.bn(vG)


# Simulation parameter settings
# Number of edges
n.e <- sum(m)
# Number of genes
n.g <- length(gALL)
# Number of samples
n.s <- 80
# Number of trials
n.trial <- 100
# Target dataset
inp.fn <- "tmp/gse27342.sip"
if (!file.exists(inp.fn)) {
  download.file("http://statgen.snu.ac.kr/software/pathome/?act=downjob&cat=dt&id=0324015452", inp.fn)
}


p.list = as.list(1:n.trial)
corr.vec.pos <- 1:n.trial
corr.vec.neg <- 1:n.trial




xorig = read.table(inp.fn, stringsAsFactors=F, header=F)
rownames(xorig) = xorig[,1]
Dorig = xorig[,-1]
Yorig = strsplit(readLines(inp.fn, 1), "\t")[[1]][-1]
Dorig = Dorig[,c(which(Yorig=='c1'),which(Yorig=='c2'))]
Drdc  = Dorig[-na.omit(match(gALL, rownames(Dorig))),]


neg.sd = 1 # sd for control group data set: weak or no correlation between neighborhood genes.
pos.sd = 1 # sd for experimental group


###
# Dataset generation
###


pw = c("04310", "04010", "04151", "04630")
X = list()
for (I in pw) X[[I]] = parallel::mclapply(1:100,function(i) {
  sim(I, m, i, length(gALL), 2, 1, 0.3, 0.5, 80)
  sim(I, m, i, length(gALL), 4, 1, 0.3, 0.5, 80)
}, mc.cores=50)
sim <- function(cpw, m, i, n.g, int1, int2, eff1, eff2, n.s) {
    TD = paste0("data/sim/hsa",cpw,"_int",int1,"_",int2,"_eff",eff1,"_",eff2,"/",i)
    KGML <- paste0("tmp/hsa",cpw,".xml")
    nAC  <- paste0("tmp/hsa",cpw,".acylic.RData")
    
    G <- parseKGML2Graph(KGML, expandGenes=TRUE)
    D <- parseKGML2DataFrame(KGML, expandGenes=TRUE)
    
    # Extract networks
    N   <- nodes(G)
    dN  <- getKEGGnodeData(G)
    nmN <- sapply(dN,function(v)v@graphics@name)
    i2g <- gsub("\\.+$","",sapply(strsplit(nmN, '[,]'),function(v)v[1]))
    D$from <- i2g[D$from]
    D$to   <- i2g[D$to]
    D2  <- D[,1:2]
    D2s <- apply(D2,1,paste,collapse="_")
    D3  <- D2[match(unique(D2s),D2s),]
    
    # Convert format
    gALL <- as.character(unique(unlist(D3)))
    m    <- matrix(0,length(gALL),length(gALL))
    rownames(m) <- gALL
    colnames(m) <- gALL
    for (ii in 1:nrow(D3)) m[D3[ii,1],D3[ii,2]] <- 1
    
    if (!file.exists(nAC)) {
      x = adj.remove.cycles(m,maxlength=7)
      save(x, file=nAC)
    } else load(nAC)
    
    m = x$adjmat.acyclic
    
    vG <- new("graphAM", adjMat=t(m), edgemode="directed")
    vvG <- as.bn(vG)
    
    # Simulation parameter settings
    # Number of edges
    n.e <- sum(m)
    # Number of genes
    n.g <- length(gALL)
    # Number of samples
    n.s <- 80
    # Number of trials
    n.trial <- 100
    # Target dataset
    inp.fn <- "tmp/gse27342.sip"
    if (!file.exists(inp.fn)) {
      download.file("http://statgen.snu.ac.kr/software/pathome/?act=downjob&cat=dt&id=0324015452", inp.fn)
    }
    
    p.list = as.list(1:n.trial)
    corr.vec.pos <- 1:n.trial
    corr.vec.neg <- 1:n.trial
    
    neg.sd = 1 # sd for control group data set: weak or no correlation between neighborhood genes.
    pos.sd = 1 # sd for experimental group
    # diff genes about 25%: 12 * 0.25 = 3
    
    xorig = read.table(inp.fn, stringsAsFactors=F, header=F)
    rownames(xorig) = xorig[,1]
    Dorig = xorig[,-1]
    Yorig = strsplit(readLines(inp.fn, 1), "\t")[[1]][-1]
    Dorig = Dorig[,c(which(Yorig=='c1'),which(Yorig=='c2'))]
    Drdc  = Dorig[-na.omit(match(gALL, rownames(Dorig))),]
  


    set.seed(1000 + i)


    ## Data generation
    neg.1 = rep(int1, n.g*0.25)
    neg.2 = rep(int2, n.g-length(neg.1))
  
    coef.1 = rep(eff2, n.e*0.25)
    coef.2 = rep(eff1, n.e-length(coef.1))
  
    neg.intercepts = sample(c(neg.1, neg.2)) # 25% genes diff.
    pos.coeffs = sample(c(coef.1, coef.2)) # coefficients
  
    neg.L = list()
    for (j in 1:ncol(m)) {
      cG = gALL[j]
      cGX = gALL[which(m[j,] == 1)]
      z = list(coef=c("(Intercept)"=neg.intercepts[j]), sd=neg.sd)
      for (k in cGX)
        z$coef[k] = 0.1
      neg.L[[cG]] = z
    }
  
    bn.neg <- custom.fit(vvG, neg.L)
  
    pos.L = list()
    kk = 1
    for (j in 1:ncol(m)) {
      cG = gALL[j]
      cGX = gALL[which(m[j,] == 1)]
      z = list(coef=c("(Intercept)"=1), sd=pos.sd)
      for (k in cGX) {
        z$coef[k] = pos.coeffs[kk]
        kk = kk+1
      }
      pos.L[[cG]] = z
    }
  
    bn.pos <- custom.fit(vvG, pos.L)
    pos.D <- rbn(bn.pos, n.s)
    neg.D <- rbn(bn.neg, n.s)
  
    Dall2 <- t(rbind(neg.D, pos.D))
    colnames(Dall2) <- paste0("V",2:(ncol(Dall2)+1))
    Dall <- rbind(Drdc, Dall2)
    pvall <- unlist(lapply(1:nrow(Dall), function(ii) {
      v <- Dall[ii,]
      t.test(v[1:n.s],v[(n.s+1):(n.s*2)])$p.value
    }))
    names(pvall) <- rownames(Dall)
  
    if (1) {
      Drdc2 = as.matrix(Drdc)
  
      DD <- cbind(
         c("#Class","#NAME",rownames(Dall)),
         rbind(
                c(rep("c1",n.s),rep("c2",n.s)),
                c(paste0("SAMP",1:n.s),paste0("SAMP",(n.s+1):(n.s*2))),
                Drdc2,
                t(rbind(pos.D, neg.D))
         )
       )
       dir.create(TD,showWarnings=F,recursive=T)
       oFN = paste0(TD,"/dataset.sip")
       write.table(DD,oFN,row.names=F,col.names=F,quote=F,sep="\t")


      DD <- cbind(
         c("Gene_Symbol",rownames(Dall)),
         rbind(
                c(paste0("SAMP",1:n.s),paste0("SAMP",(n.s+1):(n.s*2))),
                Drdc2,
                round(t(rbind(pos.D, neg.D)),2)
         )
       )
       oFN2 = paste0(TD,"/dataset.tsv")
       writeLines(
           c(paste(n.s*2, 2, 1,sep=" "), "# c1 c2",
           paste(c(rep("c1",n.s),rep("c2",n.s)), collapse=" ")
         ), paste0(TD,"/dataset.cls"))
       write.table(DD,oFN2,row.names=F,col.names=F,quote=F,sep=" ")
    }


    pv2 = p.adjust(pvall,method='BH')
    names(pv2) = rownames(Dall)
    ret = list(pvall, pv2)


    save(ret, file=paste0(TD,"/result.RData"))


    ret
}












# [[1]] = pvall
# [[2]] = BH adjusted PV
refFile <- system.file("extdata", "referenceGenes.txt", package="WebGestaltR")
R = parallel::mclapply(1:length(X), function(i) {
  v = X[[i]]
  outputDirectory = paste0("data/pathome_input_hsa",cpw,"_",i,"/webgestalt")
  dir.create(outputDirectory,F)
  z2 = v[[2]]
  gn = names(z2)[which(p.adjust(z2,method='BH') < 0.1)]


  if (0) enrichResult <- WebGestaltR(enrichMethod="ORA", organism="hsapiens",
    enrichDatabase="pathway_KEGG", interestGene=gn,
    interestGeneType="genesymbol", referenceGeneFile=refFile,
    referenceGeneType="genesymbol", isOutput=FALSE,
    outputDirectory=outputDirectory, projectName=NULL)
  drug <- WebGestaltR(enrichMethod="ORA", organism="hsapiens",
      enrichDatabase="drug_DrugBank", interestGene=gn,
      interestGeneType="genesymbol", referenceGeneFile=refFile,
      referenceGeneType="genesymbol", isOutput=FALSE,
      outputDirectory=outputDirectory, projectName=NULL)
}, mc.cores=5)




RR = lapply(R, function(v) {
  w = v[,c("description","FDR")][,1]
})
sort(table(unlist(RR)),decreasing=T)




######### PATHOME-Drug type 1
i = 1
pw = "04310"
ret.drug = parallel::mclapply(1:100,function(i) {
  out.pathome = paste0("data/pathome_input_hsa", pw, "_", i, "/Step6_out")
  tmp = suppressWarnings(strsplit(readLines(out.pathome), "\t"))
  ret = do.call(rbind,tmp[sapply(tmp,function(v)length(grep("^_", v)) == 0)])[,-2]
  json = readLines(paste0("http://statgen.snu.ac.kr/software/pathome/drug.php?id=x&ngene=21374&mine=2&gene=",
    paste(unique(as.character(ret)), collapse="|")))
  list(
    siggene = unique(as.character(ret)),
    sigdrug = names(rjson::fromJSON(json))
  )
},mc.cores=50)
  


sg = unique(as.character(res2))
p.drug = sapply(unique(db.ro5$V14), function(v) {
  db.ro5.cur = db.ro5[db.ro5$V14 == v,2]
  v11 = sum(sg %in% db.ro5.cur)
  v12 = length(sg) - v11
  v21 = length(db.ro5.cur) - sum(!(db.ro5.cur %in% sg))
  v22 = length(gg) - v11 - v12 - v21
  fisher.test(matrix(c(v11, v12, v21, v22), 2))$p.value
})
p.drug[p.drug < 0.05]
















# Summarize PATHOME-Drug
sum.PD = function(i) {
  a0 = strsplit(readLines(paste0("~/pathome/revision/data/sim/", cpw, "_int", int1, "_", int2, "_eff", eff1, "_", eff2, "/", i, "/Step4_out"))," \\/\\/ ")
  an = sapply(a0,function(v)v[1])
  a = sapply(strsplit(sapply(a0,function(v)v[3]),"\t"),function(v)v[-1])


  aa = unlist(lapply(a,function(v) {
    ix = seq(length(v)-2*as.numeric(v[length(v)-2])-2,length(v)-3,by=2)
    ix = ix[ix>0]
    v[ix]
  }))


  json = readLines(paste0("http://statgen.snu.ac.kr/software/pathome/drug.php?id=x&ngene=21374&mine=2&gene=",
    paste(unique(as.character(aa)), collapse="|")))
  list(
    siggene = unique(as.character(aa)),
    sigdrug = names(rjson::fromJSON(json))
  )
}


sum.WG = function(i) {
 read.table(i, header=T, stringsAsFactors=F, sep="\t")
}


sum.OR = function(i) {
   load(i)
   ret.ora
}


###
tdrug = list(
 hsa04310 = c("Vitamin E","Tamoxifen","Arsenic trioxide"),
 hsa04010 = c("Spironolactone","Verapamil","Amlodipine","Nimodipine","Nitrendipine","Dronedarone","Regorafenib","Isradipine","Cinnarizine","Felodipine","Magnesium Sulfate","Nifedipine","Nilvadipine","Nisoldipine","Arsenic trioxide","Ponatinib","Palifermin","Ibutilide","Sorafenib","Nicardipine","Acetylsalicylic acid","Clevidipine","Pazopanib","Imatinib","Pentosan Polysulfate","Sulfasalazine","Pseudoephedrine","Zonisamide","Gabapentin","Thalidomide","Bepridil","Flunarizine","Becaplermin","Vitamin E","Aminosalicylic Acid","Mesalazine","Amitriptyline","Sucralfate","Tamoxifen","Minocycline","Quinacrine","Amiodarone","Sunitinib","Glucosamine","Clenbuterol","Pranlukast","Niflumic Acid","Acetylcysteine","Dabrafenib"),
 hsa04630 = c("Denileukin diftitox","Sargramostim","Aldesleukin","Caffeine","Isoprenaline","Tofacitinib","Peginterferon alfa-2a","Interferon alfa-n1","Interferon alfa-n3","Peginterferon alfa-2b","Interferon gamma-1b","Interferon Alfa-2a, Recombinant","Somatropin recombinant","Interferon beta-1a","Interferon beta-1b","Interferon alfacon-1","Basiliximab","Interferon Alfa-2b, Recombinant","Daclizumab","Arsenic trioxide","Ruxolitinib"),
 hsa04151 = c("Regorafenib","Ponatinib","Sorafenib","Sunitinib","Pazopanib","Imatinib","Arsenic trioxide","Palifermin","Amitriptyline","Acetylsalicylic acid","Isoprenaline","Denileukin diftitox","Aldesleukin","Collagenase","Abciximab","Antithymocyte globulin","Vitamin E","Caffeine","Amoxapine","Pentosan Polysulfate","Dasatinib","Vandetanib","Axitinib","Tofacitinib","Peginterferon alfa-2a","Interferon alfa-n1","Interferon alfa-n3","Peginterferon alfa-2b","Insulin Regular","Interferon Alfa-2a, Recombinant","Insulin Lispro","Insulin Glargine","Somatropin recombinant","Interferon beta-1a","Interferon beta-1b","Interferon alfacon-1","Insulin, porcine","Trastuzumab","Basiliximab","Becaplermin","Interferon Alfa-2b, Recombinant","Daclizumab","Adenosine monophosphate","Adenosine triphosphate","Succinylcholine","Mesalazine","Ziprasidone","Disopyramide","Ipratropium bromide","Olanzapine","Metixene","Clozapine","Sucralfate","Trihexyphenidyl","Oxyphencyclimine","Procyclidine","Ethopropazine","Loxapine","Carbachol","Promazine","Hyoscyamine","Cyproheptadine","Pethidine","Imipramine","Methylscopolamine bromide","Darifenacin","Triflupromazine","Anisotropine Methylbromide","Nortriptyline","Cinnarizine","Atropine","Rifabutin","Nicardipine","Paroxetine","Homatropine Methylbromide","Trimipramine","Scopolamine","Tirofiban","Propiomazine","Cryptenamine","Sulfasalazine","Dicyclomine","Tropicamide","Brompheniramine","Sirolimus","Cocaine","Maprotiline","Glycopyrrolate","Amlexanox","Tolterodine","Thalidomide","Oxybutynin","Promethazine","Pilocarpine","Doxepin","Flavoxate","Desipramine","Naloxone","Ketamine","Quetiapine","Diphenidol","Aripiprazole","Chlorprothixene","Lapatinib","Mecasermin","Methotrimeprazine","Tiotropium","Solifenacin","Acetylcysteine","Fesoterodine","Cabozantinib","Ruxolitinib","Aflibercept","Aclidinium","Afatinib")
)


# Run ORA
xx = list()
library(clusterProfiler)
library(org.Hs.eg.db)




D0 = strsplit(readLines("~/pathome/revision/DSigDB_subset.gmt"),"\t")
D = lapply(D0,function(v)v[-(1:2)])
names(D) = sapply(D0,function(v)v[1])
d2g = do.call(rbind, lapply(1:length(D), function(i) {
 cbind(i,D[[names(D)[i]]])
}))
d2n = cbind(1:length(D), names(D))
kegg_organism = "hsa"


rt = parallel::mclapply(1:100, function(i) {
  rx = read.table(paste0("~/pathome/revision/data/phase1/pathome_input_hsa04310_", i, "/dataset.tt"), stringsAsFactors=F)
  xs = mapIds(org.Hs.eg.db, rx[,1], "ENTREZID", "SYMBOL")
  gn = xs[rx[,2] < 0.1]
  ogn = rx[rx[,2] < 0.1,1]
  kk <- try(enrichKEGG(gene=gn, universe=xs,
    organism="hsa",pvalueCutoff = 0.05, qvalueCutoff=0.1,
    keyType = "ncbi-geneid"), T)
 sigpw = kk@result[which(kk@result$qvalue < 0.1),1]
  dy = enricher(ogn,TERM2GENE=d2g,TERM2NAME=d2n)
  dy@result[which(dy@result$qvalue < 0.1),1]
  c("hsa04310" %in% sigpw, length(sigpw))
}, mc.cores=10)
sum(sapply(rt,function(v)v[1]) == 1)
mean(sapply(rt,function(v)v[2]-v[1]))


## 210523 남교수님 논의 반영
options(stringsAsFactors=F)
ag = toupper(read.csv("~/pathome/revision/data/drugbank_genes_pathome.csv")[,3])
ag2 = toupper(read.csv("~/pathome/revision/data/drugbank_genes_pathome_nonuniq.csv")[,1])
ag2t = table(ag2)
ag2 = names(ag2t)[which(ag2t>2)]




a = system('find GSE* -maxdepth 2 -name "webgestalt*txt"', T)
gse = sapply(strsplit(a,"/"),function(v)v[1])
res = lapply(a,readLines)
sg = res
setNames(sapply(sg,function(v) {
 r = v%in%ag
 r[is.na(r)] = FALSE
 sum(r)/length(v)
}), gse)


setNames(sapply(sg,function(v) {
 r = v%in%ag
 r[is.na(r)] = FALSE
 sum(r)
}), gse)


setNames(sapply(sg,function(v) {
 r = v%in%ag2
 r[is.na(r)] = FALSE
 sum(r)/length(v)
}), gse)


setNames(sapply(sg,function(v) {
 r = v%in%ag2
 r[is.na(r)] = FALSE
 sum(r)
}), gse)




library(clusterProfiler)
library(org.Hs.eg.db)
xxx = lapply(c("GSE13861","GSE36968","GSE37023","GSE27342","GSE63089","GSE47007","GSE15081","GSE15459"), function(v) {
  load(paste0("~/pathome/revision/data/phase1/", v, "/result.RData"))
  xs = mapIds(org.Hs.eg.db, names(sat[[1]]), "ENTREZID", "SYMBOL")
  gn = xs[sat[[2]] < 0.1]
  ogn = names(sat[[2]])[sat[[2]] < 0.1]
  dy = try(enricher(ogn,TERM2GENE=d2g,TERM2NAME=d2n), T)
  try(dy@result[which(dy@result$qvalue < 0.1),2], T)
})


library(WebGestaltR)
refFile <- system.file("extdata", "referenceGenes.txt", package="WebGestaltR")
ㅛ
xxx = lapply(c("GSE13861","GSE36968","GSE37023","GSE27342","GSE63089","GSE47007","GSE15081","GSE15459"), function(v) {
  r1 = try(read.table(paste0("~/pathome/revision/data/phase1/",v,"/",v,".tsv"),stringsAsFactors=F, header=T), T)
  if (class(r1) == 'try-error')r1 = try(read.table(paste0("~/pathome/revision/data/phase1/",v,"/",v,".tsv"),stringsAsFactors=F, header=T, sep="\t"), T)
  rdid = match(unique(r1[,1]),r1[,1])
  rd = r1[rdid,-1]
  rownames(rd) = r1[rdid,1]
  r2 = strsplit(readLines(paste0("~/pathome/revision/data/phase1/",v,"/",v,".cls"))[3], " ")[[1]]
 tr = unlist(parallel::mclapply(1:nrow(rd),function(ii) {
   try(t.test(rd[ii,r2=="c1"],rd[ii,r2=="c2"])$p.value, T)
  }, mc.cores=50))
  sa = setNames(tr, rownames(rd))
  sb = p.adjust(sa,method='BH')
  sat= list(sa,sb)
save(sat,file=paste0("~/pathome/revision/data/phase1/",v,"/result.RData"))
})




pw = c("04310", "04010", "04151", "04630")
nsim = 100


# Check status
tds = dir("~/pathome/revision/data/sim")
tds2 = sapply(strsplit(tds[grep("^hsa", tds)], "_|int|eff"), function(v)v[-c(2,5)])


D0 = strsplit(readLines("~/pathome/revision/DSigDB_subset.gmt"),"\t")
D = lapply(D0,function(v)v[-(1:2)])
names(D) = sapply(D0,function(v)v[1])


cpw = pw[1]
cset = tds2[,1]
allres.arr = list()
for (iiii in 1:ncol(tds2)) {
  cset = tds2[,iiii]
  cpw = cset[1]
  int1 = cset[2]
  int2 = cset[3]
  eff1 = cset[4]
  eff2 = cset[5]


  allres = list()
  xn = paste(cpw, int1, int2, eff1, eff2, sep="_")


  #### Fetch PATHOME-Drug step6 manually (DRUG)
  a0 = sapply(paste0("~/pathome/revision/data/sim/", cpw, "_int", int1, "_", int2, "_eff", eff1, "_", eff2, "/", 1:nsim, "/Step4_out"), file.exists)
  if (0 & sum(a0) == 100) {
    cat("PD status OK\n")
    allres$PD = parallel::mclapply(1:100, sum.PD, mc.cores=10)
  }


  #### Fetch WebGestalt step6 manually (DRUG)
  a0 = system(paste0("ls ~/pathome/revision/data/sim/", cpw, "_int", int1, "_", int2, "_eff", eff1, "_", eff2, "/*/wgDrugBank/Project*/enrichment*"), T)
  if (0 & length(a0) == 100)
    allres$WG = parallel::mclapply(a0, sum.WG, mc.cores=10)


  #### Fetch ORA step6 manually (DRUG)
  a0 = system(paste0("ls ~/pathome/revision/data/sim/", cpw, "_int", int1, "_", int2, "_eff", eff1, "_", eff2, "/*/ora.RData"), T)
  #library(clusterProfiler)
  #readLines("~/pathome/revision/DSigDB_subset.gmt"
  if (length(a0) == 100) {
    allres$OR = parallel::mclapply(a0, sum.OR, mc.cores=10)
    pow.pw = sum(unlist(lapply(allres$OR, function(v) {
     R = v[[1]]@result$ID[v[[1]]@result$qvalue < 0.1]
      cpw %in% R
    })) == cpw)
    pow.dr = sum(unlist(lapply(allres$OR, function(v) {
     R = v[[2]]@result$Description[v[[2]]@result$qvalue < 0.1]
      length(na.omit(match(R, tdrug[[cpw]]))) > 0
    })))
    cat(cpw, int1, int2, eff1, eff2, pow.pw, pow.dr, "\n")
  }
  allres.arr[[xn]] = allres
}