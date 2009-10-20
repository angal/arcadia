# 
# receives messages and tracks the
#
class MonitorLastUsedDir < ArcadiaExt

  def on_before_build(_event)
    for event in [SaveBufferEvent, AckInFilesEvent, SearchInFilesEvent, OpenBufferEvent] do
     Arcadia.attach_listener(self, event)
    end
  end

  def on_after_save_as_buffer(_event)
   MonitorLastUsedDir.set_last _event.new_file
  end

  def on_after_ack_in_files _event
    MonitorLastUsedDir.set_last _event.dir
  end
  
  # we want this one...but...not at startup time...hmm.
  def on_after_open_buffer _event
    MonitorLastUsedDir.set_last _event.file
  end
  
  alias :on_after_search_in_files :on_after_ack_in_files  

  def self.get_last_dir
    current = $arcadia['pers']['last.used.dir']
    if current != nil && current != ''
     current
    else
     $pwd # startup dir
    end
  end  

  def MonitorLastUsedDir.set_last to_this # TODO set as private...
    return if to_this.nil? or to_this == ''
    if(File.directory?(to_this))
      to_this_dir = to_this
    elsif File.directory? File.dirname(to_this)
      # filename,
      to_this_dir = File.dirname(to_this)
    end
    $arcadia['pers']['last.used.dir'] = File.expand_path(to_this_dir)
  end

end