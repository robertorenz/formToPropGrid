# ClaPropGrid — installation and use (Clarion 12, 32-bit)

A Direct2D property grid for Clarion. `PROPGRID.DLL` renders the grid, `PropGridClass`
wraps it, and the `ClaPropGrid` template set wires it into an ABC application.

## What is in this folder

| File | Role | Goes to |
|---|---|---|
| `PropGrid.inc` | class declaration + `PGT:` / `PGE:` / `PGS:` / `PGF:` / `PGC:` / `PGD:` equates | a redirection-path folder |
| `PropGrid.clw` | class implementation + the `MAP` for `PROPGRID.DLL` | the same folder |
| `ClaPropGrid.tpl` | template chain root (3 templates) | `C:\clarion12\accessory\template\win` |
| `ClaPropGrid.tpw` | shared `#GROUP`s the `.tpl` includes | same folder as the `.tpl` |
| `..\src\propgrid.h` | the DLL's flat C API — reference only, nothing to install | — |

Everything must be saved **ANSI** (no UTF-8 BOM) with **CRLF** line endings. A BOM breaks
both the Clarion compiler and the template parser.

> **Hand-coded projects need no pragma defines.** `PropGrid.inc` defaults
> `_PropGridLinkMode_=>1` / `_PropGridDllMode_=>0` when `_PropGridModesSet_` is absent, so a
> plain `.cwproj` just compiles `PropGrid.clw` and links `propgrid.lib`. Template-generated
> apps set all three through the `PROPGRID` ABC class category (the global extension emits
> `_PropGridModesSet_` via `#PDEFINE`), which also enables the multi-DLL overrides. Do not
> define the two mode pragmas *without* the guard — it works but produces "Label duplicated"
> warnings, and in a multi-DLL consumer the include's defaults would win and re-link the
> class. Without any of this, an undefined `DLL()` attribute on the class makes every
> virtual method call crash with an access violation at a garbage address.

---

## 1. The import library `propgrid.lib` — nothing to do

**`propgrid.lib` ships pre-built in this folder — no LibMaker step, ever.**
`src\build.bat` generates it directly from `propgrid.def`
(`src\make-clarion-lib.ps1`): 29 OMF import records, by ordinal, in the same
byte layout as Clarion's own `ClaTPS.lib`. Because it contains import records
only — no compiled code — **the one file works unchanged in Clarion 9, 9.1,
10, 11, 11.1 and 12**, and only ever changes if the DLL API itself grows.
(The export ordinals are pinned as a contract in `propgrid.def`; they are
never renumbered.)

Put `propgrid.lib` where the linker will find it — the simplest choice is the
application folder; the tidiest is `C:\clarion12\accessory\lib`.

The exports are **`__stdcall` with undecorated names** (`PG_Create`, not `PG_Create@24`),
which is why the Clarion prototypes use `PASCAL` **plus** `NAME('PG_Create')` — while the
lib itself binds by the pinned ordinals, so a rebuild of the DLL never breaks old apps.
This linkage was verified end-to-end: a hand-coded Clarion 12 program linked against the
generated lib, created a grid on a live `WINDOW`, and round-tripped values through the DLL.

## 2. Ship `propgrid.dll` beside the EXE

`PG_Create` is called at window-open time, so the DLL must be next to the executable (or
anywhere on the DLL search path) at run time. Nothing else is redistributable.

## 3. Put the class where redirection can find it

Copy **`PropGrid.inc`** and **`PropGrid.clw`** to one of:

* the application folder (simplest, and it wins redirection), or
* `C:\clarion12\accessory\libsrc\win` (shared across all your apps).

`CLARION120.RED` searches `.` first, then `%ROOT%\libsrc\win`, then
`%ROOT%\Accessory\libsrc\win`. **Do not leave a second, older copy in an earlier folder** —
the IDE's class registry reads *every* copy it finds while the compiler builds only the one
that won redirection, and a stale duplicate produces half-unresolved exports in a data DLL.

