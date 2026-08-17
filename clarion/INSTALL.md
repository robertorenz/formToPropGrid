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

#### Multi-tab windows → categories (the *Tabs* tab)

A window with a SHEET converts per tab:

* **Tab names become extra categories** (default on): every converted control lands under a
  category named after its TAB's text (ampersands stripped) instead of one flat default
  category. The category is created lazily, when its first row arrives — a tab that
  contributes nothing never shows an empty header. Controls outside any TAB (OK/Cancel…)
  stay in the default category.
* **The Tabs list** holds one entry per TAB you want to control: *Convert into the grid*
  (optionally under a renamed category) or **Leave alone** — the whole tab is skipped,
  nothing inside it is converted or hidden, and it keeps working exactly as before. That is
  the right choice for a tab holding a **browse LIST and its Insert/Change/Delete buttons**:
  a browse is not a name/value pair, so it stays a real tab next to the grid. A tab that is
  not listed at all is converted.
* **Scan this window for tabs** prefills the list — a tab containing a plain (non-drop)
  LIST is assumed to be a browse and prefilled as *Leave alone*; everything else as
  *Convert*. Re-scanning never duplicates entries.
* **Hide tabs the conversion empties** (default on): after the build (and after the lookup
  trios are folded — a tab that is nothing but lookups only empties then) every TAB with
  nothing visible left inside is hidden, and a SHEET whose last visible tab went is hidden
  with it. A control spared via *Controls to leave alone* keeps its tab (and the sheet)
  visible.

Under the hood, all of it is plain class API — available to hand-coded windows too:
`Obj.TabCategories = 1`, `Obj.SetTabCategory(?Tab,'Name')` (before `BuildFromWindow`),
excluding a **container** FEQ (SHEET/TAB/GROUP/OPTION) in `BuildFromWindow`'s exclude list
skips its whole subtree, `Obj.TabCategoryOf(?AnyControl)` returns/creates the category of
the tab holding a control, and `Obj.TrimTabs()` does the hiding — call it **after** the
last `AddFileDrop`.

#### Lookup trios → one drop-down row (the *Lookups* tab)

The classic Clarion lookup is three controls — `ENTRY(@s3),USE(CUS:DeptCode)`, a `'...'`
**BUTTON** that opens a select browse, and a **STRING** showing the description. List that
trio on the **Lookups** tab and the three collapse into a **single `PGT:Drop` row that shows
the description** and writes the **code** back:

| Prompt | Meaning |
|---|---|
| *Code control* (REQ) | the ENTRY holding the code — hidden, tagged on the row, target of every write-back |
| *Lookup button* | the `'...'` — excluded from the conversion and `HIDE`d (it would otherwise become a button row) |
| *Description control* | the STRING showing the description — hidden, kept in step with the row |
| *File* / *Order by key* / *Code field* / *Description field* | the lookup table and its two columns |
| *Label* / *Category* / *Description* | blank label = the PROMPT in front of the code control; blank category = the default one |

**You do not have to fill that list in by hand.** The *Find them for me* box has a
**Scan this window for lookups** button that reads what ABC already knows about the window:

Every ENTRY/SPIN is a candidate; what follows it decides whether it is a lookup.

| What it needs | Where it comes from | Certainty |
|---|---|---|
| the lookup FILE, way 1 | the ENTRY's *Lookup Key* — ABC's own pre-edit / post-edit prompts (`ABWINDOW.TPW:2058-2067`, children of `%Control`). `#FIND(%Key,<that key>)` fixes `%File` too (the trick `ABWINDOW.TPW:2096` uses) and the key's component field **is** the code field | exact |
| the lookup FILE, way 2 | **the description STRING's own field.** `STRING(@S15),USE(MAJ:Description)` names the table (`Majors`) *and* the description field, with no template settings at all — this is what finds a **hand-wired** lookup (`ALRT(F10Key)`, `DROPID`, a browse call in an embed) | exact |
| the lookup FILE, way 3 | `DROPID('Majors')` on the ENTRY, when it matches a table in the dictionary | exact |
| the code field (ways 2/3) | the side of a MANY:1 **relation** that is not the ENTRY's own field, validated against the lookup table; otherwise the table's **primary key, first component** | good guess |
| the `'...'` BUTTON | a `FieldLookupButton` pointing at this ENTRY (`%ControlToLookup`, `ABCONTRL.TPW:241`), a name containing `LOOKUP`, or **a caption of exactly `'...'`** (read with `EXTRACT(%ControlStatement,'BUTTON',1)`, quotes stripped as in `ABBROWSE.TPW:2759`) | proven, or left blank |
| the description STRING | the first STRING/PROMPT after the ENTRY that has a **USE variable** (not a caption) | guess |
| the description field | that variable when it is a field of the lookup file, else the file's first STRING/CSTRING/PSTRING field that is not the code field | guess |

