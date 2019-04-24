#!/bin/bash
for file in ~/.{dockerfunc,aliases,extra}; do
	if [[ -r "$file" ]] && [[ -f "$file" ]]; then
		source "$file"
	fi
done
unset file
