/*=====================================================================
  propgrid.cpp - ClaPropGrid: Direct2D property grid engine
  ---------------------------------------------------------------------
  C-style code compiled as C++ (for the D2D/DWrite COM headers only).
  Public API is flat C / __stdcall / ANSI - see propgrid.h.
  Build: 32-bit DLL (Clarion targets), see build.bat.
  =====================================================================*/
#define PROPGRID_EXPORTS
#define UNICODE
#define _UNICODE
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#undef DrawText
#include <windowsx.h>
#include <commctrl.h>
#include <commdlg.h>
#include <d2d1.h>
#include <dwrite.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include "propgrid.h"

#pragma comment(lib, "d2d1.lib")
#pragma comment(lib, "dwrite.lib")
#pragma comment(lib, "comctl32.lib")
#pragma comment(lib, "comdlg32.lib")

#ifdef PG_DEBUG
#include <stdio.h>
#include <stdarg.h>
static void dbg(const char* fmt, ...)
{
    char buf[512]; va_list ap; va_start(ap, fmt);
    vsnprintf(buf, 512, fmt, ap); va_end(ap);
    FILE* f = NULL;
    fopen_s(&f, "C:\\ai\\formtopropertygrid\\bin\\pgdebug.log", "a");
    if (f) { fputs(buf, f); fputs("\n", f); fclose(f); }
}
#else
#define dbg(...) ((void)0)
#endif

/*------------------------------------------------------------------*/
/* constants                                                        */
/*------------------------------------------------------------------*/
#define PG_CLASSNAME     L"ClaPropGrid"
#define MAX_EVQ          64
#define SPLIT_GRAB       4      /* px each side of splitter          */
#define CELL_PAD         6
#define GLYPH_ZONE       20     /* drop arrow / spin / ellipsis zone */
#define MIN_SPLIT        48

enum {
    ZONE_NONE = 0, ZONE_NAME, ZONE_VALUE, ZONE_SPLIT, ZONE_CHECK,
    ZONE_DROPBTN, ZONE_SPINUP, ZONE_SPINDN, ZONE_SLIDER, ZONE_BUTTON,
    ZONE_ELLIPSIS, ZONE_CATEXPAND, ZONE_SWATCH
};

/*------------------------------------------------------------------*/
/* data model                                                       */
/*------------------------------------------------------------------*/
typedef struct FontSpec {
    WCHAR   face[64];
    float   sizePt;
    BOOL    bold, italic;
    IDWriteTextFormat* fmt;
} FontSpec;

typedef struct Prop {
    int     cat;        /* owning category id, 0 = uncategorised     */
    int     type;       /* PGT_*                                     */
    WCHAR  *name, *value, *choices, *desc;
    double  lo, hi, step;
    BOOL    readOnly;
    LONG    tag;
    int     fontName;   /* 0 = inherit the category, then PGF_NAME   */
    int     fontValue;  /* 0 = inherit the category, then PGF_VALUE  */
    int     wrapLines;  /* 0 = one line + ellipsis (the default),
                           n = wrap over up to n lines and grow the
                           row to fit, -1 = as many as it takes      */
} Prop;

typedef struct Cat {
    WCHAR  *name;
    BOOL    expanded;
    int     fontHdr;    /* 0 = inherit PGF_CATEGORY                  */
    int     fontName;   /* 0 = inherit PGF_NAME  - for its rows      */
    int     fontValue;  /* 0 = inherit PGF_VALUE - for its rows      */
} Cat;

/* One visible line.  h and y are recomputed by RebuildVis: rows are
   NOT a uniform height any more, so every hit test, every scroll and
   the paint window all read this table instead of multiplying. */
typedef struct VisItem {
    BOOL    isCat;
    int     id;         /* prop id or cat id (1-based)               */
    int     h;          /* this line's height, px                    */
    int     y;          /* cumulative top, px, in document space     */
} VisItem;

typedef struct Grid {
    HWND    hwnd;
    DWORD   style;
    UINT    dpi;

    ID2D1HwndRenderTarget* rt;
    ID2D1SolidColorBrush*  br;
    /* fonts[1..4] are the PGF_* slots, fonts[5..nFonts] are the extra
       ones handed out by PG_AddFont.  fonts[0] is unused so that a
       font id of 0 can mean "inherit". */
    FontSpec *fonts; int nFonts, capFonts;
    COLORREF colors[12];            /* index by PGC_*                */

    int     rowH;                   /* 0 = auto                      */
    int     splitter;
    int     descH;

    Prop   *props;  int nProps, capProps;
    Cat    *cats;   int nCats,  capCats;
    VisItem*vis;    int nVis,   capVis;
    BOOL    visDirty;
    int     visTotalH;              /* sum of every vis[].h          */
    BOOL    anyWrap;                /* a wrapped row exists: heights
                                       depend on the cell width, so a
                                       resize / splitter drag has to
                                       re-measure, not just repaint  */

    int     scrollY;
    int     sel;                    /* selected prop id, 0 = none    */
    int     hot;  int hotZone;      /* hover prop id / zone          */
    BOOL    focus;

    HWND    hEdit;   int editProp;  /* in-place EDIT overlay         */
    HWND    hList;   int listProp;  /* popup choice list             */
    HWND    hMulti;  int multiProp; /* popup multiline editor        */
    HFONT   hEditFont; int hEditFontId;  /* font the HFONT was built
                                       from, so an editor opened on a
                                       row with its own font matches */
    BOOL    inCommit;

    BOOL    dragSplit;
    int     dragSlider;             /* prop id being slider-dragged  */
    int     pressedBtn;             /* prop id of pressed button row */

    struct { int row, type; } evq[MAX_EVQ];
    int     evHead, evTail;
    PG_EVENTPROC cb; LONG cbUser;
} Grid;

/*------------------------------------------------------------------*/
/* globals                                                          */
/*------------------------------------------------------------------*/
static LONG            g_initCount = 0;
static ID2D1Factory*   g_d2d = NULL;
static IDWriteFactory* g_dw  = NULL;
static ATOM            g_atom = 0;

/*------------------------------------------------------------------*/
/* small helpers                                                    */
/*------------------------------------------------------------------*/
static WCHAR* a2w(const char* s)
{
    if (!s) s = "";
    int n = MultiByteToWideChar(CP_ACP, 0, s, -1, NULL, 0);
    WCHAR* w = (WCHAR*)malloc(n * sizeof(WCHAR));
    if (w) MultiByteToWideChar(CP_ACP, 0, s, -1, w, n);
    return w;
}

static int w2a(const WCHAR* w, char* buf, int bufLen)
{
    if (!buf || bufLen <= 0) return 0;
    if (!w) w = L"";
    int n = WideCharToMultiByte(CP_ACP, 0, w, -1, buf, bufLen, NULL, NULL);
    if (n == 0) { buf[bufLen - 1] = 0; return (int)strlen(buf); }
    return n - 1;
}

static void setStr(WCHAR** dst, const WCHAR* src)
{
    free(*dst);
    if (!src) src = L"";
    size_t n = wcslen(src) + 1;
    *dst = (WCHAR*)malloc(n * sizeof(WCHAR));
    if (*dst) memcpy(*dst, src, n * sizeof(WCHAR));
}

static D2D1_COLOR_F CrToD2D(COLORREF c)
{
    return D2D1::ColorF(GetRValue(c) / 255.0f, GetGValue(c) / 255.0f,
                        GetBValue(c) / 255.0f, 1.0f);
}

static UINT WindowDpi(HWND h)
{
    typedef UINT (WINAPI *PFN)(HWND);
    static PFN pfn = (PFN)(void*)GetProcAddress(
        GetModuleHandleW(L"user32.dll"), "GetDpiForWindow");
    if (pfn) { UINT d = pfn(h); if (d) return d; }
    HDC dc = GetDC(NULL);
    UINT d = GetDeviceCaps(dc, LOGPIXELSY);
    ReleaseDC(NULL, dc);
    return d ? d : 96;
}

static Prop* PROP(Grid* g, int id)
{
    return (id >= 1 && id <= g->nProps) ? &g->props[id - 1] : NULL;
}
static Cat* CAT(Grid* g, int id)
{
    return (id >= 1 && id <= g->nCats) ? &g->cats[id - 1] : NULL;
}

/*------------------------------------------------------------------*/
/* fonts: id resolution and the height each one needs                 */
/*------------------------------------------------------------------*/
/* A font id is valid when it is one of the four slots or one that
   PG_AddFont handed out.  Anything else (0 included) means inherit. */
static BOOL FontOk(Grid* g, int id)
{
    return id >= PGF_NAME && id < g->nFonts && g->fonts[id].sizePt > 0;
}

/* used only if someone reaches a font before PG_Create allocated the
   table - never in normal flow, but it keeps every path NULL-safe */
static FontSpec g_fallbackFont = { L"Segoe UI", 9.0f, FALSE, FALSE, NULL };

static FontSpec* FONT(Grid* g, int id)
{
    if (!g->fonts || g->nFonts <= PGF_VALUE) return &g_fallbackFont;
    return FontOk(g, id) ? &g->fonts[id] : &g->fonts[PGF_VALUE];
}

/* the font a category header / a row's name / a row's value draws in,
   resolved row -> category -> global slot */
static int HdrFontOf(Grid* g, const Cat* c)
{
    if (c && FontOk(g, c->fontHdr)) return c->fontHdr;
    return PGF_CATEGORY;
}

static int NameFontOf(Grid* g, const Prop* p)
{
    if (!p) return PGF_NAME;
    if (FontOk(g, p->fontName)) return p->fontName;
    const Cat* c = CAT(g, p->cat);
    if (c && FontOk(g, c->fontName)) return c->fontName;
    return PGF_NAME;
}

static int ValueFontOf(Grid* g, const Prop* p)
{
    if (!p) return PGF_VALUE;
    if (FontOk(g, p->fontValue)) return p->fontValue;
    const Cat* c = CAT(g, p->cat);
    if (c && FontOk(g, c->fontValue)) return c->fontValue;
    return PGF_VALUE;
}

/* the row height one font asks for - the original formula, per font */
static int FontRowPx(Grid* g, int id)
{
    int h = (int)(FONT(g, id)->sizePt * g->dpi / 72.0f) + 10;
    return h < 20 ? 20 : h;
}

/* The nominal line: what a wheel notch, an arrow click and a page of
   PgUp/PgDn are worth.  Still driven by the value slot, so scrolling
   feels the same as it always did whatever individual rows do. */
static int DefRowH(Grid* g)
{
    if (g->rowH > 0) return g->rowH;
    return FontRowPx(g, PGF_VALUE);
}

#define WRAP_MAXLINES  64      /* hard stop so one huge value cannot
                                  swallow the whole grid             */

/* Width the value text gets when it wraps.  Depends on the splitter
   and the client width, which is why anyWrap forces a re-measure. */
static int ValueTextWidth(Grid* g, const Prop* p)
{
    RECT rc; GetClientRect(g->hwnd, &rc);
    int w = rc.right - (g->splitter + 1) - CELL_PAD * 2;
    if (p && (p->type == PGT_MULTITEXT || p->type == PGT_DROP ||
              p->type == PGT_SPIN))
        w -= GLYPH_ZONE;
    return w > 16 ? w : 16;
}

/* Height a wrapped value needs, 0 when it does not wrap after all.
   Measured with a real DWrite layout, so it matches what is painted. */
