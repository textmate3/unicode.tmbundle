#!/usr/bin/env ruby
# frozen_string_literal: true

# Prints the IPA symbols whose description matches every word of the search
# text, as HTML the picker page shows and inserts on click.
#
#   search_ipa_descriptions.rb word|full TEXT
#
# With "word" each search word has to match a whole word, with "full" it can
# match anywhere. Matching ignores case. Words are regular expressions, and a
# word that is not a valid expression is matched literally.

require "cgi"
require "zlib"

LIBRARY      = File.join(ENV.fetch("TM_BUNDLE_SUPPORT"), "lib")
IPA_FILE     = File.join(LIBRARY, "IPAnames.txt")
UNICODE_FILE = File.join(LIBRARY, "UnicodeData.txt.gz")

kind, text = ARGV
abort("usage: search_ipa_descriptions.rb word|full TEXT") unless %w[word full].include?(kind) && text

patterns = text.split(" ").map do |word|
  source = begin
    Regexp.new(word).source
  rescue RegexpError
    Regexp.escape(word)
  end
  kind == "word" ? Regexp.new("\\b#{source}\\b", Regexp::IGNORECASE) : Regexp.new(source, Regexp::IGNORECASE)
end

matches = File.readlines(IPA_FILE, encoding: "UTF-8").map(&:chomp).select do |line|
  patterns.all? { |pattern| line =~ pattern }
end

# The Unicode name of each single character match, looked up in the same
# character database the name picker searches.
def unicode_names_for(characters)
  wanted = characters.map { |character| "%04X" % character.ord }
  names  = {}
  Zlib::GzipReader.open(UNICODE_FILE) do |gz|
    gz.each_line do |line|
      code, name = line.split(";", 3)
      names[code] = name if wanted.include?(code)
    end
  end
  names
end

def unicode_name(names, character)
  return "Private Use Area (defined in e.g. Charis SIL)" if character.ord.between?(0xE000, 0xF8FF)
  names.fetch("%04X" % character.ord, "")
end

puts "<i><small>Nothing found</small></i>" if matches.empty?

puts "<p class='res'>"
names = unicode_names_for(matches.map { |line| line.split("\t").first }.select { |symbol| symbol.length == 1 })
matches.each do |line|
  symbol, description = line.split("\t", 2)
  if symbol.length == 1
    name   = unicode_name(names, symbol)
    prefix = name.include?("COMBINING") ? "<small>◌</small>" : ""
    title  = "U+%04X : %s<br>%s" % [symbol.ord, CGI.escapeHTML(description), CGI.escapeHTML(name)]
  else
    prefix = symbol == "̪͆" ? "<small>◌</small>" : ""
    title  = CGI.escapeHTML(description)
  end
  print "<span onclick='insertChar(this)' onmouseout='clearName()'; onmouseover='showName(\"#{title}\")' class='char'>#{prefix}#{symbol}</span> \n"
end

puts "</p><i><small>#{matches.size} match#{matches.size == 1 ? "" : "es"}</small></i>"
