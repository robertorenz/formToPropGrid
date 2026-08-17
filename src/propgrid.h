/*=====================================================================
  propgrid.h  -  ClaPropGrid: Direct2D property grid for Clarion
  ---------------------------------------------------------------------
  Flat C API, all functions __stdcall (Clarion PASCAL), ANSI strings
  (converted to UTF-16 internally with CP_ACP).  Designed to be called
  from Clarion 32-bit applications via PROPGRID.DLL.
  =====================================================================*/
#ifndef CLAPROPGRID_H
#define CLAPROPGRID_H

#include <windows.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifdef PROPGRID_EXPORTS
#define PGAPI __declspec(dllexport) __stdcall
#else
#define PGAPI __stdcall
#endif

typedef void* HPG;          /* property-grid instance handle */

/* ---- editor types ------------------------------------------------ */
#define PGT_TEXT       1    /* single line type-in                    */
#define PGT_PASSWORD   2    /* masked type-in                         */
#define PGT_DROP       3    /* drop-down list  (PG_SetChoices)        */
#define PGT_CHECK      4    /* checkbox, value "1"/"0"                */
#define PGT_RADIO      5    /* radio group     (PG_SetChoices)        */
#define PGT_SLIDER     6    /* slider          (PG_SetRange)          */
#define PGT_SPIN       7    /* numeric + up/down (PG_SetRange)        */
#define PGT_BUTTON     8    /* push button, fires PGE_BUTTON          */
#define PGT_COLOR      9    /* color swatch + ChooseColor, "RRGGBB"   */
#define PGT_DATE      10    /* date type-in w/ mask  (value as text)  */
#define PGT_READONLY  11    /* static display only                    */
#define PGT_TIME      12    /* time type-in                           */
#define PGT_MULTITEXT 13    /* text with "..." popup multiline editor */

/* ---- event types returned by PG_PollEvent ------------------------ */
#define PGE_CHANGED    1    /* value of row changed by the user       */
#define PGE_BUTTON     2    /* PGT_BUTTON row clicked                 */
#define PGE_SELECT     3    /* row selection changed                  */
#define PGE_DBLCLICK   4    /* row double-clicked                     */

/* ---- style flags for PG_Create ----------------------------------- */
#define PGS_BORDER        0x0001   /* thin border                     */
#define PGS_DESCRIPTION   0x0002   /* description pane at the bottom  */
#define PGS_TOOLBOXLOOK   0x0004   /* flat category headers           */
#define PGS_SORT          0x0008   /* sort rows alphabetically        */

/* ---- font parts for PG_SetFont ----------------------------------- */
#define PGF_NAME       1    /* left (property name) column            */
#define PGF_VALUE      2    /* right (value) column / editors         */
#define PGF_CATEGORY   3    /* category header rows                   */
#define PGF_DESC       4    /* description pane                       */

/* ---- color slots for PG_SetColor --------------------------------- */
#define PGC_BACK        1   /* grid background            (COLORREF)  */
#define PGC_NAMEBACK    2   /* name column background                 */
#define PGC_NAMETEXT    3   /* name column text                       */
#define PGC_VALUETEXT   4   /* value column text                      */
#define PGC_CATBACK     5   /* category header background             */
#define PGC_CATTEXT     6   /* category header text                   */
#define PGC_LINES       7   /* grid lines                             */
#define PGC_SELBACK     8   /* selected row background                */
#define PGC_SELTEXT     9   /* selected row text                      */
#define PGC_DESCBACK   10   /* description pane background            */
#define PGC_DESCTEXT   11   /* description pane text                  */

/* ---- lifetime ---------------------------------------------------- */
int   PGAPI PG_Initialize(void);                  /* once per process */
void  PGAPI PG_Shutdown(void);
HPG   PGAPI PG_Create(HWND hwndParent, int x, int y, int w, int h,
                      unsigned long style);
void  PGAPI PG_Destroy(HPG pg);
void  PGAPI PG_SetPos(HPG pg, int x, int y, int w, int h);
HWND  PGAPI PG_GetHwnd(HPG pg);

/* ---- appearance -------------------------------------------------- */
/* part = PGF_*, size in points, bold/italic 0|1                      */
void  PGAPI PG_SetFont(HPG pg, int part, const char* face, int sizePt,
                       int bold, int italic);
void  PGAPI PG_SetColor(HPG pg, int slot, COLORREF color);
void  PGAPI PG_SetRowHeight(HPG pg, int px);      /* 0 = auto from fonts */
void  PGAPI PG_SetSplitter(HPG pg, int px);       /* name column width   */
int   PGAPI PG_GetSplitter(HPG pg);

/* ---- building the grid ------------------------------------------- */
void  PGAPI PG_Clear(HPG pg);
/* returns category id (>=1) */
int   PGAPI PG_AddCategory(HPG pg, const char* name);
/* category may be 0 (uncategorised); returns row id (>=1)            */
int   PGAPI PG_AddProperty(HPG pg, int category, const char* name,
                           int type, const char* value);
/* choices: pipe-delimited, e.g. "Red|Green|Blue" (DROP / RADIO)      */
void  PGAPI PG_SetChoices(HPG pg, int row, const char* choices);
void  PGAPI PG_SetRange(HPG pg, int row, double lo, double hi,
                        double step);
void  PGAPI PG_SetDescription(HPG pg, int row, const char* text);
void  PGAPI PG_SetReadOnly(HPG pg, int row, int readOnly);
void  PGAPI PG_SetExpanded(HPG pg, int category, int expanded);
/* free-form tag the caller can associate with a row (e.g. FEQ)       */
void  PGAPI PG_SetTag(HPG pg, int row, long tag);
long  PGAPI PG_GetTag(HPG pg, int row);

/* ---- values ------------------------------------------------------ */
void  PGAPI PG_SetValue(HPG pg, int row, const char* value);
/* returns length copied (excl. NUL)                                  */
int   PGAPI PG_GetValue(HPG pg, int row, char* buf, int bufLen);
int   PGAPI PG_GetRowCount(HPG pg);
int   PGAPI PG_FindRow(HPG pg, const char* name);  /* 0 if not found  */
int   PGAPI PG_GetSelected(HPG pg);                /* selected row id */

/* ---- events ------------------------------------------------------ */
/* Poll queued user events. Returns 1 and fills row/evType while the  */
/* queue is non-empty, else 0.  Call from a Clarion TIMER event.      */
int   PGAPI PG_PollEvent(HPG pg, int* row, int* evType);
/* Optional immediate callback:                                       */
/*   void __stdcall cb(long userData, int row, int evType)            */
typedef void (__stdcall *PG_EVENTPROC)(long userData, int row, int evType);
void  PGAPI PG_SetCallback(HPG pg, PG_EVENTPROC proc, long userData);

void  PGAPI PG_Redraw(HPG pg);

#ifdef __cplusplus
}
#endif
#endif /* CLAPROPGRID_H */
