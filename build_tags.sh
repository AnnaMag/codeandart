#! /bin/bash
#Finds all unique tags, and creates a directory structure for them under
#<root>/tags/<tagname> with a list of the posts with that tag
set -e #Exit is any command returns a non-zero exit code
set -u #Exit if any command refers an unset variable

echo "Creating list of tags using sed"
sed -n '/^tags:/,/---/p' _posts/*.markdown > alltags.txt
echo "Reducing to unique entries only"
sort alltags.txt | uniq -u > uniquetags.txt
sort alltags.txt | uniq -d >> uniquetags.txt
rm alltags.txt

echo "Removing prepeding '- ' "
sed -i" " "s/- //g" uniquetags.txt

echo "Removing lines with tag: and --- in them"
sed -i" " "/tags:/d" uniquetags.txt
sed -i" " "/---/d" uniquetags.txt

#Slugify all lines
echo "Slugifying all entries"
cat uniquetags.txt | sed -e 's/[^[:alnum:]]/-/g' | tr -s '-' | tr A-Z a-z > slugs.txt
echo "Removing old tags directory"
rm -rf tags

echo "Creating Directories"
while read -u 3 -r tags_line && read -u 4 -r slugified_line; do
    mkdir -p "tags/$slugified_line"
    echo "---" > tags/$slugified_line/index.html
    echo "layout: tag_page" >> tags/$slugified_line/index.html
    echo "tag: $tags_line" >> tags/$slugified_line/index.html
    echo "---" >> tags/$slugified_line/index.html
done 3<uniquetags.txt 4<slugs.txt

rm uniquetags.txt
rm slugs.txt

#BSD linux doesn't allow inplace sed so a backup is made with a space at the end that must be removed
rm "uniquetags.txt "

echo "Completed!";
