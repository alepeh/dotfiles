#!/bin/bash
for file in ~/.{dockerfunc,extra}; do
	if [[ -r "$file" ]] && [[ -f "$file" ]]; then
		source "$file"
	fi
done
unset file
