# Copyright (C) Schelte Bron.  Freely redistributable.
# Version 1.14 - 27 Jun 2009

# File names containing <TAB> will mess up the layout. Tab char = \u2409

# Example proc for saving and restoring the user selections
proc ::ttk::__fsOptions {{arglist ""}} {
    variable fsOptions
    array set fsOptions $arglist
    array get fsOptions
}

# Import the style command in the ttk namespace, if it doesn't exist
namespace export style;catch {namespace eval ttk {namespace import ::style}}

# Install the example fsOptions proc if no fsOptions proc has been provided
if {[catch {rename ::ttk::__fsOptions ::ttk::fsOptions}]} {
    rename ::ttk::__fsOptions {}
}

namespace eval ::ttk::dialog {
}

namespace eval ::ttk::dialog::file {
    variable dirlist "" filelist "" filetype none opt
    array set opt {
	-sort		name
	-hidden		1
	-sepfolders	1
	-foldersfirst	1
	-details	0
	-reverse	0
	-filetype	none
	-typevariable	""
    }
    package require msgcat
    namespace import ::msgcat::mc
}

namespace eval ::ttk::dialog::image {
    variable dir [file dirname [info script]] err
    catch {image create photo -format png -data xxx} err
    if {$err eq "couldn't recognize image data"} {
	# Apparently png support is present
	source [file join $dir fsdlg-png.tcl]
    } else {
	# Fall back to the gif versions
	source [file join $dir fsdlg-gif.tcl]
    }
    unset dir err
}

### ttk::getOpenFile, ttk::getSaveFile, ttk::getAppendFile

interp alias {} ttk::getOpenFile {} ::ttk::dialog::file::tkFDialog open
interp alias {} ttk::getSaveFile {} ::ttk::dialog::file::tkFDialog save
interp alias {} ttk::getAppendFile {} ::ttk::dialog::file::tkFDialog append

