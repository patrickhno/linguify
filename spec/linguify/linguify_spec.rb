# encoding: utf-8

require 'linguify'

describe Linguify::Linguified, "#linguify" do

  it "should reduce multiple rules into ruby code" do

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

    reduce /view ({files:[^}]*})/ do |files|
      files.each do |file|
        pp file
      end
    end

    "view all files inside all directories recursively".linguify.to_ruby.should == "code = lambda do\n  directories_0 = Dir.entries(\".\").select { |f| (not (f[0] == \".\")) and File.directory?(f) }\n  directories_1 = (all_dirs = directories_0\n  Find.find(directories_0) do |path|\n    if FileTest.directory?(path) then\n      if (File.basename(path)[0] == \".\") then\n        Find.prune\n      else\n        (all_dirs << path)\n        next\n      end\n    end\n  end\n  all_dirs)\n  files_2 = directories_1.map { |f| File.new(f, \"r\") }\n  files_2.each { |file| pp(file) }\nend\n"
  end

  it "should mix javascript and ruby" do
    reduce /a possible javascript NOSQL query/ => {:to => 'query', :lang => :js} do
      @db.forEach(lambda{ |record|
          emit(record);
        }
      )
    end

    reduce /execute ({query:[^}]*})/ do |query|
      db.map query
    end

    "execute a possible javascript NOSQL query".linguify.to_ruby.should == "code = lambda do\n  query = \"function(){\\n  this.db.forEach(function(record){\\n    emit(record)\\n  });\\n}\"\n  db.map(query)\nend\n"
  end

  it "should inline sub-expressions" do
    reduce /sub expression/ => {:to => 'sub_expression', :lang => :ruby, :inline => true} do
      pp "this is the sub expression code"
    end

    reduce /({sub_expression:[^}]*}) of inlined code/ => {:to => 'code', :lang => :ruby, :inline => true} do |sub|
      something.each do |foobar|
        pp foobar
      end
    end

    reduce /execute ({code:[^}]*})/ do |code|
      pp "hey mum"
      code
      code[:sub]
      pp "you will never know what I just did"
    end

    "execute sub expression of inlined code".linguify.to_ruby.should == "code = lambda do\n  (pp(\"hey mum\")\n  (something.each { |foobar| pp(foobar) })\n  pp(\"this is the sub expression code\")\n  pp(\"you will never know what I just did\"))\nend\n"
  end

end
