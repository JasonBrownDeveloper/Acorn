# Acorn
Leverages [Tree-sitter](https://tree-sitter.github.io/tree-sitter/) to do more than syntax highlighting.

Built on top of [danr's](https://github.com/danr/pykak) fork of [tomKPZ's pykak](https://github.com/tomKPZ/pykak), Acorn uses [py-tree-sitter](https://tree-sitter.github.io/py-tree-sitter/) to integrate Tree-sitter utility into [Kakoune](https://kakoune.org/).

## Features
- Syntax highlighting
- Custom highlight queries
- Finer grain coloring
- Custom post processing for additional logic
- Navigation by tag

## Prerequisites
Install Python 3.
pip install py-tree-sitter and any languages you wish to support (e.g. tree-sitter-c).
Clone pykak and source it in your kakrc or link it to your autoload folder. At the time of writing some additional changes are needed from [this pull request](https://github.com/danr/pykak/pull/1).

## Installation
Clone Acorn and source it in your kakrc or link it to your autoload folder.

## Configuring
Once the module is loaded, AcornBegin can be set to initialize the configuration. acorn_state is a dictionary of configuration and state information that stays persistent in the accompanying pykak python instance.

```
hook global ModuleLoaded acorn %{

set-option global AcornBegin %{
global acorn_state
...
}  }
```

### Syntax highlighting
Tree-sitter grammars should be registered in the 'filetype' key.

```
acorn_state[ 'filetype' ].setdefault( 'c', {} )
acorn_state[ 'filetype' ][ 'c' ][ 'module' ] = 'tree_sitter_c'
```

### Custom highlight queries
Most grammars provide a highlight query but you may want to define your own.

```
acorn_state[ 'filetype' ][ 'c' ][ 'highlights_query' ] = """
    (identifier) @variable
...
    ((comment) @comment_line
     (#match? @comment_line "^//"))
    ((comment) @comment_block
     (#match? @comment_block "^/\*"))
    """
```

### Finer grain coloring
Tree-sitter highlight queries generate more precision than traditional syntax highlighting strategies.  We can leverage that to create more targeted coloring.

```
set-face global comment_line        "rgb:%opt{green_40}"
set-face global comment_block       "rgb:%opt{green_30}"
```

### Custom post processing for additional logic
Acorn can run a post-processing python function to highlight based on arbitrary rules. The function will be called once for each node in the tree. State between calls can be stored in acorn_state as needed. See included kakrc for an example.

### Navigation by tag
Most grammars will also provide a tags query. This will typically mark high level structures (e.g. function and class definitions). Acorn will allow you to cycle through each tag.

```
map -docstring 'Next tagged name' global user j ': acorn_next_tag<ret>'
map -docstring 'Previous tagged name' global user k ': acorn_prev_tag<ret>'
```