static int WrapTextPx(Grid* g, const WCHAR* txt, int fontId, int width,
                      int maxLines)
{
    if (!g_dw || !txt || !*txt || width < 16) return 0;
    IDWriteTextFormat* fmt = FONT(g, fontId)->fmt;
    if (!fmt) return 0;
    IDWriteTextLayout* lay = NULL;
    HRESULT hr = g_dw->CreateTextLayout(txt, (UINT32)wcslen(txt), fmt,
        (FLOAT)width, 100000.0f, &lay);
    if (FAILED(hr) || !lay) return 0;
    lay->SetWordWrapping(DWRITE_WORD_WRAPPING_WRAP);
    UINT32 n = 0;
    lay->GetLineMetrics(NULL, 0, &n);              /* ask for the count */
    int h = 0;
    if (n > 0) {
        DWRITE_LINE_METRICS* lm =
            (DWRITE_LINE_METRICS*)malloc(n * sizeof(DWRITE_LINE_METRICS));
        if (lm && SUCCEEDED(lay->GetLineMetrics(lm, n, &n))) {
            UINT32 cap = (maxLines > 0 && (UINT32)maxLines < n)
                       ? (UINT32)maxLines : n;
            if (cap > WRAP_MAXLINES) cap = WRAP_MAXLINES;
            for (UINT32 i = 0; i < cap; i++) h += (int)(lm[i].height + 0.5f);
        }
        free(lm);
    }
    lay->Release();
    return h;
}

/* The height of one visible line.  An explicit PG_SetRowHeight still
   wins outright - that is the escape hatch for a caller who wants the
   old uniform look back. */
static int ItemHeight(Grid* g, BOOL isCat, int id)
{
    if (g->rowH > 0) return g->rowH;
    if (isCat) return FontRowPx(g, HdrFontOf(g, CAT(g, id)));
    Prop* p = PROP(g, id);
    int hn = FontRowPx(g, NameFontOf(g, p));
    int hv = FontRowPx(g, ValueFontOf(g, p));
    int h  = hn > hv ? hn : hv;
    if (p && p->wrapLines && p->value && *p->value && g->hwnd) {
        int wrapped = WrapTextPx(g, p->value, ValueFontOf(g, p),
                                 ValueTextWidth(g, p), p->wrapLines);
        wrapped += 8;                              /* the cell's padding */
        if (wrapped > h) h = wrapped;
    }
    return h;
}

/*------------------------------------------------------------------*/
/* event queue                                                      */
/*------------------------------------------------------------------*/
static void PushEvent(Grid* g, int row, int type)
{
    int next = (g->evTail + 1) % MAX_EVQ;
    if (next != g->evHead) {
        g->evq[g->evTail].row  = row;
        g->evq[g->evTail].type = type;
        g->evTail = next;
    }
    if (g->cb) g->cb(g->cbUser, row, type);
}

/*------------------------------------------------------------------*/
/* fonts / render target                                            */
/*------------------------------------------------------------------*/
static void RebuildFormat(Grid* g, int part)
{
    FontSpec* f = &g->fonts[part];
    if (f->fmt) { f->fmt->Release(); f->fmt = NULL; }
    if (!g_dw) return;
    float px = f->sizePt * g->dpi / 72.0f;
    g_dw->CreateTextFormat(f->face, NULL,
        f->bold   ? DWRITE_FONT_WEIGHT_SEMI_BOLD : DWRITE_FONT_WEIGHT_NORMAL,
        f->italic ? DWRITE_FONT_STYLE_ITALIC     : DWRITE_FONT_STYLE_NORMAL,
        DWRITE_FONT_STRETCH_NORMAL, px, L"", &f->fmt);
    if (f->fmt) {
        f->fmt->SetParagraphAlignment(DWRITE_PARAGRAPH_ALIGNMENT_CENTER);
        f->fmt->SetWordWrapping(DWRITE_WORD_WRAPPING_NO_WRAP);
        IDWriteInlineObject* sign = NULL;
        DWRITE_TRIMMING trim = { DWRITE_TRIMMING_GRANULARITY_CHARACTER, 0, 0 };
        g_dw->CreateEllipsisTrimmingSign(f->fmt, &sign);
        f->fmt->SetTrimming(&trim, sign);
        if (sign) sign->Release();
    }
}

/* The GDI font the native EDIT / LISTBOX overlays wear.  Only ever
   called with no editor open, so deleting the old HFONT is safe. */
static void RebuildEditFont(Grid* g, int fontId)
{
    if (g->hEditFont) { DeleteObject(g->hEditFont); g->hEditFont = NULL; }
    FontSpec* f = FONT(g, fontId);
    int px = (int)(f->sizePt * g->dpi / 72.0f + 0.5f);
    g->hEditFont = CreateFontW(-px, 0, 0, 0,
        f->bold ? FW_SEMIBOLD : FW_NORMAL, f->italic, 0, 0,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH, f->face);
    g->hEditFontId = fontId;
}

static void EnsureEditFont(Grid* g, int fontId)
{
    if (g->hEditFont && g->hEditFontId == fontId) return;
    RebuildEditFont(g, fontId);
}

static void DiscardRT(Grid* g)
{
    if (g->br) { g->br->Release(); g->br = NULL; }
    if (g->rt) { g->rt->Release(); g->rt = NULL; }
}

static BOOL EnsureRT(Grid* g)
{
    if (g->rt) return TRUE;
    if (!g_d2d) return FALSE;
    RECT rc; GetClientRect(g->hwnd, &rc);
    D2D1_SIZE_U sz = D2D1::SizeU(rc.right - rc.left, rc.bottom - rc.top);
    D2D1_RENDER_TARGET_PROPERTIES rp = D2D1::RenderTargetProperties();
    rp.dpiX = rp.dpiY = 96.0f;               /* 1 unit == 1 pixel    */
    HRESULT hr = g_d2d->CreateHwndRenderTarget(rp,
        D2D1::HwndRenderTargetProperties(g->hwnd, sz), &g->rt);
    if (FAILED(hr)) return FALSE;
    g->rt->CreateSolidColorBrush(D2D1::ColorF(0), &g->br);
    return g->br != NULL;
}

/*------------------------------------------------------------------*/
/* visible-item list                                                */
/*------------------------------------------------------------------*/
static int cmpPropIdx(void* ctx, const void* a, const void* b)
{
    Grid* g = (Grid*)ctx;
    const Prop* pa = &g->props[*(const int*)a - 1];
    const Prop* pb = &g->props[*(const int*)b - 1];
    return _wcsicmp(pa->name, pb->name);
}

static void VisPush(Grid* g, BOOL isCat, int id)
{
    if (g->nVis == g->capVis) {
        g->capVis = g->capVis ? g->capVis * 2 : 32;
        g->vis = (VisItem*)realloc(g->vis, g->capVis * sizeof(VisItem));
    }
    g->vis[g->nVis].isCat = isCat;
    g->vis[g->nVis].id = id;
    g->nVis++;
}

static void AddCatProps(Grid* g, int cat)
{
    int* idx = (int*)malloc((g->nProps ? g->nProps : 1) * sizeof(int));
    int n = 0, i;
    for (i = 1; i <= g->nProps; i++)
        if (g->props[i - 1].cat == cat) idx[n++] = i;
    if (g->style & PGS_SORT)
        qsort_s(idx, n, sizeof(int), (int(__cdecl*)(void*, const void*, const void*))cmpPropIdx, g);
    for (i = 0; i < n; i++) VisPush(g, FALSE, idx[i]);
    free(idx);
}

static void RebuildVis(Grid* g)
{
    g->nVis = 0;
    AddCatProps(g, 0);
    for (int c = 1; c <= g->nCats; c++) {
        VisPush(g, TRUE, c);
        if (g->cats[c - 1].expanded) AddCatProps(g, c);
    }
    /* measure every line and lay them out head to tail.  This is the
       one place row geometry is decided; everything else reads it. */
    int y = 0;
    g->anyWrap = FALSE;
    for (int i = 0; i < g->nVis; i++) {
        VisItem* it = &g->vis[i];
        if (!it->isCat) {
            Prop* p = PROP(g, it->id);
            if (p && p->wrapLines) g->anyWrap = TRUE;
        }
        it->h = ItemHeight(g, it->isCat, it->id);
        it->y = y;
        y += it->h;
    }
    g->visTotalH = y;
    g->visDirty = FALSE;
}

/* index of the line covering a document-space y, -1 when past the end */
static int VisIndexAtY(Grid* g, int docY)
{
    if (g->nVis <= 0 || docY < 0) return -1;
    int lo = 0, hi = g->nVis - 1;
    while (lo <= hi) {
        int mid = (lo + hi) / 2;
        VisItem* it = &g->vis[mid];
        if (docY < it->y)             hi = mid - 1;
        else if (docY >= it->y + it->h) lo = mid + 1;
        else return mid;
    }
    return -1;
}

static void UpdateScroll(Grid* g)
{
    if (g->visDirty) RebuildVis(g);
    RECT rc; GetClientRect(g->hwnd, &rc);
    int view = rc.bottom - g->descH;
    if (view < 0) view = 0;
    int content = g->visTotalH;
    SCROLLINFO si = { sizeof(si), SIF_RANGE | SIF_PAGE | SIF_POS };
    si.nMin = 0; si.nMax = content > 0 ? content - 1 : 0;
    si.nPage = view; si.nPos = g->scrollY;
    SetScrollInfo(g->hwnd, SB_VERT, &si, TRUE);
    int maxScroll = content - view; if (maxScroll < 0) maxScroll = 0;
    if (g->scrollY > maxScroll) g->scrollY = maxScroll;
    if (g->scrollY < 0) g->scrollY = 0;
}

static void Dirty(Grid* g)
{
    g->visDirty = TRUE;
    UpdateScroll(g);
    InvalidateRect(g->hwnd, NULL, FALSE);
}

/*------------------------------------------------------------------*/
/* geometry                                                         */
/*------------------------------------------------------------------*/
static int VisIndexOfProp(Grid* g, int id)
{
    for (int i = 0; i < g->nVis; i++)
        if (!g->vis[i].isCat && g->vis[i].id == id) return i;
    return -1;
}

static BOOL PropRowRect(Grid* g, int id, RECT* out)
{
    if (g->visDirty) RebuildVis(g);
    int vi = VisIndexOfProp(g, id);
    if (vi < 0) return FALSE;
    RECT rc; GetClientRect(g->hwnd, &rc);
    out->left = 0; out->right = rc.right;
    out->top = g->vis[vi].y - g->scrollY;
    out->bottom = out->top + g->vis[vi].h;
    return TRUE;
}

static void ValueCell(Grid* g, const RECT* row, RECT* out)
{
    out->left = g->splitter + 1; out->right = row->right;
    out->top = row->top + 1; out->bottom = row->bottom - 1;
}

/* rect of the native EDIT overlay for a prop row */
static void EditRect(Grid* g, int id, RECT* out)
{
    RECT row; PropRowRect(g, id, &row);
    ValueCell(g, &row, out);
    Prop* p = PROP(g, id);
    if (p && (p->type == PGT_SPIN || p->type == PGT_MULTITEXT ||
              p->type == PGT_DROP))
        out->right -= GLYPH_ZONE;
    out->left += 2;
}

/*------------------------------------------------------------------*/
/* in-place editors: commit / cancel                                */
/*------------------------------------------------------------------*/
static void ValueChangedByUser(Grid* g, int id)
{
    PushEvent(g, id, PGE_CHANGED);
    InvalidateRect(g->hwnd, NULL, FALSE);
}

static double PropNum(Prop* p)
{
    return p->value ? _wtof(p->value) : 0.0;
}

static void SetNum(Grid* g, Prop* p, double v)
{
    WCHAR buf[64];
    if (p->step >= 1.0 || p->step == 0.0)
        swprintf(buf, 64, L"%.0f", v);
    else
        swprintf(buf, 64, L"%g", v);
    setStr(&p->value, buf);
}

