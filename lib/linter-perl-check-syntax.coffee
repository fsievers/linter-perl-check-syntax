{CompositeDisposable} = require('atom')
namedRegExp = require('named-regexp')
path = require('path')
pkg = require('../package.json')

class PerlCheckSyntax
    REGEX = /(:<message>[\s\S]*?) at (:<file>.*) line (:<line>\d+)(?:\.|, near.*)/ig
    helpers = require('atom-linter')

    lint: (textEditor, settings) ->
        rootDirectory = @getRootDirectory(textEditor)
        filePath = textEditor.getPath()
        fileDir = path.dirname(filePath)
        parameters = []

        if settings.includePaths.length > 0
            parameters = parameters.concat settings.includePaths.map (p) ->
                "-I" + path.join(rootDirectory, p)

        if settings.includePathsAbsolute.length > 0
            parameters = parameters.concat settings.includePathsAbsolute.map (p) ->
                "-I" + p

        parameters.push('-c')

        if settings.warnings == true
            parameters.push('-w')

        if settings.tainted == true
            parameters.push('-T')

        sourceCode = textEditor.getText()

        executableCwd = settings.executableCwd
        if executableCwd == ''
            executableCwd = fileDir

        return helpers.exec(
            settings.executablePath,
            parameters,
            {
                stdin: sourceCode,
                stream: 'both',
                cwd: executableCwd}
            ).then (result) ->
                messages = []
                regex = namedRegExp.named(REGEX)

                while ((match = regex.exec(result.stderr)) isnt null)
                    continue unless match and match.length is 4

                    line = parseInt(match.capture('line'), 10) - 1
                    #col = parseInt(match.capture('column'), 10) - 1
                    try
                        endCol = textEditor.getBuffer().lineLengthForRow(line)
                    catch error
                        endCol = 0
                        currentFilePath = filePath.split('/')
                        currentFilePathReversed = filePath.split('/').reverse()[0]
                        matchedFile = match.capture('file')
                        if currentFilePathReversed != matchedFile
                            pathSegments = currentFilePath[0..-2]
                            pathSegments.push element for element in matchedFile.split('/')
                            filePath = pathSegments.join('/')

                    message = match.capture('message')?.trim()
                    messages.push
                        type: 'Error'
                        text: message
                        filePath: filePath
                        range: [
                            [line, 0]
                            [line, endCol]
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
            type: "string"
            title: "Perl executable path"
            default: "perl"
        executableCwd:
            type: "string"
            title: "Current working directory for execution"
            default: ""
        incPathsFromProjectRoot:
            type: "array"
            title: "Include paths from project root"
            default: [".", "lib"]
            items:
                type: "string"
            description: "Include paths from the current project root directory."
        incPathsAbsolute:
            type: "array"
            title: "Include paths from filesystem root"
            default: []
            items:
                type: "string"
            description: "Absolute include paths from you file system root."
        warnings:
            type: "boolean"
            title: "Enforce warnings"
            default: false
            description: "Enforce to use warnings when executing the perl syntax check (`perl -w`)"
        tainted:
            type: "boolean"
            title: "Enable Taint check"
            default: false
            description: "Enable command line taint switch (`perl -T`)"

    activate: ->
        @subscriptions = new CompositeDisposable

        @subscriptions.add atom.config.observe "#{pkg.name}.executablePath",
            (executablePath) =>
                @executablePath = executablePath

        @subscriptions.add atom.config.observe "#{pkg.name}.executableCwd",
            (executableCwd) =>
                @executableCwd = executableCwd

        @subscriptions.add atom.config.observe "#{pkg.name}.incPathsFromProjectRoot",
            (includePaths) =>
                @includePaths = includePaths

        @subscriptions.add atom.config.observe "#{pkg.name}.incPathsAbsolute",
            (includePathsAbsolute) =>
                @includePathsAbsolute = includePathsAbsolute

        @subscriptions.add atom.config.observe "#{pkg.name}.warnings",
            (warnings) =>
                @warnings = warnings

        @subscriptions.add atom.config.observe "#{pkg.name}.tainted",
            (tainted) =>
                @tainted = tainted

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
                        executableCwd: @executableCwd,
                        includePaths: @includePaths,
                        includePathsAbsolute: @includePathsAbsolute,
                        warnings: @warnings,
                        tainted: @tainted,
                    }
                )
