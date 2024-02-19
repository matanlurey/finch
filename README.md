# `finch`

Opinionated workflow and tooling for hacking on [`flutter/engine`][gh-engine].

[gh-engine]: https://github.com/flutter/engine

```txt
$ ./finch status
Hello, matanlurey!

50731 | Try setting a consistent background color.
🟢 approved by 1/3 reviewers
🟢 checks passed

50585 | Run `impeller_unittests` in parallel by using a random directory suffix.
🟢 approved by 1/1 reviewers
🔴 checks failed (3/24)

50312 | Tool that audits GitHub for checks that appear to fail at a high rate
⚪ no reviewer assigned
🟢 checks passed

48843 | Move `third_party/googletest` to `flutter/third_party`.
⚪ no reviewer assigned
🔴 checks failed (21/26)
```

## Usage

```txt
$ ./finch
Opinionated workflow and tooling for hacking on Flutter.

Usage: finch <command> [arguments]

Global options:
-h, --help    Print this usage information.

Available commands:
  open     Open a PRs page in a browser.
  status   Show the status of open PRs.

Run "finch help <command>" for more information about a command.
```
