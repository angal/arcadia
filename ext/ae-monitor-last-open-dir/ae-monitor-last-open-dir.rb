
class MonitorLastUsedDir < ArcadiaExt

  def on_before_build(_event)
    for event in [SaveBufferEvent, AckInFilesEvent, SearchInFilesEvent] do
     Arcadia.attach_listener(self, event)
    end
  end

  def on_after_save_as_buffer(_event)
   set_last _event.new_file # works
  end

  def on_after_ack_in_files _event
    # todo...
    set_last _event.dir
  end
  
  alias :on_after_search_in_files :on_after_ack_in_files  

  def self.get_last_dir
    current = $arcadia['pers']['last.used.dir']
    if current != nil && current != ''
      return current
    else
     return $pwd # startup dir
    end
  end

  private
  def set_last to_this_dir
    return unless to_this_dir
    if(File.directory?(to_this_dir))
      # ok
    elsif File.directory? File.dirname(to_this_dir)
      # filename, not dir name
      to_this_dir = File.dirname(to_this_dir)
    end
    $arcadia['pers']['last.used.dir'] = to_this_dir if File.directory? to_this_dir # paranoia
    puts 'it is now', MonitorLastUsedDir.get_last_dir
  end



end