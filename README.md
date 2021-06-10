# PATHOME-Drug
PATHOME-Drug is a web-based interfarce that implements network-aware statistical test for expression dataset, based on KEGG pathways. In addition, this repository provides the codes for PATHOME-Drug, including:
 - A full set of both PATHOME-Drug web interface and its backend PHP codes,
 - A bootstrapping database definition for PATHOME-Drug web interface, and
 - R codes that were used in the PATHOME-Drug paper.

If there is any question, plase contact via the following address.
 - Seungyoon Nam, seungyoon.nam@gmail.com)
 
## PATHOME-Drug interface
The PATHOME-Drug web interface is provided as either of
 - An implemented, analysis-ready web server (http://statgen.snu.ac.kr/software/pathome/) or
 - A set of source code and bootstrapping database that enables the user's standalone webserver.

## Prerequisites
To use PATHOME-Drug web-based interface locally, the followings are required.
 - FreeBSD 8
 - PHP version 7 or greater
 - MySQL version 4 or greater
 - Perl version 5 or greater
 - R version 3.3.3 or greater, including the following R packages:
   - getopt
   - R.utils

To execute R codes that were used in the PATHOME-Drug paper, the followings are required.
 - All the prerequisites for PATHOME-Drug web-based interface, except R version
 - R version 4.0 or greater, including the following R packages:
   - KEGGgraph
   - Rgraphviz
   - bnlearn
   - predictionet
   - WebGestaltR
   - clusterProfiler
   - org.Hs.eg.db
   - limma

## PATHOME-Drug install
1. Pull the repository.
2. Unzip pathways.7z using 7zip.
3. Create 'tasks' and 'jobs' directories with 777 permission.
4. Create the database for PATHOME-Drug and feed the bootstrapping database.
5. Set the database connection information from xxx.php
6. Open the browser and connect to the website.

## R codes for the paper
The R codes include the following functionalities for producing the results of the paper.
1. Download the KEGG pathway graphs for performing the simulation.
2. Generate the simulation dataset under the specified parameters.
3. Perform the analyses using PATHOME-Drug, WebGestalt and ClusterProfiler.
