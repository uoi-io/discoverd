# Discoverd

Discoverd image is only useful to collect informations of an asset and learn howto build a ramdisk.

  - Interfaces name, speed, status, mac, etc...
  - Processor, memory
  - Virtual machine, physical server

### Build the image

Build the discoverd image is easy, just run the ``mkdiscoverd.sh`` script. Before running this script be dure that ``debootstrap`` *(this packages exists on Red Hat distributions)* and ``sudo`` packages are installed.
```sh
$ git clone git@github.com:uoi-io/discoverd.git
$ cd discoverd
$ ./mkdiscoverd.sh
```
When the build is done, a directory named ``generated`` has been created the ``discoverd.img.gz`` ramdisk and the ``vmlinuz`` associated to this ramdisk.

### Extract the image

For some reasons you might want extract the image to add scripts, files, etc... To avoid a full rebuild just follow the steps below.
```sh
$ gunzip discoverd.img.gz
$ mkdir discoverd ; cd discoverd
$ cpio -idv < ../discoverd.img
$ echo "> UOI DISCOVERD IMAGE <" > etc/motd
$ mkdir opt/folder1
```

Then rebuild the image with the changes made.
```
$ find . | cpio -H newc -o | gzip -v -c > ../discoverd.img.gz
```
