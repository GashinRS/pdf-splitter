#!/bin/bash

slidesPerPage=2
threshold=500

syntax() {
  message="usage: pdf-splitter.sh [-p number of slides per page, default=2] [-s threshold, default = 500] filename.pdf
          Threshold is the maximum page count for which the script will not split the file.
          Splitting the file is necessary for large files, but will make the script slower."
  echo >&2 "$message"
  exit 1
}

isyntax() {
  echo >&2 "Please provide a strict positive integer to the option"
  exit 1
}

while getopts ":p:s:h" opt; do
  case $opt in
  p)
    slidesPerPage=${OPTARG}
    if [[ ! "$slidesPerPage" =~ ^[0-9]+$ ]]; then
      isyntax
    fi
    ;;
  s)
    threshold=${OPTARG}
    if [[ ! "$threshold" =~ ^[0-9]+$ ]]; then
      isyntax
    fi
    ;;
  h)
    syntax
    ;;
  \?)
    syntax
    ;;
  :)
    syntax
    ;;
  esac
done
shift $((OPTIND - 1))

if [[ $# -ne 1 ]]; then
  echo "Illegal number of arguments. Provide one file name."
  exit 3
elif [[ ! "$1" =~ .+\.pdf ]]; then
  echo "Illegal file name. Must be pdf."
  exit 4
else
  file=$1
fi

numberOfPages=$(exiftool "$file" | awk -F": " '/Page Count/{print $2}')

# calculates the range of pages depending on the slides per page
getPages(){
  i=$1
  numberOfPages=$2
  slidesPerPage=$3
  pages=""
  while [[ $i -le $numberOfPages ]]; do
    for ((j=0; j<slidesPerPage; j++)); do
      pages+="$i,"
      i=$((i+1))
    done
    i=$((i+slidesPerPage))
  done
  pages=${pages::-1}
  echo "$pages"
}

# used to split larger files into smaller ones to make it work with ghostscript
# it then processes those files and merges it back into 1 big file
splitAndMergeFiles(){
  local -n array=$1
  local -n tempfiles=$2
  infile=$3
  outfile=$4
  threshold=$5
  pageStart=0
  steps=$((threshold/2))

  for ((i = 0; i < ${#array[@]}; i++)); do
    pages=$(echo "${array[@]:$pageStart:$steps}" | sed "s\ \,\g")
    pageStart=$((pageStart + threshold/2))
    gs -sDEVICE=pdfwrite -sPageList="$pages" -sOutputFile="${tempfiles[i]}" -dBATCH -dNOPAUSE "$infile"
  done
  pages=$(echo "${array[@]:$pageStart}" | sed "s\ \,\g")
  gs -sDEVICE=pdfwrite -sPageList="$pages" -sOutputFile="${tempfiles[i]}" -dBATCH -dNOPAUSE "$infile"
  gs -sDEVICE=pdfwrite -dNOPAUSE -dBATCH -dSAFER -sOutputFile="$outfile" "${tempfiles[@]}" > /dev/null
}

frontPages=$(getPages 1 "$numberOfPages" "$slidesPerPage")
backPages=$(getPages "$((slidesPerPage+1))" "$numberOfPages" "$slidesPerPage")

echo "Processing, please wait..."

if [[ $numberOfPages -lt $threshold ]]; then
  gs -sDEVICE=pdfwrite -sPageList="$frontPages" -sOutputFile=frontPages.pdf -dBATCH -dNOPAUSE "$file" > /dev/null
  gs -sDEVICE=pdfwrite -sPageList="$backPages" -sOutputFile=backPages.pdf -dBATCH -dNOPAUSE "$file" > /dev/null
else
  #puts the individual page numbers seperated by a comma into an array
  readarray -td '' frontArray < <(awk '{ gsub(/,/,"\0"); print; }' <<<"$frontPages,"); unset 'frontArray[-1]';
  readarray -td '' backArray < <(awk '{ gsub(/,/,"\0"); print; }' <<<"$backPages,"); unset 'backArray[-1]';

  # results from splitting the main file into smaller bits is written to these temporary files
  tempFilesAmount=$((numberOfPages / threshold))
  files=()
  for ((i = 0; i <= tempFilesAmount; i++)); do
    files+=("$(mktemp)")
  done

  splitAndMergeFiles frontArray files "$file" "frontPages.pdf" "$threshold"
  splitAndMergeFiles backArray files "$file" "backPages.pdf" "$threshold"
fi

echo "The files have been saved to frontPages.pdf and backPages.pdf respectively!"
