JF4418 Bootloader Image Generator

1> For Windowns :

   Usage: 
   
   $ bootgen.exe output input
   
   Example:    
   
   $ bootgen.exe bootloader.bin u-boot
   
2> For Linux :
   
   Usage :
   
   $ ./bootgen output input
   
   Example :
   
   $ ./bootgen bootloader.bin u-boot

3> How to write booloader image into SC card :

   For Windowns :
   
   $ dd if=bootloader.bin of=\\.\g: bs=512 seek=1

   For Linux :

   $ dd if=bootloader.bin of=/dev/sdb bs=512 seek=1       