static double ClampStep(Prop* p, double v)
{
    if (p->hi > p->lo) {
        if (v < p->lo) v = p->lo;
        if (v > p->hi) v = p->hi;
        if (p->step > 0) {
            double n = floor((v - p->lo) / p->step + 0.5);
            v = p->lo + n * p->step;
            if (v > p->hi) v = p->hi;
        }
    }
    return v;
}

static void CommitEdit(Grid* g, BOOL keep)
{
    if (!g->hEdit || g->inCommit) return;
    g->inCommit = TRUE;
    int id = g->editProp;
    HWND h = g->hEdit;
    g->hEdit = NULL; g->editProp = 0;
    if (keep) {
        Prop* p = PROP(g, id);
        if (p) {
            WCHAR buf[4096];
            GetWindowTextW(h, buf, 4096);
            if (p->type == PGT_SPIN || p->type == PGT_SLIDER) {
                double v = ClampStep(p, _wtof(buf));
                SetNum(g, p, v);
            } else {
                setStr(&p->value, buf);
            }
            ValueChangedByUser(g, id);
        }
    }
    DestroyWindow(h);
    g->inCommit = FALSE;
    InvalidateRect(g->hwnd, NULL, FALSE);
}

static void CloseList(Grid* g, BOOL keep)
{
#ifdef PG_DEBUG
    if (g->hList) dbg("CloseList keep=%d inCommit=%d", keep, g->inCommit);
#endif
    if (!g->hList || g->inCommit) return;
    g->inCommit = TRUE;
    HWND h = g->hList; int id = g->listProp;
    g->hList = NULL; g->listProp = 0;
    if (keep) {
        int selIdx = (int)SendMessageW(h, LB_GETCURSEL, 0, 0);
        Prop* p = PROP(g, id);
        if (p && selIdx >= 0) {
            WCHAR buf[1024];
            SendMessageW(h, LB_GETTEXT, selIdx, (LPARAM)buf);
            setStr(&p->value, buf);
            ValueChangedByUser(g, id);
        }
    }
    DestroyWindow(h);
    g->inCommit = FALSE;
    SetFocus(g->hwnd);
    InvalidateRect(g->hwnd, NULL, FALSE);
}

static void CloseMulti(Grid* g, BOOL keep)
{
    if (!g->hMulti || g->inCommit) return;
    g->inCommit = TRUE;
    HWND h = g->hMulti; int id = g->multiProp;
    g->hMulti = NULL; g->multiProp = 0;
    if (keep) {
        Prop* p = PROP(g, id);
        if (p) {
            int n = GetWindowTextLengthW(h) + 1;
            WCHAR* buf = (WCHAR*)malloc(n * sizeof(WCHAR));
            if (buf) {
                GetWindowTextW(h, buf, n);
                setStr(&p->value, buf);
                free(buf);
                ValueChangedByUser(g, id);
            }
        }
    }
    DestroyWindow(h);
    g->inCommit = FALSE;
    SetFocus(g->hwnd);
    InvalidateRect(g->hwnd, NULL, FALSE);
}

static void CloseEditors(Grid* g, BOOL keep)
{
    CommitEdit(g, keep);
    CloseList(g, keep);
    CloseMulti(g, keep);
}

/*------------------------------------------------------------------*/
/* subclass procs for the native editors                            */
/*------------------------------------------------------------------*/
static LRESULT CALLBACK EditSub(HWND h, UINT m, WPARAM w, LPARAM l,
                                UINT_PTR, DWORD_PTR ref)
{
    Grid* g = (Grid*)ref;
    switch (m) {
    case WM_KEYDOWN:
        if (w == VK_RETURN) { CommitEdit(g, TRUE);  SetFocus(g->hwnd); return 0; }
        if (w == VK_ESCAPE) { CommitEdit(g, FALSE); SetFocus(g->hwnd); return 0; }
        break;
    case WM_CHAR:
        if (w == VK_RETURN || w == VK_ESCAPE) return 0;   /* no beep */
        break;
    case WM_KILLFOCUS:
        CommitEdit(g, TRUE);
        break;
    }
    return DefSubclassProc(h, m, w, l);
}

static LRESULT CALLBACK ListSub(HWND h, UINT m, WPARAM w, LPARAM l,
                                UINT_PTR, DWORD_PTR ref)
{
    Grid* g = (Grid*)ref;
    switch (m) {
    case WM_LBUTTONUP: {
        LRESULT r = DefSubclassProc(h, m, w, l);
        CloseList(g, TRUE);
        return r;
    }
    case WM_KEYDOWN:
        if (w == VK_RETURN) { CloseList(g, TRUE);  return 0; }
        if (w == VK_ESCAPE) { CloseList(g, FALSE); return 0; }
        break;
    case WM_KILLFOCUS:
        CloseList(g, FALSE);
        break;
    }
    return DefSubclassProc(h, m, w, l);
}

static LRESULT CALLBACK MultiSub(HWND h, UINT m, WPARAM w, LPARAM l,
                                 UINT_PTR, DWORD_PTR ref)
{
    Grid* g = (Grid*)ref;
    switch (m) {
    case WM_KEYDOWN:
        if (w == VK_RETURN && (GetKeyState(VK_CONTROL) & 0x8000)) {
            CloseMulti(g, TRUE); return 0;
        }
        if (w == VK_ESCAPE) { CloseMulti(g, FALSE); return 0; }
        break;
    case WM_KILLFOCUS:
        CloseMulti(g, TRUE);
        break;
    }
    return DefSubclassProc(h, m, w, l);
}

/*------------------------------------------------------------------*/
/* opening editors                                                  */
/*------------------------------------------------------------------*/
static void BeginEdit(Grid* g, int id, WCHAR firstChar)
{
    Prop* p = PROP(g, id);
    if (!p || p->readOnly) return;
    if (p->type != PGT_TEXT && p->type != PGT_PASSWORD &&
        p->type != PGT_DATE && p->type != PGT_TIME &&
        p->type != PGT_SPIN && p->type != PGT_SLIDER &&
        p->type != PGT_MULTITEXT) return;
    CloseEditors(g, TRUE);
    EnsureEditFont(g, ValueFontOf(g, p));
    RECT rc; EditRect(g, id, &rc);
    DWORD es = WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL;
    if (p->type == PGT_PASSWORD) es |= ES_PASSWORD;
    if (p->wrapLines) {                /* the cell is tall - edit it that way */
        es &= ~ES_AUTOHSCROLL;
        es |= ES_MULTILINE | ES_AUTOVSCROLL;
    }
    g->hEdit = CreateWindowExW(0, L"EDIT", p->value ? p->value : L"",
        es, rc.left, rc.top + 1, rc.right - rc.left, rc.bottom - rc.top - 1,
        g->hwnd, NULL, (HINSTANCE)GetModuleHandleW(NULL), NULL);
    if (!g->hEdit) return;
    g->editProp = id;
    if (g->hEditFont) SendMessageW(g->hEdit, WM_SETFONT, (WPARAM)g->hEditFont, TRUE);
    SetWindowSubclass(g->hEdit, EditSub, 1, (DWORD_PTR)g);
    SetFocus(g->hEdit);
    if (firstChar) {
        WCHAR s[2] = { firstChar, 0 };
        SetWindowTextW(g->hEdit, s);
        SendMessageW(g->hEdit, EM_SETSEL, 1, 1);
    } else {
        SendMessageW(g->hEdit, EM_SETSEL, 0, -1);
    }
}

static void OpenList(Grid* g, int id)
{
    Prop* p = PROP(g, id);
    dbg("OpenList id=%d p=%p ro=%d choices=%p", id, p, p ? p->readOnly : -1, p ? p->choices : 0);
    if (!p || p->readOnly || !p->choices || !*p->choices) return;
    CloseEditors(g, TRUE);
    EnsureEditFont(g, ValueFontOf(g, p));
    RECT row; if (!PropRowRect(g, id, &row)) return;
    RECT cell; ValueCell(g, &row, &cell);
    POINT pt = { cell.left, row.bottom };
    ClientToScreen(g->hwnd, &pt);
    /* count choices */
    int n = 1; const WCHAR* c;
    for (c = p->choices; *c; c++) if (*c == L'|') n++;
    int rh = FontRowPx(g, ValueFontOf(g, p));   /* the row's own font */
    int lh = n * (rh - 2) + 4; if (lh > 8 * rh) lh = 8 * rh;
    g->hList = CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_TOPMOST,
        L"LISTBOX", L"", WS_POPUP | WS_BORDER | WS_VSCROLL | LBS_NOTIFY | LBS_NOINTEGRALHEIGHT,
        pt.x, pt.y, cell.right - cell.left, lh,
        g->hwnd, NULL, (HINSTANCE)GetModuleHandleW(NULL), NULL);
    dbg("OpenList hList=%p err=%d", g->hList, (int)GetLastError());
    if (!g->hList) return;
    g->listProp = id;
    if (g->hEditFont) SendMessageW(g->hList, WM_SETFONT, (WPARAM)g->hEditFont, TRUE);
    /* fill */
    WCHAR* dup = _wcsdup(p->choices);
    WCHAR* ctx2 = NULL;
    int selIdx = -1, i = 0;
    for (WCHAR* tok = wcstok_s(dup, L"|", &ctx2); tok;
         tok = wcstok_s(NULL, L"|", &ctx2), i++) {
        SendMessageW(g->hList, LB_ADDSTRING, 0, (LPARAM)tok);
        if (p->value && _wcsicmp(tok, p->value) == 0) selIdx = i;
    }
    free(dup);
    if (selIdx >= 0) SendMessageW(g->hList, LB_SETCURSEL, selIdx, 0);
    SetWindowSubclass(g->hList, ListSub, 1, (DWORD_PTR)g);
    ShowWindow(g->hList, SW_SHOW);
    SetFocus(g->hList);
}

static void OpenMulti(Grid* g, int id)
{
    Prop* p = PROP(g, id);
    if (!p || p->readOnly) return;
    CloseEditors(g, TRUE);
    EnsureEditFont(g, ValueFontOf(g, p));
    RECT row; if (!PropRowRect(g, id, &row)) return;
    RECT cell; ValueCell(g, &row, &cell);
    POINT pt = { cell.left, row.bottom };
    ClientToScreen(g->hwnd, &pt);
    int w = cell.right - cell.left; if (w < 200) w = 200;
    g->hMulti = CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_TOPMOST,
        L"EDIT", p->value ? p->value : L"",
        WS_POPUP | WS_BORDER | ES_MULTILINE | ES_AUTOVSCROLL | ES_WANTRETURN | WS_VSCROLL,
        pt.x, pt.y, w, FontRowPx(g, ValueFontOf(g, p)) * 6,
        g->hwnd, NULL, (HINSTANCE)GetModuleHandleW(NULL), NULL);
    if (!g->hMulti) return;
    g->multiProp = id;
    if (g->hEditFont) SendMessageW(g->hMulti, WM_SETFONT, (WPARAM)g->hEditFont, TRUE);
    SetWindowSubclass(g->hMulti, MultiSub, 1, (DWORD_PTR)g);
    ShowWindow(g->hMulti, SW_SHOW);
    SetFocus(g->hMulti);
}

static void PickColor(Grid* g, int id)
{
    Prop* p = PROP(g, id);
    if (!p || p->readOnly) return;
    static COLORREF custom[16] = { 0 };
    COLORREF cur = RGB(255, 255, 255);
    if (p->value) {
        const WCHAR* v = p->value; if (*v == L'#') v++;
        unsigned long x = wcstoul(v, NULL, 16);
        cur = RGB((x >> 16) & 0xFF, (x >> 8) & 0xFF, x & 0xFF);
    }
    CHOOSECOLORW cc = { sizeof(cc) };
    cc.hwndOwner = g->hwnd;
    cc.rgbResult = cur;
    cc.lpCustColors = custom;
    cc.Flags = CC_FULLOPEN | CC_RGBINIT;
    if (ChooseColorW(&cc)) {
        WCHAR buf[16];
        swprintf(buf, 16, L"%02X%02X%02X",
                 GetRValue(cc.rgbResult), GetGValue(cc.rgbResult),
                 GetBValue(cc.rgbResult));
        setStr(&p->value, buf);
        ValueChangedByUser(g, id);
    }
}