proc ::ttk::dialog::file::Create {win class} {
    toplevel $win -class $class
    wm withdraw $win
    
    set dataName [winfo name $win]
    upvar ::ttk::dialog::file::$dataName data
    
    if {[info exists data(topLevel)] && $data(topLevel) ne $win} {
	destroy $data(topLevel)
    }
    set data(topLevel) $win
    
    # Additional frame to make sure the toplevel has the correct
    # background color for the theme
    #
    set w [ttk::frame $win.f]
    pack $w -fill both -expand 1
    
    # f1: the toolbar
    #
    set f1 [ttk::frame $w.f1 -class Toolbar]
    set data(bgLabel) [ttk::label $f1.bg -style Toolbutton]
    set data(upBtn) [ttk::button $f1.up -style Toolbutton]
    $data(upBtn) configure -image {::ttk::dialog::image::up 
    disabled ::ttk::dialog::image::upbw} \
      -command [list ::ttk::dialog::file::UpDirCmd $win]
    set data(prevBtn) [ttk::button $f1.prev -style Toolbutton]
    $data(prevBtn) configure -image {::ttk::dialog::image::previous
    disabled ::ttk::dialog::image::previousbw} \
      -command [list ::ttk::dialog::file::PrevDirCmd $win]
    set data(nextBtn) [ttk::button $f1.next -style Toolbutton]
    $data(nextBtn) configure -image {::ttk::dialog::image::next
    disabled ::ttk::dialog::image::nextbw} \
      -command [list ::ttk::dialog::file::NextDirCmd $win]
    set data(homeBtn) [ttk::button $f1.home -style Toolbutton]
    $data(homeBtn) configure -image {::ttk::dialog::image::gohome \
      disabled ::ttk::dialog::image::gohomebw} \
      -command [list ::ttk::dialog::file::HomeDirCmd $win]
    set data(reloadBtn) [ttk::button $f1.reload -style Toolbutton]
    $data(reloadBtn) configure -image ::ttk::dialog::image::reload \
      -command [list ::ttk::dialog::file::Update $win]
    set data(newBtn) [ttk::button $f1.new -style Toolbutton]
    $data(newBtn) configure -image ::ttk::dialog::image::folder_new \
      -command [list ::ttk::dialog::file::NewDirCmd $win]
    set data(cfgBtn) [ttk::menubutton $f1.cfg -style Toolbutton]
    set data(cfgMenu) [menu $data(cfgBtn).menu -tearoff 0]
    $data(cfgBtn) configure -image ::ttk::dialog::image::configure \
      -menu $data(cfgMenu)
    set data(dirMenuBtn) [ttk::combobox $f1.menu]
    $data(dirMenuBtn) configure \
      -textvariable ::ttk::dialog::file::${dataName}(selectPath)
    
    set data(sortMenu) [menu $data(cfgMenu).sort -tearoff 0]
    set image [option get $data(cfgMenu) image Image]
    set selimage [option get $data(cfgMenu) selectImage Image]
    
    $data(cfgMenu) add cascade -label " [mc Sorting]" \
      -menu $data(sortMenu) -image $image -compound left
    $data(cfgMenu) add separator
    $data(cfgMenu) add radiobutton -label [mc "Short View"] \
      -compound left -image $image -indicatoron 0 \
      -selectimage ::ttk::dialog::image::radio16 \
      -variable ::ttk::dialog::file::opt(-details) -value 0 \
      -command [list ::ttk::dialog::file::setopt $win -details]
    $data(cfgMenu) add radiobutton -label [mc "Detailed View"] \
      -compound left -image $image -indicatoron 0 \
      -selectimage ::ttk::dialog::image::radio16 \
      -variable ::ttk::dialog::file::opt(-details) -value 1 \
      -command [list ::ttk::dialog::file::setopt $win -details]
    $data(cfgMenu) add separator
    $data(cfgMenu) add checkbutton -label [mc "Show Hidden Files"] \
      -image $image -selectimage $selimage -compound left \
      -variable ::ttk::dialog::file::opt(-hidden) -indicatoron 0 \
      -command [list ::ttk::dialog::file::setopt $win -hidden]
    $data(cfgMenu) add checkbutton -label [mc "Separate Folders"] \
      -image $image -selectimage $selimage -compound left \
      -variable ::ttk::dialog::file::opt(-sepfolders) -indicatoron 0 \
      -command [list ::ttk::dialog::file::setopt $win -sepfolders]
    
    $data(sortMenu) add radiobutton -label [mc "By Name"] -compound left \
      -image $image -selectimage ::ttk::dialog::image::radio16 \
      -variable ::ttk::dialog::file::opt(-sort) -value name -indicatoron 0 \
      -command [list ::ttk::dialog::file::setopt $win -sort]
    $data(sortMenu) add radiobutton -label [mc "By Date"] -compound left \
      -image $image -selectimage ::ttk::dialog::image::radio16 \
      -variable ::ttk::dialog::file::opt(-sort) -value date -indicatoron 0 \
      -command [list ::ttk::dialog::file::setopt $win -sort]
    $data(sortMenu) add radiobutton -label [mc "By Size"] -compound left \
      -image $image -selectimage ::ttk::dialog::image::radio16 \
      -variable ::ttk::dialog::file::opt(-sort) -value size -indicatoron 0 \
      -command [list ::ttk::dialog::file::setopt $win -sort]
    $data(sortMenu) add separator
    $data(sortMenu) add checkbutton -label [mc "Reverse"] \
      -image $image -selectimage $selimage -compound left \
      -variable ::ttk::dialog::file::opt(-reverse) -indicatoron 0 \
      -command [list ::ttk::dialog::file::setopt $win -reverse]
    $data(sortMenu) add checkbutton -label [mc "Folders First"] \
      -image $image -selectimage $selimage -compound left \
      -variable ::ttk::dialog::file::opt(-foldersfirst) -indicatoron 0 \
      -command [list ::ttk::dialog::file::setopt $win -foldersfirst]
    
    $data(prevBtn) state disabled
    $data(nextBtn) state disabled
    if {![info exists ::env(HOME)]} {
	$data(homeBtn) state disabled
    }
    
    place $data(bgLabel) -relheight 1 -relwidth 1
    
    pack $data(upBtn) -side left -fill y
    pack $data(prevBtn) -side left -fill y
    pack $data(nextBtn) -side left -fill y
    pack $data(homeBtn) -side left -fill y
    pack $data(reloadBtn) -side left -fill y
    pack $data(newBtn) -side left -fill y
    pack $data(cfgBtn) -side left -fill y
    pack $data(dirMenuBtn) -side left -fill x -expand 1 -padx 8
    
    # f2: the frame with the OK button, cancel button, "file name" field,
    #     and file types field.
    #
    set f2 [ttk::frame $w.f2]
    ttk::label $f2.lab1 -text "[mc Location]:" -anchor w
    set data(location) [ttk::combobox $f2.loc -validate key \
      -validatecommand [list ::ttk::dialog::file::LocEdit $win %S]]
    $data(location) configure \
      -textvariable ::ttk::dialog::file::${dataName}(selectFile)
    set data(typeMenuLab) [ttk::label $f2.lab2 -anchor w -text "[mc Filter]:"]
    set data(typeMenuBtn) [ttk::combobox $f2.filter]
    set data(okBtn) [ttk::button $f2.ok -text [mc OK] -default active \
      -width 8 -style Slim.TButton \
      -command [list ::ttk::dialog::file::Done $win]]
    set data(cancelBtn) [ttk::button $f2.cancel -text [mc Cancel] -width 8 \
      -style Slim.TButton -command [list ::ttk::dialog::file::Cancel $win]]
    
    grid $f2.lab1 $f2.loc $data(okBtn) -padx 4 -pady 5 -sticky ew
    grid $f2.lab2 $f2.filter $data(cancelBtn) -padx 4 -pady 5 -sticky ew
    grid columnconfigure $f2 1 -weight 1
    
    # f3: The file and directory lists
    #
    set f3 [ttk::panedwindow $w.f3 -orient horizontal]
    array set fontinfo [font actual [[label $f3.dummy] cget -font]]
    set font [maxfont $fontinfo(-family) 16]
    destroy $f3.dummy
    $f3 add [ttk::frame $f3.dir] -weight 0
    ttk::label $f3.dir.bg -relief sunken
    set data(dirArea) [text $f3.dir.t -bg white -width 20 -height 16 \
      -font $font -bd 0 -highlightthickness 0 -cursor "" \
      -wrap none -spacing1 1 -spacing3 1 -exportselection 0 \
      -state disabled -yscrollcommand [list $f3.dir.y set] \
      -xscrollcommand [list $f3.dir.x set]]
    ttk::scrollbar $f3.dir.y -command [list $f3.dir.t yview]
    ttk::scrollbar $f3.dir.x -command [list $f3.dir.t xview] -orient horizontal
    grid $f3.dir.t $f3.dir.y -sticky ns
    grid $f3.dir.x -sticky we
    grid $f3.dir.bg -row 0 -column 0 -rowspan 2 -columnspan 2 -sticky news
    grid $f3.dir.t -sticky news -padx {2 0} -pady {2 0}
    grid columnconfigure $f3.dir 0 -weight 1
    grid rowconfigure $f3.dir 0 -weight 1
    
    $f3 add [ttk::frame $f3.file] -weight 1
    
    # The short view version
    #
    set data(short) [ttk::frame $f3.file.short]
    ttk::label $data(short).bg -relief sunken
    set data(fileArea) [text $data(short).t -width 42 -height 16 -bg white \
      -font $font -bd 0 -highlightthickness 0 -cursor "" -wrap none \
      -spacing1 1 -spacing3 1 -exportselection 0 -state disabled \
      -xscrollcommand [list ::ttk::dialog::file::scrollset $win]]
    set data(xScroll) [ttk::scrollbar $data(short).x -orient horizontal \
      -command [list ::ttk::dialog::file::xview $win]]
    grid $data(short).t -sticky news -padx 2 -pady {2 0}
    grid $data(short).x -sticky ew
    grid $data(short).bg -row 0 -column 0 \
      -rowspan 2 -columnspan 2 -sticky news
    grid columnconfigure $data(short) 0 -weight 1
    grid rowconfigure $data(short) 0 -weight 1
    
    # The detailed view version
    #
    set data(long) [ttk::frame $f3.file.long]
    ttk::label $data(long).bg -relief sunken
    ttk::frame $data(long).f
    set data(fileHdr) [frame $data(long).f.f]
    ttk::label $data(fileHdr).l0 -style Toolbutton -anchor w -text [mc Name]
    ttk::label $data(fileHdr).l1 -style Toolbutton -anchor w -text [mc Size]
    ttk::label $data(fileHdr).l2 -style Toolbutton -anchor w -text [mc Date]
    ttk::label $data(fileHdr).l3 \
      -style Toolbutton -anchor w -text [mc Permissions]
    ttk::label $data(fileHdr).l4 -style Toolbutton -anchor w -text [mc Owner]
    ttk::label $data(fileHdr).l5 -style Toolbutton -anchor w -text [mc Group]
    ttk::separator $data(fileHdr).s1 -orient vertical
    ttk::separator $data(fileHdr).s2 -orient vertical
    ttk::separator $data(fileHdr).s3 -orient vertical
    ttk::separator $data(fileHdr).s4 -orient vertical
    ttk::separator $data(fileHdr).s5 -orient vertical
    set height [winfo reqheight $data(fileHdr).l1]
    $data(long).f configure -height [expr {$height + 1}]
    $data(fileHdr) configure -height $height
    place $data(fileHdr) -x 1 -relwidth 1
    place $data(fileHdr).l0 -x -1 -relwidth 1 -relheight 1
    place $data(fileHdr).s1 -rely .1 -relheight .8 -anchor n
    place $data(fileHdr).s2 -rely .1 -relheight .8 -anchor n
    place $data(fileHdr).s3 -rely .1 -relheight .8 -anchor n
    place $data(fileHdr).s4 -rely .1 -relheight .8 -anchor n
    place $data(fileHdr).s5 -rely .1 -relheight .8 -anchor n
    set data(fileList) [text $data(long).t -width 42 -height 12 -bg white \
      -font $font -bd 0 -highlightthickness 0 -cursor "" -wrap none \
      -spacing1 1 -spacing3 1 -exportselection 0 -state disabled \
      -yscrollcommand [list $data(long).y set] \
      -xscrollcommand [list ::ttk::dialog::file::scrollhdr $win]]
    ttk::scrollbar $data(long).y -command [list $data(long).t yview]
    ttk::scrollbar $data(long).x -orient horizontal \
      -command [list $data(long).t xview]
    grid $data(long).f $data(long).y -sticky ew -padx {2 0} -pady {2 0}
    grid $data(long).t ^ -sticky news -padx {2 0}
    grid $data(long).x -sticky ew
    grid $data(long).y -sticky ns -padx 0 -pady 0
    grid $data(long).bg -row 0 -column 0 \
      -rowspan 3 -columnspan 2 -sticky news
    grid columnconfigure $data(long) 0 -weight 1
    grid rowconfigure $data(long) 1 -weight 1
    
    grid $data(long) $data(short) -row 0 -column 0 -sticky news
    grid columnconfigure $f3.file 0 -weight 1
    grid rowconfigure $f3.file 0 -weight 1
    
    # Get rid of the default Text bindings
    bindtags $data(dirArea) [list $data(dirArea) FileDialogDir $win all]
    bindtags $data(fileArea) [list $data(fileArea) FileDialogFile $win all]
    bindtags $data(fileList) [list $data(fileList) FileDialogList $win all]
    
    $data(fileArea) tag bind file <1> \
      {set ::ttk::dialog::file::filetype file}
    $data(fileArea) tag bind characterSpecial <1> \
      {set ::ttk::dialog::file::filetype file}
    $data(fileArea) tag bind blockSpecial <1> \
      {set ::ttk::dialog::file::filetype file}
    $data(fileArea) tag bind fifo <1> \
      {set ::ttk::dialog::file::filetype file}
    $data(fileArea) tag bind link <1> \
      {set ::ttk::dialog::file::filetype link}
    $data(fileArea) tag bind directory <1> \
      {set ::ttk::dialog::file::filetype directory}
    $data(fileList) tag bind file <1> \
      {set ::ttk::dialog::file::filetype file}
    $data(fileList) tag bind characterSpecial <1> \
      {set ::ttk::dialog::file::filetype file}
    $data(fileList) tag bind blockSpecial <1> \
      {set ::ttk::dialog::file::filetype file}
    $data(fileList) tag bind fifo <1> \
      {set ::ttk::dialog::file::filetype file}
    $data(fileList) tag bind link <1> \
      {set ::ttk::dialog::file::filetype link}
    $data(fileList) tag bind directory <1> \
      {set ::ttk::dialog::file::filetype directory}
    
    set data(paneWin) $f3
    
    pack $f1 -side top -fill x
    pack $f2 -side bottom -fill x -padx 8 -pady {0 5}
    pack $f3 -side bottom -fill both -expand 1 -padx 8 -pady {6 0}
    
    set data(columns) 0
    set data(history) ""
    set data(histpos) -1
    set data(select) 0
    
    update idletasks
    pack propagate $w 0
    
    wm protocol $win WM_DELETE_WINDOW [list $data(cancelBtn) invoke]
    
    bind $win <Escape> [list $data(cancelBtn) invoke]
    bind $data(fileArea) <Configure> [list ::ttk::dialog::file::configure $win]
    bind $data(dirMenuBtn) <Return> [list ::ttk::dialog::file::chdir $win]
    bind $data(dirMenuBtn) <<ComboboxSelected>> \
      [list ::ttk::dialog::file::chdir $win]
    bind $data(location) <Return> [list ::ttk::dialog::file::Done $win]
    bind $data(typeMenuBtn) <Return> [list ::ttk::dialog::file::SetFilter $win]
    bind $data(typeMenuBtn) <<ComboboxSelected>> \
      [list ::ttk::dialog::file::SelectFilter $win]
}

