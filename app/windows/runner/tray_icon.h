#ifndef RUNNER_TRAY_ICON_H_
#define RUNNER_TRAY_ICON_H_

#include <windows.h>
#include <shellapi.h>

#include <string>

// The tHAsk icon in the notification area. A click brings the window back, the
// context menu offers "Open" and "Quit". The texts come from the app
// (lib/desktop_bridge.dart), so they follow its language.
class TrayIcon {
 public:
  // Window message the icon sends to the window.
  static constexpr UINT kCallbackMessage = WM_APP + 42;
  // Commands of the context menu.
  static constexpr UINT kCommandOpen = 1;
  static constexpr UINT kCommandQuit = 2;

  TrayIcon() = default;
  ~TrayIcon();

  // Sent by Explorer when the taskbar was (re)created; the icon must be added again.
  static UINT TaskbarCreatedMessage();

  void Add(HWND window, HICON icon);
  void Remove();
  void Readd();

  void SetTexts(const std::wstring& tooltip, const std::wstring& open, const std::wstring& quit);

  // Shows the context menu at the cursor and returns the chosen command (0 for none).
  UINT ShowMenu();

 private:
  void Update(DWORD message);

  NOTIFYICONDATAW data_ = {};
  bool added_ = false;
  std::wstring open_ = L"Open";
  std::wstring quit_ = L"Quit";
};

#endif  // RUNNER_TRAY_ICON_H_
