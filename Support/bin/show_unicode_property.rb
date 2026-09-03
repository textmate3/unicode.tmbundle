#!/usr/bin/env ruby
# Shows everything the bundle knows about the character before the caret as an
# HTML tool tip: its UnicodeData row expanded, its block, related characters,
# and for Han characters the radical, stroke count and readings from macOS's
# character palette database.
require "#{ENV['TM_BUNDLE_SUPPORT']}/lib/unicode_tools"

exit 200 if ENV.key?("TM_SELECTED_TEXT")
index = ENV.fetch("TM_LINE_INDEX", "0").to_i
exit 206 if index.zero? || !ENV.key?("TM_CURRENT_LINE")

line = ENV["TM_CURRENT_LINE"].dup.force_encoding("UTF-8")
character = line.byteslice(0, index).force_encoding("UTF-8")[-1]
code = character.ord
hex  = "%04X" % code
astral = code > 0xFFFF

library = File.join(ENV.fetch("TM_BUNDLE_SUPPORT"), "lib")
PALETTE_DATABASE = "/System/Library/Input Methods/CharacterPalette.app/Contents/Resources/CharacterDB.sqlite3"

def shell(*command)
  IO.popen(command, err: File::NULL, &:read).to_s.force_encoding("UTF-8")
end

row = shell("gzip", "-dc", File.join(library, "UnicodeData.txt.gz")).each_line.find { |r| r.start_with?(hex + ";") }
fields = row ? row.chomp.split(";", -1) : []
name = fields[1].to_s
name = UnicodeTools.range_name(code) || "U+#{hex}" if name.empty? || name.start_with?("<")
block = UnicodeTools.block_name(code)

report = {}
report["Character"] = character
report["Name"]      = name
report["Block"]     = block

related = File.foreach(File.join(library, "relatedChars.txt"), encoding: "UTF-8").find { |r| r.include?(character) }
report["Related to"] = related.chomp if related

if name.include?("CJK") && (name.include?("IDEO") || name.include?("Ideo"))
  radical = shell("unzip", "-p", File.join(library, "allHanForRadical.txt.zip")).each_line.find { |r| r.include?(character + ",") }
  if radical
    number, radical_strokes, radical_name, radical_character, extra_strokes, = radical.chomp.split("\t")
    report["Radical (trad.)"] = [radical_character, radical_strokes, "画", radical_name, number, extra_strokes]
    report["Strokes (trad.)"] = (radical_strokes.to_i + extra_strokes.to_i).to_s
  end

  palette = shell("sqlite3", PALETTE_DATABASE, "select uchr, info from unihan_dict where uchr = '#{character}';").chomp
  unless palette.empty?
    _, _, readings, hangul, _, wubi_xing, wubi_hua, bianhao, _, cangjie_characters, dayi, pinyin, bopomofo, _, _, _, cangjie = palette.split("|", -1)
    cangjie = cangjie.to_s.strip
    if readings && !readings.empty?
      kun, on = readings.split("/", 2)
      japanese = {}
      japanese["Kun"] = kun unless kun.to_s.empty?
      japanese["On"]  = on  unless on.to_s.empty?
      report["Japanese"] = japanese
    end

    variant = File.foreach(File.join(library, "zhSimTradHanzi.txt"), encoding: "UTF-8").find { |r| r.start_with?(character) }
    _, kind, counterparts = variant ? variant.chomp.split("\t", 3) : []
    chinese = {}
    chinese["Traditional"] = counterparts if kind == "T" && counterparts
    chinese["Simplified"]  = counterparts if kind == "S" && counterparts
    chinese["Pinyin"]        = pinyin    unless pinyin.to_s.empty?
    chinese["Zhuyin"]        = bopomofo  unless bopomofo.to_s.empty?
    chinese["Wubi Xing"]     = wubi_xing unless wubi_xing.to_s.empty?
    chinese["Wubi Hua"]      = wubi_hua  unless wubi_hua.to_s.empty?
    chinese["Bishu Bianhao"] = bianhao   unless bianhao.to_s.empty?
    chinese["Cangjie"]       = "#{cangjie} #{cangjie_characters}" unless cangjie.empty?
    chinese["Dayi"]          = dayi      unless dayi.to_s.empty?
    report["Chinese"] = chinese unless chinese.empty?
    report["Korean"] = { "Hangul" => hangul } unless hangul.to_s.empty?
  end
