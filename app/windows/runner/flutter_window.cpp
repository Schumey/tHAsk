#include "flutter_window.h"

#include <optional>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

namespace {

std::wstring Utf16FromUtf8(const std::string& text) {
  if (text.empty()) return std::wstring();
  const int length = ::MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()), nullptr, 0);
  std::wstring result(length, L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()), result.data(), length);
  return result;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

void FlutterWindow::Restore(HWND window) {
  ::ShowWindow(window, SW_SHOW);
  if (::IsIconic(window)) {
    ::ShowWindow(window, SW_RESTORE);
  }
  ::SetForegroundWindow(window);
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  badge_.Attach(GetHandle());
  tray_.Add(GetHandle(), ::LoadIcon(::GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON)));
  taskbar_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "thask/taskbar",
      &flutter::StandardMethodCodec::GetInstance());
  taskbar_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "setBadge") {
          const auto* count = std::get_if<int32_t>(call.arguments());
          badge_.Set(count ? *count : 0);
          result->Success();
        } else if (call.method_name() == "activate") {
          Restore(GetHandle());
          result->Success();
        } else if (call.method_name() == "setTray") {
          // {tooltip, open, quit} in the language of the app.
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          auto text = [args](const char* key) {
            if (!args) return std::wstring();
            auto it = args->find(flutter::EncodableValue(key));
            const auto* value = it == args->end() ? nullptr : std::get_if<std::string>(&it->second);
            return value ? Utf16FromUtf8(*value) : std::wstring();
          };
          tray_.SetTexts(text("tooltip"), text("open"), text("quit"));
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    if (!start_minimized_) {
      this->Show();
    }
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  tray_.Remove();
  taskbar_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Closing only hides the window; reminders keep coming. "Quit" in the tray menu ends the app.
  if (message == WM_CLOSE && !quitting_) {
    ::ShowWindow(hwnd, SW_HIDE);
    return 0;
  }
  if (message == TrayIcon::kCallbackMessage) {
    switch (LOWORD(lparam)) {
      case WM_LBUTTONUP:
      case NIN_SELECT:
      case NIN_KEYSELECT:
        Restore(hwnd);
        break;
      case WM_RBUTTONUP:
      case WM_CONTEXTMENU:
        switch (tray_.ShowMenu()) {
          case TrayIcon::kCommandOpen:
            Restore(hwnd);
            break;
          case TrayIcon::kCommandQuit:
            quitting_ = true;
            ::PostMessage(hwnd, WM_CLOSE, 0, 0);
            break;
        }
        break;
    }
    return 0;
  }
  if (message == TrayIcon::TaskbarCreatedMessage()) {
    tray_.Readd();
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }
  if (message == TaskbarBadge::ButtonCreatedMessage()) {
    badge_.OnButtonCreated();
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
