# gemspec for Arcadia
# Antonio Galeone (antonio-galeone@rubyforge.org)
 	
require 'rubygems'
  SPEC = Gem::Specification.new do |s|
  s.name = "arcadia"
  s.version = "0.7.0"
  s.date = "2009-07-21"
  s.author = "Antonio Galeone"
  s.email = "antonio-galeone@rubyforge.org"
  s.homepage = "http://arcadia.rubyforge.org"
  s.rubyforge_project = "arcadia"  
  s.platform = Gem::Platform::RUBY
  s.summary = "An Ide for Ruby written in Ruby using the classic tcl/tk GUI toolkit."
    candidates = Dir.glob("{lib,ext/ae-breakpoints,ext/ae-editor,ext/ae-file-history,ext/ae-output,ext/ae-rad,ext/ae-ruby-debug,ext/ae-search-in-files,ext/ae-shell,tcl}/**/*")
    candidates << "README"
    candidates << "bin/arcadia"
    candidates << "bin/arcadia.bat"
    candidates << "conf/arcadia.conf"
    candidates << "conf/arcadia.init.rb"
    candidates << "conf/arcadia.res.rb"
  s.files =  candidates.delete_if do |item|
      item.include?("CVS") || item.include?("rdoc")|| item.include?("cvs")|| item.include?(".git")
  end
  #s.require_path = "lib"
  s.bindir = "bin"
  s.executables << "arcadia"
  s.default_executable = 'arcadia'
  # don't reference the test until we see it execute fully and successfully
  # s.test_file = "test/runner.rb"
  # disable rdoc generation until we've got more
  s.rdoc_options << '--title' << 'Arcadia Documentation' <<  '--main'  << 'README' << '-q'   
  s.has_rdoc = false
  s.extra_rdoc_files = ["README"]
  #s.add_dependency("ruby", ">= 1.8.3")
  #s.add_dependency("rcodetools", ">= 0.5.0.0")
  s.add_dependency("ruby-debug", ">= 0.9.3")
end