/*------------------------------------------------------------------*/
/* hit testing                                                      */
/*------------------------------------------------------------------*/
static int HitTest(Grid* g, int x, int y, int* zone)
{
    *zone = ZONE_NONE;
    if (g->visDirty) RebuildVis(g);
    RECT rc; GetClientRect(g->hwnd, &rc);
    if (y >= rc.bottom - g->descH) return 0;
    int vi = VisIndexAtY(g, y + g->scrollY);
    if (vi < 0 || vi >= g->nVis) {
        if (abs(x - g->splitter) <= SPLIT_GRAB) *zone = ZONE_SPLIT;
        return 0;
    }
    VisItem* it = &g->vis[vi];
    if (it->isCat) {
        *zone = ZONE_CATEXPAND;
        return -it->id;                       /* negative = category */
    }
    Prop* p = PROP(g, it->id);
    if (abs(x - g->splitter) <= SPLIT_GRAB && p->type != PGT_BUTTON) {
        *zone = ZONE_SPLIT;
        return it->id;
    }
    if (x < g->splitter) { *zone = ZONE_NAME; return it->id; }
    /* inside value cell */
    RECT row; PropRowRect(g, it->id, &row);
    RECT cell; ValueCell(g, &row, &cell);
    switch (p->type) {
    case PGT_CHECK:
        *zone = ZONE_CHECK; break;
    case PGT_DROP: case PGT_RADIO:
        *zone = ZONE_DROPBTN; break;
    case PGT_SLIDER:
        *zone = (x >= cell.right - 52) ? ZONE_VALUE : ZONE_SLIDER; break;
    case PGT_SPIN:
        if (x >= cell.right - GLYPH_ZONE) {
            int mid = (cell.top + cell.bottom) / 2;
            *zone = (y < mid) ? ZONE_SPINUP : ZONE_SPINDN;
        } else *zone = ZONE_VALUE;
        break;
    case PGT_BUTTON:
        *zone = ZONE_BUTTON; break;
    case PGT_COLOR:
        *zone = ZONE_SWATCH; break;
    case PGT_MULTITEXT:
        *zone = (x >= cell.right - GLYPH_ZONE) ? ZONE_ELLIPSIS : ZONE_VALUE;
        break;
    default:
        *zone = ZONE_VALUE; break;
    }
    return it->id;
}

/*------------------------------------------------------------------*/
/* painting                                                         */
/*------------------------------------------------------------------*/
static void FillRectC(Grid* g, const RECT* rc, COLORREF c)
{
    g->br->SetColor(CrToD2D(c));
    g->rt->FillRectangle(D2D1::RectF((FLOAT)rc->left, (FLOAT)rc->top,
        (FLOAT)rc->right, (FLOAT)rc->bottom), g->br);
}

static void DrawTextC(Grid* g, const WCHAR* txt, const RECT* rc,
                      int part, COLORREF c)
{
    if (!txt || !*txt) return;
    IDWriteTextFormat* fmt = g->fonts[part].fmt;
    if (!fmt) return;
    g->br->SetColor(CrToD2D(c));
    g->rt->DrawText(txt, (UINT32)wcslen(txt), fmt,
        D2D1::RectF((FLOAT)rc->left, (FLOAT)rc->top,
                    (FLOAT)rc->right, (FLOAT)rc->bottom),
        g->br, D2D1_DRAW_TEXT_OPTIONS_CLIP);
}

/* Wrapped multi-line draw.  The shared IDWriteTextFormat is single
   line, vertically centred and ellipsis-trimmed, so a wrapped cell
   needs its own layout: wrap on, top aligned, clipped to the cell. */
static void DrawTextWrapC(Grid* g, const WCHAR* txt, const RECT* rc,
                          int fontId, COLORREF c, int maxLines)
{
    if (!txt || !*txt || !g_dw) return;
    IDWriteTextFormat* fmt = FONT(g, fontId)->fmt;
    if (!fmt) return;
    FLOAT w = (FLOAT)(rc->right - rc->left);
    FLOAT h = (FLOAT)(rc->bottom - rc->top);
    if (w < 4 || h < 2) return;
    IDWriteTextLayout* lay = NULL;
    if (FAILED(g_dw->CreateTextLayout(txt, (UINT32)wcslen(txt), fmt, w, h,
                                      &lay)) || !lay) return;
    lay->SetWordWrapping(DWRITE_WORD_WRAPPING_WRAP);
    lay->SetParagraphAlignment(DWRITE_PARAGRAPH_ALIGNMENT_NEAR);
    (void)maxLines;                    /* the row was sized for them  */
    g->br->SetColor(CrToD2D(c));
    g->rt->DrawTextLayout(D2D1::Point2F((FLOAT)rc->left, (FLOAT)rc->top),
        lay, g->br, D2D1_DRAW_TEXT_OPTIONS_CLIP);
    lay->Release();
}

static void HLine(Grid* g, int x1, int x2, int y, COLORREF c)
{
    g->br->SetColor(CrToD2D(c));
    g->rt->DrawLine(D2D1::Point2F((FLOAT)x1, y + 0.5f),
                    D2D1::Point2F((FLOAT)x2, y + 0.5f), g->br, 1.0f);
}

static void VLine(Grid* g, int x, int y1, int y2, COLORREF c)
{
    g->br->SetColor(CrToD2D(c));
    g->rt->DrawLine(D2D1::Point2F(x + 0.5f, (FLOAT)y1),
                    D2D1::Point2F(x + 0.5f, (FLOAT)y2), g->br, 1.0f);
}

#define ACCENT RGB(0x3D, 0x6D, 0xA8)   /* steel blue accent */

static void PaintValue(Grid* g, Prop* p, int id, RECT cell)
{
    COLORREF vt = p->readOnly ? RGB(130, 130, 130) : g->colors[PGC_VALUETEXT];
    RECT tr = cell; tr.left += CELL_PAD;
    int midY = (cell.top + cell.bottom) / 2;
    int vf = ValueFontOf(g, p);        /* row -> category -> PGF_VALUE */
    switch (p->type) {
    case PGT_PASSWORD: {
        if (p->value && *p->value) {
            size_t n = wcslen(p->value); if (n > 24) n = 24;
            WCHAR mask[26]; size_t i;
            for (i = 0; i < n; i++) mask[i] = 0x25CF;   /* ● */
            mask[n] = 0;
            DrawTextC(g, mask, &tr, vf, vt);
        }
        break;
    }
    case PGT_CHECK: {
        int bs = (cell.bottom - cell.top) - 8; if (bs > 14) bs = 14;
        D2D1_RECT_F box = D2D1::RectF((FLOAT)tr.left, (FLOAT)(midY - bs / 2 - 1),
            (FLOAT)(tr.left + bs), (FLOAT)(midY + bs - bs / 2 - 1));
        g->br->SetColor(CrToD2D(RGB(110, 110, 110)));
        g->rt->DrawRectangle(box, g->br, 1.2f);
        BOOL on = p->value && (p->value[0] == L'1' ||
                  towupper(p->value[0]) == L'Y' || towupper(p->value[0]) == L'T');
        if (on) {
            g->br->SetColor(CrToD2D(ACCENT));
            FLOAT x = box.left, yb = box.top, s = box.right - box.left;
            g->rt->DrawLine(D2D1::Point2F(x + s * 0.20f, yb + s * 0.55f),
                            D2D1::Point2F(x + s * 0.42f, yb + s * 0.78f), g->br, 2.0f);
            g->rt->DrawLine(D2D1::Point2F(x + s * 0.42f, yb + s * 0.78f),
                            D2D1::Point2F(x + s * 0.82f, yb + s * 0.25f), g->br, 2.0f);
        }
        break;
    }
    case PGT_DROP: case PGT_RADIO: {
        RECT t2 = tr; t2.right -= GLYPH_ZONE;
        if (p->type == PGT_RADIO) {
            g->br->SetColor(CrToD2D(RGB(110, 110, 110)));
            D2D1_ELLIPSE e = D2D1::Ellipse(
                D2D1::Point2F((FLOAT)(t2.left + 5), (FLOAT)midY), 5.0f, 5.0f);
            g->rt->DrawEllipse(e, g->br, 1.2f);
            g->br->SetColor(CrToD2D(ACCENT));
            e.radiusX = e.radiusY = 2.4f;
            g->rt->FillEllipse(e, g->br);
            t2.left += 16;
        }
        DrawTextC(g, p->value, &t2, vf, vt);
        /* chevron */
        FLOAT cx = (FLOAT)(cell.right - GLYPH_ZONE / 2 - 2), cy = (FLOAT)midY;
        g->br->SetColor(CrToD2D(RGB(90, 90, 90)));
        g->rt->DrawLine(D2D1::Point2F(cx - 4, cy - 2), D2D1::Point2F(cx, cy + 2), g->br, 1.6f);
        g->rt->DrawLine(D2D1::Point2F(cx, cy + 2), D2D1::Point2F(cx + 4, cy - 2), g->br, 1.6f);
        break;
    }
    case PGT_SLIDER: {
        double lo = p->lo, hi = p->hi;
        if (hi <= lo) { lo = 0; hi = 100; }
        double v = PropNum(p);
        if (v < lo) v = lo; if (v > hi) v = hi;
        int tx1 = cell.left + CELL_PAD, tx2 = cell.right - 56;
        FLOAT fy = (FLOAT)midY;
        FLOAT fx = (FLOAT)(tx1 + (tx2 - tx1) * (v - lo) / (hi - lo));
        g->br->SetColor(CrToD2D(RGB(200, 205, 212)));
        g->rt->DrawLine(D2D1::Point2F((FLOAT)tx1, fy), D2D1::Point2F((FLOAT)tx2, fy), g->br, 3.0f);
        g->br->SetColor(CrToD2D(ACCENT));
        g->rt->DrawLine(D2D1::Point2F((FLOAT)tx1, fy), D2D1::Point2F(fx, fy), g->br, 3.0f);
        g->rt->FillEllipse(D2D1::Ellipse(D2D1::Point2F(fx, fy), 6, 6), g->br);
        RECT vr = cell; vr.left = cell.right - 52; vr.right -= 4;
        DrawTextC(g, p->value, &vr, vf, vt);
        break;
    }
    case PGT_SPIN: {
        RECT t2 = tr; t2.right = cell.right - GLYPH_ZONE - 2;
        DrawTextC(g, p->value, &t2, vf, vt);
        int zx = cell.right - GLYPH_ZONE;
        VLine(g, zx, cell.top, cell.bottom, g->colors[PGC_LINES]);
        HLine(g, zx, cell.right, midY, g->colors[PGC_LINES]);
        g->br->SetColor(CrToD2D(RGB(90, 90, 90)));
        FLOAT cx = (FLOAT)(zx + GLYPH_ZONE / 2);
        FLOAT q1 = (cell.top + midY) / 2.0f, q2 = (midY + cell.bottom) / 2.0f;
        g->rt->DrawLine(D2D1::Point2F(cx - 3, q1 + 1.5f), D2D1::Point2F(cx, q1 - 1.5f), g->br, 1.4f);
        g->rt->DrawLine(D2D1::Point2F(cx, q1 - 1.5f), D2D1::Point2F(cx + 3, q1 + 1.5f), g->br, 1.4f);
        g->rt->DrawLine(D2D1::Point2F(cx - 3, q2 - 1.5f), D2D1::Point2F(cx, q2 + 1.5f), g->br, 1.4f);
        g->rt->DrawLine(D2D1::Point2F(cx, q2 + 1.5f), D2D1::Point2F(cx + 3, q2 - 1.5f), g->br, 1.4f);
        break;
    }
    case PGT_BUTTON: {
        D2D1_ROUNDED_RECT rr = { D2D1::RectF((FLOAT)cell.left + 3, (FLOAT)cell.top + 2,
            (FLOAT)cell.right - 4, (FLOAT)cell.bottom - 2), 3.0f, 3.0f };
        BOOL pressed = (g->pressedBtn == id);
        g->br->SetColor(CrToD2D(pressed ? RGB(0xC9, 0xD8, 0xEA) : RGB(0xED, 0xF1, 0xF6)));
        g->rt->FillRoundedRectangle(rr, g->br);
        g->br->SetColor(CrToD2D(RGB(0xA9, 0xB6, 0xC6)));
        g->rt->DrawRoundedRectangle(rr, g->br, 1.0f);
        RECT br2 = cell;
        const WCHAR* lbl = (p->value && *p->value) ? p->value : p->name;
        IDWriteTextFormat* fmt = FONT(g, vf)->fmt;
        if (fmt) {
            fmt->SetTextAlignment(DWRITE_TEXT_ALIGNMENT_CENTER);
            DrawTextC(g, lbl, &br2, vf, RGB(0x20, 0x2A, 0x36));
            fmt->SetTextAlignment(DWRITE_TEXT_ALIGNMENT_LEADING);
        }
        break;
    }
    case PGT_COLOR: {
        int sw = 26, sh = (cell.bottom - cell.top) - 8;
        unsigned long x = 0xFFFFFF;
        if (p->value) {
            const WCHAR* v = p->value; if (*v == L'#') v++;
            x = wcstoul(v, NULL, 16);
        }
        D2D1_RECT_F swr = D2D1::RectF((FLOAT)tr.left, (FLOAT)(midY - sh / 2),
            (FLOAT)(tr.left + sw), (FLOAT)(midY + sh - sh / 2));
        g->br->SetColor(D2D1::ColorF(((x >> 16) & 0xFF) / 255.0f,
            ((x >> 8) & 0xFF) / 255.0f, (x & 0xFF) / 255.0f, 1.0f));
        g->rt->FillRectangle(swr, g->br);
        g->br->SetColor(CrToD2D(RGB(120, 120, 120)));
        g->rt->DrawRectangle(swr, g->br, 1.0f);
        RECT t2 = tr; t2.left += sw + 8;
        WCHAR buf[16]; swprintf(buf, 16, L"#%06lX", x & 0xFFFFFF);
        DrawTextC(g, buf, &t2, vf, vt);
        break;
    }
    case PGT_MULTITEXT: {
        RECT t2 = tr; t2.right = cell.right - GLYPH_ZONE - 2;
        if (p->wrapLines && p->value && *p->value) {
            RECT wr = t2; wr.top = cell.top + 4; wr.bottom = cell.bottom - 2;
            DrawTextWrapC(g, p->value, &wr, vf, vt, p->wrapLines);
        } else {
            /* first line only */
            WCHAR line[256]; int i = 0;
            const WCHAR* s = p->value ? p->value : L"";
            while (*s && *s != L'\r' && *s != L'\n' && i < 255) line[i++] = *s++;
            line[i] = 0;
            if (*s) { wcscat_s(line, 256, L" \x2026"); }
            DrawTextC(g, line, &t2, vf, vt);
        }
        int zx = cell.right - GLYPH_ZONE;
        VLine(g, zx, cell.top, cell.bottom, g->colors[PGC_LINES]);
        RECT er = cell; er.left = zx;
        /* on a tall wrapped row keep the glyph on the first line, or it
           centres itself halfway down and reads as part of the text */
        if (p->wrapLines) er.bottom = er.top + FontRowPx(g, vf);
        DrawTextC(g, L"\x2026", &er, vf, RGB(90, 90, 90));
        break;
    }
    default:
        if (p->wrapLines && p->value && *p->value) {
            RECT wr = tr; wr.right = cell.right - CELL_PAD;
            wr.top = cell.top + 4; wr.bottom = cell.bottom - 2;
            DrawTextWrapC(g, p->value, &wr, vf, vt, p->wrapLines);
        } else {
            DrawTextC(g, p->value, &tr, vf, vt);
        }
        break;
    }
}

