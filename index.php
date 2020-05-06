<?php
if (0) {
?>
<script>
if (0) {
	Array.prototype.range = function() {
		var l = this.length;
		var V_min = this[0];
		var V_max = this[0];
		for (var i=1 ; i<l ; i++) {
			((V_min > this[i]) && (V_min = this[i])) ||
			((V_max < this[i]) && (V_max = this[i]));
		}
		return [V_min, V_max];
	}
	Array.prototype.range3 = function() {
		var l = this.length;
		var V_min = this[0];
		var V_max = this[0];
		for (var i=1 ; i<l ; i++) {
			var v = this[i];
			((V_min > v) && (V_min = v)) ||
			((V_max < v) && (V_max = v));
		}
		return [V_min, V_max];
	}
	Array.prototype.range2 = function() {
		var l = this.length;
		var V_min = this[0];
		var V_max = this[0];
		for (var i=1 ; i<l ; i++) {
			if (V_min > this[i]) V_min = this[i];
			else if (V_max < this[i]) V_max = this[i];
		}
		return [V_min, V_max];
	}
	function ff() {
		var s = [];
		var ss, q;
		for (var i=0 ; i<10000000 ; i++) s.push(Math.round(Math.random()*10000));
		ss = new Date();
		q = s.range2();
		console.log(q + " and " + (new Date() - ss)/1000);
		ss = new Date();
		q = s.range3();
		console.log(q + " and " + (new Date() - ss)/1000);
		ss = new Date();
		q = s.range();
		console.log(q + " and " + (new Date() - ss)/1000);
	}
}
</script>
<?php
}
include "lib.php";

if (isset($_GET['act'])) {
	/* Check file availability */
	$S_pathTask = "tasks/".$_GET['act'].".php";
	if (!file_exists($S_pathTask))
		error($_L['errNoTask']);
	/* Perform requested task */
	ob_start();
	/* Check file */
	if (!file_exists($S_pathTask))
		echo error("Page [".$_GET['act']."] does not exists!");
	else {
		include $S_pathTask;
		switch ($_GET['act']) {
		default:
			if ($S_error = task())
				echo error($S_error);
			break;
		}
	}
	$S_contents = ob_get_clean();
	ob_flush();
}

$width = 800;
if (isset($_GET['act']) && $_GET['act'] == 'viewjob')
	$width = "100%";

ob_start();

?>
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<meta name="viewport" content="width=device-width, user-scalable=no">
<style>
* {
text-shadow: 1px 1px 1px rgba(0,0,0,0.004);
text-rendering: optimizeLegibility !important;
-drugkit-font-smoothing: antialiased !important;
}

#txtComp {
	font-family:
	font:bold 1em Calibri, 'Malgun Gothic';
}
#title {
	border:solid 0.05em #cecece;
	font:bold 2em Calibri, 'Malgun Gothic';
	padding:0.2em;
	background-color:#f7f7f7;
	margin:0.2em;
	border-radius:0.125em;
}
#menu {
	font:bold 1.5em Calibri, 'Malgun Gothic';
	padding:0.3em;
	padding-bottom:0em;
	border-radius:0.25em;
	text-align:center;
}
#panel {
	border-radius:0.25em;
	border:solid 0.1em #cecece;
	font:1em Calibri, 'Malgun Gothic';
	padding:0.4em;
	margin:0.4em;
}
#panel2 {
	border-radius:0.25em;
	border:solid 0.1em #cecece;
	font:1em Calibri, 'Malgun Gothic';
	margin:0.4em;
	margin-top:1.5em;
}
#panelDivider {
	height:0.05em;
	background-color:#cecece;
}
#panelTitle {
	padding:0.3em;
	padding-left:0.6em;
	width:100%;
	font:bold 1.3em Calibri, 'Malgun Gothic';
}
#panelCell {
	padding:1em;
	width:100%;
}

#panelError {
	border:solid 0.1em #cecece;
	font:1em Calibri 'Malgun Gothic';
	background-color:#f7c7c7;
	margin:0.4em;
}

#menu a:link {
	color:black;
	text-decoration:none;
}
#menu a:visited {
	color:black;
}
#menu a:hover {
	color:black;
	border-bottom:2px solid red;
}
#menu .current {
	color:black;
	border-bottom:2px dashed #ff5566;
}

#copyright {
	font:1em Calibri, 'Malgun Gothic';
}

.panelTableHead {
	font-weight:bold;
	padding-right:1em;
}
</style>
</head>
<body>
<table align='center' width='<?=$width?>'><tr><td>
<!--<div id='title'>
	<a href="?"><?=$_L['mainTitle']?></a>
</div>-->
<div id='menu'>
	<a href='?' class="<?php if (!isset($_GET['act'])) echo "current"; ?>"><?=$_L['mainTitle']?></a>
	&nbsp;&nbsp;&nbsp;
	<a href='?act=submit' class="<?php if (isset($_GET['act']) && $_GET['act']=='submit') echo "current"; ?>"><?=$_L['lblJobPanel']?></a>
	&nbsp;&nbsp;&nbsp;
	<a href='?act=documentation' class="<?php if (isset($_GET['act']) && $_GET['act']=='documentation') echo "current"; ?>"><?=$_L['lblDocum']?></a>
	&nbsp;&nbsp;&nbsp;
	<a href='?act=gcdatasets' class="<?php if (isset($_GET['act']) && $_GET['act']=='gcdatasets') echo "current"; ?>"><?=$_L['lblGCdata']?></a>
