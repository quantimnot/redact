version       = "0.1.0"
author        = "quantimnot"
description   = "redaction utility"
license       = "MIT"
installExt    = @["nim", "regex", "peg"]
srcDir        = "."
bin           = @[redact]

requires "error"
requires "yaml"