proc ::ttk::dialog::file::ChangeDir {w dir} {
    set dataName [winfo name $w]
    upvar ::ttk::dialog::file::$dataName data
    
    set data(history) [lrange $data(history) 0 $data(histpos)]
    set cwd [lindex $data(history) $data(histpos)]
    set data(selectPath) [file normalize [file join $cwd $dir]]
    lappend data(history) $data(selectPath)
    if {[incr data(histpos)]} {
	$data(prevBtn) state !disabled
	set data(selectFile) ""
    }
    $data(nextBtn) state disabled
    
    UpdateWhenIdle $w
}

proc ::ttk::dialog::file::UpdateWhenIdle {w} {
    upvar ::ttk::dialog::file::[winfo name $w] data
    
    if {[info exists data(updateId)]} {
	return
    } elseif {[winfo ismapped $w]} {
	set after idle
    } else {
	set after 1
    }
    set data(updateId) [after $after [list ::ttk::dialog::file::Update $w]]
}

proc ::ttk::dialog::file::Update {w} {
    # This proc may be called within an idle handler. Make sure that the
    # window has not been destroyed before this proc is called
    if {![winfo exists $w]} return
    
    set dataName [winfo name $w]
    upvar ::ttk::dialog::file::$dataName data
    unset -nocomplain data(updateId)
    
    if {$data(-details)} {
	grid $data(long)
	grid remove $data(short)
    } else {
	grid $data(short)
	grid remove $data(long)
    }
    if {$data(-sepfolders)} {
	if {![llength [winfo manager $data(paneWin).dir]]} {
	    $data(paneWin) insert 0 $data(paneWin).dir
	}
    } else {
	if {[llength [winfo manager $data(paneWin).dir]]} {
	    $data(paneWin) forget 0
	}
    }
    
    $w configure -cursor watch
    update
    
    set dir ::ttk::dialog::image::folder
    set file ::ttk::dialog::image::file
    
    set cwd [lindex $data(history) $data(histpos)]
    
    if {$data(-hidden)} {
	set pattern "* .*"
    } else {
	set pattern "*"
    }
    
    # Make the directory list
    if {[catch [linsert $pattern 0 glob -nocomplain -tails \
      -directory $cwd -type d] list]} {
	$w configure -cursor ""
	tk_messageBox -icon warning -type ok -parent $w -message \
	  [mc {Cannot change to the directory "%s". Permission denied.} \
	  $cwd]
	set data(history) [lreplace $data(history) \
	  $data(histpos) $data(histpos)]
	if {$data(histpos) > 0} {incr data(histpos) -1}
	return
    }
    set dlist ""
    foreach f $list {
	if {$f eq "."} continue
	if {$f eq ".."} continue
	lappend dlist [list $f dir]
    }
    
    # Make the file list	
    set flist ""
    set filter $data(filter)
    if {$filter eq "*"} {
	set filter $pattern
    }
    foreach f [eval [linsert $filter 0 glob -nocomplain -tails \
      -directory $cwd -type {f l c b p}]] {
	# Links can still be directories. Skip those.
	if {[file isdirectory [file join $cwd $f]]} continue
	lappend flist [list $f file]
    }
    
    # Combine the two lists, if necessary
    if {$data(-sepfolders)} {
	set dlist [sort $w $dlist]
	set flist [sort $w $flist]
    } elseif {$data(-foldersfirst)} {
	set flist [concat [sort $w $dlist] [sort $w $flist]]
	set dlist ""
    } else {
	set flist [sort $w [concat $flist $dlist]]
	set dlist ""
    }
    
    set t $data(dirArea) 
    $t configure -state normal
    $t delete 1.0 end
    foreach f $dlist {
	$t image create end -image $dir
	$t insert end " [lindex $f 0]\n"
    }
    $t delete end-1c end
    $t configure -state disabled
    
    if {$data(-details)} {
	set data(list) $flist
	::ttk::dialog::file::FileList1 $w
    } else {
	set t $data(fileArea)
	set maxsize 50
	set list ""
	set font [$t cget -font]
	foreach f $flist {
	    lassign $f name type
	    lappend list $name $type
	    set size [font measure $font " $name"]
	    if {$size > $maxsize} {
		set maxsize $size
	    }
	}
	# Make sure maxsize is a multiple of an average size character
	set dx [font measure $font 0]
	set maxsize [expr {($maxsize + 20 + $dx) / $dx * $dx}]
	$t configure -tabs $maxsize
	set data(colwidth) $maxsize
	set data(rows) [expr {[winfo height $t] / 18}]
	set data(list) $list
	::ttk::dialog::file::FileList2 $w
    }
    
    if {$cwd eq "/"} {
	$data(upBtn) state disabled
    } else {
	$data(upBtn) state !disabled
    }
    $w configure -cursor ""
}

# Create a detailed file list
proc ::ttk::dialog::file::FileList1 {w} {
    set dataName [winfo name $w]
    upvar ::ttk::dialog::file::$dataName data
    
    set dir ::ttk::dialog::image::folder
    set file ::ttk::dialog::image::file
    
    set cwd [lindex $data(history) $data(histpos)]
    
    set t $data(fileList)
    $t configure -state normal
    $t delete 1.0 end
    set size "";set date "";set mode "";set uid "";set gid ""
    set files {}
    set maxsize 50
    set font [$t cget -font]
    foreach f $data(list) {
	lassign $f name type size date mode uid gid
	if {![info exists users($uid)] || ![info exists groups($gid)]} {
	    set fname [file join $cwd $name]
	    # May fail for dead links
	    if {![catch {array set attr [file attributes $fname]}]} {
		if {[info exists attr(-owner)]} {
		    set users($uid) $attr(-owner)
		} else {
		    set users($uid) ""
		}
		if {[info exists attr(-group)]} {
		    set groups($gid) $attr(-group)
		} else {
		    set groups($gid) ""
		}
	    }	
	}
	catch {set uid $users($uid)}
	catch {set gid $groups($gid)}
	set image [expr {$type eq "directory" ? $dir : $file}]
	set img [$t image create end -image $image]
	$t tag add name $img
	$t tag add $type $img
	$t insert end " $name" [list name $type]
	$t insert end "\t$size\t" $type
	$t insert end "[datefmt $date]\t" $type
	$t insert end "[modefmt $type $mode]\t" $type
	$t insert end "$uid\t$gid\t\n" $type
	set size [font measure $font " $name"]
	if {$size > $maxsize} {set maxsize $size}
	lappend files $name
    }
    $t delete end-1c end
    $t configure -state disabled
    set today [datefmt [clock seconds]]
    set maxu [winfo reqwidth $data(fileHdr).l4]
    foreach n [array names users] {
	set size [font measure $font $users($n)]
	if {$size > $maxu} {set maxu $size}
    }
    set maxg [winfo reqwidth $data(fileHdr).l5]
    foreach n [array names groups] {
	set size [font measure $font $groups($n)]
	if {$size > $maxg} {set maxg $size}
    }
    set tabs [list [set x [incr maxsize 22]]]
    lappend tabs [incr x [font measure $font 1000000000]] \
      [incr x [font measure $font " $today "]] \
      [incr x [font measure $font [modefmt w 0777]]] \
      [incr x [incr maxu 8]] [incr x [incr maxg 8]]
    $t configure -tabs $tabs
    set i 1
    foreach n $tabs {
	place $data(fileHdr).l$i -x $n
	place $data(fileHdr).s$i -x $n
	if {[incr i] > 5} break
    }
    
    # Reselect the files the user selected before
    if {$data(select)} {
	if {$data(-multiple)} {
	    set select $data(selectFile)
	} else {
	    set select [list $data(selectFile)]
	}
	foreach file $select {
	    set row [lsearch -exact $files $file]
	    if {$row < 0} continue
	    foreach {m1 m2} [$t tag nextrange name [incr row].0] {
		$t tag add sel "$m1 + 2c" $m2
	    }
	}
    }
}

