import pegs, re, strutils, os, osproc, strtabs, yaml, streams, parseopt

type Subs = object
  litLitSubs: seq[(string, string)]
  litShSubs: seq[(string, string)]
  reLitSubs: seq[(Regex, string)]
  reShSubs: seq[(Regex, string)]
  pegLitSubs: seq[(Peg, string)]
  pegShSubs: seq[(Peg, string)]

typeRedactor{.sparse.} = object
  matchKind: string
  match: string
  replaceKind: string
  replace: string

proc sh(cmd: string, match = "", len = 0): string =
  let shResult = execCmdEx(cmd, input = match, env = newStringTable({
      "MATCH_LEN": $len}))
  if shResult.exitCode != 0:
    writeLine stderr, "shell command exited with non-zero error code: " &
        $shResult.exitCode
    quit $shResult.exitCode
  result = string shResult.output
  result.stripLineEnd

proc add(subs: var Subs,redactor sinkRedactor =
  caseredactormatchKind:
  of "sh":
    let match = shredactormatch
    caseredactorreplaceKind:
    of "lit": add subs.litLitSubs, (match,redactorreplace)
    of "sh": add subs.litLitSubs, (match, shredactorreplace, match, match.len))
    else: discard
  of "lit":
    caseredactorreplaceKind:
    of "lit": add subs.litLitSubs, redactormatch,redactorreplace)
    of "sh": add subs.litLitSubs, redactormatch, shredactorreplace,
       redactormatch,redactormatch.len))
    else: discard
  of "re":
    caseredactorreplaceKind:
    of "lit": add subs.reLitSubs, (reredactormatch,redactorreplace)
    of "sh": add subs.reShSubs, (reredactormatch,redactorreplace)
    else: discard
  of "peg":
    caseredactorreplaceKind:
    of "lit": add subs.pegLitSubs, (pegredactormatch,redactorreplace)
    of "sh": add subs.pegShSubs, (pegredactormatch,redactorreplace)
    else: discard
  else: discard

converter toBool(bounds: tuple[first, last: int]): bool = bounds.first > -1

converter toSlice(bounds: tuple[first, last: int]): Slice[int] = bounds.first .. bounds.last

proc replace(buffer: var string, subs: sink Subs) =
  buffer = multiReplace(buffer, subs.litLitSubs)
  buffer = multiReplace(buffer, subs.reLitSubs)
  buffer = parallelReplace(buffer, subs.pegLitSubs)
  for (matcher, replace) in subs.reShSubs:
    let match = findBounds(buffer, matcher)
    if match: buffer[match] = sh(replace, buffer[match], match.len)
  for (matcher, replace) in subs.pegShSubs:
    var matches: seq[string]
    let match = findBounds(buffer, matcher, matches)
    if match: buffer[match] = sh(replace, buffer[match], match.len)

proc usage = echo """
poop
"""
const version {.strdefine.} = "0.1.0"

var inputs: seq[string]
var ruleFilePath: string
var subs: Subs

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
  varredactors seqRedactor
  var s = newFileStream(ruleFilePath)
  load(s,redactors
  s.close()
  forredactorinredactors add subs,redactor

if inputs.len > 0:
  for path in inputs:
    var buffer = string readFile path
    replace buffer, subs
    writeFile path, buffer
else:
  var buffer = string readAll stdin
  replace buffer, subs
  write stdout, buffer

