# telescope-py-outline.nvim

Outline including cell (# %%) is displayed in telescope.nvim.

![DEMO](/doc/demo.gif)

## Overview

This telescope display python outline including cell (# %%).

- It doesn't use treesitter, lsp.
- It need ripgrep, telescope.nvim.
- It express only Cell, function, class.

## Installation

```vim
Plug 'ok97465/telescope-py-outline.nvim'
```

## Configuration

```lua
require('telescope').load_extension('py_outline')
```

## Usage

```lua
require 'telescope'.extensions.py_outline.outline_file({layout_config={prompt_position="top"}, sorting_strategy="ascending"})
```

