path = require 'path'
child_process = require 'child_process'

module.exports = class LinterProvider
  swi_regex = ///
    (\w+):  #The type of issue being reported.
    \s+     #A space.
    [^\:]+:  #The file with issue.
    (\d+):  #The line number with issue.
    ((\d+):)?  #The column number with issue.
    \s+     #A space.
    (.*)    #A message explaining the issue at hand.
  ///

  getCommand = ->
    plpath = atom.config.get('linter-prolog.compilerPath', [])
    if plpath.indexOf("swi") > -1
      "#{atom.config.get 'linter-prolog.compilerPath'} -g \"halt.\" -l"
    else
      "#{atom.config.get 'linter-prolog.compilerPath'} --goal \"halt.\" -l"

  getCommandWithFile = (file) -> "#{getCommand()} '#{file}'"

  parse = (line) ->
    match = line.match swi_regex
    if match
      return {
        type: match[1]
        line: match[2]
        column: match[4] ? 1
        text: match[5]
      }

    lines = line.split("\n")
    if lines[0].endsWith("error")
      return {
        type: "Error"
        line: lines[2].substring(9)
        column: 1
        text: lines[1].substring(2)
      }


  lint: (TextEditor) ->
    new Promise (Resolve) ->
      file = path.basename TextEditor.getPath()
      cwd = path.dirname TextEditor.getPath()
      data = []
      command = getCommandWithFile file
      console.log "Linter Command: #{command}"
      process = child_process.exec command, {cwd: cwd}
      process.stderr.on 'data', (d) -> data.push d.toString()
      process.on 'close', ->
        toReturn = []
        for line in data
          console.log "Prolog Linter Provider: #{line}"
          parse_result = parse(line)
          if(parse_result?)
            line = parse_result.line
            col = parse_result.column
            toReturn.push(
              type: parse_result.type,
              text: parse_result.text,
              filePath: TextEditor.getPath()
              range: [[line-1, col-1], [line-1, col-1]]
            )
        Resolve toReturn
