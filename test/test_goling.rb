require 'helper'

class TestGoling < Test::Unit::TestCase
  should "work as intended" do

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

    reduce /every largest file inside ({directories:[^}]*})/ => 'files' do |dirs|
      dirs.map{ |f| File.new(f, "r") }
    end

    reduce /view ({files:[^}]*})/ => '' do |files|
      files.each do |file|
        pp file
      end
    end

    "view every largest file inside all directories recursively".linguify.to_ruby.size > 0
  end
end
