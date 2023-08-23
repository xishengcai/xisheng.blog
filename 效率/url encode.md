

# urldecdoe && urlencode



[Urlencode and decode from the command line with bash](https://newfivefour.com/unix-urlencode-urldecode-command-line-bash.html)

If you want a native bash solution to urlencode and urldecode, put [this](https://gist.github.com/cdown/1163649) in your .bashrc

```bash
urlencode() {
    # urlencode <string>

    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%s' "$c" | xxd -p -c1 |
                   while read c; do printf '%%%s' "$c"; done ;;
        esac
    done
}

urldecode() {
    # urldecode <string>

    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}
```

If you want to use this from xargs, you'll need to export the function via:

```sh
export -f urlencode
```

[unix](https://newfivefour.com/category_unix.html)