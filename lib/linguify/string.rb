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

class String

  # Linguify the string.
  #
  # @param   [ Binding ]    binding See the +Kernel#eval+.
  # @returns [ Linguified ] code    The compiled code
  #
  # @example Linguify a string and translate it back to Ruby
  #   "this is the famous hello world".linguify.to_ruby
  #   # => "code = lambda do
  #   #       (pp(\"hello world\")
  #   #     end
  #   #    "
  #
  def linguify bind=binding
    return Linguify::Linguified::cache[self] if Linguify::Linguified::cache[self]
    Linguify::Linguified::cache[self] = Linguify::Linguified.new(self,bind)
  end

end