# Create a short file list
proc ::ttk::dialog::file::FileList2 {w} {
    set dataName [winfo name $w]
    upvar ::ttk::dialog::file::$dataName data
    
    set dir ::ttk::dialog::image::folder
    set file ::ttk::dialog::image::file
    
    set t $data(fileArea)
    set lines $data(rows)
    set row 1;set col 0
    set coltag column$col
    set files {}
    $t configure -state normal
    $t delete 1.0 end
    foreach {name type} $data(list) {
	set idx $row.end
	set image [expr {$type eq "directory" ? $dir : $file}]
	set img [$t image create $idx -image $image]
	$t tag add $type $img
	$t tag add name $img
	$t insert $idx " $name" [list name $type $coltag] "\t" $type
	lappend files $name
	if {[incr row] > $lines} {
	    set coltag column[incr col]
	    set row 1
	} elseif {$col == 0} {
	    $t insert $idx "\n"
	}
    }
    $t insert 1.end "\t"
    $t configure -state disabled
    set data(columns) [expr {$row > 1 ? $col + 1 : $col}]
    
    # Should possibly restore the position of the last clicked file?
    $t mark unset lastpos
    
    # Reselect the files the user selected before
    if {$data(select)} {
	if {$data(-multiple)} {
	    set select $data(selectFile)
	} else {
	    set select [list $data(selectFile)]
	}
	foreach file $select {
	    set x [lsearch -exact $files $file]
	    if {$x < 0} continue
	    set row [expr {$x % $lines + 1}]
	    set col [expr {$x / $lines}]
	    foreach {m1 m2} [$t tag nextrange column$col $row.0] {
		$t tag add sel "$m1 + 1c" $m2
	    }
	}
    }
}

proc ::ttk::dialog::file::LocEdit {w str} {
    # This proc is called when a user edits the Location field
    set dataName [winfo name $w]
    upvar ::ttk::dialog::file::$dataName data
    
    $data(fileArea) tag remove sel 1.0 end
    set data(select) 0
    
    return 1
}

proc ::ttk::dialog::file::sort {w list} {
    set dataName [winfo name $w]
    upvar ::ttk::dialog::file::$dataName data
    
    set cwd [lindex $data(history) $data(histpos)]
    set order [expr {$data(-reverse) ? "-decreasing" : "-increasing"}]
    set newlist ""
    foreach f $list {
	set file [lindex $f 0]
	# Use lstat in case the destination doesn't exists
	file lstat [file join $cwd $file] stat
	if {$stat(type) eq "link"} {
	    # This may fail if the link points to nothing
	    if {![catch {file stat [file join $cwd $file] dest}]} {
		array set stat [array get dest]
		if {$stat(type) eq "file"} {
		    set stat(type) link
		}
	    }
	}
	lappend newlist [list $file $stat(type) $stat(size) \
	  $stat(mtime) $stat(mode) $stat(uid) $stat(gid)]
    }
    switch -- $data(-sort) {
	size {
	    set mode -integer
	    set idx 2
	}
	date {
	    set mode -integer
	    set idx 3
	}
	default {
	    set mode -dictionary
	    set idx 0
	}
    }
    lsort $order $mode -index $idx $newlist
}

proc ::ttk::dialog::file::datefmt {str} {
    clock format $str -format {%d-%m-%Y %H:%M}
}

proc ::ttk::dialog::file::modefmt {type mode} {
    switch $type {
	file {set rc -}
	default {set rc [string index $type 0]}
    }
    binary scan [binary format I $mode] B* bits
    foreach b [split [string range $bits end-8 end] ""] \
      c {r w x r w x r w x} {
	if {$b} {append rc $c} else {append rc -}
    }
    set rc
}

proc ::ttk::dialog::file::xview {w cmd number {units ""}} {
    set dataName [winfo name $w]
    upvar ::ttk::dialog::file::$dataName data
    
    set width [winfo width $data(fileArea)]
    lassign [$data(fileArea) xview] pos1 pos2
    set cols $data(columns)
    set page [expr {int($width / $data(colwidth))}]
    if {!$page} {set page 1}
    
    switch $cmd {
	scroll {
	    set col [expr {round($pos1 * ($cols + 1))}]
	    if {[string match p* $units]} {
		incr col [expr {$number * $page}]
	    } else {
		incr col $number
	    }
	}
	moveto {
	    set col [expr {round($number * $cols)}]
	}
    }
    set max [expr {$cols - $page}]
    if {$col > $max} {set col $max}
    if {$col < 0} {set col 0}
    set pos [expr {double($col) / ($cols + 1)}]
    $data(fileArea) xview moveto $pos
}

proc ::ttk::dialog::file::scrollset {w first last} {
    set dataName [winfo name $w]
    upvar ::ttk::dialog::file::$dataName data
    
    if {$data(columns)} {
	if {$last >= 0.999} {
	    xview $w scroll -1 units
	    return
	}
	set w $data(colwidth)
	set cols $data(columns)
	set width [winfo width $data(fileArea)]
	if {$w > $width} {set w $width}
	set vwidth [expr {$width % $w + $cols * $w}]
	set total [expr {$width / ($last - $first)}]
	set first [expr {$first * $total / $vwidth}]
	set last [expr {$last * $total / $vwidth}]
    }
    
    $data(xScroll) set $first $last
}

proc ::ttk::dialog::file::scrollhdr {w first last} {
    set dataName [winfo name $w]
    upvar ::ttk::dialog::file::$dataName data
    
    lassign [$data(fileList) dlineinfo @0,0] x y width height base
    place $data(fileHdr) -x $x -width $width
    $data(long).x set $first $last
}

proc ::ttk::dialog::file::configure {w} {
    set dataName [winfo name $w]
    upvar ::ttk::dialog::file::$dataName data
    
    if {$data(columns) == 0} return
    
    set h [winfo height $data(fileArea)]
    set rows [expr {$h / 18}]
    if {$rows != $data(rows)} {
	set data(rows) $rows
	::ttk::dialog::file::FileList2 $w
    }
}

proc ::ttk::dialog::file::setopt {w option} {
    set dataName [winfo name $w]
    upvar ::ttk::dialog::file::$dataName data
    variable opt
    
    set data($option) $opt($option)
    UpdateWhenIdle $w	
}

proc ::ttk::dialog::file::maxfont {family max} {
    set size [expr {2 - $max}]
    while {[font metrics [list $family $size] -linespace] > $max} {
	if {[incr size] > -8} break
    }
    return [list $family $size]
}

proc ::ttk::dialog::file::UpDirCmd {w} {
    set dataName [winfo name $w]
    upvar ::ttk::dialog::file::$dataName data
    
    ChangeDir $w [file dirname [lindex $data(history) $data(histpos)]]
}

proc ::ttk::dialog::file::PrevDirCmd {w} {
    set dataName [winfo name $w]
    upvar ::ttk::dialog::file::$dataName data
    
    # set data(selectFile) ""
    incr data(histpos) -1
    set data(selectPath) [lindex $data(history) $data(histpos)]
    $data(nextBtn) state !disabled
    if {!$data(histpos)} {
	$data(prevBtn) state disabled
    }
    Update $w
}

proc ::ttk::dialog::file::NextDirCmd {w} {
    set dataName [winfo name $w]
    upvar ::ttk::dialog::file::$dataName data
    
    # set data(selectFile) ""
    incr data(histpos)
    set data(selectPath) [lindex $data(history) $data(histpos)]
    $data(prevBtn) state !disabled
    if {$data(histpos) >= [llength $data(history)] - 1} {
	$data(nextBtn) state disabled
    }
    Update $w
}

proc ::ttk::dialog::file::HomeDirCmd {w} {
    ChangeDir $w ~
}

