<?php

$conn = mysql_connect("localhost", "root", "bibs@)!$");
mysql_select_db("wisard");
$synonym = array(
	'diabetes, type 2' => 'type 2 diabetes',
	'diabetes mellitus type ii' => 'type 2 diabetes',
	'diabetes mellitus, type 2' => 'type 2 diabetes',
);

$A_disease = array();
if (isset($_GET['q']) && strlen($_GET['q'])) {
	list($class, $query) = explode(":", $_GET['q']);

	switch ($class) {
	case 'drug':
		$elems = mysql_query("SELECT * FROM drugbank_entry WHERE LOWER(drugname)=LOWER('".$query."')");
		$drug = @mysql_fetch_array($elems);

		$elems2 = mysql_query("SELECT * FROM drugbank_ro5 WHERE drugbankid='".$drug['drugid']."'");
		$drug2 = @mysql_fetch_array($elems2);

		echo "<h2>DrugBank compound [".$query."]</h2>";
		echo "<b>Name</b> : $query<br />";
		echo "<b>DrugBank ID</b> : ".$drug['drugid']."<br />";
		if ($drug['pgid']) {
			echo "<b>PharmGKB ID</b> : ".$drug['pgid']."<br />";
			echo "<b>PharmGKB info</b> : <a href='https://www.pharmgkb.org/drug/".$drug['pgid']."/overview' target='_new'>[See]</a><br />";
		}
		if (count($drug2) && strlen($drug2['numacc'])) {
			echo "<b># of acceptors, donors, rotatable bonds and heavy atoms</b> : ".
				$drug2['numacc'].", ".$drug2['numdoner'].", ".$drug2['numrot'].", ".$drug2['numhatom']."<br />";
			echo "<b>Mass</b> : ".
				$drug2['mass']."<br />";
			echo "<b>logp value</b> : ".
				$drug2['logp']."<br />";
			echo "<b>Drug-likeness</b> : ".
				($drug2['druglikeness'] ? $drug2['druglikeness'] : "<i>N/A</i>")."<br />";
		}
		echo "<b>DrugBank info</b> : <a href='http://www.drugbank.ca/drugs/".$drug['drugid']."' target='_new'>[See]</a><br />";
		echo "<i>Note: The numeral (q-value) of the parenthesis in the node indicates statistical enrichment of the compound-relating targets in the subnetwork.</i>";
		break;
	case 'gene':
		$elems = mysql_query("SELECT * FROM skc_assoc WHERE GENE='".$query."' AND ASSOC = 'Y'");
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
				if (isset($synonym[$disname]))
					$disname = $synonym[$disname];
				if (strlen($disname))
					$A_disease[$disname] = 1;
			}
		}
		$A_disease = array_keys($A_disease);

		echo "<h2>Gene [".$query."]</h2>";
		echo "<img src='http://cdn.genecards.org/images/v4/genomic-location/".$query."-gene.png' /><br />";
		echo "<b>Related diseases</b><ul>";
		if (count($A_disease)) foreach ($A_disease as $v) {
			echo "<li>".$v."</li>";
		} else echo "<i>None</i>";
		echo "</ul>";
		echo "<b>GeneCard info</b> : <a href='http://genecards.org/cgi-bin/carddisp.pl?gene=".$query."' target='_new'>[See]</a>";
		break;
	case 'phrm':
		$elems = mysql_query("SELECT drugid FROM pharmgkb WHERE drugname='".$query."'");
		$drugid = mysql_result($elems, 0, 0);

		echo "<h2>PharmGKB [".$query."]</h2>";
		echo "<b>Name</b> : $query<br />";
		echo "<b>PharmGKB ID</b> : ".$drugid."<br />";
		echo "<b>PharmGKB info</b> : <a href='https://www.pharmgkb.org/drug/".$drugid."/overview' target='_new'>[See]</a>";
		break;
	}
}

?>