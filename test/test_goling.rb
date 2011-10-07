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

    reduce /all files inside ({directories:[^}]*})/ => 'files' do |dirs|
      dirs.map{ |f| File.new(f, "r") }
    end

    reduce /view ({files:[^}]*})/ => '' do |files|
      files.each do |file|
        pp file
      end
    end

    "view all files inside all directories recursively".linguify.to_ruby.size > 0
  end

  should "generate mixed ruby & javascript" do

    reduce /single day plunge/ => {:to => 'move', :lang => :js, :inline => true} do
      @traffic.forEach(lambda{ |day|
          histogram.add(day.page_views,item);
        }
      )
    end

    reduce /largest ({move:[^}]*}) last month traffic records/ => {:to => 'histogram_rule', :lang => :js, :inline => true} do |move|
      if k>=@list[lst][:k]
        @list.push(n)
      else
        while true
          if k<@list[mid][:k]
            lst=mid
          else
            beg=mid
          end
          mid = (beg+lst)>>1
          break if mid==beg
        end

        if k<@list[mid][:k]
          if @list.length >= @max && mid==0
            # lowest k in max days
            #print(tojson(this.list[mid].v));
            emit(@list[mid][:v][:date],@list[mid][:v])
          end
          @list.splice(mid,0,n)
        elsif k<@list[lst][:k]
          @list.splice(lst,0,n)
        else
          #print("!!!");
          #print(k);
          #print(this.list[mid].k);
          #print(this.list[end].k);
          while true
          end
        end
      end
    end

    reduce /({histogram_rule:[^}]*}) on all pages on the whole site/ => {:to => 'traffic_map', :lang => :js} do |rule|
      def Node k,v
        @next = nil
        @prev = nil
        @k    = nil
        @v    = nil
      end
      
      histogram = {
        max:  30,
        list: [],
        find: lambda{
          beg = 0
          lst = @list.length-1
          mid = (beg+lst)>>1
          while true
            if k<@list[mid][:k]
              lst=mid
            else
              beg=mid
            end
            mid = (beg+lst)>>1
            break if mid==beg
          end
          
          # may not be exact match (multiple of same key value), searh in both directions for a exact match
          start = mid
          dir = 1
          while v != @list[mid][:v]
            mid += dir
            if mid == @list.length
              mid = start
              dir =- 1
            end
          end
          return mid
        },
      
        add: lambda{ |k,v|
          if @list.length

            beg = 0
            lst = @list.length-1
            mid = (beg+lst)>>1

            n = Node.new(k,v)
            @last.next = n
            n.prev = @last
            @last = n

            rule

            if @list.length > @max
              # remove first
              @list.splice(this.find(@first[:k],@first[:v]),1)
              @first[:next].prev = nil
              @first = @first[:next]
            end
          else
            @last = Node.new(k,v)
            @first = @last
            @list.push(@last)
          end
        }
      }

      rule[:move]
    end
    
    reduce /view ({traffic_map:[^}]*})/ => '' do |map|
      reduce = "function(k,vals){ return 1; }"
      testing = Site.collection.map_reduce(map, reduce, :out => "testing", :query => { :page => page })      
      # I dont like how the id in mongodb doesnt match the id from the map_reduce!
      traffic.any_in(_id: testing.find.map{ |h| h['_id'].to_s.downcase.gsub(/:/,' colon ').gsub(/ /,'-') }).all.map{ |m| m }
    end

    "view largest single day plunge last month traffic records on all pages on the whole site".linguify.to_ruby.size > 0
  end

end
