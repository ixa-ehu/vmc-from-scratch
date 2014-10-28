<?php

$preKafkaDir = "/tmp/upload_file_to_queue";
$pushToKafkaPath = "/home/newsreader/opt/sbin/push_queue";
$minFreeSpace = 419430400; // byte-etan 400MB fitxategia kargatzeko diskoan eskatuko leku minimoa
$maxInputFiles = 35000; // input katalogoan zenbat fitxategi onartzen ditugun

if (!file_exists($preKafkaDir)) {
    mkdir($preKafkaDir);         
} 

if (disk_free_space($preKafkaDir) < $minFreeSpace ) {

  echo "FORBIDDEN UPLOAD - Disk full. Please empty doc dirs.\n";
  echo "Free space: ".((disk_free_space($inputDir))/1048576)." MB\n";
  exit;

}

$allowedExts = array("naf","xml","txt");
$temp = explode(".", $_FILES["file"]["name"]);
$extension = end($temp);

if (($_FILES["file"]["size"] < 2097152) && in_array($extension, $allowedExts))
  {
  if ($_FILES["file"]["error"] > 0)
    {
    echo "Return Code: " . $_FILES["file"]["error"] . "\n";
    }
  else
    {

      echo "Upload: " . $_FILES["file"]["name"] . "\n";
      echo "Type: " . $_FILES["file"]["type"] . "\n";
      echo "Size: " . ($_FILES["file"]["size"] / 1024) . " kB\n";
  
      if (file_exists($preKafkaDir."/".$_FILES["file"]["name"]))
	{
	  echo "ERROR: ".$_FILES["file"]["name"] . " already exists.\n";
	}
      else
	{
	  move_uploaded_file($_FILES["file"]["tmp_name"], $preKafkaDir."/".$_FILES["file"]["name"]);
	  system($pushToKafkaPath." -f ".$preKafkaDir."/".$_FILES["file"]["name"], $returnvar);
	  unlink ($preKafkaDir."/".$_FILES["file"]["name"]);
	  if ($returnvar != 0) {echo "ERROR: ".$pushToKafkaPath."\n";}

	}

    }

  }
else
  {
    echo "ERROR: Invalid file.\n";
    echo "TYPE: ".$_FILES["file"]["type"];
  }
?>
