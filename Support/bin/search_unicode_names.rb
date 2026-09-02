#!/usr/bin/env ruby
# frozen_string_literal: true

# Prints the characters whose Unicode names match every word of the search
# text, as HTML the picker page shows and inserts on click.
#
#   search_unicode_names.rb word|full TEXT
#
# With "word" each search word has to match a whole word of the name, with
# "full" it can match anywhere. Words are regular expressions, so "LATIN.*A"
# works, and a word that is not a valid expression is matched literally.

require "cgi"
require "zlib"

DATA_FILE = File.join(ENV.fetch("TM_BUNDLE_SUPPORT"), "lib", "UnicodeData.txt.gz")
LIMIT     = 499

# Marks that sit on another character are shown on a dotted circle so they
# are visible at all.
SHOWN_ON_DOTTED_CIRCLE = [
  "COMBINING", "HEBREW MARK", "HEBREW ACCENT", "HEBREW POINT",
  "LAO TONE", "LAO VOWEL", "LAO SEMIVOWEL", "LAO CAN", "LAO NIG",
].freeze

kind, text = ARGV
abort("usage: search_unicode_names.rb word|full TEXT") unless %w[word full].include?(kind) && text

patterns = text.upcase.split(" ").map do |word|
  source = begin
    Regexp.new(word).source
  rescue RegexpError
    Regexp.escape(word)
  end
  kind == "word" ? Regexp.new("\\b#{source}\\b") : Regexp.new(source)
end

matches = []
Zlib::GzipReader.open(DATA_FILE) do |gz|
  gz.each_line do |line|
    code, name = line.split(";", 3)
    next unless patterns.all? { |pattern| name =~ pattern }
    matches << [code, name]
    break if matches.size > LIMIT
  end
end

puts "<p>&nbsp;<br><br></p>"
if matches.empty?
  puts "<i><small>Nothing found</small></i>"
end

puts "<p class='res'>"
matches.first(LIMIT).each do |code, name|
  prefix    = SHOWN_ON_DOTTED_CIRCLE.any? { |marker| name.include?(marker) } ? "<small>◌</small>" : ""
  character = [code.hex].pack("U")
  print "<span onclick='insertChar(this)' onmouseout='clearName()'; onmouseover='showName(\"U+#{code} : #{CGI.escapeHTML(name)}\")' class='char'>#{prefix}#{character}</span> \n"
end

if matches.size > LIMIT
  puts "</p><i><small>More than 500 matches found. Please narrow down.</small></i>"
else
  puts "</p><i><small>#{matches.size} match#{matches.size == 1 ? "" : "es"}</small></i>"
end
