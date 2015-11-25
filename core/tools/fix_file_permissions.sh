#!/bin/sh

echo "All directories have exec bit for recursive reading"
find . -type d  -exec chmod -c 755 {} \;

echo "Everything in root is read only"
find . -maxdepth 1 -type f  -exec chmod -c 444 {} \;

echo "Files in data & pub writable by server, except for rcs files which are read-only"
find data -name '*.txt' -type f -exec chmod -c 644 {} \;
find pub -type f -exec chmod -c 644 {} \;
find data pub -name '*,v' -type f -exec chmod -c 444 {} \;

echo "Everything in data is writable by server."
find data -maxdepth 1 -type f  -exec chmod -c 644 {} \;

echo "bin and tools needs to be executable - with exceptions"
find bin -type f -exec chmod -c 555 {} \;
find tools -maxdepth 1 -type f -exec chmod -c 555 {} \;
echo " ... these are the exceptions:"
chmod -c 644 bin/LocalLib.cfg.txt
chmod -c 444 bin/setlib.cfg
chmod -c 444 tools/extender.pl

echo "Everything else is read only"
find lib -type f -exec chmod -c 444 {} \;
find locale -type f -exec chmod -c 444 {} \;
find templates -type f -exec chmod -c 444 {} \;

echo "Working is server writable - with exceptions"
find working -type f -exec chmod -c 644 {} \;
find working/configure -type f -exec chmod -c 444 {} \;
find working -name README -exec chmod -c 444 {} \;

echo "Restrict security related files should not be world readable."
find . -name .htaccess -exec chmod -c 440 {} \;
chmod -c 640 data/.htpasswd
chmod -c 640 lib/LocalSite.cfg 
