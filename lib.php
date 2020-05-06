<?php

date_default_timezone_set("Asia/Seoul");
session_start();
if (isset($_GET['debug'])) {
	$_SESSION['debug'] = true;
}
if (isset($_GET['lang'])) {
	switch ($_GET['lang']) {
	case 'kr': $_SESSION['lang'] = 'kr'; break;
	case 'jp': $_SESSION['lang'] = 'jp'; break;
	case 'en': $_SESSION['lang'] = 'en'; break;
	default: die("Invalid language assigned"); break;
	}
}

function doR($S_R) {
	$descriptorspec = array(
	   0 => array("pipe", "r"),  // stdin is a pipe that the child will read from
	   1 => array("pipe", "w"),  // stdout is a pipe that the child will write to
	   2 => array("pipe", "w") // stderr is a file to write to
	);
	$process = proc_open("/usr/local/bin/R --no-save --slave --args ".$S_R, $descriptorspec, $pipes);

	if (is_resource($process)) {
		// $pipes now looks like this:
		// 0 => writeable handle connected to child stdin
		// 1 => readable handle connected to child stdout
		// Any error output will be appended to /tmp/error-output.txt

		$S_retSO = stream_get_contents($pipes[1]);
		fclose($pipes[1]);
		$S_retSE = stream_get_contents($pipes[2]);
		fclose($pipes[2]);

		// It is important that you close any pipes before calling
		// proc_close in order to avoid a deadlock
		$return_value = proc_close($process);
	}

	return strlen($S_retSE) ? $S_retSE : $S_retSO;
}

function doPerl($S_perl, $B_retSO=false) {
	global $_C;
	if ($_C['debug'])
		echo "[PERL] $S_perl\n";
	$descriptorspec = array(
	   0 => array("pipe", "r"),  // stdin is a pipe that the child will read from
	   1 => array("pipe", "w"),  // stdout is a pipe that the child will write to
	   2 => array("pipe", "w") // stderr is a file to write to
	);
	$process = proc_open("perl ".$S_perl, $descriptorspec, $pipes);

	if (is_resource($process)) {
		// $pipes now looks like this:
		// 0 => writeable handle connected to child stdin
		// 1 => readable handle connected to child stdout
		// Any error output will be appended to /tmp/error-output.txt

		$S_retSO = stream_get_contents($pipes[1]);
		fclose($pipes[1]);
		$S_retSE = stream_get_contents($pipes[2]);
		fclose($pipes[2]);

		// It is important that you close any pipes before calling
		// proc_close in order to avoid a deadlock
		$return_value = proc_close($process);
	}

	return !strlen($S_retSE) || $B_retSO ? $S_retSO : $S_retSE;
}

function doPHP($S_php, $B_retSO=false) {
	$descriptorspec = array(
	   0 => array("pipe", "r"),  // stdin is a pipe that the child will read from
	   1 => array("pipe", "w"),  // stdout is a pipe that the child will write to
	   2 => array("pipe", "w") // stderr is a file to write to
	);
	$process = proc_open("/usr/local/bin/php ".$S_php, $descriptorspec, $pipes);

	if (is_resource($process)) {
		// $pipes now looks like this:
		// 0 => writeable handle connected to child stdin
		// 1 => readable handle connected to child stdout
		// Any error output will be appended to /tmp/error-output.txt

		$S_retSO = stream_get_contents($pipes[1]);
		fclose($pipes[1]);
		$S_retSE = stream_get_contents($pipes[2]);
		fclose($pipes[2]);

		// It is important that you close any pipes before calling
		// proc_close in order to avoid a deadlock
		$return_value = proc_close($process);
	}

	return !strlen($S_retSE) || $B_retSO ? $S_retSO : $S_retSE;
}

function doNormal($S_cmd) {
	$descriptorspec = array(
	   0 => array("pipe", "r"),  // stdin is a pipe that the child will read from
	   1 => array("pipe", "w"),  // stdout is a pipe that the child will write to
	   2 => array("pipe", "w") // stderr is a file to write to
	);
	$process = proc_open($S_cmd, $descriptorspec, $pipes);

	if (is_resource($process)) {
		// $pipes now looks like this:
		// 0 => writeable handle connected to child stdin
		// 1 => readable handle connected to child stdout
		// Any error output will be appended to /tmp/error-output.txt

		$S_retSO = stream_get_contents($pipes[1]);
		fclose($pipes[1]);
		$S_retSE = stream_get_contents($pipes[2]);
		fclose($pipes[2]);

		// It is important that you close any pipes before calling
		// proc_close in order to avoid a deadlock
		$return_value = proc_close($process);
	}

	return strlen($S_retSE) ? $S_retSE : $S_retSO;
}

