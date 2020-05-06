<?php

include "lib_stat.php";

$conn = mysql_connect("localhost", "root", "bibs@)!$");
mysql_select_db("wisard");
$synonym = array(
	'/gamma/i' => 'γ',
	'/kappa/i' => 'κ',
	'/alpha/i' => 'α',
);

$A_disease = array();

/* Error checking */
if (!isset($_GET['id'])) die("[]");

/* Find job */
$S_idJob = $_GET['id'];

/* Set the path of dataset in temporary */
$S_dirJob		= 'jobs/'.$S_idJob;
$S_tmpPathData	= $S_dirJob.'/tmp_dataset';
$S_pathData		= $S_dirJob.'/dataset.sip';
$S_pathConfig	= $S_dirJob.'/dataset.cfg';
$S_pathFC		= $S_dirJob.'/dataset.fc';
$S_pathErr		= $S_dirJob.'/err.txt';
$S_pathSI		= $S_dirJob.'/dataset.si';
$S_outPrefix	= $S_dirJob.'/interm_';
$S_pathFinal	= $S_dirJob.'/Step6_out';

/* Read config file */
$H_cfg = @fopen($S_pathConfig, "r");
$A_cfg = array();
if ($H_cfg) {
	while ($A_curCfg = fgetcsv($H_cfg, 1024, "\t"))
		$A_cfg[$A_curCfg[0]] = $A_curCfg[1];
	fclose($H_cfg);
}

if (isset($_GET['gene']) && strlen($_GET['gene'])) {
	$A_genes = explode("|", $_GET['gene']);
//die("SELECT * FROM drugbank_rel AS a, drugbank_entry AS b WHERE a.genename IN ('".join("','", $A_genes)."') AND a.drugid = b.drugid");
	$elems = mysql_query("SELECT * FROM drugbank_rel AS a, drugbank_entry AS b WHERE a.genename IN ('".join("','", $A_genes)."') AND a.drugid = b.drugid");
	$pvals = array();
	while ($var = mysql_fetch_array($elems)) {
		$varr = $var['drugname'];
		$disname = strtolower(trim($varr));

		/* Skip if empty */
		if (!strlen($disname)) continue;

		/* Do not add if [x] */
		if (substr($disname, 0, 3) == "[x]") continue;
		
		/* Find all drugs */
		if (!isset($A_disease[$disname])) {
			$h_tgenes = mysql_query("SELECT DISTINCT(b.genename) FROM drugbank_entry AS a, drugbank_rel AS b WHERE a.drugname='".$disname."' AND a.drugid = b.drugid");
			$ngene = mysql_num_rows($h_tgenes);
			$n11 = $n12 = 0;
			if ($ngene) while ($eachgene = mysql_fetch_row($h_tgenes)) {
//				print_r($eachgene);
				if (in_array($eachgene[0], $A_genes))
					$n11++;
				else
					$n12++;
			}
			$n21 = count($A_genes) - $n11;
		}

		/* Remove trailing . */
		if ($disname[strlen($disname)-1] == '.')
			$disname = substr($disname, 0, strlen($disname)-1);

		/* Check comma */
		$cdisname = explode(",", $disname);
		if (count($cdisname) > 1) {
			$cdisname = array_reverse($cdisname);
			foreach ($cdisname as $n=>$v)
				$cdisname[$n] = trim($v);
			$disname = join(" ", $cdisname);
		}
		/* Rule change */
		foreach ($synonym as $from=>$to)
			$disname = preg_replace($from, $to, $disname);

		if (!isset($A_disease[$disname])) {
			$A_disease[$disname] = array(
				'genes' => array(),
				'table' => array($n11, $n12, $n21, $A_cfg['nprobe']-$n11-$n12-$n21)
			);
			$pvals[$disname] = exact22($n11, $n12, $n21, $A_cfg['nprobe']-$n11-$n12-$n21);
		}
//		print_r($A_disease);
		if (strlen($disname)) {
			if (!in_array($var['genename'], $A_disease[$disname]))
				$A_disease[$disname]['genes'][] = strtoupper($var['genename']);
		}
//		$A_disease[$disname]['table'][] = array($n11, $n12, $n21);
	}
	/* Perform q-transform */
	arsort($pvals);
	// cummin(n/i * p[o])
	$i = 1;
	$pvalss = array();
	$mpval = null;
	foreach ($pvals as $n=>$v) {
		$npv = count($pvals)/$i * $v;
//		echo $npv."<br />";
		if ($mpval === null)
			$pvalss[$n] = min(1, $npv);
		else
			$pvalss[$n] = min(1, min($mpval, $npv));
		$mpval = $pvalss[$n];
		$i++;
	}
	foreach ($A_disease as $n=>$v)
		$A_disease[$n]['qval'] = sprintf("%.2g", $pvalss[$n]);
//	var_dump($pvalss);
//	ksort($pvalss);
//	exit;

	if (isset($_GET['mine'])) foreach ($A_disease as $n=>$v) {
		if (count($v['genes']) < $_GET['mine'] || $v['qval'] >= 0.1)
			unset($A_disease[$n]);
	}
	if (isset($_GET['druglikeness'])) foreach ($A_disease as $n=>$v) {
		/* Get name */
		$S_idDrugbank = mysql_result(mysql_query("SELECT drugid FROM drugbank_entry WHERE drugname='".$n."'"), 0, 0);
		/* Check RO5 */
		$N_drugLikeness = mysql_result(mysql_query("SELECT druglikeness FROM drugbank_ro5 WHERE drugbankid='".$S_idDrugbank."'"), 0, 0);

		if ($N_drugLikeness != 1)
			unset($A_disease[$n]);
	}
	echo json_encode($A_disease);
}

?>