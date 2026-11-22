#!/usr/bin/env python3
"""Check that misc/toxic.conf.example has every setting toxic reads, and
no setting toxic doesn't read.

toxic names its settings in string tables in src/settings.c: a struct of
field names, initialised with the section name ("self") and the setting
names in the same order. A setting is read if settings.c uses its field.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

TABLE = re.compile(
    r"static (?:const )?struct \w+ \{(?P<fields>.*?)\} (?P<name>\w+) = \{(?P<strings>.*?)\};",
    re.S,
)
FIELD = re.compile(r"const char \*(\w+);")
STRING = re.compile(r'"([^"]*)"')
OPEN = re.compile(r"^\s*(\w+)\s*=\s*[\[{]")
CLOSE = re.compile(r"^\s*[\]}]\s*;?\s*$")
# Settings the example shows commented out are still documented.
SETTING = re.compile(r"^\s*(?://\s*)?(\w+)\s*=\s*[^\[{\s]")


def read_settings(source: str) -> set[tuple[str, str]]:
    """The (section, setting) pairs settings.c reads."""
    settings = set()

    for table in TABLE.finditer(source):
        fields = FIELD.findall(table["fields"])
        strings = STRING.findall(table["strings"])

        if len(fields) != len(strings):
            sys.exit(f"{table['name']}: {len(fields)} fields but {len(strings)} names")

        names = dict(zip(fields, strings))
        used = set(re.findall(rf"\b{table['name']}\.(\w+)", source))

        for field in sorted(used - {"self"}):
            settings.add((names["self"], names[field]))

    return settings


def example_settings(example: str) -> set[tuple[str, str]]:
    """The (section, setting) pairs the example has. Settings for one friend
    or group (pk_...) belong to their top-level section."""
    settings = set()
    sections: list[str] = []

    for line in example.splitlines():
        if line.lstrip().startswith("//") and not SETTING.match(line):
            continue

        if match := OPEN.match(line):
            sections.append(match[1])
        elif CLOSE.match(line):
            sections.pop()
        elif (match := SETTING.match(line)) and sections:
            settings.add((sections[0], match[1]))

    return settings


def main() -> None:
    read = read_settings((ROOT / "src" / "settings.c").read_text())
    documented = example_settings((ROOT / "misc" / "toxic.conf.example").read_text())

    problems = [f"toxic reads {section}.{name}, but the example doesn't have it"
                for section, name in sorted(read - documented)]
    problems += [f"the example has {section}.{name}, but toxic doesn't read it"
                 for section, name in sorted(documented - read)]

    for problem in problems:
        print(problem)

    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
