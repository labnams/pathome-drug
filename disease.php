<?php

$conn = mysql_connect("localhost", "root", "bibs@)!$");
mysql_select_db("wisard");
$synonym = array(
	'/diabetes, type 2/i' => 'type 2 diabetes',
	'/diabetes mellitus type ii/i' => 'type 2 diabetes',
	'/diabetes mellitus, type 2/i' => 'type 2 diabetes',
	'/neoplasm[s*]/i' => 'cancer',
	'/cancers/i' => 'cancer',
	'/diseases/i' => 'disease',
);

$A_disease = array();
if (isset($_GET['gene']) && strlen($_GET['gene'])) {
	$A_genes = explode("|", $_GET['gene']);

	$elems = mysql_query("SELECT * FROM skc_assoc WHERE GENE IN ('".join("','", $A_genes)."') AND ASSOC != ''");
	while ($var = mysql_fetch_array($elems)) {
		$vars = split("\||;", $var['BROADPHENO']);
		foreach ($vars as $varr) {
			$disname = strtolower(trim($varr));

			/* Skip if empty */
			if (!strlen($disname)) continue;

			/* Do not add if [x] */
			if (substr($disname, 0, 3) == "[x]") continue;
			
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
			if (strlen($disname)) {
				if (!isset($A_disease[$disname]))
					$A_disease[$disname] = array();
				if (!in_array($var['GENE'], $A_disease[$disname]))
					$A_disease[$disname][] = strtoupper($var['GENE']);
			}
		}
	}
	if (isset($_GET['mine'])) foreach ($A_disease as $n=>$v)
		if (count($v) < $_GET['mine'])
			unset($A_disease[$n]);
	echo json_encode($A_disease);
}

?>