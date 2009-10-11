#
# an extension that triggers a shutdown after startup--should you want
# to profile the startup speed, for example
#

class ShutdownEarly < ArcadiaExt
  def on_after_build(_event)
    if File.exist? 'shutdown_immediately'
      # TODO a different call like "all set up"
      cancel = proc {
        puts 'exit'
        Arcadia.broadcast_event(QuitEvent.new(self))
      }

      cancel.call
      timer=TkAfter.new(10,-1,proc {cancel.call}) # 10ms, loop = -1
      timer.start
    end
  end
end
