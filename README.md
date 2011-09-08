# Goling

Goling is a linguistic compiler allowing you to compile and execute plain english.
And thus allows you to program in plain english provided you have the reduction rules needed.

Since the code ends up compiled like all code should be you can execute your code so amazingly fast I am in awe just to be able to write this divine text to you about it.

## Installation

    gem install goling

## Basic usage

	reduce /all directories/ => 'directories' do
	  Dir.entries('.').select{ |f| f[0] != '.' && File.directory?(f) }
	end

	reduce /({directories:[^}]*}) recursively/ => 'directories' do |dirs|
	  all_dirs = dirs
	  Find.find(dirs) do |path|
	    if FileTest.directory?(path)
	      if File.basename(path)[0] == '.'
	        Find.prune       # Don't look any further into this directory.
	      else
			all_dirs << path
	        next
	      end
	    end
	  end
	  all_dirs
	end

	reduce /all files inside ({directories:[^}]*})/ => 'files' do |dirs|
	  dirs.map{ |f| File.new(f, "r") }
	end

	reduce /view ({files:[^}]*})/ => '' do |files|
	  files.each do |file|
	    pp file
	  end
	end

	"view all files inside all directories recursively".linguify.to_ruby
    # => code = lambda do
	#	   directories_0 = Dir.entries(".").select { |f| ((not (f[0] == ".")) and File.directory?(f)) }
	#	   directories_1 = (all_dirs = dirs
	#	   Find.find(dirs) do |path|
	#	     if FileTest.directory?(path) then
	#	       if (File.basename(path)[0] == ".") then
	#	         Find.prune
	#	       else
	#	         (all_dirs << path)
	#	         next
	#	       end
	#	     end
	#	   end
	#	   all_dirs)
	#	   files_2 = dirs.map { |f| File.new(f, "r") }
	#	   files.each { |file| pp(file) }
	#	 end
	#	 Goling::Linguified.trampoline(code)
	
And if you simply want to execute your magnificent piece of art:

	"view all files inside all directories recursively".linguify.run

Or even:

    # compile once, run plenty
    code = "view all files inside all directories recursively".linguify
    loop do
      code.run
    end

## License

(The MIT License)

Copyright (c) 2010 Patrick Hanevold

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the ‘Software’), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED ‘AS IS’, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