proc ::ttk::dialog::file::NewDirCmd {win} {
    set dataName [winfo name $win]
    upvar ::ttk::dialog::file::$dataName data
    
    set dir [lindex $data(history) $data(histpos)]
    
    toplevel $win.new
    wm title $win.new [mc "New Folder"]
    set w [ttk::frame $win.new.f]
    pack $w -expand 1 -fill both
    
    ttk::label $w.prompt -anchor w -justify left \
      -text [mc "Create new folder in"]:\n$dir
    ttk::entry $w.box -width 36 -validate all \
      -validatecommand [list ::ttk::dialog::file::NewDirVCmd $w %P]
    ttk::separator $w.sep
    set f [ttk::frame $w.buttons]
    ttk::button $f.clear -text [mc Clear] -takefocus 0 \
      -command [list $w.box delete 0 end]
    ttk::button $f.ok -text [mc OK] -default active \
      -command [list ::ttk::dialog::file::NewDirExit $win 1]
    ttk::button $f.cancel -text [mc Cancel] \
      -command [list ::ttk::dialog::file::NewDirExit $win]
    grid $f.clear $f.ok $f.cancel -padx 4 -pady {0 10} -sticky we
    grid columnconfigure $f {0 1 2} -uniform 1
    pack $w.prompt $w.box $w.sep $f \
      -side top -padx 12 -pady 3 -anchor w -fill x
    pack $w.prompt -pady {12 0}
    pack $f -anchor e -fill none -padx 8
    wm transient $win.new $win
    wm resizable $win.new 0 0
    wm protocol $win.new WM_DELETE_WINDOW [list $f.cancel invoke]
    
    bind $w.box <Return> [list $f.ok invoke]
    
    ::tk::PlaceWindow $win.new widget $win
    ::tk::SetFocusGrab $win.new $w.box
}

proc ::ttk::dialog::file::NewDirVCmd {w str} {
    if {$str ne ""} {
	$w.buttons.ok state !disabled
	$w.buttons.clear state !disabled
    } else {
	$w.buttons.ok state disabled
	$w.buttons.clear state disabled
    }
    return 1
}

proc ::ttk::dialog::file::NewDirExit {w {save 0}} {
    upvar ::ttk::dialog::file::[winfo name $w] data
    
    if {$save} {
	set dir [lindex $data(history) $data(histpos)]
	set newdir [file join $dir [$w.new.f.box get]]
	if {[catch {file mkdir $newdir} err]} {
	    tk_messageBox -type ok -parent $w.new -icon error -message "$err"
	    return
	} else {
	    ChangeDir $w $newdir
	}
    }
    destroy $w.new
    ::tk::RestoreFocusGrab $w.new $w.new.f.box
}

proc ::ttk::dialog::file::Cancel {w} {
    variable selectFilePath ""
}

proc ::ttk::dialog::file::Done {w} {
    variable selectFilePath
    variable filelist
    set dataName [winfo name $w]
    upvar ::ttk::dialog::file::$dataName data
    
    if {$data(selectFile) eq "" || $data(selectFile) eq "."} {
	return -code break
    }
    
    set cwd [lindex $data(history) $data(histpos)]
    set path ""
    if {$data(-multiple) && ![catch {llength $data(selectFile)}]} {
	foreach file $data(selectFile) {
	    if {[file extension $file] eq ""} {
		append file $data(-defaultextension)
	    }
	    lappend path [file join $cwd $file]
	}
    } else {
	set file [file join $cwd $data(selectFile)]
	if {[file extension $file] eq ""} {
	    append file $data(-defaultextension)
	}
	set path [list $file]
    }
    
    set missing ""
    foreach file $path {
	if {[file isdirectory $file]} {
	    set data(selectFile) ""
	    ChangeDir $w $file
	    return -code break
	}
	if {![file exists $file]} {
	    lappend missing $file
	}
    }
    
    if {[llength $missing]} {
	if {$data(type) eq "open"} {
	    if {[llength $missing] > 1} {
		set str {Files %s do not exist.}
	    } else {
		set str {File "%s" does not exist.}
	    }
	    tk_messageBox -icon warning -type ok -parent $w \
	      -message [mc $str [join $missing {, }]]
	    return
	}
    } else {
	if {$data(type) eq "save"} {
	    set str {File "%s" already exists. Do you want to overwrite it?}
	    set reply [tk_messageBox -parent $w -icon warning -type yesno \
	      -message [mc $str [lindex $path 0]]]
	    if {$reply eq "no"} {return}
	}
    }
    
    foreach file $path {
	set filelist [lsearch -exact -all -inline -not $filelist $file]
	set filelist [linsert $filelist 0 $file]
    }
    if {$data(-multiple)} {
	set selectFilePath $path
    } else {
	set selectFilePath [lindex $path 0]
    }
    return -code break
}

proc ::ttk::dialog::file::chdir {w} {
    upvar ::ttk::dialog::file::[winfo name $w] data
    
    set dir $data(selectPath)
    if {[file isdirectory $dir]} {
	ChangeDir $w $dir
    } else {
	set str {Cannot change to the directory "%s". Permission denied.}
	tk_messageBox -type ok -parent $w -icon warning \
	  -message [mc $str $data(selectPath)]
    }
    return -code break
}

proc ::ttk::dialog::file::SelectFilter {w} {
    upvar ::ttk::dialog::file::[winfo name $w] data
    
    set data(filter) [lindex $data(-filetypes) \
      [$data(typeMenuBtn) current] 1]
    set data(typevar) [lindex $data(-filetypes) \
      [$data(typeMenuBtn) current] 0]
    ::ttk::dialog::file::UpdateWhenIdle $w
}

proc ::ttk::dialog::file::SetFilter {w} {
    upvar ::ttk::dialog::file::[winfo name $w] data
    
    set data(filter) [$data(typeMenuBtn) get]
    set data(typevar) ""
    ::ttk::dialog::file::UpdateWhenIdle $w
    return -code break
}

proc ::ttk::dialog::file::DirButton1 {w x y} {
    scan [$w index @$x,$y] %d.%d line char
    $w tag remove sel 1.0 end
    $w tag add sel $line.2 $line.end
}

proc ::ttk::dialog::file::DirRelease1 {w x y} {
    set top [winfo toplevel $w]
    $top configure -cursor ""
}

proc ::ttk::dialog::file::DirRelease1 {w x y} {
    set top [winfo toplevel $w]
    if {[$top cget -cursor] ne ""} {
	# The mouse has been moved, don't perform the action
	$top configure -cursor ""
    } elseif {[llength [$w tag ranges sel]]} {
	set dir [$w get sel.first sel.last]
	ChangeDir [winfo toplevel $w] $dir
    }
}

proc ::ttk::dialog::file::DirMotion1 {w x y} {
    [winfo toplevel $w] configure -cursor "X_cursor #C00 #000"
}

proc ::ttk::dialog::file::FileButton1 {w x y} {
    set dataName [winfo name [winfo toplevel $w]]
    upvar ::ttk::dialog::file::$dataName data
    variable filetype
    
    if {$filetype eq "none"} return
    
    set range [$w tag prevrange name @$x,$y+1c "@$x,$y linestart"]
    $w mark set lastpos @$x,$y
    
    if {[llength $range]} {
	lassign $range index1 index2
	$w tag remove sel 1.0 end
	$w tag add sel $index1+2c $index2
	set data(select) 1
	if {$filetype ne "file" && $filetype ne "link"} {
	} elseif {$data(-multiple)} {
	    set data(selectFile) [list [$w get sel.first sel.last]]
	} else {
	    set data(selectFile) [$w get sel.first sel.last]
	}
    }
}

proc ::ttk::dialog::file::FileRelease1 {w x y} {
    set dataName [winfo name [winfo toplevel $w]]
    upvar ::ttk::dialog::file::$dataName data
    variable filetype
    
    set top [winfo toplevel $w]
    if {[$top cget -cursor] ne ""} {
	# The mouse has been moved, don't perform the action
	$top configure -cursor ""
    } elseif {$filetype ne "directory"} {
	# A file was selected
    } elseif {[llength [$w tag ranges sel]]} {
	set dir [$w get sel.first sel.last]
	ChangeDir [winfo toplevel $w] $dir
    }
    [winfo toplevel $w] configure -cursor ""
    set filetype none
}

proc ::ttk::dialog::file::FileMotion1 {w x y} {
    [winfo toplevel $w] configure -cursor "X_cursor #C00 #000"
}

