#include "taskbar_badge.h"

#include <objidl.h>
#include <gdiplus.h>

#include <string>

TaskbarBadge::TaskbarBadge() {
  Gdiplus::GdiplusStartupInput input;
  Gdiplus::GdiplusStartup(&gdiplus_token_, &input, nullptr);
}

TaskbarBadge::~TaskbarBadge() {
  if (taskbar_) {
    taskbar_->Release();
  }
  Gdiplus::GdiplusShutdown(gdiplus_token_);
}

UINT TaskbarBadge::ButtonCreatedMessage() {
  static const UINT message = ::RegisterWindowMessageW(L"TaskbarButtonCreated");
  return message;
}

void TaskbarBadge::Attach(HWND window) { window_ = window; }

void TaskbarBadge::Set(int count) {
  count_ = count < 0 ? 0 : count;
  Apply();
}

void TaskbarBadge::OnButtonCreated() {
  if (taskbar_) {
    taskbar_->Release();
    taskbar_ = nullptr;
  }
  Apply();
}

void TaskbarBadge::Apply() {
  if (!window_) {
    return;
  }
  if (!taskbar_) {
    if (FAILED(::CoCreateInstance(CLSID_TaskbarList, nullptr, CLSCTX_INPROC_SERVER,
                                  IID_PPV_ARGS(&taskbar_))) ||
        FAILED(taskbar_->HrInit())) {
      if (taskbar_) {
        taskbar_->Release();
        taskbar_ = nullptr;
      }
      return;
    }
  }
  if (count_ == 0) {
    taskbar_->SetOverlayIcon(window_, nullptr, nullptr);
    return;
  }
  HICON icon = CreateIcon(count_);
  std::wstring description = std::to_wstring(count_) + L" heute fällig";
  taskbar_->SetOverlayIcon(window_, icon, description.c_str());
  if (icon) {
    ::DestroyIcon(icon);
  }
}

HICON TaskbarBadge::CreateIcon(int count) const {
  // The overlay is drawn at small icon size; render at the window's DPI.
  const UINT dpi = ::GetDpiForWindow(window_);
  const int size = ::GetSystemMetricsForDpi(SM_CXSMICON, dpi ? dpi : 96);
  const std::wstring text = count > 99 ? L"99+" : std::to_wstring(count);

  Gdiplus::Bitmap bitmap(size, size, PixelFormat32bppARGB);
  Gdiplus::Graphics graphics(&bitmap);
  graphics.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
  graphics.SetTextRenderingHint(Gdiplus::TextRenderingHintAntiAliasGridFit);
  graphics.Clear(Gdiplus::Color(0, 0, 0, 0));

  // A darker shade of the Home Assistant blue of the app icon, so the white
  // digits stay readable, with a white ring that separates it from the app icon.
  Gdiplus::SolidBrush ring(Gdiplus::Color(255, 255, 255, 255));
  Gdiplus::SolidBrush fill(Gdiplus::Color(255, 2, 119, 189));
  const Gdiplus::REAL border = size / 16.0f;
  graphics.FillEllipse(&ring, 0.0f, 0.0f, (Gdiplus::REAL)size, (Gdiplus::REAL)size);
  graphics.FillEllipse(&fill, border, border, size - 2 * border, size - 2 * border);

  const Gdiplus::REAL font_size = size * (text.size() == 1 ? 0.68f : text.size() == 2 ? 0.56f : 0.42f);
  Gdiplus::Font font(L"Segoe UI", font_size, Gdiplus::FontStyleBold, Gdiplus::UnitPixel);
  Gdiplus::StringFormat format;
  format.SetAlignment(Gdiplus::StringAlignmentCenter);
  format.SetLineAlignment(Gdiplus::StringAlignmentCenter);
  Gdiplus::SolidBrush white(Gdiplus::Color(255, 255, 255, 255));
  Gdiplus::RectF box(0.0f, 0.0f, (Gdiplus::REAL)size, (Gdiplus::REAL)size + size / 16.0f);
  graphics.DrawString(text.c_str(), -1, &font, box, &format, &white);

  HICON icon = nullptr;
  bitmap.GetHICON(&icon);
  return icon;
}
