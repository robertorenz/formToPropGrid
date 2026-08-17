/* testhost.c - tiny Win32 host to exercise PROPGRID.DLL visually */
#define UNICODE
#define _UNICODE
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include "propgrid.h"

static HPG g_pg;

static LRESULT CALLBACK WndProc(HWND h, UINT m, WPARAM w, LPARAM l)
{
    switch (m) {
    case WM_SIZE:
        if (g_pg) {
            RECT rc; GetClientRect(h, &rc);
            PG_SetPos(g_pg, 8, 8, rc.right - 16, rc.bottom - 16);
        }
        return 0;
    case WM_TIMER: {
        int row, ev;
        while (PG_PollEvent(g_pg, &row, &ev)) {
            char buf[256], val[128];
            PG_GetValue(g_pg, row, val, sizeof(val));
            wsprintfA(buf, "PropGrid test  [row %d ev %d = %s]", row, ev, val);
            SetWindowTextA(h, buf);
        }
        return 0;
    }
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(h, m, w, l);
}

int WINAPI WinMain(HINSTANCE hInst, HINSTANCE hPrev, LPSTR cmd, int show)
{
    WNDCLASSW wc = { 0 };
    wc.lpfnWndProc = WndProc;
    wc.hInstance = hInst;
    wc.hCursor = LoadCursorW(NULL, IDC_ARROW);
    wc.hbrBackground = (HBRUSH)(COLOR_BTNFACE + 1);
    wc.lpszClassName = L"PGTestHost";
    RegisterClassW(&wc);
    HWND h = CreateWindowExW(0, L"PGTestHost", L"PropGrid test",
        WS_OVERLAPPEDWINDOW | WS_VISIBLE,
        CW_USEDEFAULT, CW_USEDEFAULT, 460, 620, NULL, NULL, hInst, NULL);

    PG_Initialize();
    RECT rc; GetClientRect(h, &rc);
    g_pg = PG_Create(h, 8, 8, rc.right - 16, rc.bottom - 16,
                     PGS_BORDER | PGS_DESCRIPTION);

    int cGen = PG_AddCategory(g_pg, "General");
    int r;
    r = PG_AddProperty(g_pg, cGen, "Name", PGT_TEXT, "Widget Alpha");
    PG_SetDescription(g_pg, r, "The display name of the widget.");
    r = PG_AddProperty(g_pg, cGen, "Password", PGT_PASSWORD, "secret");
    r = PG_AddProperty(g_pg, cGen, "Enabled", PGT_CHECK, "1");
    r = PG_AddProperty(g_pg, cGen, "Kind", PGT_DROP, "Standard");
    PG_SetChoices(g_pg, r, "Standard|Advanced|Custom|Legacy");
    r = PG_AddProperty(g_pg, cGen, "Alignment", PGT_RADIO, "Left");
    PG_SetChoices(g_pg, r, "Left|Center|Right");
    r = PG_AddProperty(g_pg, cGen, "Notes", PGT_MULTITEXT, "First line\r\nSecond line");

    /* ---- wrapped, self-sizing rows -------------------------------- */
    r = PG_AddProperty(g_pg, cGen, "Long note", PGT_MULTITEXT,
        "This value is far too long for one line, so the row wraps it "
        "over as many lines as it needs and pushes everything below it "
        "further down the grid.  Drag the splitter and watch it re-flow.");
    PG_SetRowWrap(g_pg, r, -1);            /* as many lines as it takes */
    PG_SetDescription(g_pg, r, "Wrapped row, unlimited lines.");
    r = PG_AddProperty(g_pg, cGen, "Capped note", PGT_READONLY,
        "A read-only note capped at two lines: the rest is clipped, but "
        "the two lines it does show are laid out properly rather than "
        "trimmed to a single line with an ellipsis.");
    PG_SetRowWrap(g_pg, r, 2);             /* at most two lines */

    int cNum = PG_AddCategory(g_pg, "Numbers");
    r = PG_AddProperty(g_pg, cNum, "Opacity", PGT_SLIDER, "75");
    PG_SetRange(g_pg, r, 0, 100, 5);
    PG_SetDescription(g_pg, r, "Drag the slider or type a value.");
    r = PG_AddProperty(g_pg, cNum, "Count", PGT_SPIN, "3");
    PG_SetRange(g_pg, r, 0, 50, 1);
    r = PG_AddProperty(g_pg, cNum, "Ratio", PGT_SPIN, "0.5");
    PG_SetRange(g_pg, r, 0, 1, 0.05);

    int cMisc = PG_AddCategory(g_pg, "Appearance");
    r = PG_AddProperty(g_pg, cMisc, "Fore color", PGT_COLOR, "3D6DA8");
    r = PG_AddProperty(g_pg, cMisc, "Created", PGT_DATE, "16/08/2026");
    r = PG_AddProperty(g_pg, cMisc, "Start time", PGT_TIME, "09:30");
    r = PG_AddProperty(g_pg, cMisc, "Version", PGT_READONLY, "1.0.0");
    r = PG_AddProperty(g_pg, 0, "Apply now", PGT_BUTTON, "Apply");

    /* ---- per-category and per-row fonts --------------------------- */
    /* the whole "Numbers" category in a mono value font ...           */
    int fMono = PG_AddFont(g_pg, "Consolas", 10, 0, 0);
    PG_SetCatFont(g_pg, cNum, PGF_INHERIT, PGF_INHERIT, fMono);
    /* ... a bigger header on "Appearance" ...                         */
    PG_SetCatFontFace(g_pg, cMisc, PGF_CATEGORY, "Segoe UI", 13, 1, 0);
    /* ... and one single row shouting in 14pt bold italic.            */
    int rBig = PG_FindRow(g_pg, "Name");
    PG_SetRowFontFace(g_pg, rBig, PGF_VALUE, "Georgia", 14, 1, 1);

    /* read every one of them back out again */
    {
        char face[64]; int pt = 0, bold = 0, ital = 0, nf = 0, vf = 0;
        PG_GetRowFont(g_pg, rBig, &nf, &vf);
        PG_GetFont(g_pg, vf, face, sizeof(face), &pt, &bold, &ital);
        char buf[256];
        wsprintfA(buf, "PropGrid test  [row %d value font: %s %dpt b=%d i=%d,"
                       " %d fonts, row is %d px]",
                  rBig, face, pt, bold, ital,
                  PG_GetFontCount(g_pg), PG_GetRowHeight(g_pg, rBig));
        SetWindowTextA(h, buf);
    }

    SetTimer(h, 1, 100, NULL);

    MSG msg;
    while (GetMessageW(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
    PG_Destroy(g_pg);
    PG_Shutdown();
    return 0;
}