proc ::ttk::dialog::file::FileControl1 {w x y} {
    set dataName [winfo name [winfo toplevel $w]]
    upvar ::ttk::dialog::file::$dataName data
    variable filetype
    
    if {!$data(-multiple) || $filetype eq "none"} return
    if {$filetype ne "file" && $filetype ne "link"} return
    
    set range [$w tag prevrange name @$x,$y+1c "@$x,$y linestart"]
    $w mark set lastpos @$x,$y
    
    if {[llength $range]} {
	lassign $range index1 index2
	if {[lsearch [$w tag names @$x,$y] sel] < 0} {
	    $w tag add sel $index1+2c $index2
	} else {
	    $w tag remove sel $index1+2c $index2
	}
	set data(select) 1
	set files {};foreach {first last} [$w tag ranges sel] {
	    lappend files [$w get $first $last]
	}
	set data(selectFile) [lsort -dictionary $files]
    }
}

proc ::ttk::dialog::file::FileShift1 {w x y} {
    set dataName [winfo name [winfo toplevel $w]]
    upvar ::ttk::dialog::file::$dataName data
    variable filetype
    
    if {!$data(-multiple) || $filetype eq "none"} return
    
    set m1 [$w index @$x,$y]
    if {[catch {$w index lastpos} m2]} {
	set m2 $m1
    }
    set row1 [lindex [split $m1 .] 0]
    set col1 [llength [split [$w get $row1.0 $m1] \t]]
    set row2 [lindex [split $m2 .] 0]
    set col2 [llength [split [$w get $row2.0 $m2] \t]]
    
    if {$row1 > $row2} {lassign [list $row2 $row1] row1 row2}
    if {$col1 > $col2} {lassign [list $col2 $col1] col1 col2}
    
    $w tag remove sel 1.0 end
    set dir [lindex [$w tag nextrange directory $row1.0] 0]
    for {} {$row1 <= $row2} {incr row1} {
	for {set cur $row1.0;set i 1} {$i < $col1} {incr i} {
	    set cur [lindex [$w tag nextrange name $cur] 1]
	}
	for {} {$i <= $col2} {incr i} {
	    if {$dir ne "" && [$w compare $dir < $cur]} {
		set dir [lindex [$w tag nextrange directory $cur] 0]
	    }
	    lassign [$w tag nextrange name $cur] index1 index2
	    if {$dir eq "" || [$w compare $dir != $index1]} {
		$w tag add sel $index1+2c $index2
	    }
	    set cur $index2
	}
    }
    set data(select) 1
    # eval [linsert [$w tag ranges directory] 0 $w tag remove sel]
    
    $w mark set lastpos @$x,$y
    
    set files {};foreach {first last} [$w tag ranges sel] {
	lappend files [$w get $first $last]
    }
    set data(selectFile) [lsort -dictionary $files]
}

proc ::ttk::dialog::file::tkFDialog {type args} {
    global env
    variable selectFilePath
    variable filelist
    variable opt
    set dataName __ttk_filedialog
    upvar ::ttk::dialog::file::$dataName data
    
    if {[info exists data(active)]} {
	raise $data(active)
	return
    }
    
    ::ttk::dialog::file::Config $dataName $type $args
    
    if {$data(-parent) eq "."} {
	set w .$dataName
    } else {
	set w $data(-parent).$dataName
    }
    
    if {![winfo exists $w]} {
	::ttk::dialog::file::Create $w TkFDialog
    } elseif {[winfo class $w] ne "TkFDialog"} {
	destroy $w
	::ttk::dialog::file::Create $w TkFDialog
    } else {
	$data(fileArea) configure -state normal
	$data(fileArea) delete 1.0 end
	$data(fileArea) configure -state disabled
	$data(dirArea) configure -state normal
	$data(dirArea) delete 1.0 end
	$data(dirArea) configure -state disabled
	$data(prevBtn) state disabled
	$data(nextBtn) state disabled
	$data(upBtn) state disabled
	set data(history) ""
	set data(histpos) -1
    }
    
    wm transient $w $data(-parent)
    if {$data(-typevariable) ne ""} {upvar 1 $data(-typevariable) typevar}
    
    if {[llength $data(-filetypes)]} {
	set type ""; if {[info exists typevar]} {set type $typevar}
	set titles ""; set current 0
	foreach ftype $data(-filetypes) {
	    lassign $ftype title filter
	    regsub {(.*) \(.*\)} $title {\1} str
	    if {$str eq $type} {set current [llength $titles]}
	    lappend titles $title
	}
	$data(typeMenuBtn) configure -values $titles
	$data(typeMenuLab) state !disabled
	$data(typeMenuBtn) state !disabled
	$data(typeMenuBtn) current $current
	::ttk::dialog::file::SelectFilter $w
    } else {
	set data(filter) "*"
	set data(typevar) ""
	$data(typeMenuBtn) configure -takefocus 0
	$data(typeMenuBtn) state disabled
	$data(typeMenuLab) state disabled
	$data(typeMenuBtn) set ""
    }
    
    set dirlist "/"
    if {[info exists env(HOME)] && $env(HOME) ne "/"} {
	lappend dirlist $env(HOME)
    }
    if {[lsearch -exact $dirlist $data(selectPath)] < 0} {
	lappend dirlist $data(selectPath)
    }
    foreach n $filelist {
	set dir [file dirname $n]
	if {[lsearch -exact $dirlist $dir] < 0} {
	    lappend dirlist $dir
	}
    }
    $data(dirMenuBtn) configure -values $dirlist
    $data(location) configure -values $filelist
    
    ::ttk::dialog::file::ChangeDir $w $data(selectPath)
    
    ::tk::PlaceWindow $w widget $data(-parent)
    wm title $w $data(-title)
    
    ::tk::SetFocusGrab $w $data(location)
    
    set data(active) $w
    tkwait variable ::ttk::dialog::file::selectFilePath
    unset data(active)
    
    ::ttk::fsOptions [array get opt]
    ::tk::RestoreFocusGrab $w $data(location) withdraw
    
    set typevar $data(typevar)
    return $selectFilePath
}

proc ::ttk::dialog::file::Config {dataName type argList} {
    upvar ::ttk::dialog::file::$dataName data
    variable opt
    
    set data(type) $type
    
    # 1: the configuration specs
    #
    array set opt [::ttk::fsOptions]
    set specs {
	{-defaultextension "" "" ""}
	{-filetypes "" "" ""}
	{-initialdir "" "" ""}
	{-initialfile "" "" ""}
	{-parent "" "" "."}
	{-title "" "" ""}
	{-typevariable "" "" ""}
    }
    lappend specs [list -sepfolders "" "" $opt(-sepfolders)]
    lappend specs [list -foldersfirst "" "" $opt(-foldersfirst)]
    lappend specs [list -sort "" "" $opt(-sort)]
    lappend specs [list -reverse "" "" $opt(-reverse)]
    lappend specs [list -details "" "" $opt(-details)]
    lappend specs [list -hidden "" "" $opt(-hidden)]
    
    # The "-multiple" option is only available for the "open" file dialog.
    #
    if {$type eq "open"} {
	lappend specs {-multiple "" "" "0"}
    }
    
    # 2: default values depending on the type of the dialog
    #
    if {![info exists data(selectPath)]} {
	# first time the dialog has been popped up
	set data(selectPath) [pwd]
	set data(selectFile) ""
    }
    
    # 3: parse the arguments
    #
    tclParseConfigSpec ::ttk::dialog::file::$dataName $specs "" $argList
    
    if {$data(-title) == ""} {
	if {$type eq "save"} {
	    set data(-title) [mc "Save As"]
	} else {
	    set data(-title) [mc "Open"]
	}
    }
    
    # 4: set the default directory and selection according to the -initial
    #    settings
    #
    
    # Ensure that initialdir is an absolute path name.
    if {$data(-initialdir) ne ""} {
	set dir [file normalize [file join [pwd] $data(-initialdir)]]
	set path $dir
	while {[file exists $path] && [file type $path] eq "link"} {
	    set path [file normalize [file join \
	      [file dirname $path] [file link $path]]]
	}
	if {[file isdirectory $path]} {
	    set data(selectPath) $dir
	} else {
	    set data(selectPath) [pwd]
	}
    }
    set data(selectFile) $data(-initialfile)
    
    # 5. Parse the -filetypes option
    #
    set data(-filetypes) [::tk::FDGetFileTypes $data(-filetypes)]
    
    if {![winfo exists $data(-parent)]} {
	error "bad window path name \"$data(-parent)\""
    }
    
    set opt(-sepfolders) $data(-sepfolders)
    set opt(-foldersfirst) $data(-foldersfirst)
    set opt(-sort) $data(-sort)
    set opt(-reverse) $data(-reverse)
    set opt(-details) $data(-details)
    set opt(-hidden) $data(-hidden)
    
    # Set -multiple to a one or zero value (not other boolean types
    # like "yes") so we can use it in tests more easily.
    
    set data(-multiple) [expr {$type eq "open" && $data(-multiple)}]
}

