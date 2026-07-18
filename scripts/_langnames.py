"""Single source of truth for language display names in every chart/table script.

Import with `from _langnames import NAMES` (the scripts are always invoked as
`python3 scripts/<script>.py`, so this directory is sys.path[0]). Adding a
language means adding it HERE once, not to five per-script copies.
"""

NAMES = {"c": "C", "rust": "Rust", "swift": "Swift", "go": "Go", "python": "Python",
         "perl": "Perl", "php": "PHP", "kotlin": "Kotlin", "scala": "Scala",
         "csharp": "C#", "elixir": "Elixir", "ruby": "Ruby", "java": "Java",
         "javascript": "JavaScript"}
