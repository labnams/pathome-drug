<?php

$f = fopen($argv[1], "r");
$fo = fopen($argv[2], "w+");

$res = array();
while ($rr = trim(fgets($f))) {
	$res[$rr] = 1;
} 
fclose($f);

fputs($fo, join("\n", array_keys($res)));
fclose($fo);

?>
