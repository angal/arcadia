# Arcadia IDE
version 1.1.1

by Antonio Galeone
on Sep 29, 2015

## About

Arcadia is a light editor (IDE) for Ruby language 
written in Ruby using the classic Tcl/Tk GUI toolkit 
and developed with Arcadia itself.

Some of Arcadia IDE project features include:
 * Editor with source browsing, syntax highlighting, code completion
 * Working on any platform where Ruby and Tcl-Tk work.
 * Debugging support
 * Highly estensibile architecture.

## How to install
 * `exec on command line "gem install arcadia"`

## How to run
 * `exec on command line "arcadia"`

## Wiki
[https://github.com/angal/arcadia/wiki]

## News
[1.1.1] This release:
  - bug fixed [issue https://github.com/angal/arcadia/issues/58]

[1.1.0] This release:
  - added possibility to define custom runner:
    go to "run current" menubutton and click on "Manage runner ...". A dialog window will open.
    You can do actions as: "add new runner", "copy a runner", "delete a personal runner", "save".
    The list of runners is usable also in "Dir Projects".
    
    These are keywords that you can use in cmd definitions (see preconfigured runners):
    <<RUBY>> ruby interpreter
    <<FILE>> current file
    <<DIR>> current dir
    <<FILE_BASENAME>> basename of current file 
    <<FILE_BASENAME_WITHOUT_EXT>> basename of current file without extension
    <<INPUT_FILE>> open select file dialog to get file
    <<INPUT_DIR>> open select dir dialog to get dir
    <<INPUT_STRING>> open select string dialog to get a generic string
    
  - on ruby >= 2.0 added runner "debug selected as ruby file in console"
  - on ruby >= 2.0 discontinued dependence from rdebug gem
  - done changes for ruby >= 2.0 and tck/tk 8.6 compatability
  - improved "Output", added option to auto open in editor a file, usefull with
    the runner "debug selected as ruby file in console" 
  - fixed bugs
  - introduces other general improvements  

[1.0.0]
  - improves crossplatform features
  - changes dialogs metaphor
  - improves start speed
  - introduces other general improvements  
  
[0.13.1]
  - added Russian translation (Thanks to Michael)
  - bug fixes and various improvements

[0.13.0]
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
 - tcl/tk
 - tk-tile (if Tcl/Tk < 8.5)
 - ctags (Linux)
 - xterm (Linux, optional)
 - xdotool (Linux, optional)
 - ack (optional)
 - gem coderay (> 1.0)
 - gem debugger (only for Ruby < 2.0)
 - gem win32-process (only on Windows)
 - gem ruby-wmi (only on Windows)
  

## Short User guide
Application layout is splitted in vertical and horizontal resizable frames. 
On vertical and horizontal  splitter two button appear for left or right 
one shot frame closing. 
Every frame has a title, a button to expand or resizing it and a menu-button 
for dynamic layout functions (like add row, add column, close or for move a frame).

#### Main Toolbar
The toolbar button are in order:
- new, open, save, find
  (relatively to edit/find operation)
  after "new" there is a menubutton to choose a type of file
- new, open Dir Project, search in files, Open terminal from current folder, Toggle bookmark
- run current, run last 
  (for execute the raised file in the editor or the last runned file)  
  after "run current" there is a menubutton to choose a configurated runner to apply at current file
- (on ruby < 2.0) debug current, debug last, quit debug panel
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
- make custom action (by runners) 
- open terminal from selected dir 

#### File history
The last used files are organizing in tree so you can reopen them or their 
directory by clicking on the tree node.

#### Debug
Require debugger gem and ruby < 2.0.
It is created when a debug session init. 
The debug button are: Step Next, Step Into, Step Over, Resume and quit.
The debug frame show the local, instance and global variables for each
step. 

NOTE: at this moment on ruby >= 2.0 you can debug by using "debug selected as ruby file in console" runner
and optionally on "Output" the flag "auto open file in editor" using standard ruby debug input commands:

Debugger help v.-0.002b
Commands
  b[reak] [file:|class:]<line|method>
  b[reak] [class.]<line|method>
                             set breakpoint to some position
  wat[ch] <expression>       set watchpoint to some expression
  cat[ch] (<exception>|off)  set catchpoint to an exception
  b[reak]                    list breakpoints
  cat[ch]                    show catchpoint
  del[ete][ nnn]             delete some or all breakpoints
  disp[lay] <expression>     add expression into display expression list
  undisp[lay][ nnn]          delete one particular or all display expressions
  c[ont]                     run until program ends or hit breakpoint
  s[tep][ nnn]               step (into methods) one line or till line nnn
  n[ext][ nnn]               go over one line or till line nnn
  w[here]                    display frames
  f[rame]                    alias for where
  l[ist][ (-|nn-mm)]         list program, - lists backwards
                             nn-mm lists given lines
  up[ nn]                    move to higher frame
  down[ nn]                  move to lower frame
  fin[ish]                   return to outer frame
  tr[ace] (on|off)           set trace mode of current thread
  tr[ace] (on|off) all       set trace mode of all threads
  q[uit]                     exit from debugger
  v[ar] g[lobal]             show global variables
  v[ar] l[ocal]              show local variables
  v[ar] i[nstance] <object>  show instance variables of object
  v[ar] c[onst] <object>     show constants of object
  m[ethod] i[nstance] <obj>  show methods of object
  m[ethod] <class|module>    show instance methods of class or module
  th[read] l[ist]            list all threads
  th[read] c[ur[rent]]       show current thread
  th[read] [sw[itch]] <nnn>  switch thread context to nnn
  th[read] stop <nnn>        stop thread nnn
  th[read] resume <nnn>      resume thread nnn
  pp expression              evaluate expression and pretty_print its value
  p expression               evaluate expression and print its value
  r[estart]                  restart program
  h[elp]                     print this help
  <everything else>          evaluate  

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