You do not add `PropGrid.clw` to the project by hand: the `LINK('PropGrid.clw',...)`
attribute on the class does it.

## 4. Register the templates

Third-party templates belong in `C:\clarion12\accessory\template\win`. The one hard rule
is that **`ClaPropGrid.tpw` must sit in the same folder as `ClaPropGrid.tpl`** — the
template parser resolves `#INCLUDE('ClaPropGrid.tpw')` next to the `.tpl` being registered,
and a missing neighbour fails with *"Could not open include file ClaPropGrid.tpw"*.

```
copy ClaPropGrid.tpl  C:\clarion12\accessory\template\win\
copy ClaPropGrid.tpw  C:\clarion12\accessory\template\win\
"C:\clarion12\bin\ClarionCL.exe" -tr "C:\clarion12\accessory\template\win\ClaPropGrid.tpl"
```

(Registering from this location is verified working on Clarion 12.)

Silence means success. Confirm with `ClarionCL -tl` (look for `ClaPropGrid`).

> **The registry stores a parsed copy of the template.** Editing the `.tpl`/`.tpw` afterwards
> changes nothing until you copy them over again and re-run `-tr`. And **an already-open IDE
> never reloads the registry** — close and reopen Clarion after re-registering, or you will
> keep seeing the old prompts.

To remove it: `ClarionCL -tu ClaPropGrid` (by **chain name**, not by path). Never delete a
registered `.tpl` without unregistering first — that breaks *all* later registrations.

---

## 5. Using the templates

### 5a. `PropGridGlobal` — application extension, add once per app

Application → Extensions → Insert → **ClaPropGrid → PropGridGlobal**.

It does three things:

* `INCLUDE('PropGrid.inc'),ONCE` in the program module (global scope, visible to every
  `MEMBER` module);
* registers the ABC class category `PROPGRID`, which makes the chain emit
  `#pragma define(_PropGridLinkMode_=>1)` and `#pragma define(_PropGridDllMode_=>0)`;
* `#pragma link("propgrid.lib")`.

In a **single-EXE** app the two control templates are self-sufficient without it (they emit
the include and the `.lib` themselves, and with the two defines absent `LINK` behaves as 1
and `DLL` as 0 — the class is simply compiled in). In a **multi-DLL suite** the global
extension must be on **every** application in the suite; miss one and it silently compiles a
private copy of the class. The *ABC library files* box (Override defaults → LINK / DLL /
LIB / None) overrides where the class lives, exactly as it does for ABC's own classes.

### 5b. `PropertyGridControl` — a designed grid on a window

Drag it onto a window from the control-template list. It drops a **REGION**; the Direct2D
grid is created over that region and re-tracks it on every resize. It is `MULTI`, so a
window may carry several independent grids.

Prompts: *General* (object name, live sync, timer), *Appearance* (style bits, three fonts,
row height, splitter), *Colours* (eleven slots), *Fields* (a repeating **Properties…** list).

Each field entry takes a **variable or dictionary column** (the `FIELD` prompt has the
dictionary lookup button but accepts any Clarion variable that is in scope — `LOC:Whatever`,
a global, a queue field), a display name, a **category** (entries sharing a category name are
merged under one header), an editor type, choices, a range, a picture, read-only and a
description.

Generated code (per instance `n`, object name `Obj`):

```
Obj                  PropGridClass
PGResize:Obj         EQUATE(EVENT:User + 300 + n)
PGCat:n:1            LONG            ! one per DISTINCT category
PGRow:n:1            LONG            ! one per field entry
```
* `ThisWindow.Init`, **PRIORITY 8600** — after ABC opens the window (8000), restores its INI
  size (8250) and runs the field templates (8500), so the REGION is at its final size:
  `Obj.Init(window, ?region, style)`, the fonts/colours/metrics, `AddCategory` per category,
  `AddProperty` (+ `SetChoices` / `SetRange` / `SetDescription` / `SetReadOnly`) per row, then
  `DO PGLoad:Obj`.
