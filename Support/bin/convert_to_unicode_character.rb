#!/usr/bin/env ruby
# Offers replacements for the character before the caret from one of the
# bundle's lists, lib/<source>.txt, whose rows group related characters.
#
#   convert_to_unicode_character.rb relatedChars|charList
#
# Exit codes: 200 leaves the line alone, 201 replaces it, 206 shows a tool tip.
require "#{ENV['TM_BUNDLE_SUPPORT']}/lib/unicode_tools"
require "#{ENV['TM_SUPPORT_PATH']}/lib/ui"

if ENV.key?("TM_SELECTED_TEXT")
  puts "Please remove the selection first."
  exit 206
end

source = ARGV.first
library = File.join(ENV.fetch("TM_BUNDLE_SUPPORT"), "lib")
unless source && File.exist?(File.join(library, "#{source}.txt"))
  puts "Source does not exist."
  exit 206
end

line  = ENV.fetch("TM_CURRENT_LINE").dup.force_encoding("UTF-8")
index = ENV.fetch("TM_LINE_INDEX").to_i
exit 200 if index.zero?
left  = line.byteslice(0, index).force_encoding("UTF-8")
tail  = line.byteslice(index..-1).force_encoding("UTF-8")
character = left[-1]
head      = left[0...-1]

row = File.foreach(File.join(library, "#{source}.txt"), encoding: "UTF-8").find { |r| r.include?(character) }
if row.nil?
  puts "Nothing found for: U+%04X %s." % [character.ord, character]
  exit 206
end

codes = row.chomp.each_char.map(&:ord).uniq.sort
names = UnicodeTools.names_of(codes, library)
items = codes.map do |code|
  glyph = [code].pack("U")
  "%s\t:   U+%-5s\t :   %s" % [glyph == '"' ? '\"' : glyph, "%04X" % code, UnicodeTools.name_of(code, names)]
end

chosen = TextMate::UI.menu(items)
exit 200 if chosen.nil?
print head, [codes[chosen]].pack("U"), tail
exit 201
