echo "building, it will take about 2 min"
gitbook build
cd _book
rm .gitignore
rm update_book.sh
git init
git remote add origin https://github.com/LearningOS/ucore_os_webdocs.git
git add .
git commit -m "update"
git push origin master -f
cd ..
