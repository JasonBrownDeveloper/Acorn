# Colors
declare-option str red_40 "AA3333"
declare-option str red_30 "883333"
declare-option str red_20 "663333"

declare-option str green_50 "00DDAA"
declare-option str green_40 "00CC99"
declare-option str green_30 "009966"
declare-option str green_20 "006633"

declare-option str teal_40 "00DDFF"
declare-option str teal_30 "00AACC"
declare-option str teal_20 "007799"

declare-option str blue_50 "0099FF"
declare-option str blue_40 "0066CC"
declare-option str blue_30 "003399"

declare-option str indigo_40 "3333CC"
declare-option str indigo_30 "333399"
declare-option str indigo_20 "333366"

declare-option str purple_80 "AA88FF"
declare-option str purple_70 "9977EE"
declare-option str purple_60 "8866DD"
declare-option str purple_50 "7755CC"
declare-option str purple_40 "6644BB"
declare-option str purple_30 "5533AA"
declare-option str purple_20 "442288"

declare-option str grey_50 "AABBBB"
declare-option str grey_40 "889999"
declare-option str grey_30 "667777"
declare-option str grey_20 "445555"

# Tree Sitter Extended
set-face global keyword_flow        "rgb:%opt{purple_80}"
set-face global preproc_flow        "rgb:%opt{purple_80}"
set-face global operator            "rgb:%opt{purple_80}"
set-face global label               "rgb:%opt{purple_80}"
set-face global preproc_control     "rgb:%opt{purple_80}"
set-face global keyword_specifier   "rgb:%opt{purple_70}"
set-face global keyword_qualifier   "rgb:%opt{purple_60}"
set-face global keyword_storage     "rgb:%opt{purple_50}"

set-face global comment_line        "rgb:%opt{green_40}"
set-face global comment_block       "rgb:%opt{green_30}"

set-face global function            "rgb:%opt{teal_30}"
set-face global preproc_macro       "rgb:%opt{teal_30}"
set-face global type                "rgb:%opt{teal_20}"

set-face global literal_number      "rgb:%opt{grey_50}"
set-face global literal_string      "rgb:%opt{grey_40}"
set-face global literal_constant    "rgb:%opt{grey_30}"

set-face global property            "rgb:%opt{blue_50}"
set-face global variable            "rgb:%opt{blue_40}"

# Tree Sitter basic
set-face global keyword             "rgb:%opt{purple_80}"

set-face global comment             "rgb:%opt{green_40}"

set-face global function_method     "rgb:%opt{teal_30}"
set-face global function_builtin    "rgb:%opt{teal_30}"

set-face global number              "rgb:%opt{grey_50}"
set-face global string              "rgb:%opt{grey_40}"
set-face global escape              "rgb:%opt{grey_40}"
set-face global constant            "rgb:%opt{grey_30}"
set-face global constant_builtin    "rgb:%opt{grey_30}"

set-face global constructor         default
set-face global embedded            default
set-face global punctuation_special default
set-face global delimiter           default

# Utils
set-face global format              "default,rgb:%opt{red_40}"
set-face global typo                "default,rgb:%opt{red_40}"

# Kakoune
set-face global Default             default

set-face global PrimarySelection    "white,rgb:%opt{indigo_30},default+fg"
set-face global SecondarySelection  "black,rgb:%opt{indigo_30},default+fg"
set-face global PrimaryCursor       "black,white,default+fg"
set-face global SecondaryCursor     "black,rgb:%opt{grey_50},default+fg"
set-face global PrimaryCursorEol    "black,rgb:%opt{grey_50},default+fg"
set-face global SecondaryCursorEol  "black,rgb:%opt{grey_30},default+fg"

set-face global MenuForeground      "rgb:%opt{grey_50},rgb:%opt{indigo_30},default"
set-face global MenuBackground      "rgb:%opt{indigo_30},rgb:%opt{grey_50},default"
set-face global MenuInfo            "rgb:%opt{indigo_20},default,default"

set-face global Information         "black,rgb:%opt{indigo_40},default"
set-face global InlineInformation   "default,default,default"

set-face global Error               "black,red,default"
set-face global DiagnosticError     "red,default,default"
set-face global DiagnosticWarning   "yellow,default,default"

set-face global StatusLine          "rgb:%opt{teal_40},default,default"
set-face global StatusLineMode      "rgb:%opt{indigo_40},default,default"
set-face global StatusLineInfo      "rgb:%opt{blue_50},default,default"
set-face global StatusLineValue     "rgb:%opt{green_50},default,default"
set-face global StatusCursor        "black,rgb:%opt{teal_40},default"

set-face global Prompt              "rgb:%opt{indigo_40},default,default"
set-face global BufferPadding       "rgb:%opt{blue_50},default,default"