static void Paint(Grid* g)
{
    if (!EnsureRT(g)) return;
    if (g->visDirty) RebuildVis(g);
    RECT rc; GetClientRect(g->hwnd, &rc);
    int rh = DefRowH(g);
    g->rt->BeginDraw();
    g->rt->Clear(CrToD2D(g->colors[PGC_BACK]));

    int viewBottom = rc.bottom - g->descH;
    int first = VisIndexAtY(g, g->scrollY);
    if (first < 0) first = 0;

    for (int vi = first; vi < g->nVis; vi++) {
        VisItem* it = &g->vis[vi];
        RECT row = { 0, it->y - g->scrollY, rc.right, 0 };
        if (row.top >= viewBottom) break;          /* past the viewport */
        row.bottom = row.top + it->h;
        if (it->isCat) {
            Cat* c = CAT(g, it->id);
            FillRectC(g, &row, g->colors[PGC_CATBACK]);
            /* expand glyph */
            FLOAT cx = 9.0f, cy = (row.top + row.bottom) / 2.0f;
            g->br->SetColor(CrToD2D(g->colors[PGC_CATTEXT]));
            if (c->expanded) {
                g->rt->DrawLine(D2D1::Point2F(cx - 4, cy - 2), D2D1::Point2F(cx, cy + 2), g->br, 1.6f);
                g->rt->DrawLine(D2D1::Point2F(cx, cy + 2), D2D1::Point2F(cx + 4, cy - 2), g->br, 1.6f);
            } else {
                g->rt->DrawLine(D2D1::Point2F(cx - 2, cy - 4), D2D1::Point2F(cx + 2, cy), g->br, 1.6f);
                g->rt->DrawLine(D2D1::Point2F(cx + 2, cy), D2D1::Point2F(cx - 2, cy + 4), g->br, 1.6f);
            }
            RECT tr = row; tr.left = 20;
            DrawTextC(g, c->name, &tr, HdrFontOf(g, c), g->colors[PGC_CATTEXT]);
            if (!(g->style & PGS_TOOLBOXLOOK))
                HLine(g, 0, rc.right, row.bottom - 1, g->colors[PGC_LINES]);
        } else {
            Prop* p = PROP(g, it->id);
            BOOL isSel = (g->sel == it->id);
            RECT nameR = row; nameR.right = g->splitter;
            RECT cell; ValueCell(g, &row, &cell);
            FillRectC(g, &nameR, isSel ? g->colors[PGC_SELBACK] : g->colors[PGC_NAMEBACK]);
            if (isSel) {
                RECT selV = row; selV.left = g->splitter;
                FillRectC(g, &selV, g->colors[PGC_SELBACK]);
            } else if (g->hot == it->id) {
                RECT hotR = row;
                FillRectC(g, &hotR, RGB(0xF3, 0xF6, 0xFA));
                FillRectC(g, &nameR, g->colors[PGC_NAMEBACK]);
            }
            RECT tn = nameR; tn.left += CELL_PAD + (p->cat ? 10 : 4);
            DrawTextC(g, p->name, &tn, NameFontOf(g, p),
                isSel ? g->colors[PGC_SELTEXT] : g->colors[PGC_NAMETEXT]);
            PaintValue(g, p, it->id, cell);
            HLine(g, 0, rc.right, row.bottom - 1, g->colors[PGC_LINES]);
        }
    }
    /* splitter line */
    VLine(g, g->splitter, 0, viewBottom, g->colors[PGC_LINES]);

    /* description pane */
    if (g->descH > 0) {
        RECT dr = { 0, viewBottom, rc.right, rc.bottom };
        FillRectC(g, &dr, g->colors[PGC_DESCBACK]);
        HLine(g, 0, rc.right, viewBottom, g->colors[PGC_LINES]);
        Prop* p = PROP(g, g->sel);
        if (p) {
            RECT t1 = { CELL_PAD, viewBottom + 2, rc.right - CELL_PAD, viewBottom + 2 + rh };
            DrawTextC(g, p->name, &t1, PGF_CATEGORY, g->colors[PGC_DESCTEXT]);
            if (p->desc && *p->desc) {
                IDWriteTextFormat* fmt = g->fonts[PGF_DESC].fmt;
                if (fmt) {
                    fmt->SetWordWrapping(DWRITE_WORD_WRAPPING_WRAP);
                    fmt->SetParagraphAlignment(DWRITE_PARAGRAPH_ALIGNMENT_NEAR);
                    g->br->SetColor(CrToD2D(g->colors[PGC_DESCTEXT]));
                    g->rt->DrawText(p->desc, (UINT32)wcslen(p->desc), fmt,
                        D2D1::RectF((FLOAT)CELL_PAD, (FLOAT)(viewBottom + rh),
                            (FLOAT)(rc.right - CELL_PAD), (FLOAT)rc.bottom),
                        g->br, D2D1_DRAW_TEXT_OPTIONS_CLIP);
                    fmt->SetParagraphAlignment(DWRITE_PARAGRAPH_ALIGNMENT_CENTER);
                    fmt->SetWordWrapping(DWRITE_WORD_WRAPPING_NO_WRAP);
                }
            }
        }
    }

    /* border */
    if (g->style & PGS_BORDER) {
        g->br->SetColor(CrToD2D(RGB(0xB5, 0xBD, 0xC9)));
        g->rt->DrawRectangle(D2D1::RectF(0.5f, 0.5f, rc.right - 0.5f, rc.bottom - 0.5f),
            g->br, 1.0f);
    }

    HRESULT hr = g->rt->EndDraw();
    if (hr == D2DERR_RECREATE_TARGET) DiscardRT(g);
}

/*------------------------------------------------------------------*/
/* interaction                                                      */
/*------------------------------------------------------------------*/
static void SelectProp(Grid* g, int id)
{
    if (g->sel == id) return;
    g->sel = id;
    PushEvent(g, id, PGE_SELECT);
    InvalidateRect(g->hwnd, NULL, FALSE);
}

static void SliderFromX(Grid* g, int id, int x)
{
    Prop* p = PROP(g, id);
    if (!p) return;
    RECT row; if (!PropRowRect(g, id, &row)) return;
    RECT cell; ValueCell(g, &row, &cell);
    int tx1 = cell.left + CELL_PAD, tx2 = cell.right - 56;
    double lo = p->lo, hi = p->hi;
    if (hi <= lo) { lo = 0; hi = 100; }
    double f = (double)(x - tx1) / (double)(tx2 - tx1);
    if (f < 0) f = 0; if (f > 1) f = 1;
    double v = lo + f * (hi - lo);
    Prop tmp = *p; tmp.lo = lo; tmp.hi = hi;
    v = ClampStep(&tmp, v);
    WCHAR old[64]; old[0] = 0;
    if (p->value) wcsncpy_s(old, 64, p->value, _TRUNCATE);
    SetNum(g, p, v);
    if (!p->value || wcscmp(old, p->value) != 0)
        InvalidateRect(g->hwnd, NULL, FALSE);
}

static void SpinStep(Grid* g, int id, int dir)
{
    Prop* p = PROP(g, id);
    if (!p || p->readOnly) return;
    double step = p->step > 0 ? p->step : 1.0;
    double v = PropNum(p) + dir * step;
    v = ClampStep(p, v);
    SetNum(g, p, v);
    ValueChangedByUser(g, id);
}