* `ThisWindow.TakeWindowEvent`, **PRIORITY 2000** — a self-contained `CASE EVENT()`:
  `EVENT:Timer` pumps `Obj.TakeEvent()` (and `DO PGSave:Obj` when Live sync is on);
  `EVENT:Sized` **posts** `PGResize:Obj`, and the posted event calls `Obj.Reposition()`
  (at the top of `TakeWindowEvent` the ABC resizer has not moved the REGION yet, so its
  `PROP:Width` is still the old size).
* `ThisWindow.Kill`, PRIORITY 7500 — `Obj.Kill()`.
* `%ProcedureRoutines` — `PGLoad:Obj` (variables → grid) and `PGSave:Obj` (grid → variables).

Embed points: *after the grid is built*, *before/after load*, *before/after save*,
*the grid raised an event*.

With **Live sync off**, nothing writes the grid back automatically — `DO PGSave:Obj` from
your OK button.

### 5c. `FormToPropertyGrid` — turn an existing form into a grid

Procedure → Extensions → Insert → **ClaPropGrid → FormToPropertyGrid**. No field list to
maintain: `PropGridClass.BuildFromWindow` walks `FIRSTFIELD()`…`LASTFIELD()` at run time,
converts every supported control into a row, takes the label from the PROMPT (or STRING)
in front of it, tags the row with the control's field equate and hides the original.

Placement: *Fill client area* / *Dock left* / *Dock right* / *Over a region control*. The
dock and fill modes generate a visible `PGPlace:Obj` ROUTINE that reads the window's client
size in **pixels** (`0{PROP:Pixels} = TRUE`, `0{PROP:Width}` / `{PROP:Height}`) and calls
`InitXY` the first time, `SetPos` afterwards. Edit that routine, or `DO PGPlace:Obj` yourself,
whenever you move things around.

Buttons: either keep the window's OK/Cancel visible, or add **OK/Cancel rows to the grid** and
hide the buttons. A grid button row is tagged with the real button's FEQ and
`PropGridClass.TakeButton` `POST`s `EVENT:Accepted` to it, so the form's own logic runs
unchanged.

On the OK button's `EVENT:Accepted` (embedded early, PRIORITY 2000, ahead of the generated
form logic at 4999) the template emits `Obj.SyncBack()` unless Live sync is on.

Control types it converts: `ENTRY`, `SPIN`, `SLIDER`, `CHECK`, `OPTION` (+RADIO children),
drop-down `LIST`/`COMBO`, `TEXT`, `BUTTON`, `STRING`/`PROMPT` (read-only rows when added
explicitly). It deliberately skips a **plain browse LIST** (no `DROP` attribute), plus
SHEET/TAB/GROUP/PANEL/IMAGE/LINE/BOX/ELLIPSE/REGION/MENU/ITEM/TOOLBAR/PROGRESS/OLE/CUSTOM.

---

## 6. Verified runtime notes (why the class does what it does)

Every item below was measured on Clarion 12 by probing a live window, and several of them
contradict the obvious reading of the docs. Change the class at your peril.