</div>
<?php
function panel($S_title, $X_cont, $S_style="", $S_form=null, $S_id="") {
	$S_ret = "<div id='panel2' style='".$S_style."'><table cellspacing=0 cellpadding=0 border=0 width='100%'>\n";

	if ($S_form)
		echo '<form action="'.$S_form.'" method="post" enctype="multipart/form-data">';

	/* Print title unless it is available */
	if ($S_title) {
		$S_ret .= "		<tr><td id='panelTitle'>";
		if ($S_id) $S_ret .= "<a id='".$S_id."'>";
			
		$S_ret .= $S_title."</td></tr>
		<tr><td id='panelDivider'></td></tr>\n";
	}

	$S_ret .= "		<tr><td id='panelCell'>";
	if (is_array($X_cont)) {
		if (isset($X_cont[0]) && is_array($X_cont[0])) {
			array_walk($X_cont, function(&$a, $k) {
				if (is_array($a))
					$a = "<tr><td>".join("</td><td>", $a)."</td></tr>";
				else
					$a = "<tr><td colspan='2'>".$a."</td></tr>";
				$a .= "<tr><td colspan='2'><div style='width:100%;height:1px;'></div></td></tr>";
			});
			$S_ret .= "<table cellpadding=5 cellspacing=5>".join("", $X_cont)."</table>";
		} else
			$S_ret .= join("<br />", $X_cont);
	} else
		$S_ret .= $X_cont;
	$S_ret .= "</td></tr>
	</table></div>";

	return $S_ret;
}
if (isset($S_contents)) {
	echo $S_contents;
} else {
	echo panel("PATHOME-drug overview", "
<ul>
	<li>The translation of high-throughput gene expression data into biologically meaningful knowledge remains a bottleneck. Previously, we developed a novel computational algorithm, PATHOME (pathway and transcriptome), for detecting differentially expressed biological pathways. This algorithm employs straightforward statistical tests to evaluate the significance of differential expression patterns along subpathways.</li>
	<li>In our previous publication (<a href='http://www.nature.com/onc/journal/v33/n41/full/onc201480a.html' target='_new'>Oncogene (2014) 33, 4941–4951</a>), we applied the algorithm to gene expression data sets of gastric cancer (GC), identifying HNF4α-WNT5A regulation in the cross-talk between the AMPK metabolic pathway and the WNT signaling pathway. Also, we identified WNT5A as a novel potential therapeutic target for GC.</li>
	<li>For providing our algorithm to the biomedical society, we implemented the algorithm into a web server, called <font style='font-weight:bold;color:red;'>PATHOME-drug</font>.</li>
</ul>
<center>
	<div>
		<a href='images/pathome_150401_figWebMain.png'><img src='images/pathome_150401_figWebMain.png' width='700' /></a><br />
		<b>Figure 1.</b> Extraction of network from big data repository and its visualization.
	</div>
</center>
<br />
<i>Note: This section contains some parts of our previous publication (<a href='http://www.nature.com/onc/journal/v33/n41/full/onc201480a.html' target='_new'>Oncogene (2014), 33, 4941-4951</a>) under a Creative Commons Attribution-NonCommercial-NoDerivs 3.0 Unported License.</i><br />");

	echo panel("Key features", "<ul>
		<li>Big-data driven network inference</li>
		<li>Web-based visualization of results</li>
		<li>Drug enrichment analysis</li>
	</ul>", '', '?act=newjob&job=pathome');

	$H_dirJobRoot = opendir("jobs");
	$A_curJobList = array();
	while ($S_entryJob = readdir($H_dirJobRoot)) {
		$S_curJobPath = "jobs/".$S_entryJob;
		$A_curJobStat = stat($S_curJobPath);
		if (is_dir($S_curJobPath) && $S_entryJob != '.' && $S_entryJob != '..')
			$A_curJobList[] = "<a href='?act=viewjob&id=".$S_entryJob."'>".$S_entryJob."</a> (".date("Y-m-d H:i:s", $A_curJobStat['atime']).")";
	}

	echo panel($_L['lblSample'], "
	<ul>
		<li>Sample input dataset (<a href='?act=downjob&cat=dt&id=0330042215'>".$_L['lblDownSampDt']."</a>)
			<ul>
				<li>The sample dataset is the gastric cancer dataset (GEO accession: GSE15081) with the two groups: c1 (peritoneal relapse, 38 samples) vs. c2 (relapse-free, 18 samples).</i></li>
				<li>Since his dataset is log2-transformed dataset, there is no need to select '2. Is the dataset log2-scaled?' checkbox when submitting a job using this dataset.</li>
			</ul>
		</li>
		<li><a href='?act=viewjob&id=0330042215'>".$_L['lblSeeSampDt']."</a></li>
	</ul>");
//	echo panel($_L['lblCurJobs'], $A_curJobList);

	echo panel("Contact information", "
	<h3><li>Web server bug report</li></h3>
	<p>
		If there is a trouble during the preparation of dataset or the analysis, please let us know to resolve the problem via biznok@snu.ac.kr (Sungyoung Lee, the current maintainer).
	</p>
	<h3><li>Contacts</li></h3>
	<ul>
		<li>Prof. Taesung Park, Department of Statistics, Seoul National University, tspark@stats.snu.ac.kr <a href='http://bibs.snu.ac.kr/'>http://bibs.snu.ac.kr</a></li>
		<li>Dr. You Hui Kim, National Cancer Center, yhkim@ncc.re.kr <a href='http://www.ncc.re.kr/'>http://www.ncc.re.kr</a></li>
	</ul>");

	closedir($H_dirJobRoot);
}
echo "<font id='copyright'>".$_L['txtCopyright']."</font>
</td></tr></table>
</body>
</html>";

if (count($_D)) {
	echo panel($_L['lblDebug'], $_D); 
}

?>