### ttk::chooseDirectory

proc ::ttk::dialog::file::treeCreate {w} {
    destroy $w
    toplevel $w -class TkChooseDir
    wm iconname $w Dialog
    
    set dataName [winfo name $w]
    upvar ::ttk::dialog::file::$dataName data
    
    if {[winfo viewable [winfo toplevel $data(-parent)]] } {
	wm transient $w $data(-parent)
    }
    
    set f1 [ttk::frame $w.f1]
    set data(dirMenuBtn) [ttk::combobox $f1.dir \
      -textvariable ::ttk::dialog::file::${dataName}(selectPath)]
    pack $f1.dir -fill x -expand 1 -padx 8 -pady 5
    
    set f2 [ttk::frame $w.f2]
    ttk::frame $f2.f
    ttk::label $f2.f.bg -relief sunken
    array set fontinfo [font actual [[label $f2.f.dummy] cget -font]]
    set font [maxfont $fontinfo(-family) 16]
    destroy $f2.f.dummy
    ttk::label $f2.f.title -text [mc Folder] -anchor w -style Toolbutton
    set data(text) [text $f2.f.text -width 48 -height 16 -font $font \
      -tabs 20 -wrap none -highlightthickness 0 -bd 0 -cursor "" \
      -spacing1 1 -spacing3 1 -exportselection 0 \
      -yscrollcommand [list $f2.f.scroll set]]
    $data(text) mark set subdir end
    $data(text) mark gravity subdir left
    ttk::scrollbar $f2.f.scroll -command [list $data(text) yview]
    grid $f2.f.title $f2.f.scroll -sticky ns
    grid $f2.f.text ^ -sticky news -padx {2 0} -pady {0 2}
    grid $f2.f.title -padx {2 0} -pady {2 1} -sticky ew
    grid $f2.f.bg -column 0 -row 0 -columnspan 2 -rowspan 2 -sticky news
    grid columnconfigure $f2.f 0 -weight 1
    grid rowconfigure $f2.f 1 -weight 1
    pack $f2.f -fill both -expand 1 -padx 8 -pady 4
    
    set f3 [ttk::frame $w.f3]
    ttk::button $f3.ok -text [mc OK] -default active \
      -command [list ::ttk::dialog::file::TreeDone $w]
    ttk::button $f3.cancel -text [mc Cancel] \
      -command [list ::ttk::dialog::file::Cancel $w]
    grid x $f3.ok $f3.cancel -sticky ew -padx {4 8} -pady 8
    grid columnconfigure $f3 {1 2} -uniform buttons -minsize 80
    grid columnconfigure $f3 0 -weight 1
    
    pack $f1 -side top -fill x
    pack $f3 -side bottom -fill x
    pack $f2 -side top -fill both -expand 1
    
    $data(text) image create end -padx 1 -image ::ttk::dialog::image::folder 
    $data(text) insert end " /" name
    $data(text) configure -state disabled
    
    # Get rid of the default Text bindings
    bindtags $data(text) [list $data(text) DirDialog $w all]
    
    bind $data(dirMenuBtn) <Return> \
      [list ::ttk::dialog::file::TreeReturn $w]
    
    wm protocol $w WM_DELETE_WINDOW [list $f3.cancel invoke]
}

proc ::ttk::dialog::file::treeUpdate {w dir} {
    upvar ::ttk::dialog::file::[winfo name $w](text) txt
    
    set dir [file normalize [file join [pwd] $dir]]
    set list [lassign [file split $dir] parent]
    lappend list .
    $txt configure -state normal
    $txt delete 1.end end
    $txt mark set subdir end
    
    foreach d $list {
	treeOpen $w $parent subdir $d
	set parent [file join $parent $d]
    }
    $txt yview subdir-5l
    TreeSelect $w subdir
}