if (!isset($_SESSION['lang']))
	$_SESSION['lang'] = null;

if ($_SESSION['lang'] == 'kr')
$_L = array(
	'mainTitle'		=> 'PATHOME-drug',
	'lblUpload'		=> '데이터셋을 업로드',
	'lblUrl'		=> '혹은 데이터셋의 URL을 입력',
	'btnNewjob'		=> '분석 시작',
	'errNoInput'	=> '입력된 데이터셋이 없습니다',
	'errNoSig'		=> '유의한 서브패스웨이가 하나도 없습니다',
	'errIllInput'	=> '올바르지 않은 입력이 주어졌습니다',
	'errAmbgInput'	=> '데이터셋이 업로드됨과 동시에 URL도 입력되었네요. 뭘 써야 할 지 애매합니다',
	'errFileUpd'	=> '데이터셋을 서버에 전송하던 중 문제가 생겼어요',
	'errNoTask'		=> '요청하신 명령을 해석할 수가 없네요',
	'errMkJobDir'	=> '귀하의 작업이 처리될 공간을 만들지 못했어요',
	'errInvSIP'		=> '입력하신 데이터셋은 올바른 SIP 형식이 아니에요',
	'errConvSIP'	=> 'Failed to convert SIP file [%s]',
	'errNoJob'		=> '요청하신 작업이 서버에 없네요',
	'errOpPwayDir'	=> '서버가 패스웨이 정보를 찾아내지 못했어요',
	'errIntScript'	=> '분석하던 도중 다음 문제가 발생했어요. [%s] 이 메세지를 관리자에게 알려주세요',
	'errNoSigResult'=> '유의한 유전자가 발견되지 않았습니다',
	'lblJobId'		=> '작업 고유번호',
	'lblJobMkDate'	=> '작업 입력시간',
	'lblJobUpDate'	=> '작업 최종 업데이트',
	'lblJobProg'	=> '작업 진척도',
	'lblCurJobs'	=> '현재 저장된 작업들',
	'txtJobProg'	=> '%d 단계 완료됨 (총 %d 단계)',
	'lblJobTitle'	=> '작업 보기 (고유번호 %s)',
	'lblDebug'		=> '디버그 메세지',
	'lblStepNok'	=> '<font class="txtWait">대기 중</font>',
	'lblStepErr'	=> '<font class="txtErr">에러 발생!</font>',
	'lblStepOK'		=> '<font class="txtComp">완료됨</font>',
	'lblJobProgDt'	=> '자세히',
	'lblJobPanel'	=> '새로운 작업 입력',
	'txtJobStep'	=> '%d번째 단계',
	'lblLog2'		=> '입력 자료가 log2 변환됨',
	'txtPrepVis'	=> '시각화 다운로드를 준비 중입니다',
	'txtFailVis'	=> '시각화 생성에 실패하였습니다',
	'lblJobDown'	=> '작업 결과물 다운로드',
	'lbldownFC'		=> 'Fold change 정보 다운로드 (Cytoscape mrna format)',
	'lbldownGE'		=> '유의한 유전자 목록 다운로드',
	'lbldownFR'		=> '최종 결과 다운로드 (Cytoscape SIF format)',
	'lbldownFG'		=> 'Drug association을 포함하는 최종 결과 다운로드 (Cytoscape SIF format)',
	'lblJobOp'		=> '추가 작업',
	'lblJobDel'		=> '작업 삭제',
	'lblJobBkup'	=> '작업 내려받기',
	'txtJobDelCf'	=> '작업이 삭제되면 복구할 수 없습니다.\\n정말 삭제하시겠습니까?',
	'lblJobPvUpd'	=> '다시 그리기',
	'lblVisDB'		=> '데이터베이스와 연결해서 보기',
	'txtHpVisDB'	=> '아래 항목들을 선택하여 패스웨이에 어노테이션을 추가할 수 있습니다. 각 항목 옆의 숫자는 표시된 패스웨이에 포함된 유전자와 연관이 최소 해당 갯수만큼은 존재하는 항목만 보여주도록 조정합니다.',
	'lblVisSel'		=> '모두 선택',
	'lblVisUnsel'	=> '모두 선택 해제',
	'lblPvCutoff'	=> '초기 p-value 유의수준',
	'txtJobDelOk'	=> '작업이 성공적으로 삭제되었습니다',
	'txtGrpInfo'	=> '<b>그룹 [%s]<br />(샘플 수 %d)</b>',
	'lblJobSampInfo'=> '샘플 정보',
	'lblSpecies'	=> '샘플 종',
	'txtHuman'		=> '인간',
	'txtPvCutoff'	=> '<i>참고: 최대 p-value 한계치는 0.05 입니다.</i>',
	'txtDtSzLimit'	=> '<i>참고: 서버 성능 유지를 위해 업로드 가능한 최대 데이터셋 크기는 50메가바이트 이내로 제한됩니다.</i>',
	'lblJobOrigFN'	=> '입력 파일명',
	'lblJobDnData'	=> '데이터셋 다운로드',
	'txtCopyright'	=> '<center>PATHOME-drug 버전 1.0<br />대한민국 서울대학교 <a href="http://bibs.snu.ac.kr/">생물정보통계연구실</a>이 모든 권리를 보유합니다.</center>',
	'lblPathways'	=> 'Significant athways',
	'lblDiseases'	=> '질병 정보',
	'lblDrugbank'	=> '약 정보(Drugbank)',
	'lblDrugbankRO5'=> 'Drugbank w/ drug-likeness',
	'lblPharmGKB'	=> '약 정보(PharmGKB)',
	'lblPharmGKBRO5'=> 'PharmGKB w/ drug-likeness',
	'lblNone'		=> '표시하지 않음',
	'txtDtNote'		=> '<font style="font-weight:bold;color:red;">[주의!] 보안 정책에 의해 업로드할 파일의 확장자는 반드시 txt 여야 합니다.</font>',
	'lblSample'		=> '실행 예제',
	'lblDownSampDt'	=> '예제 SIP 파일 다운로드',
	'lblSeeSampDt'	=> '예제 실행 결과 보기',
	'lblDocum'		=> '도움말',
	'lblGCdata'		=> '위암 자료들',
	'lblResVis'		=> '결과 시각화',
	'lblCtrlVis'	=> 'Visualization control',
	'lblJobLog2tr'	=> '이미 log2 변환된 자료인가?',
	'txtYes'		=> '예',
	'txtNo'			=> '아니오',
	'fmtFullDate'	=> 'Y년 m월 d일 H시 i분 s초',
	'lblVisOpt'		=> 'Layout options',
	'lblActivation'	=> '활성화 관계',
	'lblInhibition'	=> '비활성화 관계',
);
else if ($_SESSION['lang'] == 'jp')
$_L = array(
	'mainTitle'		=> 'PATHOME-drug',
	'lblUpload'		=> 'データセットをアップロード',
	'lblUrl'		=> 'あるいはデータセットのURLを入力',
	'btnNewjob'		=> '分析を開始する',
	'errNoInput'	=> '入力されたデータセットが見つかりませんでした。',
	'errNoSig'		=> '統計的に意味のあるサブバスウェーが存在しません。',
	'errIllInput'	=> '不正な入力が与えられ、処理に失敗しました。',
	'errAmbgInput'	=> 'データセットがアップロードされた同時にURLも与えられ、どっちを使えばいいのかわかりません。',
	'errFileUpd'	=> 'データセットのアップロードに問題が生じました。',
	'errNoTask'		=> '要請の認識に失敗しました。',
	'errMkJobDir'	=> '分析を開始するための空間の確保に失敗しました。',
	'errInvSIP'		=> '与えられたデータセットはただしいSIPフォーマットではありません。',
	'errConvSIP'	=> 'データセットの変換が下記の理由のため失敗しました。[%s]',
	'errNoJob'		=> 'お探しの分析が見つかりませんでした。',
	'errOpPwayDir'	=> 'サーバーのパスウェイ情報に問題があります。',
	'errIntScript'	=> '分析中に問題が生じました。下記のエラーを伝達お願いいたします。[%s]',
	'errNoSigResult'=> 'No significant gene found from the input dataset',
	'lblJobId'		=> '分析の認識番号',
	'lblJobMkDate'	=> '分析の入力時間',
	'lblJobUpDate'	=> '分析状態の更新時間',
	'lblJobProg'	=> '分析の状態',
	'lblCurJobs'	=> '現在の分析のリスト',
	'txtJobProg'	=> '%dの段階が終了 (総計%d段階)',
	'lblJobTitle'	=> '分析を見る (認識番号 %s)',
	'lblDebug'		=> 'デバッグのメッセージ',
	'lblStepNok'	=> '<font class="txtWait">待機中</font>',
	'lblStepErr'	=> '<font class="txtErr">エラー発生！</font>',
	'lblStepOK'		=> '<font class="txtComp">完了</font>',
	'lblJobProgDt'	=> '詳しい状態',
	'lblJobPanel'	=> '새로운 작업 입력',
	'txtJobStep'	=> '%d番目の段階',
	'lblLog2'		=> 'log2変換されたデータセットです',
	'txtPrepVis'	=> '視覚化のダウンロードを準備しています。',
	'txtFailVis'	=> '視覚化の作成に失敗しました。',
	'lblJobDown'	=> '작업 결과물 다운로드',
	'lbldownFC'		=> 'Fold changeの情報をダウンロードする (Cytoscape mrna format)',
	'lbldownGE'		=> 'List of significant genes',
	'lbldownFR'		=> '最終の結果をダウンロードする (Cytoscape SIF format)',
	'lblJobOp'		=> '他の作業',
	'lblJobDel'		=> '分析を消去',
	'lblJobBkup'	=> '작업 내려받기',
	'txtJobDelCf'	=> '分析の消去は取り消しができません。\\n本当に消去しますか？',
	'lblJobPvUpd'	=> '描き直しする',
	'lblVisDB'		=> '데이터베이스와 연결해서 보기',
	'txtHpVisDB'	=> 'Turn on the checkbox to annotate the information to the visualization. Adjusting the number on right side will display the nodes only their adjacent nodes over or equal to that number.',
	'lblVisSel'		=> '모두 선택',
	'lblVisUnsel'	=> '모두 선택 해제',
	'lblPvCutoff'	=> 'Initial p-value cutoff',
	'txtJobDelOk'	=> '작업이 성공적으로 삭제되었습니다',
	'txtGrpInfo'	=> '<b>Group [%s]<br />(%d samples)</b>',
	'lblJobSampInfo'=> 'サンプルの情報',
	'lblSpecies'	=> 'サンプルの種',
	'txtHuman'		=> '人間',
	'txtPvCutoff'	=> '<i>参考: p-valueの最大数値は0.05に制限されます。</i>',
	'txtDtSzLimit'	=> '<i>参考: サーバー性能の維持のため、アップロードできるデータの大きさは５０メガに制限します。</i>',
	'lblJobOrigFN'	=> '入力されたファイル',
	'lblJobDnData'	=> '데이터셋 다운로드',
	'txtCopyright'	=> '<center>PATHOME-drug ヴァージョン 1.0<br />韓国のソウル大学の<a href="http://bibs.snu.ac.kr/">生物統計研究室（BIBS laboratory）</a>にすべて
	の権利があります。</center>',
	'lblPathways'	=> 'Significant pathways',
	'lblDiseases'	=> '疾患の情報',
	'lblDrugbank'	=> '薬の情報（Drugbank）',
	'lblDrugbankRO5'=> 'Drugbank w/ drug-likeness',
	'lblPharmGKB'	=> '薬の情報（PharmGKB）',
	'lblPharmGKBRO5'=> 'PharmGKB w/ drug-likeness',
	'lblNone'		=> '何も表示しまい',
	'txtDtNote'		=> '<font style="font-weight:bold;color:red;">[Important!] File extension should be ended with .txt (for our security reason).</font>',
	'lblSample'		=> 'Sample output',
	'lblDownSampDt'	=> 'Download the sample input SIP file',
	'lblSeeSampDt'	=> 'See the sample output',
	'lblDocum'		=> 'Documentation',
	'lblGCdata'		=> 'Gastric cancer datasets',
	'lblResVis'		=> 'Result visualization',
	'lblCtrlVis'	=> 'Visualization control',
	'lblJobLog2tr'	=> 'Is the data log2-transformed?',
	'txtYes'		=> 'はい',
	'txtNo'			=> 'いいえ',
	'fmtFullDate'	=> 'Y-m-d H:i:s',
	'lblVisOpt'		=> 'Layout options',
	'lblActivation'	=> '활성화 관계',
	'lblInhibition'	=> '비활성화 관계',
);
else
$_L = array(
	'mainTitle'		=> 'PATHOME-drug',
	'lblUpload'		=> '1. Upload dataset',
	'lblUrl'		=> 'or data URL',
	'btnNewjob'		=> 'Execute',
	'errNoInput'	=> 'No input found',
	'errNoSig'		=> 'No significant sub-pathway found!',
	'errIllInput'	=> 'Request failed due to illegal input',
	'errAmbgInput'	=> 'File and URL were given simultaneously, it is ambiguous!',
	'errFileUpd'	=> 'An error was occurred during file upload',
	'errNoTask'		=> 'A requested task was not found',
	'errMkJobDir'	=> 'Failed to create job workspace',
	'errInvSIP'		=> 'An input dataset is not valid SIP file',
	'errConvSIP'	=> 'Failed to convert SIP file [%s]',
	'errNoJob'		=> 'A requested job was not found',
	'errOpPwayDir'	=> 'Failed to retrieve pathway information',
	'errIntScript'	=> 'An error [%s] was occurred during internal script execution!',
	'errNoSigResult'=> 'No significant gene found from the input dataset',
	'lblJobId'		=> 'Job ID',
	'lblJobMkDate'	=> 'Date of submission',
	'lblJobUpDate'	=> 'Date of last update',
	'lblJobProg'	=> 'Job progress',
	'lblCurJobs'	=> 'Current jobs',
	'txtJobProg'	=> '%d/%d complete',
	'lblJobTitle'	=> 'Download & job description',
	'lblDebug'		=> 'Debug messages',
	'lblStepNok'	=> '<font class="txtWait">Waiting...</font>',
	'lblStepErr'	=> '<font class="txtErr">Error!</font>',
	'lblStepOK'		=> '<font class="txtComp">Complete</font>',
	'lblJobProgDt'	=> 'Detail',
	'lblJobPanel'	=> 'Submit a job',
	'txtJobStep'	=> 'Step %d',
	'lblLog2'		=> '2. Is the dataset log2-scaled?',
	'txtPrepVis'	=> 'Preparing visualization for download...',
	'txtFailVis'	=> 'Failed to prepare visualization',
	'lblJobDown'	=> 'Download results',
	'lbldownFC'		=> 'Fold-change information (Cytoscape mrna format)',
	'lbldownGE'		=> 'List of significant genes',
	'lbldownFR'		=> 'Final result file (Cytoscape SIF format)',
	'lbldownFG'		=> 'Final result file with drug association result (Cytoscape SIF format)',
	'lblJobOp'		=> 'Job management',
	'lblJobDel'		=> 'Delete job',
	'lblJobBkup'	=> 'Download job as portable',
	'txtJobDelCf'	=> 'Removed job cannot be recovered,\\ndo you want to remove this job?',
	'lblJobPvUpd'	=> 'Update result',
	'lblVisDB'		=> 'Annotation databases',
	'txtHpVisDB'	=> 'Turn on the checkbox to annotate the information to the visualization. Adjusting the number on right side will display the nodes only their adjacent nodes over or equal to that number.',
	'lblVisSel'		=> 'Select all',
	'lblVisUnsel'	=> 'Unselect all',
	'lblPvCutoff'	=> '3. Initial p-value cutoff <a href="?act=documentation#simpleUsage">[?]</a>',
	'txtJobDelOk'	=> 'Requested task has removed successfully',
	'txtGrpInfo'	=> '<b>Group [%s]<br />(%d samples)</b>',
	'lblJobSampInfo'=> 'Sample information',
	'lblSpecies'	=> 'Species',
	'txtHuman'		=> 'Human',
	'txtPvCutoff'	=> '<i>Note: Maximum p-value threshold is 0.05.</i>',
	'txtDtSzLimit'	=> '<i>Note: Maximum size of dataset is limited to 50 MiB.</i>',
	'lblJobOrigFN'	=> 'Original filename',
	'lblJobDnData'	=> 'Download dataset',
	'txtCopyright'	=> '<center>PATHOME-drug version 1.0<br />All rights reserved to <a href="http://bibs.snu.ac.kr/">BIBS laboratory</a>, Seoul National University, Korea.</center>',
	'lblPathways'	=> 'Significant pathways',
	'lblDiseases'	=> 'Diseases',
	'lblDrugbank'	=> 'Drugbank',
	'lblDrugbankRO5'=> 'Drugbank w/ drug-likeness',
	'lblPharmGKB'	=> 'PharmGKB',
	'lblPharmGKBRO5'=> 'PharmGKB w/ drug-likeness',
	'lblNone'		=> 'None',
	'txtDtNote'		=> '<font style="font-weight:bold;color:red;">[Important!] File extension should be ended with .txt (for our security reason).</font>',
	'lblSample'		=> 'Sample output',
	'lblDownSampDt'	=> 'download',
	'lblSeeSampDt'	=> 'Sample output',
	'lblDocum'		=> 'Help page',
	'lblGCdata'		=> 'Examples: gastric cancer',
	'lblResVis'		=> 'Result visualization',
	'lblCtrlVis'	=> 'Visualization control panel',
	'lblJobLog2tr'	=> 'Is the data log2-transformed?',
	'txtYes'		=> 'Yes',
	'txtNo'			=> 'No',
	'fmtFullDate'	=> 'Y-m-d H:i:s',
	'lblVisOpt'		=> 'Layout options',
	'lblActivation'	=> 'Activation relationship',
	'lblInhibition'	=> 'Inhibition relationship',
);

