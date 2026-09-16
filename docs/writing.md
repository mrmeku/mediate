# Writing

*How does a document earn its place, and how is it written? For anyone who changes a document, a moduledoc, a doc, or a comment.*

## Before you write

Name the question the document answers and the reader who asks it. Put both in one italic sentence on the document's third line. If an existing document answers the question, edit that document and write no new one.

## Where a fact lives

A document points at a fact's source of truth and copies nothing from it.

| Kind of fact | Source of truth | What a document does |
|---|---|---|
| An API, an option, a callback | the `@moduledoc`, the `@doc`, the `NimbleOptions` docs | names the module and links to it |
| A version pin | `flake.nix`, `mix.exs`, `mix.lock` | names the file and copies no number |
| A command the build runs | the mix alias in `mix.exs` | names the alias |
| Why a line is the way it is | a comment at the line | says nothing |
| Why the shape is the way it is | `docs/design.md`, with the alternative it rejected | cites the heading |
| A rule for a person | `CONTRIBUTING.md` | cites the heading |
| A frozen list | the document a test parses | changes the list and the test in one commit |
| A number a test asserts | the test | names the test |
| A number no test asserts | nowhere | deletes it |

## Delete when

The first rule that matches decides.

- The sentence repeats another document.
- A reader derives the sentence from the code in one glance.
- The sentence describes a state that no longer exists.
- The sentence addresses nobody.
- The sentence is a why with no alternative beside it.

## Sentences

The rules are ASD-STE100's, as this repository holds to them.

- One instruction per sentence.
- Present tense.
- Active voice.
- The same word for the same thing.
- No filler word.
- No exclamation mark and no em dash.
- Define a term on first use, or do not use it.
- A comment says why, never what.

## The gate

Run this over every document you changed. It must print `exit=1`. This file is the one exception, because it lists the words.

```
grep -rniE "\b(simply|just|obviously|easy|easily|of course|basically|note that|in order to)\b|!|—" <files>; echo "exit=$?"
```

## The commit message

A commit that changes a document says these five things, in this order.

1. The question the document answers.
2. The reader who asks it.
3. Each fact the commit moved, and the source of truth it moved to.
4. Each sentence the commit deleted, and the rule above that deleted it.
5. The gate command and its output.
