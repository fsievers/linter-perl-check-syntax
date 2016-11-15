## 0.5.0
* Allow configuring cwd for execution. (Thanks to icgood)

## 0.4.0
* Update RegEx to match multiline error messages from perl. (Closes: #2)

## 0.3.0
* Fix undefined buffer error messages when perl error messages references another file.

## 0.2.3
* Add option to enable taint mode for perl interpreter.

## 0.2.2
* Add option to set absolute include paths for your perl interpreter.

## 0.2.1
* Add settings option to enforce the usage of warnings when checking the code (`perl -w`).

## 0.2.0 - Code refactor
* Move linter function into own class for better readability.
* Observe settings, to always start linting with current package configuration.

## 0.1.0 - First Release
* Implement syntax check with `perl -c`
