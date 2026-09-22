provide-module acorn %{

declare-option str AcornBegin
declare-option -hidden int acorn_history_cache_id 999999999

python %{
global acorn_server
def acorn_server( pipe_server ):
    global jdb_test
    global acorn_state, acorn_pattern
    global acorn_update_tree, acorn_highlight, acorn_spell, acorn_tag, acorn_next_tag, acorn_prev_tag, acorn_format, acorn_init_buffer

    # Initialize global state if not already
    try:
        acorn_state
    except NameError:
        import re

        acorn_state = {}
        acorn_state[ 'bufname' ] = {}
        acorn_state[ 'filetype' ] = {}

        acorn_pattern = {}
        acorn_pattern[ 'history' ] = re.compile(
            '(?P<parent>-|\d+) (?P<committed>\d+) (?P<child>-|\d+)(?P<modifications>( [-+]\d+\.\d+\|(?s:.)+?(?= (-|\d+) \d+ (-|\d+) |\Z))*)'
            )
        acorn_pattern[ 'modifications' ] = re.compile(
            '[-+]\d+\.\d+\|(?s:.)+?(?= [-+]\d+\.\d+\||\Z)'
            )
        acorn_pattern[ 'group' ] = re.compile(
            '(?P<action>[-+])(?P<line>\d+)\.(?P<column>\d+)\|(?P<text>(?s:.)+?)(?= [-+]\d+\.\d+\||\Z)'
            )

    while True:
        action, client, filetype, bufname = pipe_server.recv()

        if action == 'init_acorn':
            # AcornBegin needs to be evaluated in this thread
            AcornBegin, = pipe_server.recv()
            exec( AcornBegin )
            continue

        elif action == 'init_buffer':
            acorn_init_buffer( client, filetype, bufname )
            continue

        elif action == 'remove_buffer':
            acorn_remove_buffer( client, bufname )
            continue

        elif action == 'exit':
            break

        if ( ( filetype not in acorn_state[ 'filetype' ] )
        or ( 'parser' not in acorn_state[ 'filetype' ][ filetype ] ) ):
            pipe_server.recv()
            continue

        if action == 'highlight':
            history_id, history, uncommitted_modifications, view_first_line, view_line_count = pipe_server.recv()
            acorn_update_tree( client, filetype, bufname, history_id, history, uncommitted_modifications )
            acorn_highlight( client, filetype, bufname, history_id, uncommitted_modifications, view_first_line, view_line_count )

        elif action == 'spell':
            history_id, history, uncommitted_modifications = pipe_server.recv()
            acorn_update_tree( client, filetype, bufname, history_id, history, uncommitted_modifications )
            acorn_spell( client, filetype, bufname, history_id, uncommitted_modifications )

        elif action == 'next_name':
            history_id, history, uncommitted_modifications, cursor_line = pipe_server.recv()
            acorn_update_tree( client, filetype, bufname, history_id, history, uncommitted_modifications )
            acorn_tag( client, filetype, bufname, history_id, uncommitted_modifications )
            acorn_next_tag( client, bufname, cursor_line )

        elif action == 'prev_name':
            history_id, history, uncommitted_modifications, cursor_line = pipe_server.recv()
            acorn_update_tree( client, filetype, bufname, history_id, history, uncommitted_modifications )
            acorn_tag( client, filetype, bufname, history_id, uncommitted_modifications )
            acorn_prev_tag( client, bufname, cursor_line )

        elif action == 'format':
            history_id, history, uncommitted_modifications, view_first_line, view_line_count = pipe_server.recv()
            acorn_update_tree( client, filetype, bufname, history_id, history, uncommitted_modifications )
            acorn_format( client, filetype, bufname, history_id, uncommitted_modifications, view_first_line, view_line_count )

        elif action == 'reload':
            acorn_reload( bufname )
            acorn_init_buffer( client, filetype, bufname )
            history_id, history, uncommitted_modifications, view_first_line, view_line_count = pipe_server.recv()
            acorn_update_tree( client, filetype, bufname, history_id, history, uncommitted_modifications )
            acorn_highlight( client, filetype, bufname, history_id, uncommitted_modifications, view_first_line, view_line_count )

        elif action == 'dump':
            acorn_dump( client )

global acorn_init_buffer
def acorn_init_buffer( client, filetype, bufname ):
    global acorn_state

    acorn_state[ 'bufname' ][ bufname ] = {}

    # Initialize filetype if not already
    # Initialize filetype parser if not already
    # but only if there is a module for filetype defined
    filetype_cache = acorn_state[ 'filetype' ].setdefault( filetype, {} )
    if ( ( 'parser' not in filetype_cache )
    and ( 'module' in filetype_cache ) ):
        from tree_sitter import Language, Parser
        import importlib

        filetype_cache[ 'grammar' ] = importlib.import_module( filetype_cache[ 'module' ] )
        filetype_cache[ 'language' ] = Language( filetype_cache[ 'grammar' ].language() )
        filetype_cache[ 'parser' ] = Parser( filetype_cache[ 'language' ] )

    keval_async( 'try %[ remove-highlighter window/{} ]'.format( filetype ), client=client )
    keval_async( 'try %[ remove-hooks window c-.+ ]', client=client )

global acorn_remove_buffer
def acorn_remove_buffer( client, bufname ):
    global acorn_state

    del acorn_state[ 'bufname' ][ bufname ]

global acorn_update_tree
def acorn_update_tree( client, filetype, bufname, history_id, history, uncommitted_modifications ):
    global acorn_state

    bufname_cache = acorn_state[ 'bufname' ][ bufname ]
    filetype_cache = acorn_state[ 'filetype' ][ filetype ]

    if ( bufname_cache.get( 'tree_history_id', None ) == history_id
    and not uncommitted_modifications ):
        return

    # TODO Pick either parse history or parse buffer based on size of either

    # If our current history_id is the parent or child of our previous history_id
    # or we have uncommitted modifications
    # then we should be able to generate a tree.edit()
    modification = None
    if ( ( 'tree_history_id' in bufname_cache
    and bufname_cache[ 'tree_history_id' ] != history_id )
    or uncommitted_modifications ):
        import re
        global acorn_pattern

        history_parsed = bufname_cache.setdefault( 'history_parsed', [] )
        last_pos = 0
        if history_parsed:
            last_pos = history_parsed[-1][ 'pos' ]
            history_parsed.pop()

        match = acorn_pattern[ 'history' ].finditer( history, last_pos )
        bufname_cache[ 'history' ] = history

        history_parsed.extend( [ m.groupdict() | { 'pos':m.start() } for m in match ] )

        history_id_old = bufname_cache[ 'tree_history_id' ]

        # case 1 new entry, or moved down history
        if str( history_id ) == history_parsed[ history_id_old ][ 'child' ]:
            #print( '1 - ', str( history_id ), history_parsed[ history_id_old ][ 'child' ] )

            # case 1.a new entry already covered by a now complete um
            # some auto formatting will not be in our stored UM
            if ( bufname_cache.get( 'uncommitted_modifications', '' )
            and history_parsed[ history_id ][ 'modifications' ][1:].startswith( bufname_cache[ 'uncommitted_modifications' ] ) ):
                #print( '1.a - x{}x y{}y'.format( history_parsed[ history_id ][ 'modifications' ][1:], bufname_cache.get( 'uncommitted_modifications', '' ) ) )
                new_um = history_parsed[ history_id ][ 'modifications' ][ len( bufname_cache.setdefault( 'uncommitted_modifications', '' ) ) : ]
                reverse = False
                modification = acorn_pattern[ 'modifications' ].findall( new_um )

            # case 1.b new entry pasted or deleted, or moved down history
            else:
                #print( '1.b - z{}z'.format( history_parsed[ history_id ][ 'modifications' ][1:] ) )
                reverse = False
                modification = acorn_pattern[ 'modifications' ].findall( history_parsed[ history_id ][ 'modifications' ] )

        # case 2 we moved up history
        elif str( history_id ) == history_parsed[ history_id_old ][ 'parent' ]:
            #print( '2 - ', str( history_id ), history_parsed[ history_id_old ][ 'parent' ] )
            reverse = True
            modification = acorn_pattern[ 'modifications' ].findall( history_parsed[ history_id_old ][ 'modifications' ] )
        else:
            #print( 'not 1 or 2' )
            pass

        # case 3 mods haven't been committed yet, ie in insert mode
        if uncommitted_modifications:
            #print( '3 - a{}a'.format( uncommitted_modifications ) )
            # The raw list[str] causes kakoune's eval to throw a parse error: unterminated string '...'
            new_um = uncommitted_modifications[ len( bufname_cache.setdefault( 'uncommitted_modifications', '' ) ) : ]
            reverse = False
            modification = acorn_pattern[ 'modifications' ].findall( new_um )
            bufname_cache[ 'uncommitted_modifications' ] = uncommitted_modifications
        else:
            #print( 'not 3' )
            bufname_cache[ 'uncommitted_modifications' ] = ''

        if modification is not None:
            if reverse: modification.reverse()

            for m in modification:
                buffer = bufname_cache[ 'buffer' ]
                match = acorn_pattern[ 'group' ].match( m )
                if not match:
                    continue

                # TODO if you paste when the selection is on the line end (e.g. an empty buffer)
                # then the paste drops to a new/next line. There isn't a newline to count in the
                # new case. May or may not be a problem.
                line = 0
                start_byte = 0
                for i, c in enumerate( buffer ):
                    if line == int( match.group( 'line' ) ):
                        start_byte = i
                        break
                    if c == '\n':
                        line += 1
                start_byte += int( match.group( 'column' ) )
                #print( 'mod - {}{}.{}; {}'.format( 
                #      match.group( 'action' )
                #    , match.group( 'line' )
                #    , match.group( 'column' )
                #    , start_byte ) )

                if ( match.group( 'action' ) == ( '-' if not reverse else '+' ) ):
                    old_end_byte = start_byte + len( match.group( 'text' ) )

                    old_end_line = buffer.count( '\n', 0, old_end_byte )
                    old_end_column = old_end_byte - buffer.rfind( '\n', 0, old_end_byte )

                    buffer = buffer[ : start_byte ] + buffer[ old_end_byte : ]
                    bufname_cache[ 'buffer' ] = buffer

                    new_end_byte = start_byte

                    new_end_line = int( match.group( 'line' ) )
                    new_end_column = int( match.group( 'column' ) )

                else:
                    old_end_byte = start_byte

                    old_end_line = int( match.group( 'line' ) )
                    old_end_column = int( match.group( 'column' ) )

                    buffer = buffer[ : start_byte ] + match.group( 'text' ) + buffer[ old_end_byte : ]
                    bufname_cache[ 'buffer' ] = buffer

                    new_end_byte = start_byte + len( match.group( 'text' ) )

                    new_end_line = buffer.count( '\n', 0, new_end_byte )
                    #print( 'action - {} {} b{}b'.format(
                    #      new_end_byte
                    #    , buffer.rfind( '\n', 0, new_end_byte )
                    #    , buffer[ max( 0, start_byte - 5 ) : min( len( buffer ),  new_end_byte + 5 ) ] ) )
                    new_end_column = new_end_byte - buffer.rfind( '\n', 0, new_end_byte ) - 1

                #print( 'mod - {} {} {}; {} {} {}'.format(
                #      start_byte
                #    , old_end_byte
                #    , new_end_byte
                #    , ( int( match.group( 'line' ) ), int( match.group( 'column' ) ) )
                #    , ( old_end_line, old_end_column )
                #    , ( new_end_line, new_end_column ) ) )
                bufname_cache[ 'tree' ].edit(
                      start_byte=start_byte
                    , old_end_byte=old_end_byte
                    , new_end_byte=new_end_byte
                    , start_point=( int( match.group( 'line' ) ), int( match.group( 'column' ) ) )
                    , old_end_point=( old_end_line, old_end_column )
                    , new_end_point=( new_end_line, new_end_column ) )

                bufname_cache[ 'tree' ] = \
                    filetype_cache[ 'parser' ].parse(
                          bufname_cache[ 'buffer' ].encode()
                        , bufname_cache[ 'tree' ] )

            # In case 1.a we want to update the history id
            bufname_cache[ 'tree_history_id' ] = history_id

            return
        else:
            #print( 'no mods found' )
            pass

    # This will only happen if none of the other cases were true
    # case 4 its a new buffer or we've lost the throughline and need to reparse everything
    import os, tempfile, fcntl, subprocess, threading

    #print( '4 - reparse' )
    tmpdir = tempfile.mkdtemp()
    filename = os.path.join( tmpdir, 'acorn' )
    try:
        os.mkfifo( filename )
    except OSError as e:
        keval_async( 'echo -debug Failed to create FIFO: {}'.format( e ), client=client )
    else:
        def read_fifo( filename, bufname_cache ):
            with open( filename, 'r' ) as fifo:
                bufname_cache[ 'buffer' ] = fifo.read()

        reader = threading.Thread( target=read_fifo, args=( filename, bufname_cache ) )
        reader.start()

        keval_async( 'write {}'.format( filename ), client=client )

        reader.join()
        os.remove( filename )

    os.rmdir( tmpdir )

    bufname_cache[ 'tree' ] = \
        filetype_cache[ 'parser' ].parse( bufname_cache[ 'buffer' ].encode() )
    bufname_cache[ 'tree_history_id' ] = history_id

global acorn_highlight
def acorn_highlight( client, filetype, bufname, history_id, uncommitted_modifications, view_first_line, view_line_count ):
    global acorn_state

    bufname_cache = acorn_state[ 'bufname' ][ bufname ]
    filetype_cache = acorn_state[ 'filetype' ][ filetype ]
    client_state = bufname_cache.setdefault( 'client', {} ).setdefault( client, {} )

    margin = max( view_line_count, 50 )
    view_start_line = max( 0, view_first_line - margin )
    view_end_line = view_first_line + view_line_count + margin

    cached_range = client_state.get( 'highlight_range' )
    range_covered = ( cached_range is not None
        and cached_range[0] <= view_start_line
        and cached_range[1] >= view_end_line )

    if ( ( 'highlight_history_id' not in client_state )
    or ( client_state[ 'highlight_history_id' ] != history_id )
    or ( uncommitted_modifications )
    or ( not range_covered ) ):
        if 'highlights_query' in filetype_cache:
            query_string = filetype_cache[ 'highlights_query' ]
        else:
            try:
                query_string = filetype_cache[ 'grammar' ].HIGHLIGHTS_QUERY
            except:
                query_string = None

        if query_string:
            from tree_sitter import Query, QueryCursor
            query = Query( filetype_cache[ 'language' ], query_string )
            highlights = QueryCursor( query )
            highlights.set_point_range( ( view_start_line, 0 ), ( view_end_line, 0 ) )

            captures_by_type = highlights.captures( bufname_cache[ 'tree' ].root_node )
            captures_by_type_items = captures_by_type.items()

            cmds = []
            for nodetype, captures in captures_by_type_items:
                nodetype = nodetype.replace( '.', '_' )
                ranges = ''.join(
                    '{}.{},{}.{}|{} '.format(
                        # TODO take a deeper look at the 0-based coordinates
                        # This will be X.0 - X.0 for a single char on the margin
                        # But X.0 - X.3 for a longer string
                          captured.start_point[0] + 1
                        , captured.start_point[1] + 1
                        , captured.end_point[0] + 1
                        , max( captured.end_point[1], 1 )
                        , nodetype )
                    for captured in captures )

                #print( 'high - {} {}'.format( nodetype, ranges ) )
                cmds.append( 'try %[ declare-option range-specs {}_range ]'.format( nodetype ) )

                cmds.append( 'try %[ add-highlighter window/acorn group ]' )
                cmds.append( 'try %[ add-highlighter window/acorn/{} ranges {}_range ]'.format( nodetype, nodetype ) )

                cmds.append( 'set-option window {}_range %val[timestamp] {}'.format( nodetype, ranges ) )

            cmds = 'eval -buffer {} %[ eval -client {} %[ {} ] ]'.format(
                  bufname
                , client
                , '\n'.join( cmds ) )
            keval_async( cmds )

        client_state[ 'highlight_history_id' ] = history_id
        client_state[ 'highlight_range' ] = ( view_start_line, view_end_line )

global acorn_spell
def acorn_spell( client, filetype, bufname, history_id, uncommitted_modifications ):
    global acorn_state

    bufname_cache = acorn_state[ 'bufname' ][ bufname ]
    filetype_cache = acorn_state[ 'filetype' ][ filetype ]
    client_state = {}
    bufname_cache.setdefault( 'client', {} )[ client ] = client_state

    if ( ( 'spell_history_id' not in client_state )
    or ( client_state[ 'spell_history_id' ] != history_id )
    or ( uncommitted_modifications ) ):
        import re

        import nltk
        nltk.download( 'words' )
        from nltk.corpus import words

        query_string = """
        (comment) @comment
        """
        from tree_sitter import Query, QueryCursor
        query = Query( filetype_cache[ 'language' ], query_string )
        highlights = QueryCursor( query )
        captures = highlights.captures( bufname_cache[ 'tree' ].root_node )

        cmds = []
        words_set = set( words.words() )
        range_parts = []
        for cap in captures[ 'comment' ]:
            comment = bufname_cache[ 'buffer' ][ cap.start_byte : cap.end_byte ].decode()
            chopped = [
                ( m.group( 0 ), m.start(), m.end() - 1 )
                for m in re.finditer(
                      r'\S+'
                    , comment ) ]
            for word in chopped:
                if word[0].isalpha() and word[0].lower() not in words_set:
                    line = comment.count( '\n', 0, word[ 1 ] )
                    start_col = word[ 1 ] - comment.rfind( '\n', 0, word[ 1 ] )
                    start_col += cap.start_point[1] if line == 0 else 0
                    end_col = word[ 2 ] - comment.rfind( '\n', 0, word[ 2 ] )
                    end_col += cap.start_point[1] if line == 0 else 0
                    range_parts.append( '{}.{},{}.{}|{} '.format(
                          cap.start_point[0] + 1 + line
                        ,                      start_col
                        , cap.start_point[0] + 1 + line
                        ,                      end_col
                        , 'typo' ) )
        ranges = ''.join( range_parts )

        cmds.append( 'try %[ declare-option range-specs {}_range ]'.format( 'typo' ) )
        cmds.append( 'try %[ add-highlighter window/acorn group ]' )
        cmds.append( 'try %[ add-highlighter window/acorn/{} ranges {}_range ]'.format( 'typo', 'typo' ) )

        cmds.append( 'set-option window {}_range %val[timestamp] {}'.format( 'typo', ranges ) )

        cmds = 'eval -buffer {} %[ eval -client {} %[ {} ] ]'.format(
              bufname
            , client
            , '\n'.join( cmds ) )
        keval_async( cmds )

        client_state[ 'spell_history_id' ] = history_id

global acorn_tag
def acorn_tag( client, filetype, bufname, history_id, uncommitted_modifications ):
    global acorn_state

    bufname_cache = acorn_state[ 'bufname' ][ bufname ]
    filetype_cache = acorn_state[ 'filetype' ][ filetype ]

    if ( ( 'tag_history_id' not in bufname_cache )
    or ( bufname_cache[ 'tag_history_id' ] != history_id )
    or ( uncommitted_modifications ) ):
        from tree_sitter import Query, QueryCursor
        query = Query( filetype_cache[ 'language' ], filetype_cache[ 'grammar' ].TAGS_QUERY )
        tags = QueryCursor( query )
        captures = tags.captures( bufname_cache[ 'tree' ].root_node )

        bufname_cache[ 'tag' ] = { k:sorted( set( [ n.start_point[0] + 1 for n in v ] ) ) for k, v in captures.items() }
        bufname_cache[ 'tag_history_id' ] = history_id

global acorn_next_tag
def acorn_next_tag( client, bufname, cursor_line ):
    global acorn_state
    import bisect

    name_cache = acorn_state[ 'bufname' ][ bufname ][ 'tag' ][ 'name' ]
    next_biggest = bisect.bisect( name_cache, cursor_line )

    keval_async( 'execute-keys {}g'.format( name_cache[ next_biggest % len( name_cache ) ] ), client=client )


global acorn_prev_tag
def acorn_prev_tag( client, bufname, cursor_line ):
    global acorn_state
    import bisect

    name_cache = acorn_state[ 'bufname' ][ bufname ][ 'tag' ][ 'name' ]
    prev_biggest = bisect.bisect_left( name_cache, cursor_line )

    keval_async( 'execute-keys {}g'.format( name_cache[ prev_biggest - 1 ] ), client=client )


global acorn_format
def acorn_format( client, filetype, bufname, history_id, uncommitted_modifications, view_first_line, view_line_count ):
    global acorn_state

    bufname_cache = acorn_state[ 'bufname' ][ bufname ]
    filetype_cache = acorn_state[ 'filetype' ][ filetype ]
    client_state = bufname_cache.setdefault( 'client', {} ).setdefault( client, {} )

    margin = max( view_line_count, 50 )
    view_start_line = max( 0, view_first_line - margin )
    view_end_line = view_first_line + view_line_count + margin
    start_point = ( view_start_line, 0 )
    end_point = ( view_end_line, 0 )

    cached_range = client_state.get( 'format_range' )
    range_covered = ( cached_range is not None
        and cached_range[0] <= view_start_line
        and cached_range[1] >= view_end_line )

    if ( ( 'format_history_id' not in client_state )
    or ( client_state[ 'format_history_id' ] != history_id )
    or ( uncommitted_modifications )
    or ( not range_covered ) ):
        if 'formatter' in filetype_cache:
            formatter = filetype_cache[ 'formatter' ]
        else:
            formatter = None

        if formatter:
            cursor = bufname_cache[ 'tree' ].walk()
            visited_children = False
            cmds = []
            range_parts = []
            while True:
                if not visited_children:
                    node_start = cursor.node.start_point
                    node_end = cursor.node.end_point
                    intersects = node_start <= end_point and node_end >= start_point
                    if intersects:
                        range_parts.append( formatter( cursor, bufname ) )
                    if intersects and cursor.goto_first_child():
                        visited_children = False
                    else:
                        visited_children = True
                elif cursor.goto_next_sibling():
                    visited_children = False
                elif not cursor.goto_parent():
                    break
            ranges = ''.join( range_parts )

            cmds.append( 'try %[ declare-option range-specs {}_range ]'.format( 'format' ) )
            cmds.append( 'try %[ add-highlighter window/acorn group ]' )
            cmds.append( 'try %[ add-highlighter window/acorn/{} ranges {}_range ]'.format( 'format', 'format' ) )

            cmds.append( 'set-option window {}_range %val[timestamp] {}'.format( 'format', ranges ) )

            cmds = 'eval -buffer {} %[ eval -client {} %[ {} ] ]'.format(
                  bufname
                , client
                , '\n'.join( cmds ) )
            keval_async( cmds )

        client_state[ 'format_history_id' ] = history_id
        client_state[ 'format_range' ] = ( view_start_line, view_end_line )

global acorn_reload
def acorn_reload( bufname ):
    global acorn_state
 
    del acorn_state[ 'bufname' ][ bufname ]

global acorn_dump
def acorn_dump( client ):
    global acorn_state

    keval_async( 'eval -client {} %[ echo -debug -- %[ {} ] ]'.format(
          client
        , acorn_state ) )

global acorn_fetch_history
def acorn_fetch_history( history_id, uncommitted_modifications ):
    cached_hid = opt.acorn_history_cache_id.as_int()
    if uncommitted_modifications or history_id != cached_hid:
        history_cache = val.history.as_str()
        keval_async( 'set-option buffer acorn_history_cache_id {}'.format( history_id ) )
        return history_cache
    return ''

# __main__
import multiprocessing
global acorn_pipe_client

# Do work in separate thread so not to hang up the UI thread
acorn_pipe_client, pipe_server = multiprocessing.Pipe()
process = multiprocessing.Process( target=acorn_server, args=( pipe_server, ), daemon=True )
process.start()
}

hook -once global WinSetOption AcornBegin=.* %{ py %{
    global acorn_pipe_client

    acorn_pipe_client.send( ( 'init_acorn', val.client, None, None ) )
    acorn_pipe_client.send( ( opt.AcornBegin.as_str(), ) )
} }

define-command -override acorn_exit %{ py %{
    global acorn_pipe_client

    acorn_pipe_client.send( ( 'exit', None, None, None ) )
} }

define-command -override acorn_init_buffer %{ py %{
    global acorn_pipe_client

    acorn_pipe_client.send( ( 'init_buffer', val.client, opt.filetype, val.bufname ) )
} }

define-command -override acorn_remove_buffer %{ py %{
    global acorn_pipe_client

    acorn_pipe_client.send( ( 'remove_buffer', val.client, opt.filetype, val.bufname ) )
} }

define-command -override acorn_highlight %{ py %{
    global acorn_pipe_client

    history_id_cache = val.history_id
    uncommitted_modifications_cache = val.uncommitted_modifications.as_str()
    history_cache = acorn_fetch_history( history_id_cache, uncommitted_modifications_cache )
    window_range_cache = val.window_range
    acorn_pipe_client.send( ( 'highlight', val.client, opt.filetype, val.bufname ) )
    acorn_pipe_client.send( ( history_id_cache, history_cache, uncommitted_modifications_cache, window_range_cache.line, window_range_cache.height ) )
} }

define-command -override acorn_spell %{ py %{
    global acorn_pipe_client

    acorn_pipe_client.send( ( 'spell', val.client, opt.filetype, val.bufname ) )
    acorn_pipe_client.send( ( val.history_id, val.history.as_str(), val.uncommitted_modifications.as_str() ) )
} }

define-command -override acorn_next_tag %{ py %{
    global acorn_pipe_client

    acorn_pipe_client.send( ( 'next_name', val.client, opt.filetype, val.bufname ) )
    acorn_pipe_client.send( ( val.history_id, val.history.as_str(), val.uncommitted_modifications.as_str(), val.cursor_line ) )
} }

define-command -override acorn_prev_tag %{ py %{
    global acorn_pipe_client

    acorn_pipe_client.send( ( 'prev_name', val.client, opt.filetype, val.bufname ) )
    acorn_pipe_client.send( ( val.history_id, val.history.as_str(), val.uncommitted_modifications.as_str(), val.cursor_line ) )
} }

define-command -override acorn_format %{ py %{
    global acorn_pipe_client

    history_id_cache = val.history_id
    uncommitted_modifications_cache = val.uncommitted_modifications.as_str()
    history_cache = acorn_fetch_history( history_id_cache, uncommitted_modifications_cache )
    window_range_cache = val.window_range
    acorn_pipe_client.send( ( 'format', val.client, opt.filetype, val.bufname ) )
    acorn_pipe_client.send( ( history_id_cache, history_cache, uncommitted_modifications_cache, window_range_cache.line, window_range_cache.height ) )
} }

define-command -hidden -override acorn_reload %{ py %{
    global acorn_pipe_client

    history_id_cache = val.history_id
    uncommitted_modifications_cache = val.uncommitted_modifications.as_str()
    history_cache = acorn_fetch_history( history_id_cache, uncommitted_modifications_cache )
    window_range_cache = val.window_range
    acorn_pipe_client.send( ( 'reload', val.client, opt.filetype, val.bufname ) )
    acorn_pipe_client.send( ( history_id_cache, history_cache, uncommitted_modifications_cache, window_range_cache.line, window_range_cache.height ) )
} }

define-command -hidden -override acorn_dump %{ py %{
    global acorn_state

    acorn_pipe_client.send( ( 'dump', val.client, opt.filetype, val.bufname ) )
} }

}

hook -once global User pykak %{ require-module acorn }
hook -once global User pykak_exit %{ acorn_exit }