A candidate that resolves to **no table** is dropped — a plain data entry silently, one that
looks like a trio (button *and* description present) counted as *could not identify*, which is
what you see when the description STRING shows a local variable instead of a table field.

The trio ends at the next data control (ENTRY/SPIN/LIST/COMBO/CHECK/OPTION/TEXT/SHEET/TAB),
so a lookup never swallows the control after it. Results are **appended**; an entry whose code
control is already listed is skipped, so re-scanning after you change the window is safe. The
*Last scan* line reports `added N, already listed N, could not identify N`.

> **A button is only paired when it proves it is the lookup**, because the generated code
> `HIDE`s it — pairing "the next button on the window" would hide something like `?Btn_Save`.
> When nothing qualifies the entry is still converted, the *Lookup button* prompt stays blank,
> and your browse button stays visible and keeps working.

Generated per entry (instance `n`, entry `i`), right after `BuildFromWindow`:

```
PGFLCode:n:i = ''                                   ! pipe list of codes
PGFLName:n:i = ''                                   ! pipe list of descriptions
Relate:Dept.Open()                                  ! reference counted - safe
PGFLBuf:n = Access:Dept.SaveBuffer()                ! the scan is side effect free
SET(Dept)                                           ! or SET(<key>) when you pick one
LOOP
  IF Access:Dept.Next() THEN BREAK.
  IF PGFLCnt:n >= Obj.MaxScanItems THEN BREAK.      ! 500 by default
  ...
  PGFLCode:n:i = CLIP(PGFLCode:n:i) & '|' & Obj.PipeSafe(DEP:Code)
  PGFLName:n:i = CLIP(PGFLName:n:i) & '|' & Obj.PipeSafe(DEP:Name)
END
Access:Dept.RestoreBuffer(PGFLBuf:n)
Relate:Dept.Close()
PGFLRow:n:i = Obj.AddFileDrop(PGFCat:n,'',?DeptCode,?DeptName,CLIP(PGFLCode:n:i),CLIP(PGFLName:n:i),'')
HIDE(?LookDept)
```

* `PipeSafe()` CLIPs/LEFTs the value and turns a `'|'` **inside the data** into `'/'`, so a
  description can never split the list.
* The lookup file is added to the procedure with `#ADD(%ProcFilesUsed,...)` at
  `%GatherSymbols`, exactly like ABC's own *Must be in file* validation
  (`ABUPDATE.TPW:112`), so ABC opens it at Init PRIORITY 7500 and closes it in Kill. The
  explicit `Relate:x.Open()/Close()` pair around the scan is safe on top of that —
  `FileManager.Opened` is a **counter** (`ABFILE.CLW:899`).
* `SaveBuffer()`/`RestoreBuffer()` mean the scan cannot disturb a record the form already
  loaded — important when the description control's USE variable *is* a field of the lookup
  file.
* Matching code → description is case-insensitive, blank-tolerant and, when both sides are
  numeric, **value**-tolerant (`1` finds `001`, `30` finds `30` from an `@n4` ENTRY). An
  unmatched code is shown raw and never overwritten.
* The row is read back by `SyncRow` (description → ordinal → code → `CHANGE(?code)` plus the
  description control) and refreshed by `SyncFrom` (code → description).
* **Lookup rows are appended after the automatically converted rows**, because
  `BuildFromWindow` runs first. Give them their own *Category* if you want them grouped.
* This reads the whole table once, at window-open time — it suits code tables, not files with
  thousands of records. Leave the browse button alone for those.

#### Added rows for things that are not on the window (the *Added rows* tab)

`BuildFromWindow` can only convert controls that exist. The **Added properties…** list adds
rows for a variable or dictionary column that has **no control** on this window (or that the
scan cannot convert) — the same list the `PropertyGridControl` template offers:

| Prompt | Default |
|---|---|
| *Variable / field* (REQ) | — (dictionary lookup button, or any variable in scope) |
| *Display name* | derived from the variable: leading `?` and prefix stripped (`Loc:ReceiverPhone` → `ReceiverPhone`) |
| *Category* | blank = the extension's default category |
| *Editor* | `Text` (Text\|Password\|Drop list\|Checkbox\|Radio\|Slider\|Spin\|Button\|Color\|Date\|Time\|Multiline\|Read only) |
| *Choices* (Drop/Radio), *Range low/high/step* (Slider/Spin), *Picture* (Date/Time) | `@d17` / `@t4` when blank |
| *Read only*, *Description* | 0 / blank |

These rows are bound to a **variable**, not to a control, so they carry no field equate and
`SyncBack()` / `SyncFrom()` step over them (`GetTag` = 0). They are moved by two generated
ROUTINEs instead, exactly like the control template's `PGLoad:` / `PGSave:`:

