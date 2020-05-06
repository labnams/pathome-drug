<?php

$addr = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : "localhost";

/* Generate unique id */
$uid = md5(microtime().$addr);

/* Default value handling */
if (!isset($_POST['svg'])) $_POST['svg'] = "";
if (!isset($_POST['format'])) $_POST['format'] = "";
if (!isset($_POST['width'])) $_POST['width'] = 600;
if (!isset($_POST['height'])) $_POST['height'] = 400;

/* Get the contents */
$S_svg = $_POST['svg'];
$S_fmt = $_POST['format'];

if (!$S_svg) {
	$f = fopen("tmp/ae636eab331d326f33c54617e1286278.emf.svg", "r");
	$S_svg = fread($f, filesize("tmp/ae636eab331d326f33c54617e1286278.emf.svg"));
	$S_fmt = "emf";
}

$f = fopen("tmp/aa.txt", "w+");
fputs($f, $S_svg);
fclose($f);

$S_opt = "";

/* Check format
 * Check svg contents */
if (!in_array($S_fmt, array("pdf", "svg", "png", "emf", "jpg", "tif")) ||
	!strlen($S_svg)) {
	$S_svg = "error";
	$S_err = "INVALIDFILETYPE";
	$S_fmt = "jpg";
} else if ($S_fmt == "tif") {
	$S_opt = "-compress lzw -units PixelsPerInch -density 400";
}

/* Convert only there is no error */
if ($S_svg != "error") {
	$S_baseFn = $uid.'.'.$S_fmt;
	$S_out = 'tmp/'.$S_baseFn;

	/* Input type is always svg */
	$descriptorspec = array(
	   0 => array("pipe", "rb"),  // stdin is a pipe that the child will read from
	   1 => array("pipe", "w"),  // stdout is a pipe that the child will write to
	   2 => array("pipe", "w") // stderr is a file to write to
	);
	$S_in = $S_out.".svg";
	$H_fp = fopen($S_in, "w+");
	fputs($H_fp, $S_svg);
	fclose($H_fp);

	/* If TIF */
	if ($S_fmt == "tif") {
		$process = proc_open('/usr/bin/inkscape -z -e '.$S_in.'.png '.$S_in.' -w '.($_POST['width']*(400/72)).' -h '.($_POST['height']*(400/72)).' '.$S_out, $descriptorspec, $pipes);
		proc_close($process);
	} else if ($S_fmt == "emf") {
		chdir("tmp");
	}

	if ($S_fmt == "pdf")
		$process = proc_open('/usr/local/bin/rsvg-convert -f pdf -o '.$S_out.' '.$S_in, $descriptorspec, $pipes);
	else if ($S_fmt == "emf")
		$process = proc_open('/usr/share/java -jar /usr/bin/svg2emf.jar '.$S_baseFn.'.svg', $descriptorspec, $pipes);
	else if ($S_fmt == "tif")
		$process = proc_open('/usr/local/bin/convert '.$S_in.'.png '.$S_opt.' '.$S_out, $descriptorspec, $pipes);
	else if ($S_fmt == "png")
		$process = proc_open('/usr/local/bin/inkscape -d 300 -z -e '.$S_out.' '.$S_in, $descriptorspec, $pipes);
	else
		$process = proc_open('/usr/local/bin/convert '.$S_in.' '.$S_opt.' '.$S_out, $descriptorspec, $pipes);

//	echo 'convert '.$S_out.'.tmp '.$S_out;
//echo $process;
	/* Write to the stream */
//	fwrite($pipes[0], $S_svg);
//	fclose($pipes[0]);

	/* Get the contents */
//	fpassthru($pipes[1]);
//	fpassthru($pipes[2]);
	proc_close($process);
//	unlink($S_in);

	if ($S_fmt == "emf") {
		chdir("..");
		system('mv '.$S_in.'.emf '.$S_out);
	}
	/* Check file */
	if (!file_exists($S_out)) {
		$S_svg = "error";
		$S_err = "FAILEDTOGENERATE";
		$S_fmt = "jpg";
	}
}

$S_out = 'tmp/'.$uid.'.'.$S_fmt;

/* If there is an error, just copy */
if ($S_svg == "error") {
	copy($S_svg.'.'.$S_fmt, $S_out);
	$S_fn  = "error_".$S_err.".".$S_fmt;
} else
	$S_fn  = "result.".$S_fmt;

/* Downloader setting */
header('Set-Cookie: fileDownload=true; path=/');
header('Cache-Control: max-age=60, must-revalidate');
if ($S_fmt == "pdf")
	header("Content-Type: application/pdf");
else if ($S_fmt == "emf")
	header("Content-Type: image/emf");
else if ($S_fmt == "tif")
	header("Content-Type: image/tiff");
else if ($S_fmt == "png")
	header("Content-Type: image/png");
else if ($S_fmt == "jpg")
	header("Content-Type: image/jpeg");
else if ($S_fmt == "svg")
	header("Content-Type: image/svg+xml");
else
	header("Content-Type: text/csv");
header('Content-Disposition: attachment; filename="'.$S_fn.'"');
//exit;

/* Do fpassthru */
$H_out = fopen($S_out, "rb");
if (!$H_out) {
	echo $process;
	die(var_dump($S_out));
}
fpassthru($H_out);
fclose($H_out);

?>