static void ToggleCheck(Grid* g, int id)
{
    Prop* p = PROP(g, id);
    if (!p || p->readOnly) return;
    BOOL on = p->value && (p->value[0] == L'1' ||
              towupper(p->value[0]) == L'Y' || towupper(p->value[0]) == L'T');
    setStr(&p->value, on ? L"0" : L"1");
    ValueChangedByUser(g, id);
}

static void ActivateProp(Grid* g, int id, int zone, int x, int y)
{
    Prop* p = PROP(g, id);
    if (!p) return;
    switch (p->type) {
    case PGT_CHECK:
        if (zone == ZONE_CHECK || zone == ZONE_VALUE) ToggleCheck(g, id);
        break;
    case PGT_DROP: case PGT_RADIO:
        OpenList(g, id);
        break;
    case PGT_SLIDER:
        if (zone == ZONE_SLIDER && !p->readOnly) {
            g->dragSlider = id;
            SetCapture(g->hwnd);
            SliderFromX(g, id, x);
        } else if (zone == ZONE_VALUE) {
            BeginEdit(g, id, 0);
        }
        break;
    case PGT_SPIN:
        if (zone == ZONE_SPINUP)      SpinStep(g, id, +1);
        else if (zone == ZONE_SPINDN) SpinStep(g, id, -1);
        else                          BeginEdit(g, id, 0);
        break;
    case PGT_BUTTON:
        g->pressedBtn = id;
        SetCapture(g->hwnd);
        InvalidateRect(g->hwnd, NULL, FALSE);
        break;
    case PGT_COLOR:
        PickColor(g, id);
        break;
    case PGT_MULTITEXT:
        if (zone == ZONE_ELLIPSIS) OpenMulti(g, id);
        else BeginEdit(g, id, 0);
        break;
    case PGT_READONLY:
        break;
    default:
        BeginEdit(g, id, 0);
        break;
    }
}

static void KeyNav(Grid* g, int dir)
{
    if (g->visDirty) RebuildVis(g);
    if (!g->nVis) return;
    int vi = g->sel ? VisIndexOfProp(g, g->sel) : -1;
    int i = vi;
    do {
        i += dir;
        if (i < 0 || i >= g->nVis) return;
    } while (g->vis[i].isCat);
    SelectProp(g, g->vis[i].id);
    /* ensure visible */
    RECT rc; GetClientRect(g->hwnd, &rc);
    int view = rc.bottom - g->descH;
    int top = g->vis[i].y, bot = top + g->vis[i].h;
    if (top < g->scrollY) g->scrollY = top;
    if (bot > g->scrollY + view) g->scrollY = bot - view;
    UpdateScroll(g);
    InvalidateRect(g->hwnd, NULL, FALSE);
}

/*------------------------------------------------------------------*/
/* window proc                                                      */
/*------------------------------------------------------------------*/
static LRESULT CALLBACK GridProc(HWND h, UINT m, WPARAM w, LPARAM l)
{
#ifdef PG_DEBUG
    static LONG s_msgCount = 0;
    if (s_msgCount < 400) { InterlockedIncrement(&s_msgCount); dbg("msg %04X w=%08X l=%08X", m, (unsigned)w, (unsigned)l); }
#endif
    Grid* g = (Grid*)GetWindowLongPtrW(h, GWLP_USERDATA);
    switch (m) {
    case WM_NCCREATE:
        g = (Grid*)((CREATESTRUCTW*)l)->lpCreateParams;
        g->hwnd = h;
        SetWindowLongPtrW(h, GWLP_USERDATA, (LONG_PTR)g);
        return TRUE;
    case WM_PAINT: {
        PAINTSTRUCT ps; BeginPaint(h, &ps);
        if (g) Paint(g);
        EndPaint(h, &ps);
        return 0;
    }
    case WM_ERASEBKGND:
        return 1;
    case WM_SIZE:
        if (g) {
            if (g->rt) g->rt->Resize(D2D1::SizeU(LOWORD(l), HIWORD(l)));
            RECT rc; GetClientRect(h, &rc);
            if (g->splitter > rc.right - 60) g->splitter = rc.right - 60;
            if (g->splitter < MIN_SPLIT) g->splitter = MIN_SPLIT;
            /* a wrapped row's height is a function of the cell width,
               so a resize changes the layout, not just the painting */
            if (g->anyWrap) g->visDirty = TRUE;
            UpdateScroll(g);
            InvalidateRect(h, NULL, FALSE);
        }
        return 0;
    case WM_VSCROLL: {
        if (!g) return 0;
        CloseEditors(g, TRUE);
        SCROLLINFO si = { sizeof(si), SIF_ALL };
        GetScrollInfo(h, SB_VERT, &si);
        int pos = g->scrollY, rh = DefRowH(g);
        switch (LOWORD(w)) {
        case SB_LINEUP:   pos -= rh; break;
        case SB_LINEDOWN: pos += rh; break;
        case SB_PAGEUP:   pos -= (int)si.nPage; break;
        case SB_PAGEDOWN: pos += (int)si.nPage; break;
        case SB_THUMBTRACK: case SB_THUMBPOSITION: pos = si.nTrackPos; break;
        case SB_TOP:      pos = 0; break;
        case SB_BOTTOM:   pos = si.nMax; break;
        }
        if (pos < 0) pos = 0;
        int maxp = si.nMax - (int)si.nPage + 1; if (maxp < 0) maxp = 0;
        if (pos > maxp) pos = maxp;
        if (pos != g->scrollY) {
            g->scrollY = pos;
            UpdateScroll(g);
            InvalidateRect(h, NULL, FALSE);
        }
        return 0;
    }
    case WM_MOUSEWHEEL: {
        if (!g) return 0;
        CloseEditors(g, TRUE);
        int delta = GET_WHEEL_DELTA_WPARAM(w);
        g->scrollY -= (delta / WHEEL_DELTA) * 3 * DefRowH(g);
        if (g->scrollY < 0) g->scrollY = 0;
        UpdateScroll(g);
        InvalidateRect(h, NULL, FALSE);
        return 0;
    }
    case WM_LBUTTONDOWN: {
        if (!g) return 0;
        SetFocus(h);
        int x = GET_X_LPARAM(l), y = GET_Y_LPARAM(l);
        int zone; int id = HitTest(g, x, y, &zone);
        if (zone == ZONE_SPLIT) {
            CloseEditors(g, TRUE);
            g->dragSplit = TRUE;
            SetCapture(h);
            return 0;
        }
        if (id < 0) {                     /* category header */
            Cat* c = CAT(g, -id);
            if (c) { c->expanded = !c->expanded; CloseEditors(g, TRUE); Dirty(g); }
            return 0;
        }
        if (id > 0) {
            CloseEditors(g, TRUE);
            SelectProp(g, id);
            if (zone != ZONE_NAME) ActivateProp(g, id, zone, x, y);
        }
        return 0;
    }
    case WM_LBUTTONDBLCLK: {
        if (!g) return 0;
        int x = GET_X_LPARAM(l), y = GET_Y_LPARAM(l);
        int zone; int id = HitTest(g, x, y, &zone);
        if (id > 0) {
            PushEvent(g, id, PGE_DBLCLICK);
            Prop* p = PROP(g, id);
            if (p && zone == ZONE_NAME) {
                /* double-click the name toggles/edits like VS */
                if (p->type == PGT_CHECK) ToggleCheck(g, id);
                else ActivateProp(g, id, ZONE_VALUE, x, y);
            }
        } else if (id < 0) {
            Cat* c = CAT(g, -id);
            if (c) { c->expanded = !c->expanded; Dirty(g); }
        }
        return 0;
    }
    case WM_MOUSEMOVE: {
        if (!g) return 0;
        int x = GET_X_LPARAM(l), y = GET_Y_LPARAM(l);
        if (g->dragSplit) {
            RECT rc; GetClientRect(h, &rc);
            int s = x;
            if (s < MIN_SPLIT) s = MIN_SPLIT;
            if (s > rc.right - 60) s = rc.right - 60;
            if (s != g->splitter) {
                g->splitter = s;
                if (g->anyWrap) {          /* narrower cell, taller rows */
                    g->visDirty = TRUE;
                    UpdateScroll(g);
                }
                InvalidateRect(h, NULL, FALSE);
            }
            return 0;
        }
        if (g->dragSlider) { SliderFromX(g, g->dragSlider, x); return 0; }
        int zone; int id = HitTest(g, x, y, &zone);
        int hot = id > 0 ? id : 0;
        if (hot != g->hot || zone != g->hotZone) {
            g->hot = hot; g->hotZone = zone;
            InvalidateRect(h, NULL, FALSE);
        }
        TRACKMOUSEEVENT tme = { sizeof(tme), TME_LEAVE, h, 0 };
        TrackMouseEvent(&tme);
        return 0;
    }
    case WM_MOUSELEAVE:
        if (g && g->hot) { g->hot = 0; InvalidateRect(h, NULL, FALSE); }
        return 0;
    case WM_LBUTTONUP: {
        if (!g) return 0;
        if (g->dragSplit) { g->dragSplit = FALSE; ReleaseCapture(); return 0; }
        if (g->dragSlider) {
            int id = g->dragSlider;
            g->dragSlider = 0;
            ReleaseCapture();
            ValueChangedByUser(g, id);
            return 0;
        }
        if (g->pressedBtn) {
            int id = g->pressedBtn;
            g->pressedBtn = 0;
            ReleaseCapture();
            int zone; int hit = HitTest(g, GET_X_LPARAM(l), GET_Y_LPARAM(l), &zone);
            InvalidateRect(h, NULL, FALSE);
            if (hit == id && zone == ZONE_BUTTON) PushEvent(g, id, PGE_BUTTON);
            return 0;
        }
        return 0;
    }
    case WM_SETCURSOR: {
        if (g && LOWORD(l) == HTCLIENT) {
            POINT pt; GetCursorPos(&pt); ScreenToClient(h, &pt);
            int zone; HitTest(g, pt.x, pt.y, &zone);
            if (zone == ZONE_SPLIT || g->dragSplit) {
                SetCursor(LoadCursorW(NULL, IDC_SIZEWE));
                return TRUE;
            }
        }
        break;
    }
    case WM_GETDLGCODE:
        return DLGC_WANTARROWS | DLGC_WANTCHARS;
    case WM_SETFOCUS:
        if (g) { g->focus = TRUE; InvalidateRect(h, NULL, FALSE); }
        return 0;
    case WM_KILLFOCUS:
        if (g) { g->focus = FALSE; InvalidateRect(h, NULL, FALSE); }
        return 0;
    case WM_KEYDOWN: {
        if (!g) return 0;
        Prop* p = PROP(g, g->sel);
        switch (w) {
        case VK_UP:    KeyNav(g, -1); return 0;
        case VK_DOWN:  KeyNav(g, +1); return 0;
        case VK_PRIOR: { int n = 1; RECT rc; GetClientRect(h, &rc);
                         n = (rc.bottom - g->descH) / DefRowH(g);
                         if (n < 1) n = 1;
                         for (int i = 0; i < n; i++) KeyNav(g, -1); return 0; }
        case VK_NEXT:  { int n = 1; RECT rc; GetClientRect(h, &rc);
                         n = (rc.bottom - g->descH) / DefRowH(g);
                         if (n < 1) n = 1;
                         for (int i = 0; i < n; i++) KeyNav(g, +1); return 0; }
        case VK_LEFT:
            if (p && p->type == PGT_SLIDER) { SpinStep(g, g->sel, -1); return 0; }
            if (p && p->type == PGT_SPIN)   { SpinStep(g, g->sel, -1); return 0; }
            break;
        case VK_RIGHT:
            if (p && (p->type == PGT_SLIDER || p->type == PGT_SPIN)) {
                SpinStep(g, g->sel, +1); return 0;
            }
            break;
        case VK_SPACE:
            if (p) {
                if (p->type == PGT_CHECK)  { ToggleCheck(g, g->sel); return 0; }
                if (p->type == PGT_BUTTON) { PushEvent(g, g->sel, PGE_BUTTON); return 0; }
            }
            break;
        case VK_RETURN: case VK_F2:
            if (p) ActivateProp(g, g->sel, ZONE_VALUE, 0, 0);
            return 0;
        }
        return 0;
    }
    case WM_CHAR: {
        if (!g) return 0;
        Prop* p = PROP(g, g->sel);
        if (p && w >= 32 && (p->type == PGT_TEXT || p->type == PGT_PASSWORD ||
            p->type == PGT_DATE || p->type == PGT_TIME ||
            p->type == PGT_SPIN || p->type == PGT_MULTITEXT))
            BeginEdit(g, g->sel, (WCHAR)w);
        return 0;
    }
    case WM_DESTROY:
        return 0;
    }
    return DefWindowProcW(h, m, w, l);
}