| Fact | Consequence |
|---|---|
| `?ctl{PROP:Text}` on an ENTRY/SPIN returns the picture **without the leading `@`** (`d17`, `n-9.2`, `s30`) | testing `SUB(pic,1,2) = '@D'` never matches; `ControlPicture()` prepends the `@` |
| `CONTENTS(feq)` returns the **raw** USE-variable value, never the formatted text (`82413`, not `18/08/2026`) | date/time rows are displayed with `FORMAT(CONTENTS(feq), pic)` |
| `DEFORMAT('9876.543', '@n-24.6')` returns **9876543** — an `@N` picture treats the decimal point as formatting | `DEFORMAT` is used for `@D`/`@T` **only**; numbers round-trip as plain text |
| `CHANGE(feq, value)` does a plain string→numeric assignment; a `REAL` argument arrives via a lossy conversion | dates/times are deformatted into a **LONG** first, then passed to `CHANGE` |
| `feq{PROP:Selected} = n` on an OPTION sets the USE variable to that RADIO's `VALUE()`; `CHANGE(option,'text')` corrupts it | OPTION write-back is **ordinal based** |
| `PROP:Checked` is **read only** — writing it does nothing | CHECK write-back is `CHANGE(feq, PROP:TrueValue / PROP:FalseValue)`, defaulting to `1`/`0` |
| `PROP:From` reads back only for a **string** `FROM('a\|b')`; a queue-driven DROP returns blank | a queue DROP is enumerated by walking `PROP:Selected` 1..`PROP:Items` and reading `CONTENTS` |
| `PROP:Use` returns the USE variable's **value**, not its name | labels come from the preceding PROMPT/STRING, or the control's caption, else `'Field <feq>'` |
| A designer "drop list" is a `LIST` with `DROP()`; `PROP:Type` is `CREATE:list` (14), not `CREATE:droplist` | `PROP:Drop` is what distinguishes a drop-down from a browse list |
| Every property read/write above still works after `feq{PROP:Hide} = TRUE` | hiding the originals does not break SyncBack |

Also, in `PropGrid.clw` the DLL prototypes live in `MODULE('ClaPropGridDLL')` and **not**
`MODULE('PROPGRID.DLL')`: Clarion strips the extension, matches the result against the module
being compiled (`PropGrid.clw`), decides the prototypes are defined *here*, and every one of
them fails with `Missing procedure definition: PG_CREATE((LONG,...)`. The `MODULE()` label is
only a grouping name — binding is by `NAME()` plus `propgrid.lib`.

---

## 7. Verifying a change without opening the IDE

```
:: template side
ClarionCL -tr "C:\clarion12\accessory\template\win\ClaPropGrid.tpl"   :: parse check (silent = OK)
ClarionCL -win -au -ax app.app out.txa                       :: export, edit the %prompts
ClarionCL -win -au -ai app.app out.txa                       :: import
ClarionCL -win -au -ag app.app                               :: GENERATE, then read the .clw

:: compile side (32-bit MSBuild)
C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe myapp.cwproj ^
    -p:Configuration=Release -p:ClarionBinPath=C:\clarion12\bin
```

TXA gotcha worth writing down: a repeating `#BUTTON(...),MULTI(%list,%desc)` list is stored as
`%list MULTI DEFAULT ('1','2')` with its children as
`%child DEPEND %list <type> TIMES n` — and the `WHEN` keys must be **unquoted integers**
(`WHEN  (1) ('?OK')`). A quoted key (`WHEN ('1') ...`) corrupts the `.app`, after which
`-ag` reports *"cannot be load. Probably it has an invalid format"*.

## 8. Troubleshooting

| Symptom | Cause |
|---|---|
| `Could not open include file ClaPropGrid.tpw` when registering | the `.tpw` is not in the same folder as the `.tpl` being registered |
| The new prompts do not appear | the IDE was open during `-tr`; restart it |
| `Unresolved External PG_Create` | `propgrid.lib` missing from the project / linker path, or built with decorated names |
| `Missing procedure definition: PG_CREATE(...)` | the `MODULE()` label in `PropGrid.clw` was changed back to `PROPGRID.DLL` |
| `Label duplicated, second used: _PROPGRIDLINKMODE_` | the two mode defines were EQUATEd inside `PropGrid.inc`; they must arrive only as project defines |
| The grid is created but stays blank | the window has no timer — set the template's *Timer interval* above 0, or give the window `TIMER()` |
| Grid edits never reach the variables | Live sync off **and** no OK button resolved; turn Live sync on or call `SyncBack()` / `DO PGSave:<object>` yourself |
| `… is unresolved for export` in a data DLL | a stale `.inc` with a bare `!ABCIncludeFile` on the redirection path — this one carries `!ABCIncludeFile(PROPGRID)` |
