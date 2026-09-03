#!/usr/bin/env ruby
# Lists every distinct character of the input with its count, code point,
# block and name, as an HTML page, followed by a grid of the characters.
#
#   show_character_inventory.rb            # one row per character, sortable
#   show_character_inventory.rb grouped    # rows grouped by lib/relatedChars.txt
require "#{ENV['TM_BUNDLE_SUPPORT']}/lib/unicode_tools"

STDIN.set_encoding("UTF-8")
STDOUT.set_encoding("UTF-8")
grouped = ARGV.first == "grouped"
library = File.join(ENV.fetch("TM_BUNDLE_SUPPORT"), "lib")

counts = Hash.new(0)
STDIN.read.each_char { |c| counts[c.ord] += 1 }
counts.delete(10)
codes = counts.keys.sort
names = UnicodeTools.names_of(codes, library)
def row(code, count, names, css_class = nil)
  name  = UnicodeTools.name_of(code, names)
  glyph = [code].pack("U")
  glyph = "◌" + glyph if name.include?("COMBINING")
  opening = css_class.nil? ? "<tr>" : "<tr class='#{css_class}'>"
  "#{opening}<td class='a'> #{glyph} </td><td class='a'> #{count} </td><td> U+%04X </td><td> #{UnicodeTools.block_name(code)} </td><td> #{name} </tr>" % code
end

puts File.read(File.join(library, grouped ? "character_inventory_grouped_header.html" : "character_inventory_header.html"))
puts "<table border=1><tr>"
if !grouped && codes.size < 400
  puts "<th><span title='click to sort' onclick='return sortTable2(0)'>Character</span></th> " \
       "<th><span title='click to sort' onclick='return sortTable2(1)'>Occurrences</span></th> " \
       "<th><span title='click to sort' onclick='return sortTable2(0)'>UCS</span></th> " \
       "<th><span title='click to sort' onclick='return sortTable2(3)'>Unicode Block</span></th> " \
       "<th><span title='click to sort' onclick='return sortTable2(4)'>Unicode Name</span></th>"
else
  puts "<th>Character</th><th>Occurrences</th><th>UCS</th><th>Unicode Block</th><th>Unicode Name</th>"
end
puts "</tr><tbody id='theTable'>"

if grouped
  related = File.readlines(File.join(library, "relatedChars.txt"), encoding: "UTF-8", chomp: true)
  groups = {}
  unrelated = []
  codes.each do |code|
    glyph = [code].pack("U")
    index = related.index { |group| group.include?(glyph) }
    if index
      (groups[index] ||= []) << code
    else
      unrelated << code
    end
  end
  groups.values.each_with_index do |members, i|
    css_class = members.size == 1 ? "" : %w[tr2 tr1][i % 2]
    members.each { |code| puts row(code, counts[code], names, css_class) }
  end
  unrelated.each { |code| puts row(code, counts[code], names) }
  puts "</table>"
else
  codes.each { |code| puts row(code, counts[code], names) }
  puts "</tbody></table>"
end

total = counts.values.sum
puts '<h2><a name="inventory">Character Inventory</a></h2>'
puts "<p><i>#{total} character#{total < 2 ? "" : "s"} total, #{codes.size} distinct</i></p>"
puts '<table id="character-inventory">'
puts "<tr>"
codes.each_slice(25) { |slice| puts slice.map { |code| "<td> #{[code].pack("U")} </td>" }.join(" ") + "</tr><tr>" }
puts "</tr>"
puts "</table>"
puts "<p></p>"
puts "</body></html>"
