#!/bin/sh

# look for old 0.x cruft, and get rid of it.
# we're already in the npm folder

node="$NODE"
if [ "x$node" = "x" ]; then
  node=`which node`
fi
if [ "x$node" = "x" ]; then
  echo "Can't find node to determine prefix. Aborting."
fi


PREFIX=`dirname $node`
PREFIX=`dirname $PREFIX`
echo "prefix=$PREFIX"
PREFIXES=$PREFIX

altprefix=`$node -e process.installPrefix`
if ! [ "x$altprefix" = "x" ] && ! [ "x$altprefix" = "x$PREFIX" ]; then
  echo "altprefix=$altprefix"
  PREFIXES="$PREFIX $altprefix"
fi


# now prefix is where npm would be rooted by default
# go hunting.

packages=
for prefix in $PREFIXES; do
  packages="$packages
    "`ls "$prefix"/lib/node/.npm 2>/dev/null | grep -v .cache`
done

packages=`echo $packages`

echo ""
echo "This script will find and eliminate any shims, symbolic"
echo "links, and other cruft that was installed by npm 0.x."
echo ""

if ! [ "x$packages" = "x" ]; then
  echo "The following packages appear to have been installed with"
  echo "an old version of npm, and will be removed forcibly:"
  for pkg in $packages; do
    echo "    $pkg"
  done
  echo "Make a note of these. You may install them with"
  echo "npm 1.0 when this process is completed."
  echo ""
fi

OK=
if [ "x$1" = "x-y" ]; then
  OK="yes"
fi

while ! [ "$OK" = "y" ] && ! [ "$OK" = "yes" ] && ! [ "$OK" = "no" ]; do
  echo "Is this OK? enter 'yes' or 'no' "
  read OK
done
if [ "$OK" = "no" ]; then
  echo "Aborting"
  exit 1
fi

filelist=""

for prefix in $PREFIXES; do
  # remove any links into the .npm dir, or links to
  # version-named shims/symlinks.
  for folder in share/man bin lib/node; do
    find $prefix/$folder -type l | while read file; do
      target=`readlink $file | grep '/\.npm/'`
      if ! [ "x$target" = "x" ]; then
        # found one!
        echo rm -rf "$file"
        rm -rf "$file"
        # also remove any symlinks to this file.
        base=`basename "$file"`
        base=`echo "$base" | awk -F@ '{print $1}'`
        if ! [ "x$base" = "x" ]; then
          find "`dirname $file`" -type l -name "$base"'*' \
          | while read l; do
              target=`readlink "$l" | grep "$base"`
              if ! [ "x$target" = "x" ]; then
                echo rm -rf $l
                rm -rf $l
              fi
            done
        fi
      fi
    done

    # Scour for shim files.  These are relics of 0.2 npm installs.
    # note: grep -r is not portable.
    find $prefix/$folder -type f \
      | xargs grep -sl '// generated by npm' \
      | while read file; do
          echo rm -rf $file
          rm -rf $file
        done
  done

  # now remove the package modules, and the .npm folder itself.
  if ! [ "x$packages" = "x" ]; then
    for pkg in $packages; do
      echo rm -rf $prefix/lib/node/$pkg
      rm -rf $prefix/lib/node/$pkg
      echo rm -rf $prefix/lib/node/$pkg\@*
      rm -rf $prefix/lib/node/$pkg\@*
    done
  fi

  for folder in lib/node/.npm lib/npm share/npm; do
    if [ -d $prefix/$folder ]; then
      echo rm -rf $prefix/$folder
      rm -rf $prefix/$folder
    fi
  done
done

exit 0
