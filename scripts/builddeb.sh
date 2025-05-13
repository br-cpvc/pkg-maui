#!/bin/bash
set -ex
BUILD_NUMBER=$1

script_dir=$(dirname "$0")
cd ${script_dir}/..

srcdir="maui-3.3.1"
if [ -d $srcdir ]
then
    rm -rf $srcdir
fi

# from: https://wiki.debian.org/SimplePackagingTutorial
# section: Creating a basic source package

# Download the upstream source as tarball.
# Rename it to <source_package>_<upstream_version>.orig.tar.gz
# (eg. node-pretty-hrtime_1.0.3.orig.tar.gz).
if [ ! -f maui_3.3.1.orig.tar.gz ]; then
    # from https://twiki.cern.ch/twiki/bin/view/Main/TorqueAndMaui
    #curl https://twiki.cern.ch/twiki/pub/Main/TorqueAndMaui/maui-3.3.1.tar.gz -o maui_3.3.1.orig.tar.gz
    # from: https://support.adaptivecomputing.com/hpc-cloud-support-portal-2/
    curl --insecure https://support.adaptivecomputing.com/wp-content/uploads/filebase/maui-downloads/maui-3.3.1.tar.gz -o maui_3.3.1.orig.tar.gz
fi
md5sum -c maui_3.3.1.orig.tar.gz.md5sum
# Untar the tarball.
# Rename the directory to <source_package>-<upstream_version> (eg. node-pretty-hrtime-1.0.3).
tar -zxf maui_3.3.1.orig.tar.gz
# Switch to the above directory (eg. cd node-pretty-hrtime-1.0.3)
cd maui-3.3.1
# and run debmake
export DEBEMAIL="mauiusers@supercluster.org"
export DEBFULLNAME="Cluster Resources"
export TZ="Europe/Copenhagen"
faketime '2014-10-14 13:36:38 +0200' dh_make -s -y -e $DEBEMAIL
cp debian/init.d.ex debian/maui.init
cp debian/postinst.ex debian/maui.postinst
cd ..

# make copy for use when comparing via diff
mkdir -p original
cp -r $srcdir/debian original/

# and manually edited changes
cp debian/changelog $srcdir/debian/changelog
cp debian/control $srcdir/debian/control
cp debian/rules $srcdir/debian/rules
cp debian/maui.init $srcdir/debian/maui.init
cp debian/maui.postinst $srcdir/debian/maui.postinst

# show manually edited changed using diff
set +e
diff -r original/debian $srcdir/debian
set -e
#exit 0

cat << EOF > $srcdir/debian/conffiles
/var/spool/maui/maui.cfg
EOF

version="3.3.1-1"
package="maui"
arch="amd64"

#date=`date -u +%Y%m%d`
#echo "date=$date"

#gitrev=`git rev-parse HEAD | cut -b 1-8`
gitrevfull=`git rev-parse HEAD`
gitrevnum=`git log --oneline | wc -l | tr -d ' '`
#echo "gitrev=$gitrev"

buildtimestamp=`date -u +%Y%m%d-%H%M%S`
hostname=`hostname`
echo "build machine=${hostname}"
echo "build time=${buildtimestamp}"
echo "gitrevfull=$gitrevfull"
echo "gitrevnum=$gitrevnum"

debian_revision="${gitrevnum}"
upstream_version="${version}"
echo "upstream_version=$upstream_version"
echo "debian_revision=$debian_revision"

packageversion="${upstream_version}-github${debian_revision}"
packagename="${package}_${packageversion}_${arch}"
echo "packagename=$packagename"
packagefile="${packagename}.deb"
echo "packagefile=$packagefile"

rm -f ${package}_*.deb
sed -i 's/maui ('${upstream_version}'/maui ('${packageversion}'/' $srcdir/debian/changelog

echo "Creating .deb file: $packagefile"
cd $srcdir
fakeroot debian/rules binary
cd ..

dpkg -I $packagefile