else
  if name.include?("HANGUL") && !block.include?("Jamo")
    report["Decomposition"] = character.unicode_normalize(:nfkd).chars.join(" ")
  end
  unless fields.empty?
    category, combining, direction, decomposition, numeral1, numeral2, numeral3, mirrored, old_name, _, upper, lower, title = fields[2..14]
    report["Category"]        = UnicodeTools.category(category)             unless category.to_s.empty?
    report["Old Name"]        = old_name                                    unless old_name.to_s.empty?
    report["Bidirectional"]   = UnicodeTools.direction_class(direction)     unless direction.to_s.empty?
    report["Combining Class"] = UnicodeTools.combining_class(combining)     unless combining.to_s.empty?
    report["Mirrored"]        = mirrored                                    unless mirrored.to_s.empty?
    report["Upper Case"]      = "#{[upper.hex].pack("U")} (U+#{upper})"     unless upper.to_s.empty?
    report["Lower Case"]      = "#{[lower.hex].pack("U")} (U+#{lower})"     unless lower.to_s.empty?
    report["Title Case"]      = "#{[title.hex].pack("U")} (U+#{title})"     unless title.to_s.empty?
    report["Numeral Type"]    = [numeral1, numeral2, numeral3].join(" ").strip unless numeral1.to_s.empty?
    if !decomposition.to_s.empty? && !astral
      parts = decomposition.split(" ")
      details = {}
      if parts.first.start_with?("<")
        details["Class"] = UnicodeTools.decomposition_class(parts.shift)
      end
      composed = parts.map { |p| [p.hex].pack("U") }.join(" ") + " (U+" + parts.join(" U+") + ")"
      folded = character.unicode_normalize(:nfkd).chars
      if folded.size != parts.size
        composed += "; " + folded.join(" ") + "(" + folded.map { |c| "U+%04X" % c.ord }.join(" ") + ")"
      end
      details["into"] = composed
      report["Decomposition"] = details
    end
  end
end

points = {}
points["UCS dec/hex"] = "#{code} / U+#{hex}"
points["UTF-8"] = character.bytes.map { |b| "%X" % b }.join(" ")
utf16 = character.encode("UTF-16BE").unpack1("H*").upcase
points["UTF-16BE"] = utf16[0, 4] + "+" + utf16[4..-1] if utf16.size > 4
report["Codepoints"] = points

def cell(value)
  value.to_s.gsub("&", "&amp;").gsub("<", "&lt;")
end

placeholder = report["Category"].to_s.include?("Nonspacing") ? "o" : ""
html = "<table style=\"border-collapse:collapse;\">"
html << "<tr><td rowspan=2 style=\"border:1px dotted silver;font-size:20pt;text-align:center;\"><font color=#CCCCCC>#{placeholder}</font>#{cell(character)}</td><td>&nbsp;</td><td style=\"color:grey;\">Name</td><td>#{cell(name)}</td></tr>"
html << "<tr><td>&nbsp;</td><td style=\"color:grey;\">Block</td><td>#{cell(block)}</td></tr>"
html << "</table><table style=\"border-collapse:collapse;width:200px;\">"
report.each do |key, value|
  next if %w[Character Name Block].include?(key)
  if key.include?("Radical")
    html << "<tr><td align=right style=\"color:grey;\">#{key}</td><td>&nbsp;</td><td style=\"white-space:nowrap;\">#{cell(value[0])} (#{cell(value[1])}#{cell(value[2])} - #{cell(value[3])}) #{cell(value[4])}.#{cell(value[5])}</td></tr>"
  elsif value.is_a?(Hash)
    html << "<tr><td colspan=2 align=right style=\"color:grey;\"><b><i>#{key}</i></b></td></tr>"
    value.each do |inner_key, inner_value|
      html << "<tr><td align=right style=\"color:grey;white-space:nowrap;\">#{inner_key}</td><td>&nbsp;</td><td style=\"white-space:nowrap;\">#{cell(inner_value)}</td></tr>"
    end
  else
    html << "<tr><td align=right style=\"color:grey;white-space:nowrap;\">#{key}</td><td>&nbsp;</td><td style=\"white-space:nowrap;\">#{cell(value)}</td></tr>"
  end
end
html << "</table>"

if ENV["DIALOG"]
  system(ENV["DIALOG"], "tooltip", "--html", html)
  exit 206
end
puts html
