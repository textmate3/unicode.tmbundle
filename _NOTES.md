# Notes on the Unicode bundle

## Where the data files come from

The commands in this bundle read the files in `Support/lib` as they are committed.
Nothing ever regenerates them.

- `UnicodeData.txt.gz` is the Unicode Character Database file from unicode.org, version 13.0
  - The commit that last updated it, `4d931c8`, says 14.0, but the data stops at 13.0 and 14.0 did not exist yet
- `relatedChars.txt` was extracted from the character palette dictionary of Mac OS X 10.5 and 10.6
  - macOS no longer has this file
  - A refresh would need to read `RelatedCharDB.sqlite3` inside today's CharacterPalette input method instead
- `allHanForRadical.txt.zip` was converted from a radical data property list of the same Mac OS X era

There is no script for the following files which were derived from the Unicode 5.1 data files in 2008 and not refreshed since:

- `zhSimTradHanzi.txt`, from Unihan
- `mirror.txt`, from the bidirectional mirroring data
- `HanZenKaku.txt`, from the Halfwidth and Fullwidth Forms block

The following files were curated by hand:

- `charList.txt`
- `greekList.txt`
- `IPAnames.txt`
