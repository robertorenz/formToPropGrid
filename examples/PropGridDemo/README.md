# PropGridDemo — the whole class, hand coded

A plain Clarion program that drives `PropGridClass` directly. No AppGen, no ABC,
no templates: every call in `PropGridDemo.clw` is one you can copy straight into
your own procedure. The `ClaPropGrid` templates emit exactly these calls.

## Build and run

```
build.bat
PropGridDemo.exe
```

`build.bat` stages `PropGrid.inc`, `PropGrid.clw` and `propgrid.lib` from
`..\..\clarion`, builds with MSBuild, and *then* copies `..\..\bin\propgrid.dll`
in — after the link on purpose, because the Clarion build copies any DLL it
finds on the redirection path into the output folder and would otherwise drop a
stale `propgrid.dll` on top of the one you just built.

Set `CLARIONBIN` first if Clarion is not at `C:\clarion12\bin`:

```
set CLARIONBIN=C:\clarion11\bin && build.bat
```

`PropGridDemo.exe 1`, `2`, `3` or `4` opens one window straight away and quits when
it closes — handy for a quick look at one feature.

## What each window shows

### 1 — Everything the class does

| Shown | Calls |
|---|---|
| All 13 editor types | `AddProperty` with each `PGT:` equate, `SetChoices`, `SetRange` |
| Categories, colours, the four global fonts | `AddCategory`, `SetColor`, `SetFont`, `SetSplitter` |
| Descriptions in the bottom pane | `SetDescription` |
| **A whole category in a mono value font** | `AddFont` + `SetCategoryFont` |
| **A bigger header on one category** | `SetCategoryFontFace` |
| **One row in 14pt Georgia bold italic** | `SetRowFontFace` — and the row grows to fit |
| **A value wrapped over as many lines as it needs** | `SetRowWrap(row, -1)` |
| **A note capped at two lines** | `SetRowWrap(row, 2)` |
| Reading the fonts back | `GetRowFont`, `GetFontInfo`, `FontCount`, `RowHeight` |
| A grid row that drives a real button | `SetTag` + the window's own `?ApplyBtn` handler |
| Reacting to selection and edits | a derived class overriding `TakeSelect` / `TakeChanged` |

### 2 — The same form, converted

A normal data-entry form (entries, a spin, a check, a drop list, a lookup trio,
OK/Cancel) turned into a grid at run time.

- `BuildFromWindow(cat, excludeList)` converts and hides everything in one call.
- The classic lookup trio — code `ENTRY` + `'...'` **BUTTON** + description
  `STRING` — is folded into **one drop row** by `AddFileDrop`: it shows the
  description and writes the code back.
- OK and Cancel become `PGT:Button` rows tagged with the real buttons, so the
  form's own handlers run unchanged. `SyncBack()` on OK writes the grid into the
  USE variables, and the window prints what it wrote.

### 3 — Tabs, categories and TrimTabs

- `TabCategories = 1` makes each TAB's text its own category.
- `SetTabCategory(?TabAddr, 'Postal address')` renames one of them — it only
  *records* the override, so it must run **before** `BuildFromWindow`.
- The History tab is excluded by its **TAB field equate alone**: excluding a
  container excludes its whole subtree, so the browse LIST and its buttons stay
  live and working next to the grid.
- `TrimTabs()` runs **last** and hides the two tabs the conversion emptied.

### 4 — A settings dialog: PDF export

What a property grid is actually best at — a long, grouped settings list where
some settings govern others. Thirty-odd options across **Output, Compression,
Fonts, Document, Security and Viewer**, using every editor type because a real
options dialog needs them.

The point of the window is the **rules**, applied by a derived class in
`ApplyRules`, called from `TakeChanged` on every edit:

| Change this | And this happens |
|---|---|
| Page size → `Custom` | *Custom width* and *height* stop being read-only |
| *Compress images* off | image compression, quality and both downsample rows grey out |
| Image compression → `Flate (lossless)` | *Image quality* greys out — there is nothing to trade |
| *PDF/A-1b compliant* on | *Embed fonts* is forced on and locked, *Encrypt* forced off and locked |
| *Encrypt* off | the two passwords and all three permissions grey out |
| anything | the wrapped **Summary** row rewrites itself to describe the current settings in a sentence |

`SetValue` never raises an event, so forcing a value from inside `TakeChanged`
cannot loop back. That is what makes this pattern safe.

Also shown here: `SetExpanded` (Viewer starts collapsed), a per-category mono
font on the Compression numbers, `FindRow` used instead of keeping every row id,
and a wrapped read-only row that grows as its text changes.

## Files

| File | What it is |
|---|---|
| `PropGridDemo.clw` | The whole demo — one PROGRAM, four procedures, two derived classes |
| `PropGridDemo.cwproj` | Minimal Clarion project; the class is pulled in by its own `LINK()` attribute |
| `build.bat` | Stages the class + lib, builds, then stages the DLL |

Everything `build.bat` copies in (`PropGrid.*`, `propgrid.lib`, `propgrid.dll`)
is generated, not source — delete them freely.
