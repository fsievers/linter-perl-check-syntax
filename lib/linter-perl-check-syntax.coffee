{CompositeDisposable} = require('atom')
namedRegExp = require('named-regexp')
path = require('path')
pkg = require('../package.json')

class PerlCheckSyntax
    REGEX = /(:<message>.*) at (:<file>.*) line (:<line>\d+)/ig
    helpers = require('atom-linter')

    lint: (textEditor, settings) ->
        rootDirectory = @getRootDirectory(textEditor)
        filePath = textEditor.getPath()
        fileDir = path.dirname(filePath)
        parameters = []
        if settings.includePaths.length > 0
            parameters = parameters.concat settings.includePaths.map (p) ->
                "-I" + path.join(rootDirectory, p)
        parameters.push('-c')
        sourceCode = textEditor.getText()

        return helpers.exec(
            settings.executablePath,
            parameters,
            {
                stdin: sourceCode,
                stream: 'both',
                cwd: fileDir}
            ).then (result) ->
                messages = []
                regex = namedRegExp.named(REGEX)

                while ((match = regex.exec(result.stderr)) isnt null)
                    continue unless match and match.length is 4

                    line = parseInt(match.capture('line'), 10) - 1
                    #col = parseInt(match.capture('column'), 10) - 1
                    message = match.capture('message')
                    messages.push
                        type: 'Error'
                        text: message
                        filePath: filePath
                        range: [
                            [line, 0]
                            [line, textEditor.getBuffer().lineLengthForRow(line)]
                        ]

                return messages

    # Get root directory for the current textEditor
    getRootDirectory: (textEditor) ->
        findIndex = (values, fn) ->
            i = 0
            len = values.length
            while i < len
                return i if fn values[i]
                i++
            return -1

        currentFilePath = textEditor.getPath()
        directories = atom.project.getDirectories()
        index = findIndex directories, (dir) -> dir.contains(currentFilePath)
        if index >= 0
            return directories[index].getPath()
        else
            return path.dirname(currentFilePath)

module.exports =
    config:
        executablePath:
            type: 'string'
            title: 'Perl executable path'
            default: 'perl'
        incPathsFromProjectRoot:
            type: "array"
            default: [".", "lib"]
            items:
                type: "string"
            description: "Include paths from the current project root directory."

    activate: ->
        @subscriptions = new CompositeDisposable

        @subscriptions.add atom.config.observe "#{pkg.name}.executablePath",
            (executablePath) =>
                @executablePath = executablePath

        @subscriptions.add atom.config.observe "#{pkg.name}.incPathsFromProjectRoot",
            (includePaths) =>
                @includePaths = includePaths

    deactivate: ->
        @subscriptions.dispose()

    provideLinter: ->
        linter = new PerlCheckSyntax()
        provider =
            name: "Perl"
            grammarScopes: ['source.perl']
            scope: 'file'
            lintOnFly: true
            lint: (textEditor) =>
                linter.lint(
                    textEditor,
                    {
                        executablePath: @executablePath,
                        includePaths: @includePaths
                    }
                )
