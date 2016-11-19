#! /bin/bash
#Finds all unique categories, and creates a directory structure for them under
#<root>/tags/<tagname> with a list of the posts with that category
set -e #Exit is any command returns a non-zero exit code
set -u #Exit if any command refers an unset variable

echo "Creating list of tags using sed"
sed -n '/^categories:/p' _posts/*.markdown > allcat.txt
echo "Reducing to unique entries only"
sort allcat.txt | uniq -u > uniquecat.txt
sort allcat.txt | uniq -d >> uniquecat.txt
rm allcat.txt

sed -e 's/categories://g' uniquecat.txt | tr "," "\n" |  uniq  > temp.txt
rm uniquecat.txt

#Slugify all lines
echo "Slugifying all entries"
cat temp.txt | tr A-Z a-z   > slugs.txt
echo "Removing old categories directory"
rm -rf categories

echo "Creating Directories"
while read -u 3 -r cat_line && read -u 4 -r slugified_line; do
    mkdir -p "categories/$slugified_line"
    echo "---" > categories/$slugified_line/index.html
    echo "layout: category_page" >> categories/$slugified_line/index.html
    echo "categories: $cat_line" >> categories/$slugified_line/index.html
    echo "---" >> categories/$slugified_line/index.html
done 3<temp.txt 4<slugs.txt

rm temp.txt
rm slugs.txt


echo "Completed!";
