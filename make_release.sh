#!/bin/sh

RM="`which rm` -vrf"
MKDIR="`which mkdir` -p"

if [ "$1foo" = "foo" ]; then
        echo "usage: `basename $0` X.Y.Z"
        exit 1
fi

PKG="fantasdic-$1"
TAR_PKG="$PKG.tar.gz"
ZIP_PKG="$PKG.zip"
TMP_DIR="/tmp/$PKG"

echo "Creating temporary directory..."
$RM $TMP_DIR
$MKDIR $TMP_DIR
cp -r * $TMP_DIR
cd $TMP_DIR

echo "Removing unnecessary files..."
$RM `find . -name CVS -or -name ".*" -or -name "*~" -or -name "*.orig"`
$RM `find data/fantasdic/glade -name "*.gladep" -or -name "*.bak"`
$RM RELEASE_CHECKLIST make_release.sh InstalledFiles config.save
$RM data/locale lib/fantasdic/config.rb lib/fantasdic/version.rb
$RM po/fantasdic

echo "Updating version number..."
echo $1 > VERSION

echo "Creating man page"
mkdir -p data/man/man1/
docbook-to-man fantasdic.sgml > data/man/man1/fantasdic.1
gzip data/man/man1/fantasdic.1

cd ..

echo "Generating tarball..."
$RM $TAR_PKG 
tar -czf $TAR_PKG $PKG

echo "Generating zip..."
$RM $ZIP_PKG 
zip -r $ZIP_PKG $PKG

echo "Generated archives:"
du -h "`dirname $TMP_DIR`/$TAR_PKG"
du -h "`dirname $TMP_DIR`/$ZIP_PKG"

echo "Uploading to site"
echo $1 > LATEST
scp "`dirname $TMP_DIR`/$TAR_PKG" "`dirname $TMP_DIR`/$ZIP_PKG" LATEST \
matt@ffworld.com:~/www/files/fantasdic/

exit 0
