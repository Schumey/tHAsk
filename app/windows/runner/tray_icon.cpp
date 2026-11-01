#include "tray_icon.h"

#include <cwchar>

TrayIcon::~TrayIcon() { Remove(); }

UINT TrayIcon::TaskbarCreatedMessage() {
  static const UINT message = ::RegisterWindowMessageW(L"TaskbarCreated");
  return message;
}

void TrayIcon::Add(HWND window, HICON icon) {
  data_.cbSize = sizeof(data_);
  data_.hWnd = window;
  data_.uID = 1;
  data_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
  data_.uCallbackMessage = kCallbackMessage;
  data_.hIcon = icon;
  if (data_.szTip[0] == L'\0') {
    wcsncpy_s(data_.szTip, L"tHAsk", _TRUNCATE);
  }
  added_ = ::Shell_NotifyIconW(NIM_ADD, &data_) != FALSE;
}

void TrayIcon::Readd() {
  if (data_.hWnd) {
    Add(data_.hWnd, data_.hIcon);
  }
}

void TrayIcon::Remove() {
  if (added_) {
    ::Shell_NotifyIconW(NIM_DELETE, &data_);
    added_ = false;
  }
}

void TrayIcon::SetTexts(const std::wstring& tooltip, const std::wstring& open, const std::wstring& quit) {
  if (!open.empty()) open_ = open;
  if (!quit.empty()) quit_ = quit;
  wcsncpy_s(data_.szTip, tooltip.empty() ? L"tHAsk" : tooltip.c_str(), _TRUNCATE);
  Update(NIM_MODIFY);
}

void TrayIcon::Update(DWORD message) {
  if (added_) {
    ::Shell_NotifyIconW(message, &data_);
  }
}

UINT TrayIcon::ShowMenu() {
  HMENU menu = ::CreatePopupMenu();
  ::AppendMenuW(menu, MF_STRING, kCommandOpen, open_.c_str());
  ::AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  ::AppendMenuW(menu, MF_STRING, kCommandQuit, quit_.c_str());
  ::SetMenuDefaultItem(menu, kCommandOpen, FALSE);
  POINT cursor;
  ::GetCursorPos(&cursor);
  // Without this the menu does not close when clicking elsewhere.
  ::SetForegroundWindow(data_.hWnd);
  const UINT command = ::TrackPopupMenu(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON | TPM_NONOTIFY, cursor.x, cursor.y, 0,
                                        data_.hWnd, nullptr);
  ::DestroyMenu(menu);
  return command;
}