/*==================================================================*/
/* exported API                                                     */
/*==================================================================*/
extern "C" {

int PGAPI PG_Initialize(void)
{
    dbg("PG_Initialize enter count=%ld", g_initCount);
    if (InterlockedIncrement(&g_initCount) > 1) return 1;
    HRESULT hr = D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED,
        __uuidof(ID2D1Factory), NULL, (void**)&g_d2d);
    if (FAILED(hr)) { g_initCount = 0; return 0; }
    hr = DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED,
        __uuidof(IDWriteFactory), (IUnknown**)&g_dw);
    if (FAILED(hr)) { g_d2d->Release(); g_d2d = NULL; g_initCount = 0; return 0; }
    WNDCLASSW wc = { 0 };
    wc.style = CS_DBLCLKS | CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc = GridProc;
    wc.hInstance = GetModuleHandleW(NULL);
    wc.hCursor = LoadCursorW(NULL, IDC_ARROW);
    wc.lpszClassName = PG_CLASSNAME;
    g_atom = RegisterClassW(&wc);
    INITCOMMONCONTROLSEX icc = { sizeof(icc), ICC_STANDARD_CLASSES };
    InitCommonControlsEx(&icc);
    return 1;
}

void PGAPI PG_Shutdown(void)
{
    if (InterlockedDecrement(&g_initCount) > 0) return;
    if (g_atom) { UnregisterClassW(PG_CLASSNAME, GetModuleHandleW(NULL)); g_atom = 0; }
    if (g_dw)  { g_dw->Release();  g_dw = NULL; }
    if (g_d2d) { g_d2d->Release(); g_d2d = NULL; }
    if (g_initCount < 0) g_initCount = 0;
}

