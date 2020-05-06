<?php

ignore_user_abort(true); 
set_time_limit(0);

include "lib.php";
if (isset($argv[5])) {
	$_C['debug'] = 1;
	debug("Debug mode ON\n");
}

$S_idJob		= $argv[1];
$S_dirJob		= 'jobs/'.$S_idJob;

try {
	$chipname		= "bin/PATHOMEWEBSERVER_v_HGNC20140623.dummy.chip";
	$R_pvalThr		= $argv[2];
	$B_dataLog2		= $argv[3];
	$S_origFN		= base64_decode($argv[4]);
	if (!file_exists($S_dirJob)) {
		throw new pathomeEx("No such job [".$S_idJob."]");
	}
	$S_tmpPathData	= $S_dirJob.'/tmp_dataset';
	$S_pathData		= $S_dirJob.'/dataset_nr.sip';
	$S_pathOdata	= $S_dirJob.'/dataset.sip';
	$S_pathConfig	= $S_dirJob.'/dataset.cfg';
	$S_pathPdata	= $S_dirJob.'/dataset_checked.sip';
	$S_outPrefix	= $S_dirJob.'/interm_';
	$S_pathFC		= $S_dirJob.'/dataset.fc';
	$S_pathTTest	= $S_dirJob.'/dataset.tt';
	$S_pathFChist	= $S_dirJob.'/hist.fc.png';
	$S_pathSI		= $S_dirJob.'/dataset.si';

//	$N_probe		= `wc -l $S_dirJob/$S_origFN`;
//	$N_probe		= array_shift(explode(" ", trim($N_probe)));

	/* Save the config */
	$A_cfg = array();
	$H_cfg = fopen($S_pathConfig, "w+");
	debug("Save setting to [".$S_pathConfig."]");
	fputs($H_cfg, "jobid	".$S_idJob."\n");
	fputs($H_cfg, "datalog2	".$B_dataLog2."\n");
	fputs($H_cfg, "pvalthr	".$R_pvalThr."\n");
	fputs($H_cfg, "filename	".$S_origFN."\n");
//	fputs($H_cfg, "nprobe	".$N_probe."\n");
	fclose($H_cfg);

	/* Check file integrity */
	$S_codeStep0 = "bin/0_isCorrectSIPFormat.pl -sip ".$S_pathOdata;
	debug("Perl exec [".$S_codeStep0."]");
	$S_ret = doPerl($S_codeStep0);
	flush();

	/* If the checking is failed */
	$A_step2out = array();
	if (substr($S_ret, 0, 7) != "SUCCESS")
		throw new pathomeEx($_L['errInvSIP'], $S_idJob);
	else {
		/* Check file integrity #2 */
		$S_codeStep0 = "bin/0_1_checkNumericMatrixInSIPFormat.pl -sip ".$S_pathOdata." -o ".$S_pathPdata;
		debug("Perl exec [".$S_codeStep0."]");
		$S_ret = doPerl($S_codeStep0);
		flush();
		if (substr($S_ret, 0, 7) != "SUCCESS")
			throw new pathomeEx(sprintf($_L['errConvSIP'], trim($S_ret)), $S_idJob);

		/* Make NR */
		if ($B_dataLog2)
			$S_codeStep00 = "bin/2_MakeNRExprData.pl -l -i ".$S_pathPdata." -c $chipname > ".$S_pathData;
		else
			$S_codeStep00 = "bin/2_MakeNRExprData.pl -i ".$S_pathPdata." -c $chipname > ".$S_pathData;
		debug("Perl make NR exec [".$S_codeStep00."]");
		$S_ret = explode("\n", doPerl($S_codeStep00));
		flush();
		print_r($S_ret);
		foreach ($S_ret as $S_subRet)
			if (substr($S_subRet, 0, 5) == "ERROR")
				throw new pathomeEx(sprintf($_L['errConvSIP'], $S_subRet), $S_idJob);
		$N_probe                = `wc -l $S_pathData`;
		$N_probe                = array_shift(explode(" ", trim($N_probe)));

		$H_cfg = fopen($S_pathConfig, "a+");
		fputs($H_cfg, "nprobe	".$N_probe."\n");
		fclose($H_cfg);
//exit;

		/* Find out pathways */
		$H_dirPway = @opendir($_C['dirPathway']);
		if (!$H_dirPway)
			throw new pathomeEx($_L['errOpPwayDir'], $S_idJob);

		/* Perform step 0 */
		$S_codeStep01 = " ".$S_pathPdata." ".$S_pathTTest." < bin/R_ttest.R";
		doR($S_codeStep01);
		debug("R t-test");

		/* Perform step 1 */
		$A_pwayFiles = array();
		while ($S_pwayFile = readdir($H_dirPway)) {
			$S_curFullPath = $_C['dirPathway'].'/'.$S_pwayFile;
			if (is_file($S_curFullPath))
				$A_pwayFiles[] = $S_pwayFile;
		}
		closedir($H_dirPway);
		debug("Pathway scan found [".count($A_pwayFiles)."] pathways");

		/* For each pathway, do an analysis */
		$q = 0;
		foreach ($A_pwayFiles as $N_pwayIdx=>$S_pwayFile) {
			if ($N_pwayIdx == 0) {
				debug("Fold change count\n");
				$S_calcFC = " 1";
			} else
				$S_calcFC = "";
			$S_curPrefix = $S_outPrefix.$S_pwayFile;
/*
			$S_codeStep1 = "bin/1_calcoef2 ".$_C['dirPathway']."/".$S_pwayFile." ".$S_pathData." ".$S_curPrefix.$S_calcFC;

			debug("C exec [".$S_codeStep1."]");
			$A_ret	= explode("\n", trim(doNormal($S_codeStep1)));
			$S_last	= $A_ret[count($A_ret)-1];
			if (substr($S_last, 0, 6) == "SYSERR")
				throw new pathomeEx(sprintf($_L['errIntScript'], substr($S_last, 8)), $S_idJob);
			print_r($A_ret);
			echo "\n";

			/* Retrieve FC and sampleInfo *
			if ($N_pwayIdx == 0) {
				rename($S_curPrefix.".foldChange", $S_pathFC);
				rename($S_curPrefix.".sampleInfo", $S_pathSI);
			}

			$S_curStep1out = $S_curPrefix.".fisherCorr";
			$S_curStep2out = $S_curPrefix."_f_pval";
			if (filesize($S_curStep1out)) {
				$S_codeStep2 = "-i ".$S_curStep1out." -o ".$S_curStep2out." < bin/Step2_TtestFromFisherCorrUnderCutoff_ver3.R";
				$A_step2out[] = $S_curStep2out;
				debug("R exec [".$S_codeStep2."]");
				$A_ret	= explode("\n", trim(doR($S_codeStep2)));
				print_r($A_ret);
			}
			if (!file_exists($S_curStep2out))
				touch($S_curStep2out);
			echo "\n";*/

			$S_codeStep1 = "bin/1_calcoef3 ".$_C['dirPathway']."/".$S_pwayFile." ".$S_pathData." ".$S_curPrefix.$S_calcFC;

			debug("C exec [".$S_codeStep1."]");
			$A_ret	= explode("\n", trim(doNormal($S_codeStep1)));
			$S_last	= $A_ret[count($A_ret)-1];

			/* Retrieve FC and sampleInfo */
			if ($N_pwayIdx == 0) {
				rename($S_curPrefix.".foldChange", $S_pathFC);
				rename($S_curPrefix.".sampleInfo", $S_pathSI);
			}

			$S_filePv = $S_curPrefix."_f_pval";
			if (filesize($S_filePv) >= 50)
				$A_step2out[] = $S_curPrefix."_f_pval";
			debug("Outsize [".filesize($S_filePv)."]");

			if (substr($S_last, 0, 6) == "SYSERR")
				throw new pathomeEx(sprintf($_L['errIntScript'], substr($S_last, 8)), $S_idJob);
			print_r($A_ret);
			echo "\n";
		}
		flush();
	}

	/* Perform step 3_0 */
//	$S_codeStep30 = "bin/Step3_0_visDataset.R -i ".$S_pathFC." -o ".$S_pathFChist);

	/* Perform step 3_1 */
	$S_codeStep3 = "bin/Step3_1_GetPvalues_GivenCutoff.pl -pvalDir '".join(" ", $A_step2out)."' -pathDir ".$_C['dirPathway']." -cutoff ".$R_pvalThr." > ".$S_dirJob."/Step3_1.pval";
	debug("Perl exec [".$S_codeStep3."]");
	$S_ret = doPerl($S_codeStep3);

	/* Perform step 3_2 */
	$S_codeStep32 = " -i ".$S_dirJob."/Step3_1.pval -o ".$S_dirJob."/Step3_2_sorted_pval_qval_table_for_Step3_1 < bin/Step3_2_TableForAllPValuesAndTheirQValues.R";
	debug("R exec [".$S_codeStep32."]");
	$S_ret = doR($S_codeStep32);
	print_r($S_ret);
	if (!file_exists($S_dirJob."/Step3_2_sorted_pval_qval_table_for_Step3_1"))
		throw new pathomeEx($_L['errNoSigResult'], $S_idJob);

	/* Perform step 3_3 */
	$S_codeStep33 = "bin/Step3_3_GetInformation.pl -pvalDir '".join(" ", $A_step2out)."' -pathDir ".$_C['dirPathway']." -cutoff ".$R_pvalThr." > ".$S_dirJob."/Step3_3_sig_pval_subpath.txt";
	debug("Perl exec [".$S_codeStep33."]");
	$S_ret = doPerl($S_codeStep33);

	/* Perform step 4 */
	$S_codeStep4 = "bin/Step4_make_sig_pval_subpath_AllInfo_with_qval.pl -sigPaths ".$S_dirJob."/Step3_3_sig_pval_subpath.txt -fdr ".$S_dirJob."/Step3_2_sorted_pval_qval_table_for_Step3_1 > ".$S_dirJob."/Step4_out";
	$S_ret = doPerl($S_codeStep4);

	/* Perform step 5 */
	$S_codeStep5 = "bin/Step5_parse_sig_pval_subpath_To_SIF.pl -sigPaths ".$S_dirJob."/Step3_3_sig_pval_subpath.txt > ".$S_dirJob."/Step5_out";
	$S_ret = doPerl($S_codeStep5);

	/* Perform step 6 */
	$S_codeStep6 = "bin/Step6_remove_redundant.php ".$S_dirJob."/Step5_out ".$S_dirJob."/Step6_out";
	$S_ret = doPHP($S_codeStep6);
} catch (pathomeEx $e) {
	$fp = @fopen($S_dirJob.'/err.txt', 'w+');
	if (!$fp) {
		die("Failed to write an error [".$e->getMessage()."]\n");
	} else {
		fputs($fp, $e->getMessage());
		fclose($fp);
		die("Failed to write an error [".$e->getMessage()."]\n");
	}
}

?>