```
PGFLoad:Obj ROUTINE                    ! variables -> the added rows
  Obj.SetValue(PGFRow:n:1,CLIP(LEFT(Loc:ReceiverPhone)))
  Obj.SetValue(PGFRow:n:2,FORMAT(Loc:SentOn,@d17))       ! Date / Time are FORMATted
  Obj.SetValue(PGFRow:n:3,CHOOSE(Loc:Active = 1,'1','0'))
  Obj.Redraw()
PGFSave:Obj ROUTINE                    ! the added rows -> variables
  Loc:ReceiverPhone = CLIP(Obj.GetValue(PGFRow:n:1))
  Loc:SentOn = DEFORMAT(CLIP(Obj.GetValue(PGFRow:n:2)),@d17)   ! DEFORMAT for @D/@T ONLY
  Loc:Active = CHOOSE(CLIP(Obj.GetValue(PGFRow:n:3)) = '1',1,0)
```

* `PGFLoad:` runs once, right after the rows are added; `DO PGFLoad:Obj` yourself whenever
  those variables change behind the grid's back.
* `PGFSave:` is called **on the OK button, before `SyncBack()`**, and — with *Live sync* on —
  from the `EVENT:Timer` branch whenever `TakeEvent()` handled something.
* Numbers go back as **raw text**; `DEFORMAT` is used for `@D`/`@T` only, because an `@N`
  picture eats the decimal point (see §6).
* *Read only* rows, and the `Read only` / `Button` editors, are loaded but never saved.
* Embeds: *before/after loading the added rows*, *before/after saving the added rows*.

**Categories merge by name across all four row sources** — the converted controls, the lookup
drop-downs, the added rows and the OK/Cancel actions. A name equal to the default category
reuses `PGFCat:n`, one equal to the actions category reuses `PGFAct:n` (created early when a
lookup or added row asks for it by name), anything else gets one `PGFLCat:n:k` per distinct
name. Three names, three `AddCategory` calls, no duplicate headers.

> With *Live sync* off **and** no OK button resolved, nothing calls `PGFSave:` — the same
> caveat that already applies to `SyncBack()`.

#### The browse button that is still there

Any button row (including a `'...'` you did **not** convert) POSTs `EVENT:Accepted` to the
real control. After it returns — the lookup browse has written a new code into the USE
variable — `PropGridClass` refreshes the grid by itself: `TakeButton` arms
`PendingSyncFrom = 2` and the second `TakeEvent` after that calls `SyncFrom()`. So a
conventional lookup keeps working *and* the grid stops showing the old code.

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
| `PROP:Use` on a control whose USE is only a field equate (`STRING('Caption'),USE(?SCap)`) reads back **blank** — indistinguishable from an empty USE variable | "has this control a USE variable?" is answered by *writing*: `SetNameControl()` does `CHANGE()` then compares `CONTENTS()`, and only falls back to `PROP:Text` when they disagree |
| `CHANGE(?captionString,'x')` sets **no** error and changes nothing; `PROP:Text` is the only way in | see above |
| A `POST(EVENT:Accepted, feq)` issued from inside `TakeEvent` is processed **before** the next `EVENT:Timer` (measured: handler at tick 0, next timer tick 1) | `PendingSyncFrom` still counts **2** ticks, because an `EVENT:Timer` may already be queued behind the POST |
| `FileManager.Opened` is a counter (`ABFILE.CLW:899`) | the generated `Relate:x.Open()/Close()` pair around a lookup scan cannot close a file ABC still needs |
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
`%list MULTI LONG  (1, 2)` — the **list of row keys** — with its children as
`%child DEPEND %list <type> TIMES n` followed by one `WHEN  (<key>) ('value')` line per row.
The `WHEN` keys must be **unquoted integers**; a quoted key (`WHEN ('1') ...`) corrupts the
`.app`, after which `-ag` reports *"cannot be load. Probably it has an invalid format"*.

Two more measured `-ai` rules, learned the hard way while testing the repeating lists:

* the number of keys in `(1, 2)` decides how many rows survive — `WHEN` entries whose key is
  not in that list are silently discarded (a list written as `(2)` with `TIMES 2` keeps only
  row 2);
* **do not paste a new `%list MULTI …` block anywhere you like.** With the template
  registered, `-ax` already writes an *empty* declaration for every repeating prompt
  (`%F2PAdded MULTI LONG  ()` plus `%child DEPEND %F2PAdded <type> TIMES 0`), and it puts them
  at the END of that addition's prompt list. A hand-inserted copy earlier in the file is
  overwritten by the empty one that follows, and the rows vanish without a message. **Edit the
  emitted declarations in place**, keeping the type keyword `-ax` chose (`FILE`, `KEY`,
  `FIELD` and `LONG` values are written **unquoted**, `DEFAULT` values quoted). Done that way
  the import works with the new template registered:

```
ClarionCL -tr <new path>\ClaPropGrid.tpl        :: register the NEW chain first
ClarionCL -win -au -ax app.app a.txa            :: export - it writes the empty MULTI blocks
::  ... replace those blocks in place with populated ones ...
ClarionCL -win -au -ai app.app a.txa            :: import
ClarionCL -win -au -ag app.app                  :: generate, then read the .clw
```

Template-language traps around `#FOR(%SomeMultiList)`, all measured in this chain:

| Call in a generated line, inside `#FOR` over a MULTI list | Result |
|---|---|
| `%(%PGEditorEquate(%F2PAddEditor))` — **one** argument | works (`PGT:Date` emitted) |
| `%(%PGLabelFor(%F2PAddName,%F2PAddVar))` — **two** arguments | expands to **nothing** |
| `%(%PGAddedLabel())` — no arguments, but the group reads *this* template's MULTI children | expands to **nothing** |
| `%(%PGDefaultLabel())` — no arguments, group reads the *control* template's symbols | works there, and **silently kills the whole `#AT` block** when called from the extension |

So: compute values with `#SET` into symbols declared in `#ATSTART` and emit `%MySymbol`. That
is what the Lookups code does for the category variable and the description control, and what
the Added-rows code does for the row label. **If generated code disappears entirely, suspect a
`#GROUP` call** — AppGen reports nothing.

## 8. Troubleshooting

| Symptom | Cause |
|---|---|
| `Could not open include file ClaPropGrid.tpw` when registering | the `.tpw` is not in the same folder as the `.tpl` being registered |
| The new prompts do not appear | the IDE was open during `-tr`; restart it |
| A prompt-time action (e.g. *Scan this window for lookups*) behaves like the **previous** build — right prompts, old behaviour | same cause, and the one that bites hardest: the registry holds a *parsed* copy of the chain, and an IDE that was already open keeps serving it. Close the IDE, re-run `-tr`, reopen. Deploying the new `.tpl` alone changes nothing |
| `Unresolved External PG_Create` | `propgrid.lib` missing from the project / linker path, or built with decorated names |
| `Missing procedure definition: PG_CREATE(...)` | the `MODULE()` label in `PropGrid.clw` was changed back to `PROPGRID.DLL` |
| `Label duplicated, second used: _PROPGRIDLINKMODE_` | the two mode defines were EQUATEd inside `PropGrid.inc`; they must arrive only as project defines |
| The grid is created but stays blank | the window has no timer — set the template's *Timer interval* above 0, or give the window `TIMER()` |
| Grid edits never reach the variables | Live sync off **and** no OK button resolved; turn Live sync on or call `SyncBack()` / `DO PGSave:<object>` yourself |
| `… is unresolved for export` in a data DLL | a stale `.inc` with a bare `!ABCIncludeFile` on the redirection path — this one carries `!ABCIncludeFile(PROPGRID)` |
| A lookup drop-down row shows the raw code instead of a description | the code is not in the scanned list — the table has more rows than `MaxScanItems`, the code field on the form and in the file differ in type/padding, or the record was added after the window opened |
| A lookup row's drop-down is empty | the lookup file was empty, or `Relate:<file>` could not open — check the file is in the app (the template adds it to the procedure automatically, but the *table* must exist in the dictionary) |
| The grid still shows the old code after a `'...'` browse | the window has no timer: `PendingSyncFrom` is counted down inside `TakeEvent`, which only runs on `EVENT:Timer` |
| An added row shows the right value but never writes it back | *Live sync* off and no OK button resolved — nothing calls `PGFSave:`; or the row is marked *Read only* / uses the `Read only` or `Button` editor |
| An added row shows a number as `1234.56000000` or a date as `82907` | the editor type is `Text` — pick `Date` / `Time` (and a picture) so the row is FORMATted |
| *Scan this window for lookups* reports `could not identify N` | the trio is there but nothing names the table: the description STRING shows a **local variable** rather than a field of the lookup table, and the ENTRY has neither a *Lookup Key* nor a `DROPID`. Point the *Description control* at the table's field, or add that entry by hand |
| *Scan this window for lookups* finds nothing at all | no ENTRY on the window is followed by anything that identifies a table — check you are on the right procedure, and that the description STRING really is `USE(PRE:Field)` |
| The scan found the trio but left *Lookup button* blank | no button proved itself (no `FieldLookupButton` extension, no `LOOKUP` in the name) — pick it in the entry, or leave it: the button simply stays visible |
| The scan filled in the wrong *Description field* | that one is a guess — correct it in the entry; a re-scan will not overwrite it |