HPG PGAPI PG_Create(HWND hwndParent, int x, int y, int w, int h,
                    unsigned long style)
{
    dbg("PG_Create enter parent=%p xywh=%d,%d,%d,%d style=%lu", hwndParent, x, y, w, h, style);
    if (!g_d2d && !PG_Initialize()) return NULL;
    Grid* g = (Grid*)calloc(1, sizeof(Grid));
    if (!g) return NULL;
    g->style = style;
    g->splitter = w > 0 ? w * 2 / 5 : 120;
    if (g->splitter < MIN_SPLIT) g->splitter = MIN_SPLIT;
    g->sel = 0;
    /* default professional palette (no purple) */
    g->colors[PGC_BACK]      = RGB(0xFF, 0xFF, 0xFF);
    g->colors[PGC_NAMEBACK]  = RGB(0xF5, 0xF6, 0xF8);
    g->colors[PGC_NAMETEXT]  = RGB(0x20, 0x25, 0x2B);
    g->colors[PGC_VALUETEXT] = RGB(0x20, 0x25, 0x2B);
    g->colors[PGC_CATBACK]   = RGB(0xE4, 0xE9, 0xF0);
    g->colors[PGC_CATTEXT]   = RGB(0x2C, 0x3A, 0x4F);
    g->colors[PGC_LINES]     = RGB(0xDD, 0xE1, 0xE6);
    g->colors[PGC_SELBACK]   = RGB(0xD6, 0xE4, 0xF5);
    g->colors[PGC_SELTEXT]   = RGB(0x14, 0x1A, 0x21);
    g->colors[PGC_DESCBACK]  = RGB(0xF0, 0xF2, 0xF5);
    g->colors[PGC_DESCTEXT]  = RGB(0x3A, 0x42, 0x4C);
    /* default fonts - slots 1..4, extras appended by PG_AddFont */
    g->capFonts = 8;
    g->fonts = (FontSpec*)calloc(g->capFonts, sizeof(FontSpec));
    if (!g->fonts) { free(g); return NULL; }
    g->nFonts = PGF_FIRSTEXTRA;               /* 1..4 in use, next is 5 */
    for (int i = PGF_NAME; i <= PGF_DESC; i++) {
        wcscpy_s(g->fonts[i].face, 64, L"Segoe UI");
        g->fonts[i].sizePt = 9.0f;
    }
    g->fonts[PGF_CATEGORY].bold = TRUE;
    g->hEditFontId = -1;
    g->descH = (style & PGS_DESCRIPTION) ? 52 : 0;
    HWND hw = CreateWindowExW(0, PG_CLASSNAME, L"",
        WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS | WS_VSCROLL | WS_TABSTOP,
        x, y, w, h, hwndParent, NULL, GetModuleHandleW(NULL), g);
    if (!hw) { free(g->fonts); free(g); return NULL; }
    /* Clarion SHEET/TAB and other native siblings can sit above us in the
       z-order and paint over the grid - pin it to the top of its siblings */
    SetWindowPos(hw, HWND_TOP, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    g->dpi = WindowDpi(hw);
    for (int i = PGF_NAME; i <= PGF_DESC; i++) RebuildFormat(g, i);
    RebuildEditFont(g, PGF_VALUE);
    dbg("PG_Create exit hwnd=%p g=%p dpi=%u", hw, g, g->dpi);
    return (HPG)g;
}

void PGAPI PG_Destroy(HPG pg)
{
    Grid* g = (Grid*)pg;
    if (!g) return;
    CloseEditors(g, FALSE);
    DiscardRT(g);
    if (g->hwnd) {
        SetWindowLongPtrW(g->hwnd, GWLP_USERDATA, 0);
        DestroyWindow(g->hwnd);
    }
    for (int i = 0; i < g->nProps; i++) {
        free(g->props[i].name);  free(g->props[i].value);
        free(g->props[i].choices); free(g->props[i].desc);
    }
    for (int i = 0; i < g->nCats; i++) free(g->cats[i].name);
    free(g->props); free(g->cats); free(g->vis);
    for (int i = PGF_NAME; i < g->nFonts; i++)
        if (g->fonts[i].fmt) g->fonts[i].fmt->Release();
    free(g->fonts);
    if (g->hEditFont) DeleteObject(g->hEditFont);
    free(g);
}

void PGAPI PG_SetPos(HPG pg, int x, int y, int w, int h)
{
    Grid* g = (Grid*)pg;
    if (!g || !g->hwnd) return;
    CloseEditors(g, TRUE);
    SetWindowPos(g->hwnd, HWND_TOP, x, y, w, h, SWP_NOACTIVATE);
}

HWND PGAPI PG_GetHwnd(HPG pg)
{
    Grid* g = (Grid*)pg;
    return g ? g->hwnd : NULL;
}

void PGAPI PG_SetFont(HPG pg, int part, const char* face, int sizePt,
                      int bold, int italic)
{
    Grid* g = (Grid*)pg;
    if (!g || part < PGF_NAME || part > PGF_DESC) return;
    FontSpec* f = &g->fonts[part];
    if (face && *face) {
        WCHAR* w = a2w(face);
        if (w) { wcsncpy_s(f->face, 64, w, _TRUNCATE); free(w); }
    }
    if (sizePt > 0) f->sizePt = (float)sizePt;
    f->bold = bold ? TRUE : FALSE;
    f->italic = italic ? TRUE : FALSE;
    RebuildFormat(g, part);
    if (part == PGF_VALUE) RebuildEditFont(g, PGF_VALUE);
    if (g->hwnd) { Dirty(g); }          /* the size changed row heights */
}

/*------------------------------------------------------------------*/
/* per-category / per-row fonts                                      */
/*------------------------------------------------------------------*/
int PGAPI PG_AddFont(HPG pg, const char* face, int sizePt,
                     int bold, int italic)
{
    Grid* g = (Grid*)pg;
    if (!g || !g->fonts) return 0;
    WCHAR wface[64];
    wcscpy_s(wface, 64, g->fonts[PGF_VALUE].face);      /* inherit face */
    if (face && *face) {
        WCHAR* w = a2w(face);
        if (w) { wcsncpy_s(wface, 64, w, _TRUNCATE); free(w); }
    }
    float pt = sizePt > 0 ? (float)sizePt : g->fonts[PGF_VALUE].sizePt;
    BOOL b = bold ? TRUE : FALSE, i2 = italic ? TRUE : FALSE;
    /* de-dupe: the same font asked for twice is the same id, so a
       caller may call this once per row without growing the table */
    for (int i = PGF_NAME; i < g->nFonts; i++) {
        FontSpec* f = &g->fonts[i];
        if (f->sizePt == pt && f->bold == b && f->italic == i2 &&
            _wcsicmp(f->face, wface) == 0)
            return i;
    }
    if (g->nFonts == g->capFonts) {
        int cap = g->capFonts ? g->capFonts * 2 : 8;
        FontSpec* nf = (FontSpec*)realloc(g->fonts, cap * sizeof(FontSpec));
        if (!nf) return 0;
        memset(nf + g->capFonts, 0, (cap - g->capFonts) * sizeof(FontSpec));
        g->fonts = nf; g->capFonts = cap;
    }
    int id = g->nFonts++;
    FontSpec* f = &g->fonts[id];
    memset(f, 0, sizeof(*f));
    wcscpy_s(f->face, 64, wface);
    f->sizePt = pt; f->bold = b; f->italic = i2;
    RebuildFormat(g, id);
    return id;
}

/* id of an existing category by name, 0 when there is no such header.
   AddCategory would CREATE one on a typo; this never does, which is
   what a "style the category called X" call wants. */
int PGAPI PG_FindCategory(HPG pg, const char* name)
{
    Grid* g = (Grid*)pg;
    if (!g || !name) return 0;
    WCHAR* w = a2w(name);
    if (!w) return 0;
    int found = 0;
    for (int i = 0; i < g->nCats; i++) {
        if (g->cats[i].name && _wcsicmp(g->cats[i].name, w) == 0) {
            found = i + 1; break;
        }
    }
    free(w);
    return found;
}

int PGAPI PG_GetFontCount(HPG pg)
{
    Grid* g = (Grid*)pg;
    return g ? g->nFonts - 1 : 0;          /* highest valid font id */
}

int PGAPI PG_GetFont(HPG pg, int fontId, char* faceBuf, int bufLen,
                     int* sizePt, int* bold, int* italic)
{
    Grid* g = (Grid*)pg;
    if (!g || !FontOk(g, fontId)) return 0;
    FontSpec* f = &g->fonts[fontId];
    if (faceBuf && bufLen > 0) w2a(f->face, faceBuf, bufLen);
    if (sizePt) *sizePt = (int)(f->sizePt + 0.5f);
    if (bold)   *bold   = f->bold   ? 1 : 0;
    if (italic) *italic = f->italic ? 1 : 0;
    return 1;
}

void PGAPI PG_SetCatFont(HPG pg, int category, int hdrFont,
                         int nameFont, int valueFont)
{
    Grid* g = (Grid*)pg;
    Cat* c = g ? CAT(g, category) : NULL;
    if (!c) return;
    c->fontHdr   = FontOk(g, hdrFont)   ? hdrFont   : 0;
    c->fontName  = FontOk(g, nameFont)  ? nameFont  : 0;
    c->fontValue = FontOk(g, valueFont) ? valueFont : 0;
    if (g->hwnd) Dirty(g);
}

int PGAPI PG_GetCatFont(HPG pg, int category, int* hdrFont,
                        int* nameFont, int* valueFont)
{
    Grid* g = (Grid*)pg;
    Cat* c = g ? CAT(g, category) : NULL;
    if (!c) return 0;
    if (hdrFont)   *hdrFont   = c->fontHdr;
    if (nameFont)  *nameFont  = c->fontName;
    if (valueFont) *valueFont = c->fontValue;
    return 1;
}

void PGAPI PG_SetRowFont(HPG pg, int row, int nameFont, int valueFont)
{
    Grid* g = (Grid*)pg;
    Prop* p = g ? PROP(g, row) : NULL;
    if (!p) return;
    p->fontName  = FontOk(g, nameFont)  ? nameFont  : 0;
    p->fontValue = FontOk(g, valueFont) ? valueFont : 0;
    if (g->hwnd) Dirty(g);
}

int PGAPI PG_GetRowFont(HPG pg, int row, int* nameFont, int* valueFont)
{
    Grid* g = (Grid*)pg;
    Prop* p = g ? PROP(g, row) : NULL;
    if (!p) return 0;
    if (nameFont)  *nameFont  = p->fontName;
    if (valueFont) *valueFont = p->fontValue;
    return 1;
}

/* one-call: register (or reuse) the font and hang it on the row */
int PGAPI PG_SetRowFontFace(HPG pg, int row, int which, const char* face,
                            int sizePt, int bold, int italic)
{
    Grid* g = (Grid*)pg;
    Prop* p = g ? PROP(g, row) : NULL;
    if (!p) return 0;
    int id = PG_AddFont(pg, face, sizePt, bold, italic);
    if (!id) return 0;
    if (which == PGF_NAME)       p->fontName  = id;
    else if (which == PGF_VALUE) p->fontValue = id;
    else return 0;
    if (g->hwnd) Dirty(g);
    return id;
}

int PGAPI PG_SetCatFontFace(HPG pg, int category, int which, const char* face,
                            int sizePt, int bold, int italic)
{
    Grid* g = (Grid*)pg;
    Cat* c = g ? CAT(g, category) : NULL;
    if (!c) return 0;
    int id = PG_AddFont(pg, face, sizePt, bold, italic);
    if (!id) return 0;
    if (which == PGF_NAME)          c->fontName  = id;
    else if (which == PGF_VALUE)    c->fontValue = id;
    else if (which == PGF_CATEGORY) c->fontHdr   = id;
    else return 0;
    if (g->hwnd) Dirty(g);
    return id;
}

void PGAPI PG_SetRowWrap(HPG pg, int row, int maxLines)
{
    Grid* g = (Grid*)pg;
    Prop* p = g ? PROP(g, row) : NULL;
    if (!p) return;
    if (maxLines < 0) maxLines = WRAP_MAXLINES;
    if (maxLines > WRAP_MAXLINES) maxLines = WRAP_MAXLINES;
    p->wrapLines = maxLines;
    if (g->hwnd) Dirty(g);
}

int PGAPI PG_GetRowWrap(HPG pg, int row)
{
    Grid* g = (Grid*)pg;
    Prop* p = g ? PROP(g, row) : NULL;
    return p ? p->wrapLines : 0;
}

int PGAPI PG_GetRowHeight(HPG pg, int row)
{
    Grid* g = (Grid*)pg;
    if (!g || !PROP(g, row)) return 0;
    if (g->visDirty) RebuildVis(g);
    int vi = VisIndexOfProp(g, row);
    return vi >= 0 ? g->vis[vi].h : 0;
}

void PGAPI PG_SetColor(HPG pg, int slot, COLORREF color)
{
    Grid* g = (Grid*)pg;
    if (!g || slot < PGC_BACK || slot > PGC_DESCTEXT) return;
    g->colors[slot] = color & 0x00FFFFFF;
    if (g->hwnd) InvalidateRect(g->hwnd, NULL, FALSE);
}

void PGAPI PG_SetRowHeight(HPG pg, int px)
{
    Grid* g = (Grid*)pg;
    if (!g) return;
    g->rowH = px;
    if (g->hwnd) Dirty(g);
}

void PGAPI PG_SetSplitter(HPG pg, int px)
{
    Grid* g = (Grid*)pg;
    if (!g) return;
    if (px < MIN_SPLIT) px = MIN_SPLIT;
    g->splitter = px;
    if (g->hwnd) InvalidateRect(g->hwnd, NULL, FALSE);
}

int PGAPI PG_GetSplitter(HPG pg)
{
    Grid* g = (Grid*)pg;
    return g ? g->splitter : 0;
}

void PGAPI PG_Clear(HPG pg)
{
    Grid* g = (Grid*)pg;
    if (!g) return;
    CloseEditors(g, FALSE);
    for (int i = 0; i < g->nProps; i++) {
        free(g->props[i].name);  free(g->props[i].value);
        free(g->props[i].choices); free(g->props[i].desc);
    }
    for (int i = 0; i < g->nCats; i++) free(g->cats[i].name);
    g->nProps = g->nCats = 0;
    g->sel = g->hot = 0;
    g->scrollY = 0;
    Dirty(g);
}

int PGAPI PG_AddCategory(HPG pg, const char* name)
{
    Grid* g = (Grid*)pg;
    if (!g) return 0;
    if (g->nCats == g->capCats) {
        g->capCats = g->capCats ? g->capCats * 2 : 8;
        g->cats = (Cat*)realloc(g->cats, g->capCats * sizeof(Cat));
    }
    Cat* c = &g->cats[g->nCats];
    memset(c, 0, sizeof(*c));
    c->name = a2w(name);
    c->expanded = TRUE;
    g->nCats++;
    Dirty(g);
    return g->nCats;
}

int PGAPI PG_AddProperty(HPG pg, int category, const char* name,
                         int type, const char* value)
{
    Grid* g = (Grid*)pg;
    if (!g) return 0;
    if (type < PGT_TEXT || type > PGT_MULTITEXT) type = PGT_TEXT;
    if (g->nProps == g->capProps) {
        g->capProps = g->capProps ? g->capProps * 2 : 32;
        g->props = (Prop*)realloc(g->props, g->capProps * sizeof(Prop));
    }
    Prop* p = &g->props[g->nProps];
    memset(p, 0, sizeof(*p));
    p->cat = (category >= 1 && category <= g->nCats) ? category : 0;
    p->type = type;
    p->name = a2w(name);
    p->value = a2w(value);
    g->nProps++;
    if (!g->sel && type != PGT_READONLY) g->sel = g->nProps;
    Dirty(g);
    return g->nProps;
}

void PGAPI PG_SetChoices(HPG pg, int row, const char* choices)
{
    Grid* g = (Grid*)pg;
    Prop* p = g ? PROP(g, row) : NULL;
    if (!p) return;
    WCHAR* w = a2w(choices);
    free(p->choices); p->choices = w;
    if (g->hwnd) InvalidateRect(g->hwnd, NULL, FALSE);
}

void PGAPI PG_SetRange(HPG pg, int row, double lo, double hi, double step)
{
    Grid* g = (Grid*)pg;
    Prop* p = g ? PROP(g, row) : NULL;
    if (!p) return;
    p->lo = lo; p->hi = hi; p->step = step;
    if (g->hwnd) InvalidateRect(g->hwnd, NULL, FALSE);
}

void PGAPI PG_SetDescription(HPG pg, int row, const char* text)
{
    Grid* g = (Grid*)pg;
    Prop* p = g ? PROP(g, row) : NULL;
    if (!p) return;
    WCHAR* w = a2w(text);
    free(p->desc); p->desc = w;
    if (g->hwnd) InvalidateRect(g->hwnd, NULL, FALSE);
}

void PGAPI PG_SetReadOnly(HPG pg, int row, int readOnly)
{
    Grid* g = (Grid*)pg;
    Prop* p = g ? PROP(g, row) : NULL;
    if (!p) return;
    p->readOnly = readOnly ? TRUE : FALSE;
    if (g->hwnd) InvalidateRect(g->hwnd, NULL, FALSE);
}

void PGAPI PG_SetExpanded(HPG pg, int category, int expanded)
{
    Grid* g = (Grid*)pg;
    Cat* c = g ? CAT(g, category) : NULL;
    if (!c) return;
    c->expanded = expanded ? TRUE : FALSE;
    Dirty(g);
}

void PGAPI PG_SetTag(HPG pg, int row, long tag)
{
    Grid* g = (Grid*)pg;
    Prop* p = g ? PROP(g, row) : NULL;
    if (p) p->tag = tag;
}

long PGAPI PG_GetTag(HPG pg, int row)
{
    Grid* g = (Grid*)pg;
    Prop* p = g ? PROP(g, row) : NULL;
    return p ? p->tag : 0;
}

void PGAPI PG_SetValue(HPG pg, int row, const char* value)
{
    Grid* g = (Grid*)pg;
    Prop* p = g ? PROP(g, row) : NULL;
    if (!p) return;
    if (g->editProp == row) CommitEdit(g, FALSE);
    WCHAR* w = a2w(value);
    free(p->value); p->value = w;
    /* a wrapped row is as tall as its text, so new text = new layout */
    if (g->hwnd) {
        if (p->wrapLines) Dirty(g);
        else InvalidateRect(g->hwnd, NULL, FALSE);
    }
}

int PGAPI PG_GetValue(HPG pg, int row, char* buf, int bufLen)
{
    Grid* g = (Grid*)pg;
    Prop* p = g ? PROP(g, row) : NULL;
    if (!p || !buf || bufLen <= 0) return 0;
    /* live edit in progress? return the editor's current text */
    if (g->editProp == row && g->hEdit) {
        WCHAR tmp[4096];
        GetWindowTextW(g->hEdit, tmp, 4096);
        return w2a(tmp, buf, bufLen);
    }
    return w2a(p->value, buf, bufLen);
}

int PGAPI PG_GetRowCount(HPG pg)
{
    Grid* g = (Grid*)pg;
    return g ? g->nProps : 0;
}

int PGAPI PG_FindRow(HPG pg, const char* name)
{
    Grid* g = (Grid*)pg;
    if (!g || !name) return 0;
    WCHAR* w = a2w(name);
    int found = 0;
    for (int i = 0; i < g->nProps; i++) {
        if (g->props[i].name && _wcsicmp(g->props[i].name, w) == 0) {
            found = i + 1; break;
        }
    }
    free(w);
    return found;
}

int PGAPI PG_GetSelected(HPG pg)
{
    Grid* g = (Grid*)pg;
    return g ? g->sel : 0;
}

int PGAPI PG_PollEvent(HPG pg, int* row, int* evType)
{
    Grid* g = (Grid*)pg;
    if (!g || g->evHead == g->evTail) return 0;
    if (row)    *row    = g->evq[g->evHead].row;
    if (evType) *evType = g->evq[g->evHead].type;
    g->evHead = (g->evHead + 1) % MAX_EVQ;
    return 1;
}

void PGAPI PG_SetCallback(HPG pg, PG_EVENTPROC proc, long userData)
{
    Grid* g = (Grid*)pg;
    if (!g) return;
    g->cb = proc; g->cbUser = userData;
}

void PGAPI PG_Redraw(HPG pg)
{
    Grid* g = (Grid*)pg;
    if (g && g->hwnd) { UpdateScroll(g); InvalidateRect(g->hwnd, NULL, FALSE); }
}

} /* extern "C" */

BOOL WINAPI DllMain(HINSTANCE, DWORD, LPVOID) { return TRUE; }