proc ::ttk::dialog::file::treeOpen {w path {index insert} {subdir .}} {
    upvar ::ttk::dialog::file::[winfo name $w](text) txt
    
    set level [llength [file split $path]]
    set tabs [string repeat "\t" [expr {$level - 1}]]
    set img [lindex [$txt dump -image \
      "$index linestart" "$index lineend"] 1]
    if {$img ne "" && [$txt image cget $img -name] eq "diropen"} {
	$txt image configure $img -image ::ttk::dialog::image::dirclose
    } else {
	set img ""
    }
    
    # Do we already have this data available, but perhaps elided?
    if {[llength [$txt tag ranges $path]]} {
	# Also show all subdirectories that were expanded before
	set list [lsearch -all -inline [$txt tag names] $path/*]
	foreach n [lappend list $path] {
	    $txt tag configure $n -elide 0
	}
	return
    }
    
    # This may take a little longer so give some indication to the user
    $w configure -cursor watch
    update
    
    if {[catch {glob -nocomplain -tails -dir $path -type d * .*} list]} {
	if {$img ne ""} {
	    $txt image configure $img -image ::ttk::dialog::image::diropen
	}
	$w configure -cursor ""
	tk_messageBox -icon warning -type ok -parent $w -message \
	  [mc {Cannot change to the directory "%s". Permission denied.} \
	  $path]
	return
    }
    $txt configure -state normal
    $txt mark set insert $index
    foreach d [lsort -dictionary $list] {
	# Skip . and ..
	if {$d eq "." || $d eq ".."} continue
	# Specify no tags so the tags at the current position are used
	$txt insert insert "\n"
	# Insert the line with the appropriate tags
	$txt insert insert $tabs [list $path]
	file stat [file join $path $d] stat
	if {$stat(nlink) != 2} {
	    set img [$txt image create insert -name diropen \
	      -image ::ttk::dialog::image::diropen -padx 3]
	    $txt tag add $path $img
	}
	$txt insert insert "\t" [list $path]
	set img [$txt image create insert -padx 1 \
	  -image ::ttk::dialog::image::folder]
	$txt tag add $path $img
	$txt insert insert " $d" [list name $path]
	# Remove tags from the lineend
	foreach n [$txt tag names insert] {
	    $txt tag remove $n insert
	}
	# Add the correct tag to the lineend
	$txt tag add $path insert
	# Put a mark if this is the specified subdirectory
	if {$d eq $subdir} {
	    $txt mark set subdir insert
	}
    }
    # Directory is considered empty if it only contains . and ..
    if {[llength $list] <= 2 && $img ne ""} {
	$txt delete $img
    }
    $txt configure -state disabled
    $w configure -cursor ""
}

proc ::ttk::dialog::file::treeClose {w path} {
    upvar ::ttk::dialog::file::[winfo name $w](text) txt
    
    set img root
    set pathindex [lindex [$txt tag ranges $path] 0]
    lassign [$txt dump -image "$pathindex-1l" $pathindex] - img pos
    if {[string match diropen* $img]} {
	$txt image configure $img -image ::ttk::dialog::image::diropen
    }
    
    set list [lsearch -all -inline [$txt tag names] $path/*]
    lappend list $path
    $txt configure -state normal
    foreach n $list {
	# Eliding sounds promising, but doesn't work correctly
	# $txt tag configure $n -elide 1
	eval [list $txt delete] [$txt tag ranges $n]
	$txt tag delete $n
    }
    $txt configure -state disabled
}

proc ::ttk::dialog::file::TreeDone {w} {
    upvar ::ttk::dialog::file::[winfo name $w] data
    
    if {[file exists $data(selectPath)]} {
	if {![file isdirectory $data(selectPath)]} {
	    return
	}
    } elseif {[string is true $data(-mustexist)]} {
	return
    }
    variable selectFilePath $data(selectPath)
}

proc ::ttk::dialog::file::cdTree {w dir {subdir .}} {
    upvar ::ttk::dialog::file::[winfo name $w](text) txt
    
    set parent [file dirname $dir]
    
    set ranges [$txt tag ranges $parent]
    if {[llength $ranges]} {
	set pat [format {^\t* %s$} [file tail $dir]]
	foreach {index1 index2} $ranges {
	    set idx [$txt search -regexp $pat $index1 $index2]
	    if {$idx ne ""} {
		$txt mark set subdir "$idx lineend"
		break
	    }
	}
    } else {
	cdTree $w $parent [file tail $dir]
    }
    ::ttk::dialog::file::treeOpen $w $dir subdir $subdir
}

proc ::ttk::dialog::file::TreeSelect {w index} {
    upvar ::ttk::dialog::file::[winfo name [winfo toplevel $w]] data
    
    set idx [$data(text) index "$index lineend"]
    set range [$data(text) tag prevrange name $idx "$idx linestart"]
    if {[llength $range]} {
	lassign $range index1 index2
	$data(text) tag remove sel 1.0 end
	$data(text) tag add sel $index1-1c $index2+1c
	set path [lsearch -inline [$data(text) tag names $index1] /*]
	set dir [$data(text) get $index1+1c $index2]
	set data(selectPath) [file join $path $dir]
    }
}

proc ::ttk::dialog::file::TreeRelease1 {w} {
    set w [winfo toplevel $w]
    upvar ::ttk::dialog::file::[winfo name $w](text) txt
    
    if {[$w cget -cursor] ne ""} {
	$w configure -cursor ""
	return
    }
    
    set dir [string range [$txt get sel.first sel.last] 1 end-1]
    set path [lsearch -inline [$txt tag names sel.first] /*]
    if {![catch {$txt image cget sel.first-2c -image} name]} {
	set index [$txt index sel.last-1c]
	$txt mark set selmark sel.first
	switch -glob $name {
	    *::diropen {
		treeOpen $w [file join $path $dir] $index
	    }
	    *::dirclose {
		treeClose $w [file join $path $dir]
	    }
	}
	$txt tag remove sel 1.0 end
	$txt tag add sel selmark "selmark lineend+1c"
    }
}

proc ::ttk::dialog::file::TreeMotion1 {w} {
    [winfo toplevel $w] configure -cursor "X_cursor #C00 #000"
}

proc ::ttk::dialog::file::TreeReturn {w} {
    upvar ::ttk::dialog::file::[winfo name $w] data
    
    if {[file isdirectory $data(selectPath)]} {
	::ttk::dialog::file::cdTree $w $data(selectPath)
	$data(text) yview subdir-5l
	TreeSelect $w subdir
    }
    
    return -code break
}

proc ttk::chooseDirectory {args} {
    set dataName __ttk_dirdialog
    upvar ::ttk::dialog::file::$dataName data
    
    set specs {
	{-initialdir "" "" .}
	{-mustexist "" "" 0}
	{-parent "" "" .}
	{-title "" "" ""}
    }
    tclParseConfigSpec ::ttk::dialog::file::$dataName $specs "" $args
    
    if {$data(-title) == ""} {
	set data(-title) "[::tk::mc "Choose Directory"]"
    }
    
    if {![winfo exists $data(-parent)]} {
	error "bad window path name \"$data(-parent)\""
    }
    
    if {$data(-parent) eq "."} {
	set w .$dataName
    } else {
	set w $data(-parent).$dataName
    }
    
    if {![winfo exists $w]} {
	::ttk::dialog::file::treeCreate $w
    }
    
    ::tk::PlaceWindow $w widget $data(-parent)
    wm title $w $data(-title)
    ::tk::SetFocusGrab $w $data(text)
    
    ::ttk::dialog::file::treeUpdate $w $data(-initialdir)
    
    tkwait variable ::ttk::dialog::file::selectFilePath
    
    ::tk::RestoreFocusGrab $w $data(text) withdraw
    
    return $::ttk::dialog::file::selectFilePath
}

# Alternative procedure names
interp alias {} ttk_getOpenFile {} ::ttk::dialog::file::tkFDialog open
interp alias {} ttk_getSaveFile {} ::ttk::dialog::file::tkFDialog save
interp alias {} ttk_getAppendFile {} ::ttk::dialog::file::tkFDialog append

# Need to have a lassign command
if {![llength [info commands lassign]]} {
    proc lassign {list args} {
	uplevel 1 [list foreach $args [linsert $list end {}] break]
	lrange $list [llength $args] end
    }
}

ttk::style configure Slim.TButton -padding 0
option add *TkFDialog*selectBackground #0a5f89 startupFile
option add *TkFDialog*inactiveSelectBackground #0a5f89 startupFile
option add *TkFDialog*selectForeground #ffffff startupFile
option add *TkFDialog*Toolbar*takeFocus 0
option add *TkFDialog*Text.background white startupFile
option add *TkFDialog*Menu.activeBackground #0a5f89 startupFile
option add *TkFDialog*Menu.activeForeground #ffffff startupFile
option add *TkFDialog*Menu.activeBorderWidth 1 startupFile
option add *TkFDialog*Menu.borderWidth 1 startupFile
option add *TkFDialog*Menu.relief solid startupFile
option add *TkFDialog*Menu.Image ::ttk::dialog::image::blank16 startupFile
option add *TkFDialog*Menu*selectImage ::ttk::dialog::image::tick16 startupFile

# Bindings
bind FileDialogDir <ButtonPress-1> {::ttk::dialog::file::DirButton1 %W %x %y}
bind FileDialogDir <ButtonRelease-1> {::ttk::dialog::file::DirRelease1 %W %x %y}
bind FileDialogDir <B1-Motion> {::ttk::dialog::file::DirMotion1 %W %x %y}
bind FileDialogDir <Double-1> {;}
bind FileDialogDir <4> {%W yview scroll -5 units}
bind FileDialogDir <5> {%W yview scroll 5 units}
bind FileDialogFile <ButtonPress-1> {::ttk::dialog::file::FileButton1 %W %x %y}
bind FileDialogFile <ButtonRelease-1> {::ttk::dialog::file::FileRelease1 %W %x %y}
bind FileDialogFile <Shift-1> {::ttk::dialog::file::FileShift1 %W %x %y}
bind FileDialogFile <Shift-ButtonRelease-1> {;}
bind FileDialogFile <Control-ButtonRelease-1> {;}
bind FileDialogFile <Control-1> {::ttk::dialog::file::FileControl1 %W %x %y}
bind FileDialogFile <Double-Control-1> {;}
bind FileDialogFile <Double-Shift-1> {;}
bind FileDialogFile <B1-Motion> {::ttk::dialog::file::FileMotion1 %W %x %y}
bind FileDialogFile <Control-B1-Motion> {;}
bind FileDialogFile <Double-B1-Motion> {;}
bind FileDialogFile <Double-1> {::ttk::dialog::file::Done [winfo toplevel %W]}
bind FileDialogFile <4> \
  {::ttk::dialog::file::xview [winfo toplevel %W] scroll -1 units}
bind FileDialogFile <5> \
  {::ttk::dialog::file::xview [winfo toplevel %W] scroll 1 units}
bind FileDialogList <ButtonPress-1> {::ttk::dialog::file::FileButton1 %W %x %y}
bind FileDialogList <ButtonRelease-1> {::ttk::dialog::file::FileRelease1 %W %x %y}
bind FileDialogList <Shift-1> {::ttk::dialog::file::FileShift1 %W %x %y}
bind FileDialogList <Shift-ButtonRelease-1> {;}
bind FileDialogList <Control-ButtonRelease-1> {;}
bind FileDialogList <Control-1> {::ttk::dialog::file::FileControl1 %W %x %y}
bind FileDialogList <Double-Control-1> {;}
bind FileDialogList <Double-Shift-1> {;}
bind FileDialogList <B1-Motion> {::ttk::dialog::file::FileMotion1 %W %x %y}
bind FileDialogList <Double-1> {::ttk::dialog::file::Done [winfo toplevel %W]}
bind FileDialogList <4> {%W yview scroll -5 units}
bind FileDialogList <5> {%W yview scroll 5 units}

bind DirDialog <4> {%W yview scroll -5 units}
bind DirDialog <5> {%W yview scroll 5 units}
bind DirDialog <ButtonPress-1> {::ttk::dialog::file::TreeSelect %W @%x,%y}
bind DirDialog <ButtonRelease-1> {::ttk::dialog::file::TreeRelease1 %W}
bind DirDialog <B1-Motion> {::ttk::dialog::file::TreeMotion1 %W}
