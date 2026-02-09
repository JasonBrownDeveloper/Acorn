colorscheme starry_night

hook global ModuleLoaded acorn %{

set-option global AcornBegin %{
global acorn_state

acorn_state[ 'filetype' ].setdefault( 'c', {} )
acorn_state[ 'filetype' ][ 'c' ][ 'module' ] = 'tree_sitter_c'
acorn_state[ 'filetype' ][ 'c' ][ 'highlights_query' ] = """
    (identifier) @variable

    ((identifier) @literal_constant
     (#match? @literal_constant "^[A-Z][A-Z\\d_]*$"))

    "break" @keyword_flow
    "case" @keyword_flow
    "const" @keyword_qualifier
    "continue" @keyword_flow
    "default" @keyword_flow
    "do" @keyword_flow
    "else" @keyword_flow
    "enum" @keyword_specifier
    "extern" @keyword_storage
    "for" @keyword_flow
    "if" @keyword_flow
    "inline" @keyword_specifier
    "return" @keyword_flow
    "sizeof" @operator
    "static" @keyword_storage
    "struct" @keyword_specifier
    "switch" @keyword_flow
    "typedef" @keyword_specifier
    "union" @keyword_specifier
    "volatile" @keyword_qualifier
    "while" @keyword_flow
    "goto" @keyword_flow

    "#define" @preproc_control
    "#elif" @preproc_flow
    "#else" @preproc_flow
    "#endif" @preproc_flow
    "#if" @preproc_flow
    "#ifdef" @preproc_flow
    "#ifndef" @preproc_flow
    "#include" @preproc_control
    (preproc_directive) @preproc_control
    (preproc_arg) @literal_string

    "--" @operator
    "-" @operator
    "-=" @operator
    "->" @operator
    "=" @operator
    "!=" @operator
    "*" @operator
    "&" @operator
    "&&" @operator
    "+" @operator
    "++" @operator
    "+=" @operator
    "<" @operator
    "==" @operator
    ">" @operator
    "||" @operator

    "." @delimiter
    ";" @delimiter

    (string_literal) @literal_string
    (system_lib_string) @literal_string

    (null) @literal_constant
    (false) @literal_constant
    (true) @literal_constant
    (number_literal) @literal_number
    (char_literal) @literal_string

    (field_identifier) @property
    (statement_identifier) @label
    (type_identifier) @type
    (primitive_type) @type
    (sized_type_specifier) @type

    (call_expression
      function: (identifier) @function)
    (call_expression
      function: (field_expression
        field: (field_identifier) @function))
    (function_declarator
      declarator: (identifier) @function)
    (preproc_function_def
      name: (identifier) @preproc_macro)

    ((comment) @comment_line
     (#match? @comment_line "^//"))
    ((comment) @comment_block
     (#match? @comment_block "^/\*"))
    """

def acorn_formatter_c( cursor, bufname ):
    global acorn_state

    state = acorn_state[ 'filetype' ][ 'c' ][ 'formatter_state' ]
    if not state:
        state[ 'error' ] = False
        state[ 'header' ] = state[ 'footer' ] = None

    if cursor.node.type == 'function_definition':
        if cursor.goto_previous_sibling():
            if cursor.node.type == 'comment':
                state[ 'header' ] = ( cursor.node.start_byte, cursor.node.end_byte )
            else:
                state[ 'error' ] = True
            cursor.goto_next_sibling()

        if cursor.goto_next_sibling():
            if cursor.node.type == 'comment':
                state[ 'footer' ] = ( cursor.node.start_byte, cursor.node.end_byte )
            else:
                state[ 'error' ] = True
            cursor.goto_previous_sibling()

    if state[ 'header' ] and state[ 'footer' ] and cursor.node.type == 'identifier':
        # we only need to expand if we haven't yet found an error
        if not state[ 'error' ]:
            header = acorn_state[ 'bufname' ][ bufname ][ 'buffer' ][
                state[ 'header' ][0] : state[ 'header' ][1] ]
            footer = acorn_state[ 'bufname' ][ bufname ][ 'buffer' ][
                state[ 'footer' ][0] : state[ 'footer' ][1] ]
            ident = acorn_state[ 'bufname' ][ bufname ][ 'buffer' ][
                cursor.node.start_byte : cursor.node.end_byte ]

            if ( ( 'PROCEDURE NAME' not in header )
            or ( 'DESCRIPTION' not in header )
            or ( ident not in header )
            or ( ident + '()' not in footer ) ):
                state[ 'error' ] = True

        state[ 'header' ] = state[ 'footer' ] = None

        if state[ 'error' ]:
            state[ 'error' ] = False
            return '{}.{},{}.{}|{} '.format(
                  cursor.node.start_point[0] + 1
                , cursor.node.start_point[1] + 1
                , cursor.node.end_point[0] + 1
                , cursor.node.end_point[1]
                , 'format' )

    return ''

acorn_state[ 'filetype' ][ 'c' ][ 'formatter' ] = acorn_formatter_c
acorn_state[ 'filetype' ][ 'c' ][ 'formatter_state' ] = {}

acorn_state[ 'filetype' ][ 'cpp' ] = acorn_state[ 'filetype' ][ 'c' ]

acorn_state[ 'filetype' ].setdefault( 'python', {} )
acorn_state[ 'filetype' ][ 'python' ][ 'module' ] = 'tree_sitter_python'

acorn_state[ 'filetype' ].setdefault( 'bash', {} )
acorn_state[ 'filetype' ][ 'bash' ][ 'module' ] = 'tree_sitter_bash'

acorn_state[ 'filetype' ].setdefault( 'devicetree', {} )
acorn_state[ 'filetype' ][ 'devicetree' ][ 'module' ] = 'tree_sitter_devicetree'
acorn_state[ 'filetype' ][ 'devicetree' ][ 'highlights_query' ] = """
    (file_version) @keyword_qualifier

    "#include" @preproc_control
    (system_lib_string) @literal_string

    ((identifier) @literal_constant
     (#match? @literal_constant "^[A-Z][A-Z\\d_]*$"))

    "=" @operator
    "@" @operator
    "&" @operator

    (string_literal) @literal_string
    (unit_address) @literal_number
    (integer_literal) @literal_number

    (call_expression
      function: (identifier) @preproc_macro)
    (node
      name: (identifier) @function)
    (node
      label: (identifier) @label
      name: (identifier) @function)
    (reference
      label: (identifier) @label)
    (property
      name: (identifier) @variable)

    ((comment) @comment_line
     (#match? @comment_line "^//"))
    ((comment) @comment_block
     (#match? @comment_block "^/\*"))
    """
}

# TODO shift actions < > dont proc an Idle
# hook -group acorn buffer BufClose .* %{ acorn_remove_buffer }
#  printf "%s\n" "hook -group acorn buffer BufClose .* %{ acorn_remove_buffer }"
evaluate-commands -client * %sh{
    printf "%s\n" "hook -group acorn global WinSetOption filetype=(c|cpp|python|devicetree|bash) %{
        acorn_init_buffer
        hook -group acorn window NormalIdle .* %{ acorn_highlight; acorn_format }
        hook -group acorn window InsertIdle .* %{ acorn_highlight; acorn_format }
        }"
    printf "%s\n" "acorn_init_buffer"
    printf "%s\n" "hook -group acorn window NormalIdle .* %{ acorn_highlight; acorn_format }"
    printf "%s\n" "hook -group acorn window InsertIdle .* %{ acorn_highlight; acorn_format }"
}

}

map -docstring 'Next tagged name' global user j ': acorn_next_tag<ret>'
map -docstring 'Previous tagged name' global user k ': acorn_prev_tag<ret>'

