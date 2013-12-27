snit::type tabServer {
    # BOTH
    variable id_var
    # UI Controls
    variable chat
    variable input
    variable nickList
    variable awayLabel
    variable nicklistCtrl
    # Other
    variable sendHistory
    variable sendHistoryIndex
    variable logDesc
    variable lastSearchIndex
    variable lastSearchTerm
    variable lastSearchSwitches
    variable lastSearchDirection
    
    # SPECIFIC
    variable server
    variable port
    variable nick
    variable connDesc
    variable channelMap
    variable activeChannels
    variable banRequestList
    # map from nick to channel & mask; banRequestList(notbryant) = {#qweex *!*@domain shouldKick banMsg}
    variable pingtime
    
    # Server info
    variable ServerCreationTime
    variable MOTD
    variable ChannelPrefixes
    variable NickPrefixesA	;# Alphanumeric; e.g. 'q'; used in things like /mode
    variable NickPrefixesS	;# Symbol; e.g. '~'; used in the NickList and in /lusers
    variable NetworkName
    variable ServerName
    variable ServerDaemon
 
    
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~Similar (same name)~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
    ############## Constructor ##############
    constructor {args} {    ;# args = irc.geekshed.net 6697 nick pass
        set server ""
        set sendHistory [list ""]
        set sendHistoryIndex 0
        set lastSearchIndex 1.0
        
        # If it has no args it's a dummy tab for measurement
        if { [string length $args] > 0 } {
            $self init [lindex $args 0] [lindex $args 1] [lindex $args 2]
        } else {
            set channel Temp
            set id_var measure_tab
        }
        
        $self init_ui
        if { [string length $args] > 0 } {
            if {$Pref::logEnabled} {
                $self createLog
            }
            $self initServer [lindex $args 3]
        }
    }
    
    ############## Initialize the variables ##############
    method init {arg0 arg1 arg2} {
        set nickList [list]
        set activeChannels [list]
    
        debug "~~~~~~~~~~NEW TAB~~~~~~~~~~~~~~"
        
        set server $arg0
        set port $arg1
        set id_var "$server"
        set nick [string trim $arg2]
        debug "  Server: $server"
        debug "  Port:   $port"
        debug "  Nick:   $nick"
    }
    
    ############## GUI stuff ##############
    method init_ui {} {
        variable name
        set name $server
        
        regsub -all "\\." $id_var "_" id_var
        regsub -all " " $id_var "*" id_var
        
        # Magic bullshit
        set frame [$Main::notebook insert end $id_var -text $name -image [image create photo -file "[pwdW]/icons/x.gif"]]
        set_close_bindings $Main::notebook $id_var
        set topf  [frame $frame.topf]
        
        # Create the chat text widget
        set chat [text $topf.chat -height 20 -wrap word -font {Arial 11} -undo true ]
        $chat tag config bold   -font [linsert [$chat cget -font] end bold]
        $chat tag config italic -font [linsert [$chat cget -font] end italic]
        $chat tag config timestamp -font {Arial 7} -foreground grey60
        $chat tag config blue   -foreground blue
        $chat tag config mention   -foreground red
        $chat configure -background white
        $chat configure -state disabled
        #$chat configure -bd 1
        $chat configure -relief solid
        $chat tag configure regionSearch -background yellow
        
        set lowerFrame [frame $topf.f]
        
        # Create the away label
        set awayLabel [xlabel $lowerFrame.l_away -text ""]
        
        # Create the input widget
        set input [text $lowerFrame.input -height 1 -undo true]
        $input configure -background white
        bind $input <Return> "[mymethod hitSendKey]; break;"
        bind $input <Up> "[mymethod upDown] -1; break;"
        bind $input <Down> "[mymethod upDown] 1; break;"
    
        grid $awayLabel -row 0 -column 0
        grid $input -row 0 -column 1 -sticky ew
        grid columnconfigure $lowerFrame 1 -weight 1
        pack $lowerFrame -side bottom -fill x
    
        ## And this where a NickList widget would go
        ## IF I HAD ONE
        
        pack $chat -fill both -expand 1
        pack $topf -fill both -expand 1
        
        grid remove $awayLabel
    }
    
    ############## Update the toolbar's statuses ##############
    method updateToolbar {mTarget} {
        if [info exists channelMap($mTarget)] {
            $channelMap($mTarget) updateToolbar $mTarget
            return
        }
        
        $Main::toolbar_find configure -state normal
        #Is connected
        if [info exists connDesc] {
            $Main::toolbar_join configure -state normal
            $Main::toolbar_disconnect configure -state normal
            $Main::toolbar_reconnect configure -state disabled
            $Main::toolbar_properties configure -state normal
            $Main::toolbar_channellist configure -state normal
            $Main::toolbar_nick configure -state normal
            $Main::toolbar_away configure -state normal
            $self updateToolbarAway $mTarget
        } else {
            $Main::toolbar_join configure -state disabled
            $Main::toolbar_disconnect configure -state disabled
            $Main::toolbar_reconnect configure -state normal
            $Main::toolbar_properties configure -state disabled
            $Main::toolbar_channellist configure -state disabled
            $Main::toolbar_away configure -state disabled
            $Main::toolbar_away configure -image [image create photo -file $About::icondir/away.gif]
        }
        $Main::toolbar_part configure -state disabled
    }
    
    ############## checks if a channel is connected ##############
    method isChannelConnected {chann} {
        #TODO: Is activeChannels a list?
        if {[lsearch $activeChannels $chann] != -1} {
            return true
        }
        return false
    }
    
    ############## Join a channel ##############
    method joinChan {chan pass} {
        if [info exists channelMap($chan)] {
            $channelMap($chan) initChan $pass
        } else {
            set channelMap($chan) [tabChannel %AUTO% $self $chan $pass]
            set reason [$awayLabel cget -text]
            if {[regexp {^\(Away: (.+)\)} $reason -> reason]} {
                $channelMap($chan) away $reason
                $channelMap($chan) _showAwayLabel
            }
        }
        lappend activeChannels $chan
        .tabMenu unpost
        $Main::notebook raise [$channelMap($chan) getId]
        $self updateToolbar $chan
    }
    
    
    
    ############## Send a Private Message to a user...or maybe channel? ##############    
    method sendPM { mNick mMsg} {
        $self _send "PRIVMSG $mNick :$mMsg"
        $self createPMTabIfNotExist $mNick
        $channelMap($mNick) handleReceived [$self getTimestamp] <$mNick> bold $mMsg ""
    }
    
    ############## getters ##############
    method getChannPrefixes {} { return $ChannPrefixes }
    method getNick {} { return $nick }
    method getServer {} { return $server }
    method getNickPrefixes {} { return $NickPrefixesS }
    method isServer {} { return 1 }
    
    method propogateMessage {what timestamp title titleStyle msg msgStyle} {
        foreach key $activeChannels {
            $channelMap($key) propogateMessage $what $timestamp $title $titleStyle $msg $msgStyle
        }
    }
    
    ############## Internal function ##############
    method _send {str} { puts $connDesc $str; flush $connDesc }
 
    ############## Quit the server ##############
    method quit {reason} {
        set timestamp [$self getTimestamp]
        debug "Quitting server: [$self getServer]"
        if {![info exists connDesc]} {
            return
        }
        $self _send "QUIT $reason"
        close $connDesc
        unset connDesc
        $self handleReceived $timestamp "\[Quit\] " bold "You have left the server" ""
        $self updateToolbar ""
        
        $self propogateMessage ALL $timestamp "\[Quit\] " bold "You have left the server" ""
    }
    
    ############## Part a channel ##############
    method part {chann reason} { $channelMap($chann) part $chann $reason }
    
    ############## Nick has been changed ##############
    method nickChanged {newnick} {
        set nick $newnick
        #foreach key $activeChannels {
            #$activeChannels($key) handleReceived [$self getTimestamp] "***" bold "You are now known as $nick" ""
        #}
        #$self propogateMessage ALL [$self getTimestamp] "***" bold "You are now known as $nick" ""
        #$self handleReceived [$self getTimestamp] "***" bold "You are now known as $nick" ""
    }
    
    ############## Used by the server to notify its children that it is away ##############
    method awaySignalServer {reason} {
        foreach key $activeChannels {
            $channelMap($key) away $reason
        }
        $self away $reason
    }
    
    ############## Hides GUI element ##############
    method _hideAwayLabel {} {
        foreach key $activeChannels {
            $channelMap($key) _hideAwayLabel
        }
        grid remove $awayLabel
    }
    
    ############## Shows GUI element ##############
    method _showAwayLabel {} {
        foreach key $activeChannels {
            $channelMap($key) _showAwayLabel
        }
        grid $awayLabel
    }
    
    ############## Toggles away status; for use with the button ##############
    method toggleAway {} {
        set reason [$awayLabel cget -text]
        # Is away, come back
        if {[regexp {^\(Away: (.+)\)} $reason -> reason]} {
            performSpecialCase "away" $self
        # Is back, go away
        } else {
            performSpecialCase "away $Pref::defaultAway" $self
        }
    }
    
    ############## Show properties dialog ##############
    method showProperties {chann} {
        if { [string length $chann] > 0 } {
            $channelMap($chann) showProperties ""
            return
        }
        
        destroy .propDialog
        toplevel .propDialog -padx 10 -pady 10
        wm title .propDialog "Properties"
        wm transient .propDialog .
        wm resizable .propDialog 0 0
        
        xlabel .propDialog.network -text $NetworkName -font {-size 16}
        
        xlabel .propDialog.name_l -text "Server Name:"
        text .propDialog.name -width 32 -height 1 -background white -undo true
        xlabel .propDialog.daemon_l -text "Running:"
        text .propDialog.daemon -width 32 -height 1 -background white -undo true
        xlabel .propDialog.time_l -text "Created:"
        text .propDialog.time -width 32 -height 1 -background white -undo true
        
        xlabel .propDialog.spacer -text ""
        
        xlabel .propDialog.cprefixes_l -text "Channel types:"
        text .propDialog.cprefixes -width 32 -height 1 -background white -undo true
        xlabel .propDialog.nprefixes_l -text "User Modes:"
        text .propDialog.nprefixes -width 32 -height 1 -background white -undo true
        
        xlabel .propDialog.spacer2 -text ""
        
        xlabel .propDialog.motd_l -text "MOTD:"
        text .propDialog.motd  -width 60 -height 7 -background white -undo true
        
        .propDialog.name insert end $ServerName ""
        .propDialog.name configure -state disabled
        .propDialog.daemon insert end $ServerDaemon ""
        .propDialog.daemon configure -state disabled
        .propDialog.time insert end $ServerCreationTime ""
        .propDialog.time configure -state disabled
        
        .propDialog.cprefixes insert end $ChannelPrefixes ""
        .propDialog.cprefixes configure -state disabled
        .propDialog.nprefixes insert end "$NickPrefixesA = $NickPrefixesS" ""
        .propDialog.nprefixes configure -state disabled
        
        .propDialog.motd insert end $MOTD ""
        .propDialog.motd configure -state disabled
        
        grid config .propDialog.network     -row 0 -column 0
        grid config .propDialog.name_l      -row 1 -column 0 -sticky "w"
        grid config .propDialog.name        -row 1 -column 1
        grid config .propDialog.daemon_l    -row 2 -column 0 -sticky "w"
        grid config .propDialog.daemon      -row 2 -column 1
        grid config .propDialog.time_l      -row 3 -column 0 -sticky "w"
        grid config .propDialog.time        -row 3 -column 1
        grid config .propDialog.spacer      -row 4 -column 0
        grid config .propDialog.cprefixes_l -row 5 -column 0 -sticky "w"
        grid config .propDialog.cprefixes   -row 5 -column 1
        grid config .propDialog.nprefixes_l -row 6 -column 0 -sticky "w"
        grid config .propDialog.nprefixes   -row 6 -column 1
        grid config .propDialog.spacer2     -row 7 -column 0
        grid config .propDialog.motd_l      -row 8 -column 0 -sticky "w"
        grid config .propDialog.motd        -row 9 -column 0 -columnspan 2
        
        xlabel .propDialog.spacer3 -text ""
        
        # Connection info
        xlabel .propDialog.connInfo_l -text "Connection Info" -font {-size 12}
        xlabel .propDialog.server_l -text "Connection:"
        text .propDialog.server -width 32 -height 1 -background white -undo true
        xlabel .propDialog.port_l -text "Port:"
        text .propDialog.port -width 32 -height 1 -background white -undo true
        xlabel .propDialog.username_l -text "Created:"
        text .propDialog.username -width 32 -height 1 -background white -undo true
        
        grid config .propDialog.spacer      -row 10 -column 0
        grid config .propDialog.server_l    -row 11 -column 0
        grid config .propDialog.server      -row 11 -column 1
        grid config .propDialog.port_l      -row 12 -column 0
        grid config .propDialog.port        -row 12 -column 1
        grid config .propDialog.username_l  -row 12 -column 0
        grid config .propDialog.username    -row 12 -column 1
        
        .propDialog.server insert end $server ""
        .propDialog.server configure -state disabled
        .propDialog.port insert end $port ""
        .propDialog.port configure -state disabled
        #.propDialog.username insert end $Username ""
        #.propDialog.username configure -state disabled
        
        
        Main::foreground_win .propDialog
        catch {grab release .}
        catch {grab set .propDialog}
    }
    
    #TODO: This should not exist
    method _setData {newport newnick} {
        set nick $newnick
        set port $newport
    }
    
    ############## Issued when calling find ##############
    method find {chann direction switches val} {
        if {[string length $chann] > 0} {
            $channelMap($chann) find $direction $switches $val
            return
        }
        $self findClear
        if {![info exists lastSearchSwitches] || ([info exists lastSearchSwitches] && $lastSearchSwitches != $switches)} {
            set lastSearchSwitches $switches
        }
        if { ![info exists lastSearchTerm] || ([info exists lastSearchTerm] && $lastSearchTerm != $val)} {
            set lastSearchIndex 1.0
            set lastSearchTerm $val
        } else {
            if {$lastSearchIndex < 1 } {
                set lastSearchIndex 1.0
            }
        }
        set lastSearchDirection $direction
        $self findNext $chann
    }
    
    method findNext {chann} {
        variable lastSearchLength
        if {[string length $chann] > 0} {
            $channelMap($chann) findNext
            return
        }
        
        set offsetFromLast "+1c"
        if {$lastSearchDirection == "-backwards"} {
            set offsetFromLast "-1c"
        }
        if {![info exists lastSearchTerm]} {
            return
        }
        if {$lastSearchIndex < 1 } {
            set lastSearchIndex 1.0
        }
        $self findClear
        set loc ""
        catch {
            set evalString "$chat search -count lastSearchLength $lastSearchDirection $lastSearchSwitches -- \"$lastSearchTerm\" \"$lastSearchIndex$offsetFromLast\""
            set loc [eval $evalString]
        }
        if { $loc == "" } {
            set lastSearchIndex 1.0
            return
        }
        set lastSearchIndex $loc
    
        $chat see $lastSearchIndex
        $chat tag add regionSearch $lastSearchIndex "$lastSearchIndex+${lastSearchLength}c"
        set lastSearchIndex "$lastSearchIndex"
    }
    
    method findMarkAll {chann switches var} {
        variable locLen
        if {[string length $chann] > 0} {
            $channelMap($chann) findMarkAll $switches $var
            return
        }
        $self findClear
        
        set lastFind -1
        set evalString "$chat search -count locLen $switches -- \"$var\" 1.0"
        set loc [eval $evalString]
        while {$loc > $lastFind && $loc != ""} {
            $chat tag add regionSearch $loc "$loc+${locLen}c"
            set lastFind $loc
            set evalString "$chat search -count locLen $switches -- \"$var\" \"$loc+1c\""
            set loc [eval $evalString]
        }
    }
    
    method findClearAndChildren {} {
        $self findClear
        set chanNames [array names channelMap]
        foreach c $chanNames {
            $channelMap($c) findClear
        }
    }
    
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~Shared (same)~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
    method getId {} { return $id_var }
    
    method findClear {} {
        $chat tag remove regionSearch 1.0 end
    }
    
    ############## Change the tab name ##############
    method updateTabName {newName} {
        if {$newName != $channel} {
            set channel $newName
            $Main::notebook itemconfigure [$self getId] -text $channel
        }
    }
 
    ############## Internal function ##############
    method handleReceived {timestamp title style1 message style2} {
        set isAtBottom [lindex [$chat yview] 1]
        
        set beginning [$chat index [list end - 1 lines]]
        $chat configure -state normal
        $chat insert end $timestamp\  timestamp
        $chat insert end $title\  $style1
        $chat insert end $message\n $style2
        
        # Aw yiss. Mother. Fucking. Hyperlinks.
        set linkRegex {(http|https|ftp)\://([a-zA-Z0-9\.\-]+(\:[a-zA-Z0-9\.&amp;%\$\-]+)*@)*((25[0-5]|2[0-4][0-9]|[0-1]{1}[0-9]{2}|[1-9]{1}[0-9]{1}|[1-9])\.(25[0-5]|2[0-4][0-9]|[0-1]{1}[0-9]{2}|[1-9]{1}[0-9]{1}|[1-9]|0)\.(25[0-5]|2[0-4][0-9]|[0-1]{1}[0-9]{2}|[1-9]{1}[0-9]{1}|[1-9]|0)\.(25[0-5]|2[0-4][0-9]|[0-1]{1}[0-9]{2}|[1-9]{1}[0-9]{1}|[0-9])|localhost|([a-zA-Z0-9\-]+\.)*[a-zA-Z0-9\-]+\.(com|edu|gov|int|mil|net|org|biz|arpa|info|name|pro|aero|coop|museum|[a-zA-Z]{2}))(\:[0-9]+)*(/($|[a-zA-Z0-9\.\,\?\'\\\+&amp;%\$#\=~_\-]+))*}
            # ^ via http://stackoverflow.com/questions/3726807/regex-expression-for-valid-website-link
        set lastMatchInd 0
        while {[regexp -start $lastMatchInd -indices -- $linkRegex $message location]} {
            set msgStart [expr {[string length $timestamp] + [string length $title] + 2}]
            set urlStart [$chat index [list $beginning + [expr {[lindex $location 0] + $msgStart}] chars]]
            set urlEnd   [$chat index [list $beginning + [expr {[lindex $location 1] + $msgStart + 1}] chars]]
            set url [$chat get $urlStart $urlEnd]
            set tagname "${id_var}[clock milliseconds]"
            $chat tag add $tagname $urlStart $urlEnd
            $chat tag configure $tagname -underline true
            $chat tag configure $tagname -foreground blue
            $chat tag bind      $tagname "<Enter>" "$chat configure -cursor $Main::cursor_link"
            $chat tag bind      $tagname "<Leave>" "$chat configure -cursor arrow"
            $chat tag bind      $tagname "<Button-1>" "platformOpen $url"
            
            set lastMatchInd [lindex $location 1] 
        }
        
        # the original example (on the interwebs) used -1; -2 is for the trailing newline?
        if {[expr [lindex [split [$chat index end] .] 0] -2] > $Pref::maxScrollback} {
            $chat delete 1.0 2.0
            if {[info exists logDesc]} {
                if {[info exists lastSearchIndex]} {
                    set lastSearchIndex [expr {$lastSearchIndex -1}]
                } else {
                    set lastSearchIndex 1.0
                }
            } else {
                set lastSearchIndex 1.0
            }
        }
        $chat configure -state disabled
        
        if {$isAtBottom==1.0} {
            $chat yview end
        }
        if {$Pref::logEnabled} {
            set timestamp [clock format [clock seconds] -format "\[%A, %B %d, %Y\] \[%I:%M:%S %p\]"]
            puts $logDesc "$timestamp $title $message"
            flush $logDesc
        }
    }
    
    ############## Creates the logDesc ##############
    method createLog {} {
        file mkdir $Pref::logDir
        set logDesc [open "$Pref::logDir/$id_var.log" a+]
        debug "Creating log:  $Pref::logDir/$id_var.log      $logDesc"
    }
    
    ############## Closes the log handle ##############
    method closeLog {} {
        if {[info exists logDesc] && [string length $logDesc] > 0 } {
            close $logDesc
        }
    }
    
    ############## When enter key is pressed ##############
    method hitSendKey {} {
        set msg [$input get 1.0 end-1c]
        $input delete 1.0 end
        $self sendMessage $msg
    }
    
    ############## Send Message ##############
    method sendMessage {msg} {
        #sendHistory
        set sendHistoryIndex [expr {[llength $sendHistory] - 1}]
        lset sendHistory $sendHistoryIndex $msg
        if {[llength $sendHistory] > $Pref::maxSendHistory} {
            set sendHistory [lreplace $sendHistory 0 0]
        }
        lappend sendHistory ""
        set sendHistoryIndex [expr {[llength $sendHistory] -1}]

        # Starts with a backslash
        if [regexp {^/(.+)} $msg -> msg] {
            if { [string index $msg 0] != "/"} {
                if [performSpecialCase $msg $self ] {
                    return
                }
            }
        }
        
        $self _send $msg
        $self handleReceived [$self getTimestamp] \[Raw\] {bold blue} $msg ""
        
        #TODO: Scroll only if at bottom
        $chat yview end
    }
    
    method getTimestamp {} {
        return [clock format [clock seconds] -format \[%H:%M\] ]
    }
    
    ############## Clears the chat view ##############
    method clearScrollback {} {
        $chat configure -state normal
        $chat delete 0.0 end
        $chat configure -state disabled
    }
    
    ############## Modifies the message away ##############
    method away {reason } {
        $awayLabel configure -text "(Away: $reason)"
    }
    
    ############## Notify user of a mention ##############
    method notifyMention {mNick mMsg} {
        if {[string length [focus]] > 0 && [$Main::notebook raise] == $id_var} {
            return
        }
        ::notebox::addmsg "$mNick - $mMsg"
        $Main::notebook itemconfigure $id_var -background $Pref::mentionColor
        if {[string length $Pref::mentionSound] > 0 } {
            playSound $Pref::mentionSound
        }
    }
    
    ############## Handles pressing of the up down buttons for send history ###############
    ## direction == -1 for prior (up), +1 for next (down)
    method upDown {direction} {
        set newSHindex [expr {$sendHistoryIndex + $direction}]
        if { $newSHindex < 0 || $newSHindex > $Pref::maxSendHistory || $newSHindex >= [llength $sendHistory]} { return }

        # Save old one
        set msg [$input get 1.0 end-1c]
        #set msg [string range $msg 0 [expr {[string length $msg]-2}]]
        lset sendHistory $sendHistoryIndex $msg

        # Retrieve new one
        set sendHistoryIndex $newSHindex
        $input replace 1.0 end [lindex $sendHistory $sendHistoryIndex]
    }
    
    
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~Specific (this)~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
    ############## Specific init ##############
    method initServer {pass} {
        global connectStatus
        $self handleReceived [$self getTimestamp] \[Connect\] bold "Connecting to $server on port $port..." ""
        set connectStatus "unknown"
        # Try to connect; an error can be caused by two reasons:
        #   1. Exception - e.g. failure to connect
        #   2. Etc - e.g. timeout, basically if it's unable to connect and we don't know why
        if {[catch {
                # Set up the timeout; trip the flag only if it has not been set to "ok"
                after $Pref::timeout {
                    if {![info exists connectStatus] || ($connectStatus == "unknown")} {
                        set connectStatus timeout
                }}
            # Create the connection; -async means it will continue on until it hits vwait
            debug "Attempting to connect $server $port"
            set connDesc [socket -async $server $port]
            # Dummy handler to detect when the socket is writeable (i.e. open)
            fileevent $connDesc readable {set connectStatus ok}
            # Wait for either the socket to become writable, or the 
            vwait connectStatus
        } problemDesc]} {
            # Catch any exceptions thrown
            $self handleReceived [$self getTimestamp] \[Connect\] bold $problemDesc ""
            debugE "tabServer::initServer - $problemDesc"
            tk_messageBox -message "$problemDesc" -parent . -title "Error" -icon error -type ok
                if [info exists connDesc] {
                    close $connDesc
                    unset connDesc
                }
            return
        }
        
        # Catch any errors
        switch $connectStatus {
            "ok" {
                debug "Connect ok!"
            }
            "timeout" {
                close $connDesc
                unset connDesc
                $self handleReceived [$self getTimestamp] \[Connect\] bold "Connection timed out" ""
                debugE "tabServer::initServer - Connection timed out"
                tk_messageBox -message "Connection timed out" -parent . -title "Error" -icon error -type ok
                return
            }
            default {
                close $connDesc
                unset connDesc
                $self handleReceived [$self getTimestamp] \[Connect\] bold "Unable to connect" ""
                debugE "tabServer::initServer - Unknown"
                tk_messageBox -message "An unknown error has occurred; the world is probably ending" -parent . -title "Error" -icon error -type ok
                return
            }
        }
        
        # Set the readable (received) event handler
        
        # Initiate variables & unset ones that may be left over for some reason
        set activeChannels [list]
        if [info exists ServerCreationTime] {
            unset ServerCreationTime
        }
        set MOTD ""
        if [info exists ChannelPrefixes] {
            unset ChannelPrefixes
        }
        if [info exists NickPrefixesA] {
            unset NickPrefixesA
        }
        if [info exists NickPrefixesS] {
            unset NickPrefixesS
        }
        if [info exists NetworkName] {
            unset NetworkName
        }
        if [info exists ServerName] {
            unset ServerName
        }
        if [info exists ServerDaemon] {
            unset ServerDaemon
        }
        
        if {[catch {
                $self _send "NICK $nick"
                #TODO: What is this
                $self _send "USER $nick 0 * :Psyche user"
                fileevent $connDesc readable [mymethod _recv]
                if {[string length $pass]>0} {
                    $self _send "PRIVMSG NickServ :identify $pass"
                }
            } probDesc]} {
            if [info exists connDesc] {
                close $connDesc
                unset connDesc
            }
            debugE "initServer - $probDesc"
            tk_messageBox -message "$probDesc" -parent . -title "Error" -icon error -type ok
        }
        
        $self updateToolbar ""
    }
    
    ############## Update the specific Away button ##############
    method updateToolbarAway {mTarget} {
        if [info exists channelMap($mTarget)] {
            $channelMap($mTarget) updateToolbarAway $mTarget
            return
        }
        
        set reason [$awayLabel cget -text]
        if {[regexp {^\(Away: (.+)\)} $reason -> reason]} {
            $Main::toolbar_away configure -image [image create photo -file $About::icondir/back.gif] -helptext "Back"
        } else {
            $Main::toolbar_away configure -image [image create photo -file $About::icondir/away.gif] -helptext "Away"
        }
    }
    
    ############## Creates a PM Tab ##############
    method createPMTabIfNotExist { mNick } {
        if {![info exists channelMap($mNick)]} {
            set channelMap($mNick) [tabChannel %AUTO% $self $mNick]
            if { $Pref::raiseNewTabs} {
                $Main::notebook raise [$channelMap($mNick) getId]
            }
        }
        $channelMap($mNick) updateTabName $mNick
    }
    
    method getconnDesc {} {
        if [info exists connDesc] {
            return $connDesc
        } else {
            return ""
        }
    }

    
    ############## Removes a channel from the active list ##############
    method removeActiveChannel {chann} {
        debug "REMOVING: $activeChannels"
        set idx [lsearch $activeChannels $chann]
        set activeChannels [lreplace $activeChannels $idx $idx]
    }
    
    method closeChannel {chann} {
        $Main::notebook delete [$channelMap($chann) getId]
        $self _send "part $chann"
        $channelMap($chann) closeLog
        $self removeActiveChannel $chann
        unset channelMap($chann)
    }
    
    method closeAllChannelTabs {} {
        foreach chann [array names channelMap] {
            $self closeChannel $chann
        }
    }
    
    method getPingtime {} {
        if {[info exists connDesc] && [info exists pingtime]} {
            return $pingtime
        }
        return 0
    }
    
    method getSelectedNickOfChannel {mChann} {
        return [$channelMap($mChann) getSelectedNick]
    }

    method requestBan {var1 var2 var3 var4} {
        debug "WRONG REQUEST BAN CALLED. THIS IS A SERVER"
    }

    method requestBan {thenick thechan bantype shouldkick banmsg} {
        set banRequestList($thenick) [list $thechan $bantype $shouldkick $banmsg]
        $self _send "WHO $thenick"
    }
    
    ############## Internal Function ##############
    method _recv {} {
        catch {
        gets $connDesc line
        set timestamp [$self getTimestamp]
        debug $line
        set style ""
        
        # PING
        if {[regexp {^PING :(.*)} $line -> mResponse]} {
            $self _send "PONG :$mResponse"
            set pingtime [clock seconds]
            after 1000 Main::updateStatusbar
            debug "Ping: $pingtime"
            return
        }
        
        # CTCP - EXCEPT for ACTION
        if {[regexp ":(\[^!\]*)!.* (\[^ \]*) [$self getNick] :\001\(\[^ \]*\) ?\(.*\)\001" \
                $line -> mFrom mThing mCmd mContent]} {
            debug "REC: CTCP"
            # mFrom    = User that sent CTCP msg
            # mThing   = NOTICE for response, PRIVMSG for initiation
            # mCmd     = VERSION, PING, etc
            # mContent = timestamp for PING, empty for VERSION, etc
            if {[regexp ".*$nick.*" $mContent]} {
                set style "mention"
                $self notifyMention $mFrom $mContent
            }
            set mContent [string trim $mContent]
            switch $mCmd {
                "PING" {
                    if {$mThing == "NOTICE"} {
                        $self handleReceived $timestamp \[CTCP\] bold "Ping response from $mFrom: [expr {[clock seconds] - $mContent}] seconds" $style
                    } else {
                        $self _send "NOTICE $mFrom :\001PING $mContent\001"
                        $self handleReceived $timestamp \[CTCP\] bold "Ping request from $mFrom" $style
                    }
                }
                "VERSION" {
                    if {$mThing == "NOTICE"} {
                        $self handleReceived $timestamp \[CTCP\] bold "Version response from $mFrom: $mContent" $style
                    } else {
                        $self _send "NOTICE $mFrom :\001VERSION $Main::APP_NAME v$Main::APP_VERSION (C) 2013 Jon Petraglia"
                        $self handleReceived $timestamp \[CTCP\] bold "Version request from $mFrom" $style
                    }
                }
            }
            return
        }
        
        
        # Private message - sent to channel or user
        if {[regexp {:([^!]*)(![^ ]+) +PRIVMSG ([^ :]+) +:(.*)} $line -> mFrom mHost mTo mMsg]} {
            debug "REC: PRIVMSG"
            # PM to me
            if {$mTo == [$self getNick]} {
                $self createPMTabIfNotExist $mFrom
                $channelMap($mFrom) notifyMention $mFrom $mMsg
                # PM - /me
                if [regexp {\001ACTION ?(.+)\001} $mMsg -> mMsg] {
                    set style "mention"
                    $channelMap($mFrom) handleReceived $timestamp " \*" bold "$mFrom $mMsg" $style
                # PM - general
                } else {
                    $channelMap($mFrom) handleReceived $timestamp <$mFrom> bold $mMsg $style
                }
                
                # Msg to channel
            } else {
                if {[regexp ".*$nick.*" $mMsg]} {
                    set style "mention"
                    $channelMap($mTo) notifyMention $mFrom $mMsg
                    $channelMap($mTo) touchLastSpoke $mFrom
                }
                # Msg - /me
                if [regexp {\001ACTION ?(.+)\001} $mMsg -> mMsg] {
                    $channelMap($mTo) handleReceived $timestamp " \*" bold "$mFrom $mMsg" $style
                # Msg - general
                } else {
                    debugV "ColorForNick:   [Main::colorForNick $mFrom]"
                    $channelMap($mTo) handleReceived $timestamp <$mFrom> {bold [Main::colorForNick $mFrom]} $mMsg $style
                }
            }
            return
        }
    
        # Numbered message from a SERVER - sent to channel, user, or no one (mTarget could be blank)
        #  Type A: Has an intended target, even if that target is blank;
        #          Following the nick, there is a string of length 0 or more, then a space, then a colon
        if {[regexp ":(\[^ \]*) (\[0-9\]+) [$self getNick] ?\[=@\]? ?(\[^ \]*) :(.*)" $line -> mServer mCode mTarget mMsg]} {
            debug "REC: Numbered from server"
                set style "" ;# TODO: Can numbered messages be addressed to me?
            set mTarget [string trim $mTarget]
            set mMsg [string trim $mMsg]
            switch $mCode {
                001 {
                    set pingtime [clock seconds]
                    after 1000 Main::updateStatusbar
                }
                002 {
                    #Your host is hitchcock.freenode.net[93.152.160.101/6667], running version ircd-seven-1.1.3
                    #Your host is Komma.GeekShed.net, running version Unreal3.2.8-gs.9
                    regexp {^Your host is ([^,]+), running version (.*)} $mMsg -> ServerName ServerDaemon
                }
                003 {
                    regexp {^This server was created (.*)} $mMsg -> ServerCreationTime
                }
                303 {
                    #RPL_ISON
                    set mMsg "$mMsg is online"
                }
                305 {
                    #RPL_UNAWAY
                    $self _hideAwayLabel
                    $self awaySignalServer ""
                    Main::updateAwayButton
                }
                306 {
                    #RPL_NOWAWAY
                    $self _showAwayLabel
                    Main::updateAwayButton
                }
                315 {
                    #RPL_ENDOFWHO
                    return
                }
                321 {
                    #RPL_LISTSTART
                    if {[wm state .channelList]=="normal"} {
                        return
                    }
                }
                323 {
                    #RPL_LISTEND
                    set sss [$self getServer]
                                                #COMPAT: nocase is not in 8.4
                    set Main::channelList($sss) [lsort -nocase $Main::channelList($sss)]
                    if {[wm state .channelList]=="normal"} {
                        return
                    }
                }
                328 {
                    #RPL_CHANNEL_URL
                    # Ignore
                    return
                }
                332 {
                    #RPL_TOPIC
                    if {[string length $mMsg] == 0} {
                        set mMsg "(No topic set)"
                    }
                    $channelMap($mTarget) setTopic $mMsg
                }
                353 {
                    #RPL_NAMREPLY
                    $channelMap($mTarget) addUsers $mMsg
                    return
                }
                366 {
                    #RPL_ENDOFNAMES
                    $channelMap($mTarget) sortUsers
                    return
                }
                368 {
                    #RPL_ENDOFBANLIST
                    #TODO Do things
                    return
                }
                372 {
                    #RPL_MOTD
                    append MOTD "$mMsg\n"
                }
                474 {
                    #ERR_BANNEDFROMCHAN
                    set mMsg "$mMsg - $mTarget"
                }
            }
            if [info exists channelMap($mTarget)] {
                    $channelMap($mTarget) handleReceived $timestamp [getTitle $mCode] bold $mMsg $style 
                    return
            } else {
                $self handleReceived $timestamp [getTitle $mCode] bold $mMsg $style 
                return
            }
        }
        #  Type B: Is still a numbered message, but the content immediately follows the nick
        if {[regexp ":(\[^ \]*) (\[0-9\]+) [$self getNick] (.*)" $line -> mServer mCode mMsg]} {
            debug "REC: Numbered2 from server"
            set style ""	;#TODO: Can a numbered message be addressed to me?
            switch $mCode {
                005 {
                    # Pull out CHANTYPES (prefixes for channels)
                    if [regexp {.*CHANTYPES=([^ ]+) .*} $mMsg -> derp] {
                        set ChannelPrefixes $derp
                    }
                    
                    # Pull out PREFIX (user modes, e.g. ~&@%+)
                    if [regexp ".*PREFIX=\\((.*)\\)(\[^ \]+) .*" $mMsg -> userKeys userModes] {
                        set NickPrefixesA $userKeys
                        set NickPrefixesS $userModes
                    }
                    
                    regexp {.*NETWORK=([^ ]+) .*} $mMsg -> NetworkName
                    
                }
                322 {
                    #RPL_LIST
                    if {[regexp "\(\[$ChannelPrefixes\]\[^ \]+\) \(\[0-9\]+\)" $mMsg -> mTarget mUserCount]} {
                        #TODO: Fix regex to remove modes
                        regexp { ?\[.*\] (.*)} $mMsg -> mMsg
                        set whspc [string length $mTarget]
                        set whspc [expr {33 - $whspc}]
                        set whspc [string repeat " " $whspc]
                        set sss [$self getServer]
                        debug "RPL_LIST: $mTarget$whspc$mMsg"
                        lappend Main::channelList($sss) "$mTarget$whspc$mMsg"
                    }
                    if {[wm state .channelList]=="normal"} {
                        return
                    }
                }
                324 {
                    #RPL_CHANNELMODEIS
                    regexp "(\[^ \]*) .(.*)" $mMsg -> mTarget mModes
                    if [info exists channelMap($mTarget)] {
                        # If it was auto-requested the first time, don't print it
                        if {[$channelMap($mTarget) setModes $mModes] > 0} {
                            return
                        }
                        $channelMap($mTarget) handleReceived $timestamp [getTitle $mCode] bold "Channel modes: +$mModes" $style
                    }
                $self handleReceived $timestamp [getTitle $mCode] bold "$mTarget modes: +$mModes" $style
                return
                }
                329 {
                    #RPL_CREATIONTIME
                    regexp "(\[^ \]*) (.*)" $mMsg -> mTarget mTime
                    $self handleReceived $timestamp [getTitle $mCode] bold "$mTarget created at [clock format $mTime]" $style
                    #if [info exists channelMap($mTarget)] {
                    #$channelMap($mTarget) handleReceived $timestamp [getTitle $mCode] bold "Channel created [clock format $mTime]" $style
                    #}
                    return
                }
                333 {
                    #RPL_TOPICWHOTIME
                    if {[regexp "\(\[$ChannelPrefixes\]\[^ \]+\) \(\[^ \]+\) \(\[0-9\]+\)" $mMsg -> mTarget mBy mTime]} {
                        $channelMap($mTarget) setTopicInfo $mBy $mTime
                        $channelMap($mTarget) handleReceived $timestamp [getTitle $mCode] bold "Topic set by $mBy [clock format $mTime]" $style
                        return
                    }
                }
                352 {
                    #RPL_WHOREPLY
                    if {[regexp "\(\[$ChannelPrefixes\]\[^ \]+\) \(\[^ \]+\) \(\[^ \]+\) \(\[^ \]+\) \(\[^ \]+\) .*" $mMsg \
                                    -> mChannelWhat mUser mHostmask mServer mNick]} {
                        if [info exists banRequestList($mNick)] {
                            set chann [lindex $banRequestList($mNick) 0]
                            set bantype [lindex $banRequestList($mNick) 1]
                            set shouldkick [lindex $banRequestList($mNick) 2]
                            set banmsg [lindex $banRequestList($mNick) 3]
                            
                        #       nick!user@domain
                        #       nick!user@*.host
                            if {[regexp ".*nick.*" $bantype]} {
                                set banCommand "$mNick"
                            } else {
                                set banCommand "*"
                            }
                            if {[regexp ".*user.*" $bantype]} {
                                set banCommand "${banCommand}!${mUser}"
                            } else {
                                set banCommand "${banCommand}!*"
                            }
                            if {[regexp ".*domain$" $bantype]} {
                                set banCommand "${banCommand}@${mHostmask}"
                            } else {
                                set banCommand "${banCommand}@*[string range $mHostmask [string first . $mHostmask] end]"
                            }
                            
                            debug "BANNING: $banCommand"
                            $self _send "MODE $chann +b $banCommand"
                            if {$shouldkick} {
                                $self _send "KICK $chann $mNick $banmsg"
                            }
                            unset banRequestList($mNick)
                            return
                        }
                    }
                }
                367 {
                    #RPL_BANLIST
                    if {[regexp "\(\[$ChannelPrefixes\]\[^ \]+\) \(\[^ \]+\) \(\[^ \]+\) \(\[0-9\]+\)" $mMsg -> mTarget mEntry mCreator mTime]} {
                    #Send to server if it exists
                    if [info exists channelMap($mTarget)] {
                        if {[$channelMap($mTarget) addBanEntry $mEntry $mCreator $mTime] == 0 } {
                            return
                        }
                        catch { if {[wm state .propDialog]!="normal"} {
                            $channelMap($mTarget) handleReceived $timestamp [getTitle $mCode] bold "$mEntry - set by $mCreator [clock format $mTime]" $style
                        }}
                    #Otherwise just print it here
                    } else {
                        $self handleReceived $timestamp [getTitle $mCode] bold "$mEntry - set by $mCreator [clock format $mTime]" $style
                    }
                    return
                    }
                }
                default {
                    $self handleReceived $timestamp [getTitle $mCode] bold $mMsg $style
                }
            }
            return
        }
    
        #:byteslol!~byteslol@protectedhost-99B37D77.hsd1.co.comcast.net NICK :bytes101
        if {[regexp {:([^!]*)![^ ]* ([^ ]*) ?([^ ]*) ?([^ ]*)[^:]*:(.*)} $line -> mNick mSomething mChannel mTarget mMsg]} {
            debug "REC: Special: $mSomething"
            switch $mSomething {
                "NICK" {
                    debug "Nick Change: '$mNick\' == \'[$self getNick]\'   [string equal $mNick [$self getNick]]"
                    if {[string equal $mNick [$self getNick]]} {
                        $self handleReceived $timestamp "***" bold "You are now known as $mMsg" ""
                        $self propogateMessage MYNICK $timestamp "***" bold "You are now known as $mMsg" ""
                        $self nickChanged $mMsg
                    } else {
                        if {[regexp ".*$nick.*" "$mNick$mMsg"]} {
                            set style "mention"
                            #$channelMap($mChannel) notifyMention $mNick $mMsg
                        }
                        $self propogateMessage NICK $timestamp "***" bold "$mNick is now known as $mMsg" $style
                    }
                    return
                }
                "JOIN" {
                    if {[string equal $mNick [$self getNick]]} {
                    $self joinChan $mMsg ""
                    } else {
                    if {[regexp ".*$nick.*" "$mNick"]} {
                        set style "mention"
                        $channelMap($mMsg) notifyMention $mMsg "$mNick has joined"
                    }
                    $channelMap($mMsg) handleReceived $timestamp "***" bold "$mNick has joined" $style
                    $channelMap($mMsg) NLadd $mNick
                    }
                    return
                }
                "KICK" {
                    if {$mTarget == [$self getNick]} {
                    $channelMap($mChannel) handleReceived $timestamp "***" bold "$mNick kicked you: $mMsg" $style
                    $self removeActiveChannel $mChannel
                    set style "mention"
                    $channelMap($mMsg) notifyMention $mMsg "$mNick kicked you: $mMsg"
                    } else {
                    if {[regexp ".*$nick.*" "$mNick$mTarget$mMsg"]} {
                        set style "mention"
                        $channelMap($mMsg) notifyMention $mMsg "$mNick kicked $mTarget: $mMsg"
                    }
                    $self handleReceived $timestamp "***" bold "$mNick kicked $mTarget: $mMsg" $style
                    $channelMap($mChannel) NLremove $mTarget
                    }
                    return
                }
                "PART" {
                    if {$mTarget == [$self getNick]} {
                    if {[regexp ".*$nick.*" "$mNick$mMsg"]} {
                        set style "mention"
                        $channelMap($mChannel) notifyMention $mChannel "$mNick has left ($mMsg)"
                    }
                    $self handleReceived $timestamp "***" bold "$mNick has left ($mMsg)" $style
                    $channelMap($mChannel) NLremove $mNick
                    $self removeActiveChannel $mChannel
                    } else {
                    $self handleReceived $timestamp "***" bold "You have left ($mMsg)" $style
                    $channelMap($mChannel) NLremove $mNick
                    }
                    return
                }
                "QUIT" {
                    if {$mTarget == [$self getNick]} {
                    debugE "You quit? What the hell?"
                    #$self removeActiveChannel $mChannel
                    } else {
                    if {[regexp ".*$nick.*" "$mNick$mMsg"]} {
                        set style "mention"
                        $self notifyMention $mChannel "$mNick has quit ($mMsg)"
                    }
                    $self propogateMessage QUIT $timestamp "***" bold "$mNick has quit ($mMsg)" $style
                    }
                    return
                }
                "NOTICE" {
                    $self handleReceived $timestamp \[Notice\] bold $mMsg ""
                    return
                }
            }
        }
    
        #:ChanServ!services@geekshed.net MODE #qweex +qo notbryant notbryant
        if {[regexp {:([^!]*)![^ ]* ([^ ]*) ([^ ]*) (.*)} $line -> mNick mSomething mChann mMsg]} {
            debug "REC: Special2: $mSomething"
            if {[regexp ".*$nick.*" "$mNick$mMsg"]} {
                set style "mention"
                $channelMap($mChann) notifyMention $mNick $mMsg
            }
            switch $mSomething {
                "MODE" {
                    #User mode
                    if { [regexp {([^ ]+) ([^ ]+).*} $mMsg -> mModes mTarget] } {
                        $channelMap($mChann) handleReceived $timestamp "***" bold "$mNick has set mode $mModes for $mTarget" $style
                    
                        set modes [split $mModes {}]
                        set what "?"
                        foreach m $modes {
                            if {$m == "+" || $m == "-"} {
                                set what $m
                                continue
                            }
                            set modePos [string first $m $NickPrefixesA ]
                            debug "?MODE: $m  $modePos  $NickPrefixesA"
                            if {$modePos > -1 && $what!="?"} {
                                debug "!MODE: [string index $NickPrefixesS $modePos]$mTarget"
                                $channelMap($mChann) NLchmod $mTarget [string index $NickPrefixesS $modePos] $what
                                break
                            }
                        }
                    
                    #Channel mode
                    } else {
                        $channelMap($mChann) handleReceived $timestamp "***" bold "$mNick has set channel modes $mMsg" $style
                    }
                    return
                }
            }
        }
    
        # Server message with no numbers but sent explicitely from server
        if {[regexp {:([^ ]*) ([^ ]*) ([^:]*):(.*)} $line -> mServer mSomething mTarget mMsg]} {
            debug "REC: Etc: $mSomething $mTarget"
            switch $mSomething {
                "MODE" {
                    set mMsg "$ServerName has set your personal modes: $mMsg"
                }
                "NOTICE" {
                    $self handleReceived $timestamp \[Notice\] bold $mMsg ""
                    return
                }
                "433" {
                # Note that this only happens when it is a catastrophic failure!
                    close $connDesc
                    unset connDesc
                    $self handleReceived $timestamp \[Error\] bold $mMsg ""
                    $self updateToolbar ""
                    return
                }
            }
            if {[regexp ".*$nick.*" "$mTarget$mMsg"]} {
                set style "mention"
                $self notifyMention $mTarget $mMsg
            }
            $self handleReceived $timestamp \[$mSomething\] bold $mMsg $style
            return
        }
            
        # "NOTICE AUTH : *** Please wait while we scan your connection for open proxies"
        if {[regexp {NOTICE AUTH:(.*)} $line -> mMsg]} {
            $self handleReceived $timestamp \[Notice\] bold $mMsg "";
            return
        }
        debug "WHAT: $line"
        } error_msg error_options
        if {[string length $error_msg] > 0} {
            ::notebox::addmsg "ERROR: $server  -  $error_msg"
            puts "ERROR: $server ${error_options}"
        }
    }
}
