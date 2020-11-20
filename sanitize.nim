import pegs, re, strutils, os, osproc, strtabs, yaml, streams, parseopt

type Subs = object
  litLitSubs :seq[(string, string)]
  litShSubs :seq[(string, string)]
  reLitSubs :seq[(Regex, string)]
  reShSubs :seq[(Regex, string)]
  pegLitSubs :seq[(Peg, string)]
  pegShSubs :seq[(Peg, string)]

type Sanitizer {.sparse.} = object
  matchKind :string
  match :string
  replaceKind :string
  replace :string

proc sh(cmd :string, match = "", len = 0) :string =
  let shResult = execCmdEx(cmd, input = match, env = newStringTable({"MATCH_LEN": $len}))
  if shResult.exitCode != 0:
    writeLine stderr, "shell command exited with non-zero error code: " & $shResult.exitCode
    quit $shResult.exitCode
  result = string shResult.output
  result.stripLineEnd

proc add(subs :var Subs, sanitizer :sink Sanitizer) =
  case sanitizer.matchKind:
  of "sh":
    let match = sh sanitizer.match
    case sanitizer.replaceKind:
    of "lit": add subs.litLitSubs, (match, sanitizer.replace)
    of "sh": add subs.litLitSubs, (match, sh(sanitizer.replace, match, match.len))
    else: discard
  of "lit":
    case sanitizer.replaceKind:
    of "lit": add subs.litLitSubs, (sanitizer.match, sanitizer.replace)
    of "sh": add subs.litLitSubs, (sanitizer.match, sh(sanitizer.replace, sanitizer.match, sanitizer.match.len))
    else: discard
  of "re":
    case sanitizer.replaceKind:
    of "lit": add subs.reLitSubs, (re sanitizer.match, sanitizer.replace)
    of "sh": add subs.reShSubs, (re sanitizer.match, sanitizer.replace)
    else: discard
  of "peg":
    case sanitizer.replaceKind:
    of "lit": add subs.pegLitSubs, (peg sanitizer.match, sanitizer.replace)
    of "sh": add subs.pegShSubs, (peg sanitizer.match, sanitizer.replace)
    else: discard
  else: discard

converter toBool(bounds :tuple[first, last :int]) :bool = bounds.first > -1
converter toSlice(bounds :tuple[first, last :int]) :Slice[int] = bounds.first .. bounds.last
proc replace(input :sink string, subs :sink Subs) :string =
  result = multiReplace(result, subs.litLitSubs)
  result = multiReplace(result, subs.reLitSubs)
  result = parallelReplace(result, subs.pegLitSubs)
  for (matcher, replace) in subs.reShSubs:
    let match = findBounds(result, matcher)
    if match: result[match] = sh(replace, result[match], match.len)
  for (matcher, replace) in subs.pegShSubs:
    var matches :seq[string]
    let match = findBounds(result, matcher, matches)
    if match: result[match] = sh(replace, result[match], match.len)

proc usage = echo """
poop
"""
const version {.strdefine.} = "0.0.0"

var inputs :seq[string]
var ruleFilePath :string
var subs :Subs

for kind, key, value in getOpt():
  case kind
  of cmdArgument:
    inputs.add key
  of cmdLongOption, cmdShortOption:
    case key
    of "f": ruleFilePath = value
    of "V", "version":
      echo version
      quit 0
    of "h", "help":
      usage()
      quit 0
    else:
      usage()
      quit 1
  else:
    discard

if fileExists ruleFilePath:
  var sanitizers :seq[Sanitizer]
  var s = newFileStream(ruleFilePath)
  load(s, sanitizers)
  s.close()
  for sanitizer in sanitizers: add subs, sanitizer

if inputs.len > 0:
  for path in inputs:
    var file = open(path, mode = fmReadWrite)
    write stdout, replace(string readAll file, subs)
    close file
else:
  echo "h"
  write stdout, replace(string readAll stdin, subs)

