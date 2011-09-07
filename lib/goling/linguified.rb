# encoding: utf-8

require 'sourcify'

module Goling

  class Linguified

    attr_accessor :proc, :sentence

    def initialize str,bind

      @sentence = str.dup
      @bind = bind
      loop do
        found = Goling.rules.select do |rule|
          if rule[:match] =~ str
            true
          else
            false
          end
        end
        raise "no step definition for #{str}" if found.size == 0

        rule = found[0]
        match = rule[:match].match(str)
        reduced = Reduction.new(
          :returns  => rule[:result],
          :location => rule[:proc].source_location[0],
          :line     => rule[:proc].source_location[1],
          :regexp   => rule[:match].inspect,
          :args     => match.to_a[1..-1],
          :sexp     => rule[:proc].to_sexp,
        )
        str.gsub!(rule[:match],reduced.to_rexp)
        break if /^{.*}$/ =~ str
      end

      @encoded = str

      @merged_code = []
      if /^{(?<code>.*)}$/ =~ @encoded
        code = Reduction::parse(code).compile_with_return_to_var(nil)

        @sexy = Sexp.new(:block,
          Sexp.new(:lasgn,:code, Sexp.new(:iter,
            Sexp.new(:call, nil, :lambda, Sexp.new(:arglist)), nil,
              Sexp.new(:block,
                *code
              )
            )
          ),
          Sexp.new(:call, Sexp.new(:colon2, Sexp.new(:const, :Goling), :Linguified), :trampoline, Sexp.new(:arglist, Sexp.new(:lvar, :code)))
        )

        @@me = self
        eval to_ruby,bind
        raise "hell" unless @proc      
      else
        raise "hell"
      end
    end
  
    def to_sexp
      @sexy
    end

    def to_ruby
      clone = Marshal.load(Marshal.dump(@sexy)) # sexy is not cleanly duplicated
      Ruby2Ruby.new.process(clone)
    end
    
    def run
      begin
        @proc.call
      rescue Exception => e
        $stderr.puts e
      end
    end
  
    def register_code code
      @proc = code
    end

    def self.trampoline code
      @@me.register_code code
    end
  
    def self.cache
      @@cache ||= {}
    end

  end

end
