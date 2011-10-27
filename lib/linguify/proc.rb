# encoding: utf-8

# Copyright (c) 2011 Patrick Hanevold.
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

class Proc

  # Translate the Proc to a +Reduction+.
  #
  # @returns [ Reduction ] A +Reduction+ containing the code of the Proc.
  #
  def to_reduction args={}
    Linguify::Reduction.new(
      :returns  => args[:returns] || '',
      :lang     => args[:lang]    || :ruby,
      :inline   => args[:inline]  || false,
      :location => source_location[0],
      :line     => source_location[1],
      :regexp   => args[:regexp]  || //.inspect,
      :args     => args[:args]    || [],
      :sexp     => self.to_sexp
    )
  end

  def to_code collection
    reduction = to_reduction

    sexy = reduction.compile
    code = Marshal.load(Marshal.dump(sexy.first)) # sexy is not cleanly duplicated
    code.replace_variable_references! :replacement => Linguify::Replacement.new(:sexp => collection.name), :needle => :collection
    code
  end
end