class pathomeEx extends Exception
{
	var $S_idJob;
	public function __construct($S_msg, $S_idJob="") {
		parent::__construct($S_msg);
		if (strlen($S_idJob))
			$this->S_idJob = $S_idJob;
	}
	public function __toString() {
		return __CLASS__ . ": [".$this->S_idJob."]: ".$this->message."\n";
	}
	public function getJob() {
		return $this->S_idJob;
	}
}

function msgError() {
	$E = error_get_last();
	return $E['message'];
}

function makeJob() {
	global $_C, $_L;

	$N_seed = 0;
	do {
		$S_idJob = md5(date("his").$_C['ip'].$N_seed);
		debug("Check job id [".$S_idJob."]");
		$N_seed++;
	} while (file_exists("jobs/".$S_idJob));

	debug("Job id [".$S_idJob."]");

	/* Create job directory */
	$S_pathJob = "jobs/".$S_idJob;
	if (!@mkdir($S_pathJob)) {
		debug("Job dir create fail, reason [".msgError()."]");
		throw new pathomeEx($_L['errMkJobDir']);
	}

	return $S_idJob;
}

function task() {
	try {
		myTask();
	} catch (pathomeEx $e) {
		debug("Task encountered an error [".$e->getMessage()."]");
		if ($e->getJob())
			delJob($e->getJob());
		return $e->getMessage();
	}
}

function delJob($S_idJob) {
	@system("rm -rf jobs/".$S_idJob);
}

function debug($str) {
	global $_C, $_D;

	if ($_C['ip'] == 'localhost') {
		global $S_dirJob;
		$S_logPath = $S_dirJob.'/log.txt';
		$H_fp = @fopen($S_logPath, 'a+');
		fputs($H_fp, "[".date("Y-m-d H:i:s")."] ".$str."\n");
		fclose($H_fp);
	}
	if ($_C['debug'])
		$_D[] = "[".date("Y-m-d H:i:s")."] ".$str."<br />";
}

$_D = array();
$_C = array(
	"debug"			=> isset($_GET['debug']) || isset($_SESSION['debug']) ? true : false,
	"ip"			=> isset($_SERVER['REMOTE_ADDR'])?$_SERVER['REMOTE_ADDR']:"localhost",
	"dirPathway"	=> "pathways/non-metabolic_KEGG_LinearPath"
);

function error($str) {
	return panel("Error", $str, "panelError");
}

?>