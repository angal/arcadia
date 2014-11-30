# Arcadia IDE
version 1.0.0

by Antonio Galeone
on Nov 30, 2014

## About

Arcadia is a light editor (IDE) for Ruby language 
written in Ruby using the classic Tcl/Tk GUI toolkit.

Some of Arcadia ide project features include:
 * Editor with source browsing, syntax highlighting, code completion
 * Working on any platform where Ruby and Tcl-Tk work.
 * Debugging support
 * Highly estensibile architecture.

## How to install
 * `exec on command line "gem install arcadia"`

NOTE: on some linux distributions like archlinux the default Tcl/Tk runtime at this time is on versions >= 8.6
on the other hand ruby-tk supports fully only versions <= 8.5.x.y so to make arcadia working a choice 
can be install ActiveTcl 8.5 and use ruby via rvm. 

## How to run
 * `exec on command line "arcadia"`

## Wiki
[https://github.com/angal/arcadia/wiki]

## News
[1.0.0]
    This release:
  - improves crossplatform features
  - changes dialogs metaphor
  - improves start speed
  - introduces others general improvements  
  
[0.13.1]
    This release:
  - added Russian translation (Thanks to Michael)
  - bug fixes and various improvements

[0.13.0]
    This release:
  - improves file-history introducing bookmarks management
  - improves layout    
  - fixes bugs 

[0.12.2]
 - this release adds support to debugger gem and fixes minor bugs
  
[0.12.1] 
 - fixed bug in file-history 
 
[0.12.0]
 - added new extension : terminal's integration
   from Projects' navigator you can now open a terminal from selected directory
   in linux is required xterm and xdotool (xterm is embedded like a other frame) 
 - buffers' interchange between more instance of editor
 - introduced internationalization of text :
   in conf/LC/ are searched translation files in format <locale>.LANG (es. en-UK.LANG)
   locale is settable in ~/.arcadia/arcadia.conf overriding default (locale=en-UK)
  ... collaborations in translations are welcome!
 - added possibility to interact with running application typing input in output's console
 - introduced in file-history a new kind of view (list view) activable by button on toolbar  
 - bugs fixed and optimizations 
 
## Dependencies

  - rubygems
  - ruby-tk
  - tcl/tk (ruby-tk supports fully Tcl/Tk runtime <= 8.5 )
  - tk-tile (if Tcl/Tk < 8.5)
  - ctags (Linux)
  - xterm (Linux, optional)
  - xdotool (Linux, optional)
  - ack (optional)
  - gem coderay (> 1.0)
  - gem debugger (ruby-debug on Ruby < 1.9)
  - gem win32-process (only on Windows)
  - gem ruby-wmi (only on Windows)
  

## Short User guide
Application layout is splitted in vertical and horizontal resizable frames. 
On vertical and horizontal  splitter appear two button for left or right 
one shot frame closing. 
Every frame has a title, a button to expand or resizing it and a menu-button 
for dynamic layout functions (like add row, add column, close or for move a frame).

#### Main Toolbar
The toolbar button are in order:
- new, open, save, find
  (relatively to edit/find operation)
  after "new" there is a menubutton to choose a type of file
- run current, run last 
  (for execute the raised file in the editor or the last runned file)  
  after "run current" there is a menubutton to choose a configurated runner to apply at current file
- debug current, debug last, quit debug panel
  (for debug need)
- quit (to exit from arcadia)

#### Editor
Editor can use the notebook metaphor. Same command are on the popup menu 
that is raised on "Button-3" click event fundamentally for closing the tab 
under the mouse pointer.
These are same editor short-cut:
- Ctrl-c  => copy selected text
- Ctrl-v  => paste copied text
- Ctrl-x  => cut selected text
- Ctrl-g  => show go to line dialog
- Ctrl-o  => open file dialog
- Ctrl-d  => close file dialog
- Ctrl-z  => undo
- Ctrl-r  => redo
- Ctrl-f  => copy the selected text on input combobox of find dialog and moves focus
- Ctrl-s  => save
- Ctrl-space or esc => completion code
- Ctrl-shift-i or Tab => indent the selected block
- Ctrl-shift-u or Shift-Tab => unindent the selected block
- Ctrl-shift-c => comment/uncomment the selected code block
- Alt-shift-a => select all
- Alt-shift-i => invert selection
- Alt-shift-u => selected to uppercase
- Alt-shift-l => selected to lowercase
- F5 => execute the current file 
- F3 => find/ find next
- Ctrl-F3 => Search in files

- Double-Click on line number set or unset a debug breakpoint

#### Project drawer
It is a navigational tree: 
- open or create dir as project
- make commons file system activity (by contextual menu)
- open terminal from selected dir 

#### File history
The last used files are organizing in tree so you can reopen them or their 
directory by clicking on the tree node.

#### Debug
Require debugger gem.
It is created when a debug session init. 
The debug button are: Step Next, Step Into, Step Over, Resume and quit.
The debug frame show the local, instance and global variables for each
step. 

NOTE: at this moment debugger doesn't seem to work with ruby >= 2.0  

#### Configuration
Same Arcadia properties are locally configurabled by editing the file arcadia.conf
under ~/.arcadia  directory. The format of property definition are:
<OPERATING SYSTEM IDENTIFY::>PROPERTY_NAME=PROPERTY_VALUE


I have tested arcadia with ruby 1.8, 1.9, 2.x on 

 * Archlinux
 * Ubuntu/Mint
 * Fedora
 * FreeBsd, 
 * Vector linux,
 * Mac OS X
 * Windows 2000/XP/7, 
 * Cygwin (note: same page fault error on dll under cygwin may be solved in this way: `by ash.exe exec "/bin/rebaseall"`) 

## Developers e general information
Released on arcadia web site (http://www.arcadia-ide.org) 

## License
Arcadia is released under the Ruby License

## Contacts
For all questions:
support@arcadia-ide.org

For bugs, support request, features request:
http://github.com/angal/arcadia/issues

Repository at:
http://github.com/angal/arcadia/tree/master