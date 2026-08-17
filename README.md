# ClaPropGrid — Direct2D Property Grid for Clarion

A fast, modern property grid for Clarion 12 applications, rendered with
Direct2D/DirectWrite by a native C DLL, and integrated into the Clarion
AppGen through two templates:

1. **Property Grid control template** — drop a property grid on any window and
   feed it fields (table columns or any variables) picked in the template UI.
2. **Form-to-PropertyGrid extension template** — point it at an existing form
   procedure: at runtime it discovers every input control on the window,
   hides the originals, rebuilds them as rows of a property grid, and syncs
   values back on OK (or live). The form's own OK/Cancel logic keeps working —
   grid button rows simply POST `EVENT:Accepted` to the original buttons.

![screenshot](docs/screenshot.png)

## Features

- Direct2D + DirectWrite rendering — fast, crisp, per-monitor DPI aware.
- Editor types: text, password, drop-down list, checkbox, radio group,
  slider, spin (numeric up/down), push button, color picker, date, time,
  multiline text popup, read-only.
- Collapsible categories, draggable name/value splitter, mouse-wheel +
  keyboard navigation (arrows, PgUp/PgDn, Enter/F2, Space), hover highlight.
- Independent font face/size/bold/italic for the **name column**, **value
  column**, **category headers**, and **description pane** (`PG_SetFont`).
- Every color is configurable (`PG_SetColor`); professional steel-blue
  default palette.
- Optional description pane, border, sorted rows, toolbox look.
- Resizable at runtime (`PG_SetPos` / `PropGridClass.Reposition` tracks a
  placeholder REGION).
- Events delivered through a poll queue (`PG_PollEvent`, pumped from a
  Clarion TIMER) and/or an immediate C callback.

## Repository layout

| Path | Contents |
|------|----------|
| `src/` | `propgrid.cpp/.h/.def` — the Direct2D engine; `testhost.c` — standalone visual test; `build.bat` |
| `bin/` | `propgrid.dll` (32-bit), `testhost.exe`, MSVC import lib |
| `clarion/` | `PropGrid.inc/.clw` — wrapper class; `ClaPropGrid.tpl` — the two templates; `INSTALL.md` |

The engine is C-style code compiled as C++ purely because the D2D/DWrite COM
headers are far cleaner that way; the exported surface is a flat C API,
`__stdcall`, undecorated names, ANSI strings — exactly what Clarion's
`PASCAL, RAW, NAME()` prototypes expect.

## Building the DLL

Run `src\build.bat` (needs Visual Studio 2022). It produces a **32-bit**
`bin\propgrid.dll` (Clarion apps are 32-bit) plus `testhost.exe`, a plain
Win32 program that exercises every editor type — run it to see the grid
without involving Clarion at all.

## Using from Clarion

See `clarion/INSTALL.md` for template registration, LibMaker import-library
generation, and deployment. In short:

```clarion
PG  PropGridClass
cat SIGNED
row SIGNED
  CODE
  PG.Init(Window, ?Region1, PGS:Border + PGS:Description)
  PG.SetFont(PGF:Name, 'Segoe UI', 9)
  PG.SetFont(PGF:Value, 'Consolas', 10)
  cat = PG.AddCategory('General')
  row = PG.AddProperty(cat, 'Customer name', PGT:Text, CUS:Name)
  row = PG.AddProperty(cat, 'Active', PGT:Check, CUS:Active)
  ! ... in the ACCEPT loop (any event):
  PG.TakeEvent()
  ! ... on OK:
  PG.SyncBack()
```

Or, for a whole form at once:

```clarion
  PG.InitXY(Window, x, y, w, h, PGS:Border)
  PG.BuildFromWindow(0, ?OK & '|' & ?Cancel)   ! converts + hides controls
```

## License / status

Internal tool. Engine, wrapper and templates generated 2026-08-16.
